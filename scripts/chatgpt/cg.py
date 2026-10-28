#!/usr/bin/env python3
"""Organize and clean up the ChatGPT website — from the official data export.

ChatGPT's web app has no public API for history. The one sanctioned way to read
it is Settings -> Data controls -> Export data. So this tool works in two
phases, both local:

    ingest   build a local index from the export (zip or conversations.json)
    plan     write a triage plan: what goes into which Project, what to archive,
             what is safe to delete — each row with a direct chat link

It never signs in, never calls back into chatgpt.com, never deletes anything.
You act in the web UI; the plan tells you exactly what to click.

    python cg.py ingest ~/Downloads/chatgpt-export.zip
    python cg.py plan
    python cg.py status

Archiving is the only write path, and it is opt-in and reversible:

    python cg.py auth                         # validate the browser session
    python cg.py archive                      # dry-run: who would be archived
    python cg.py archive --yes --limit 20     # archive 20, 1.5s apart
    python cg.py unarchive --log <jsonl>      # undo

It uses the session cookie you paste in, hits the same endpoint the web app
uses, and stops at the first 401/403/429 instead of hammering your account.
Bulk reads (`sync --deep`, `export --fetch`) stop on 429 too and keep their
progress; `--deep` is capped per run and resumes where it left off. There is
deliberately no delete function in this file.

Re-running ingest with a newer export only adds what is new: every conversation
is keyed by its ChatGPT id. Old verdicts are recomputed, never resurrected.
"""

from __future__ import annotations

import argparse
import contextlib
import errno
import fcntl
import hashlib
import json
import logging
import os
import random
import re
import signal
import sqlite3
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from email.utils import parsedate_to_datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path
from urllib.request import Request, urlopen

# Roles and content types that carry real conversation text. The rest of the
# export (thoughts, tool output, browsing stubs, memory context) is machine
# noise and would skew every keyword score.
KEEP_ROLES = {"user", "assistant"}
DROP_CONTENT = {
    "thoughts",
    "reasoning_recap",
    "user_editable_context",
    "model_editable_context",
    "system_error",
    "execution_output",
    "tether_browsing_display",
}
ASSET_LABEL = {
    "image_asset_pointer": "[imagem]",
    "audio_asset_pointer": "[áudio]",
    "file": "[arquivo]",
    "video_asset_pointer": "[vídeo]",
}

# Suggested ChatGPT Projects. Terms are matched as distinct hits, not counts, so
# one chat that repeats "linux" forty times does not outvote a mixed chat.
PROJECTS: dict[str, tuple[str, ...]] = {
    "Linux & Arch": (
        "arch linux",
        "archlinux",
        "pacman",
        "aur",
        "systemd",
        "journalctl",
        "grub",
        "hyprland",
        "niri",
        "wayland",
        "btrfs",
        "luks",
        "initramfs",
        "zram",
        "bootloader",
        "kernel panic",
    ),
    "NixOS & Dotfiles": (
        "nixos",
        "nixpkgs",
        "flake",
        "home-manager",
        "nix-shell",
        "dotfiles",
        "stow",
        "nix flake",
    ),
    "Self-hosting": (
        "podman",
        "docker",
        "quadlet",
        "container",
        "searxng",
        "dnscrypt",
        "tor",
        "proxy",
        "nginx",
        "unbound",
        "homelab",
        "vps",
        "self-host",
        "servidor",
        "dns",
    ),
    "AI & Agents": (
        "chatgpt",
        "openai",
        "llm",
        "prompt",
        "opencode",
        "mcp",
        "claude",
        "gemini",
        "ollama",
        "agente",
        "modelo de linguagem",
        "gguf",
        "hugging face",
        "token",
        "contexto",
    ),
    "Math & Study": (
        "matemática",
        "matematica",
        "cálculo",
        "calculo",
        "álgebra",
        "algebra",
        "geometria",
        "trigonometria",
        "derivada",
        "integral",
        "equação",
        "equacao",
        "logaritmo",
        "progressão",
        "progressao",
        "função",
        "conjunto",
        "probabilidade",
    ),
    "Anki & Learning": (
        "anki",
        "flashcard",
        "mnemônico",
        "mnemonico",
        "revisão espaçada",
        "revisao espacada",
        "active recall",
        "técnica de estudo",
        "feynman",
        "estudar para",
        "memorizar",
    ),
    "Language": (
        "português",
        "portugues",
        "gramática",
        "gramatica",
        "sintaxe",
        "morfologia",
        "ortografia",
        "redação",
        "redacao",
        "conjugação",
        "conjugacao",
        "crase",
        "inglês",
        "ingles",
        "phrasal verb",
    ),
    "Career & Education": (
        "currículo",
        "curriculo",
        "resume",
        "entrevista",
        "estágio",
        "estagio",
        "faculdade",
        "universidade",
        "enem",
        "vestibular",
        "concurso",
        "emprego",
        "carreira",
        "vaga",
    ),
    "Hardware & Shopping": (
        "notebook",
        "laptop",
        "placa de vídeo",
        "placa de video",
        "ssd",
        "memória ram",
        "memoria ram",
        "processador",
        "comprar",
        "preço",
        "preco",
        "vale a pena",
        "aliexpress",
        "monitor",
        "teclado",
        "celular",
        "mini pc",
    ),
    "Health & Personal": (
        "médico",
        "medico",
        "remédio",
        "remedio",
        "tdah",
        "ansiedade",
        "sono",
        "psicólogo",
        "psicologo",
        "saúde",
        "saude",
        "rotina",
    ),
    # --- craft & machines ------------------------------------------------- #
    "Programming": (
        "python",
        "javascript",
        "typescript",
        "golang",
        "linguagem c",
        "c++",
        "rust",
        "sql",
        "git ",
        "regex",
        "compilador",
        "compiler",
        "segfault",
        "stack trace",
        "traceback",
        "refatorar",
        "algoritmo",
        "virtualenv",
        "pip install",
        "npm install",
        "framework",
        "biblioteca",
        "api",
        "json",
        "yaml",
        "teste unitário",
        "teste unitario",
        "unit test",
    ),
    "DIY & Electronics": (
        "solda",
        "soldar",
        "arduino",
        "esp32",
        "multímetro",
        "multimetro",
        "impressão 3d",
        "impressao 3d",
        "3d printer",
        "eletrônica",
        "eletronica",
        "consertar",
        "reparo",
        "furadeira",
        "marcenaria",
        "madeira",
    ),
    "Cars & Transport": (
        "carro",
        "moto",
        "pneu",
        "óleo do motor",
        "oleo do motor",
        "gasolina",
        "mecânico",
        "mecanico",
        "bicicleta",
        "transporte público",
        "transporte publico",
        "ônibus",
        "onibus",
        "metrô",
        "metro",
        "passagem de ônibus",
    ),
    # --- life outside the terminal ---------------------------------------- #
    "Money & Finance": (
        "finanças",
        "financas",
        "orçamento",
        "orcamento",
        "investimento",
        "investir",
        "ações",
        "acoes",
        "renda fixa",
        "tesouro direto",
        "cdb",
        "juros",
        "dívida",
        "divida",
        "empréstimo",
        "emprestimo",
        "imposto",
        "irpf",
        "receita federal",
        "cripto",
        "bitcoin",
        "poupança",
        "poupanca",
        "inflação",
        "inflacao",
        "câmbio",
        "cambio",
        "financiamento",
        "aposentadoria",
    ),
    "Legal & Bureaucracy": (
        "contrato",
        "documento",
        "passaporte",
        "visto",
        "consulado",
        "certidão",
        "certidao",
        "cartório",
        "cartorio",
        "cpf",
        "cnh",
        "inss",
        "previdência",
        "previdencia",
        "advogado",
        "direito",
        "multa",
        "rescisão",
        "rescisao",
        "imigração",
        "imigracao",
        "cidadania",
    ),
    "Home & Kitchen": (
        "receita",
        "cozinhar",
        "ingrediente",
        "forno",
        "panela",
        "limpeza",
        "faxina",
        "móveis",
        "moveis",
        "geladeira",
        "máquina de lavar",
        "maquina de lavar",
        "apartamento",
        "aluguel",
        "mudança",
        "mudanca",
        "organização da casa",
        "organizacao da casa",
    ),
    "Food & Nutrition": (
        "dieta",
        "calorias",
        "proteína",
        "proteina",
        "carboidrato",
        "jejum",
        "vegetariano",
        "vegano",
        "suplemento",
        "vitamina",
        "hidratação",
        "hidratacao",
        "comida saudável",
        "comida saudavel",
        "cardápio",
        "cardapio",
    ),
    "Travel & Places": (
        "viagem",
        "viajar",
        "passagem aérea",
        "passagem aerea",
        "voo",
        "hotel",
        "turismo",
        "roteiro de viagem",
        "praia",
        "mochilão",
        "mochilao",
        "destino",
        "turista",
        "trip",
        "flight",
        "hostel",
    ),
    "Relationships & Family": (
        "namoro",
        "relacionamento",
        "amizade",
        "amigo",
        "família",
        "familia",
        "mãe",
        "mae",
        "pai",
        "irmão",
        "irmao",
        "filho",
        "filha",
        "casamento",
        "conflito",
        "ciúmes",
        "ciumes",
        "tinder",
        "dating",
        "terapia de casal",
    ),
    "Fitness & Sport": (
        "academia",
        "treino",
        "musculação",
        "musculacao",
        "corrida",
        "correr",
        "ciclismo",
        "natação",
        "natacao",
        "futebol",
        "basquete",
        "alongamento",
        "calistenia",
        "emagrecer",
        "ganhar massa",
        "exercício",
        "exercicio",
    ),
    "Style & Appearance": (
        "roupa",
        "vestuário",
        "vestuario",
        "estilo",
        "moda",
        "corte de cabelo",
        "barba",
        "skincare",
        "perfume",
        "maquiagem",
        "guarda-roupa",
        "look",
    ),
    # --- thinking & culture ------------------------------------------------ #
    "Writing & Arts": (
        "escrever",
        "escrita",
        "ensaio",
        "poema",
        "roteiro",
        "personagem",
        "romance",
        "desenho",
        "pintura",
        "design",
        "fotografia",
        "ilustração",
        "ilustracao",
        "tipografia",
        "criatividade",
    ),
    "Music & Audio": (
        "música",
        "musica",
        "guitarra",
        "violão",
        "violao",
        "piano",
        "acorde",
        "escala musical",
        "harmonia",
        "produção musical",
        "producao musical",
        "ableton",
        "mixagem",
        "fone de ouvido",
    ),
    "Games & Fun": (
        "jogo",
        "steam",
        "rpg",
        "dungeons",
        "minecraft",
        "zelda",
        "pokémon",
        "pokemon",
        "xadrez",
        "quebra-cabeça",
        "quebra-cabeca",
        "piada",
        "humor",
    ),
    "Media & Entertainment": (
        "filme",
        "série",
        "serie",
        "anime",
        "mangá",
        "manga",
        "documentário",
        "documentario",
        "podcast",
        "netflix",
        "youtube",
        "resenha",
        "recomendação de",
        "recomendacao de",
    ),
    "Science & Space": (
        "física",
        "fisica",
        "química",
        "quimica",
        "biologia",
        "astronomia",
        "universo",
        "planeta",
        "relatividade",
        "quântica",
        "quantica",
        "evolução",
        "evolucao",
        "célula",
        "celula",
        "dna",
        "átomo",
        "atomo",
        "experimento",
    ),
    "Politics & Society": (
        "política",
        "politica",
        "eleição",
        "eleicao",
        "governo",
        "notícia",
        "noticia",
        "guerra",
        "democracia",
        "esquerda",
        "direita",
        "violência",
        "violencia",
        "sociedade",
    ),
    "Philosophy & Spirituality": (
        "filosofia",
        "ética",
        "etica",
        "existencial",
        "sentido da vida",
        "estoicismo",
        "religião",
        "religiao",
        "bíblia",
        "biblia",
        "meditação",
        "meditacao",
        "espiritualidade",
        "budismo",
        "consciência",
        "consciencia",
        "moral",
    ),
    # --- what comes next --------------------------------------------------- #
    "Future & Life Planning": (
        "futuro",
        "planejamento de vida",
        "plano de vida",
        "objetivo de vida",
        "objetivos de vida",
        "metas",
        "hábitos",
        "habitos",
        "disciplina",
        "propósito",
        "proposito",
        "mudar de carreira",
        "morar fora",
        "mudar de país",
        "mudar de pais",
        "cinco anos",
        "5 anos",
        "autorreflexão",
        "autorreflexao",
        "mudança de vida",
        "mudanca de vida",
        "decisão de vida",
        "decisao de vida",
    ),
    "Gardening & Nature": (
        "planta",
        "jardim",
        "horta",
        "cultivo",
        "sementes",
        "adubo",
        "natureza",
        "meio ambiente",
        "sustentabilidade",
        "compostagem",
    ),
    "Pets & Animals": (
        "cachorro",
        "gato",
        "pet",
        "ração",
        "racao",
        "veterinário",
        "veterinario",
        "adestramento",
        "pássaro",
        "passaro",
        "aquário",
        "aquario",
    ),
}
PROJECT_MIN_HITS = 2

STATE_DIR = Path(
    os.environ.get("CG_STATE_DIR")
    or (
        Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
        / "cg"
    )
)
DB_PATH = STATE_DIR / "cg.db"
REPORT_DIR = STATE_DIR / "reports"
EXPORT_DIR = Path(
    os.environ.get("CG_EXPORT_DIR") or (Path.home() / "Documents" / "ChatGPT")
)

# Debug trail lives with the other throwaway data, not with the index.
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "cg"
CONV_CACHE_DIR = CACHE_DIR / "convs"
LOG_PATH = CACHE_DIR / "cg.log"

log = logging.getLogger("cg")

WS = re.compile(r"\s+")


# --------------------------------------------------------------------------- #
# export parsing
# --------------------------------------------------------------------------- #


def load_export(source: Path) -> tuple[list[dict], list[str]]:
    """Return (conversations, member names) from a .zip, a .json, or a folder."""
    if source.is_dir():
        files = sorted(source.glob("conversations*.json"))
        if not files:
            raise SystemExit(f"error: no conversations*.json in {source}")
        convs: list[dict] = []
        for f in files:
            convs.extend(_as_list(json.loads(f.read_text(encoding="utf-8"))))
        return convs, [f.name for f in files]

    if source.suffix.lower() == ".zip":
        convs, members = [], []
        with zipfile.ZipFile(source) as zf:
            for name in zf.namelist():
                if not re.fullmatch(r"conversations(-\d+)?\.json", Path(name).name):
                    continue
                members.append(Path(name).name)
                convs.extend(_as_list(json.loads(zf.read(name).decode("utf-8"))))
        if not members:
            raise SystemExit(f"error: no conversations*.json inside {source.name}")
        return convs, members

    if source.suffix.lower() == ".json":
        return _as_list(json.loads(source.read_text(encoding="utf-8"))), [source.name]

    raise SystemExit(f"error: expected .zip, .json or a directory, got {source}")


def _as_list(data) -> list[dict]:
    if isinstance(data, list):
        return [c for c in data if isinstance(c, dict)]
    if isinstance(data, dict) and isinstance(data.get("conversations"), list):
        return [c for c in data["conversations"] if isinstance(c, dict)]
    raise SystemExit(
        "error: not a ChatGPT conversations file (no list, no 'conversations' key)"
    )


def message_text(msg: dict) -> str:
    content = msg.get("content") or {}
    if not isinstance(content, dict):
        return ""
    if content.get("content_type") in DROP_CONTENT:
        return ""
    parts = content.get("parts")
    if not isinstance(parts, list):
        text = content.get("text")
        return text.strip() if isinstance(text, str) else ""

    out = []
    for part in parts:
        if isinstance(part, str):
            if part.strip():
                out.append(part.strip())
        elif isinstance(part, dict):
            label = ASSET_LABEL.get(part.get("content_type", ""))
            if label:
                out.append(label)
            elif isinstance(part.get("text"), str) and part["text"].strip():
                out.append(part["text"].strip())
    return "\n\n".join(out)


def active_branch(conv: dict) -> list[dict]:
    """Follow current_node -> parent -> root.

    Blindly iterating mapping.values() mixes abandoned edit branches into the
    transcript and loses the order; this is the branch the author actually sees.
    """
    mapping = conv.get("mapping")
    if not isinstance(mapping, dict) or not mapping:
        return []

    node_id = conv.get("current_node")
    if node_id not in mapping:
        leaves = [
            nid
            for nid, node in mapping.items()
            if isinstance(node, dict) and not node.get("children")
        ]
        if not leaves:
            return []
        node_id = max(
            leaves,
            key=lambda nid: (mapping[nid].get("message") or {}).get("create_time") or 0,
        )

    chain, seen = [], set()
    while node_id and node_id in mapping and node_id not in seen:
        seen.add(node_id)
        node = mapping[node_id]
        if isinstance(node, dict):
            chain.append(node)
        node_id = node.get("parent") if isinstance(node, dict) else None
    chain.reverse()
    return chain


@dataclass
class Turn:
    role: str
    text: str


@dataclass
class Conversation:
    conv_id: str
    title: str
    created: datetime | None
    archived: bool = False
    project_id: str | None = None
    turns: list[Turn] = field(default_factory=list)

    @property
    def user_chars(self) -> int:
        return sum(len(t.text) for t in self.turns if t.role == "user")

    @property
    def body_sha(self) -> str:
        blob = "\n".join(f"{t.role}:{t.text}" for t in self.turns)
        return hashlib.sha256(WS.sub(" ", blob).strip().encode()).hexdigest()

    @property
    def first_user(self) -> str:
        for t in self.turns:
            if t.role == "user":
                return WS.sub(" ", t.text).strip()[:200].casefold()
        return ""


def parse_conversation(raw: dict) -> Conversation:
    turns = []
    for node in active_branch(raw):
        msg = node.get("message")
        if not isinstance(msg, dict):
            continue
        if ((msg.get("author") or {}).get("role") or "").lower() not in KEEP_ROLES:
            continue
        text = message_text(msg)
        if text:
            turns.append(Turn(msg["author"]["role"].lower(), text))

    created = None
    ts = raw.get("create_time")
    if isinstance(ts, str) and ts:
        try:  # the API returns ISO-8601, the export returns an epoch float
            created = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        except ValueError:
            created = None
    elif isinstance(ts, (int, float)) and ts > 0:
        created = datetime.fromtimestamp(ts).astimezone()

    title = WS.sub(" ", str(raw.get("title") or "")).strip()
    if not title or title.casefold() in {"new chat", "novo chat"}:
        title = next((t.text for t in turns if t.role == "user"), "").split("\n", 1)[0][
            :80
        ]
        title = title.strip() or "(sem título)"

    project_id = raw.get("gizmo_id")
    return Conversation(
        conv_id=str(raw.get("id") or raw.get("conversation_id") or ""),
        title=title,
        created=created,
        archived=bool(raw.get("is_archived", False)),
        project_id=str(project_id) if project_id else None,
        turns=turns,
    )


# --------------------------------------------------------------------------- #
# index
# --------------------------------------------------------------------------- #


def connect() -> sqlite3.Connection:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS conversations (
            conv_id      TEXT PRIMARY KEY,
            title        TEXT NOT NULL,
            created_ts   REAL,
            turns        INTEGER NOT NULL,
            user_turns   INTEGER NOT NULL DEFAULT 0,
            user_chars   INTEGER NOT NULL,
            body_sha     TEXT NOT NULL,
            first_user   TEXT NOT NULL,
            sample       TEXT NOT NULL,
            archived     INTEGER NOT NULL DEFAULT 0,
            has_content  INTEGER NOT NULL DEFAULT 0,
            -- the server answered 404: listed in the sidebar, gone for real.
            gone         INTEGER NOT NULL DEFAULT 0,
            project_id   TEXT,
            source_file  TEXT,
            indexed_at   TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS sources (
            path    TEXT PRIMARY KEY,
            sha256  TEXT NOT NULL,
            size    INTEGER NOT NULL,
            seen_at TEXT NOT NULL,
            n_convs INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS c_sha   ON conversations(body_sha);
        CREATE INDEX IF NOT EXISTS c_first ON conversations(first_user);
        """
    )
    # Migration for indexes created before content tracking existed.
    cols = {row[1] for row in con.execute("PRAGMA table_info(conversations)")}
    if "has_content" not in cols:
        con.execute(
            "ALTER TABLE conversations ADD COLUMN has_content INTEGER NOT NULL "
            "DEFAULT 0"
        )
        con.execute("UPDATE conversations SET has_content = 1 WHERE turns > 0")
    if "user_turns" not in cols:
        con.execute(
            "ALTER TABLE conversations ADD COLUMN user_turns INTEGER NOT NULL DEFAULT 0"
        )
    if "project_id" not in cols:
        con.execute("ALTER TABLE conversations ADD COLUMN project_id TEXT")
    if "gone" not in cols:
        con.execute(
            "ALTER TABLE conversations ADD COLUMN gone INTEGER NOT NULL DEFAULT 0"
        )
    con.commit()
    return con


def record(
    con: sqlite3.Connection,
    conv: Conversation,
    source: str,
    now: str,
    fetched: bool | None = None,
) -> bool:
    """Upsert one conversation. Returns True when it was not indexed before.

    `fetched` marks that the message bodies came from a full fetch (the API list
    endpoint returns an empty mapping), so an empty chat can be told apart from
    an unfetched one.
    """
    sample = WS.sub(" ", " ".join(t.text for t in conv.turns))[:6000]
    existed = con.execute(
        "SELECT 1 FROM conversations WHERE conv_id = ?", (conv.conv_id,)
    ).fetchone()
    con.execute(
        """INSERT INTO conversations
             (conv_id, title, created_ts, turns, user_turns, user_chars, body_sha,
              first_user, sample, archived, has_content, project_id, source_file,
              indexed_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
           ON CONFLICT(conv_id) DO UPDATE SET
             title=excluded.title, created_ts=excluded.created_ts,
             -- the list endpoint carries no bodies: never let it erase content
             -- that a deep fetch already stored.
             turns      = CASE WHEN excluded.has_content = 1
                               THEN excluded.turns      ELSE conversations.turns END,
             user_turns = CASE WHEN excluded.has_content = 1
                               THEN excluded.user_turns
                               ELSE conversations.user_turns END,
             user_chars = CASE WHEN excluded.has_content = 1
                               THEN excluded.user_chars
                               ELSE conversations.user_chars END,
             body_sha   = CASE WHEN excluded.has_content = 1
                               THEN excluded.body_sha   ELSE conversations.body_sha END,
             first_user = CASE WHEN excluded.has_content = 1
                               THEN excluded.first_user
                               ELSE conversations.first_user END,
             sample     = CASE WHEN excluded.has_content = 1
                               THEN excluded.sample     ELSE conversations.sample END,
             archived=excluded.archived,
             -- membership changes on the website, so the freshest list wins
             project_id=excluded.project_id,
             has_content=MAX(excluded.has_content, conversations.has_content),
             -- seeing it again means the server still has it: clear any 404 mark
             gone=0,
             source_file=excluded.source_file, indexed_at=excluded.indexed_at""",
        (
            conv.conv_id,
            conv.title,
            conv.created.timestamp() if conv.created else None,
            len(conv.turns),
            sum(1 for t in conv.turns if t.role == "user"),
            conv.user_chars,
            conv.body_sha,
            conv.first_user,
            sample,
            int(conv.archived),
            int(bool(conv.turns)) if fetched is None else int(fetched),
            conv.project_id,
            source,
            now,
        ),
    )
    return not existed


def mark_gone(con: sqlite3.Connection, conv_id: str) -> None:
    """Record that the server has no such conversation (404).

    The account listing keeps handing out chats that were deleted or never
    persisted: they still show in the sidebar index, but every write to them
    answers 404. Flagging them keeps `plan`, `organize` and `archive` from
    burning a request on them on every run.
    """
    con.execute("UPDATE conversations SET gone = 1 WHERE conv_id = ?", (conv_id,))


def cmd_ingest(args) -> int:
    source = Path(args.source).expanduser()
    if not source.exists():
        raise SystemExit(f"error: {source} not found")

    raw_convs, members = load_export(source)
    con = connect()
    now = datetime.now().isoformat(timespec="seconds")
    new = updated = 0

    for raw in raw_convs:
        conv = parse_conversation(raw)
        if not conv.conv_id:
            continue
        if record(con, conv, source.name, now):
            new += 1
        else:
            updated += 1

    digest = hashlib.sha256(source.read_bytes()).hexdigest() if source.is_file() else ""
    con.execute(
        """INSERT INTO sources (path, sha256, size, seen_at, n_convs) VALUES (?,?,?,?,?)
           ON CONFLICT(path) DO UPDATE SET sha256=excluded.sha256, size=excluded.size,
             seen_at=excluded.seen_at, n_convs=excluded.n_convs""",
        (
            str(source),
            digest,
            source.stat().st_size if source.is_file() else 0,
            now,
            len(raw_convs),
        ),
    )
    con.commit()
    total = con.execute("SELECT COUNT(*) FROM conversations").fetchone()[0]

    print(f"export    : {source.name} → {', '.join(members)}")
    print(f"lidas     : {len(raw_convs)}")
    print(f"novas     : {new}")
    print(f"atualizadas: {updated}")
    print(f"índice    : {total} conversas")
    print("\npróximo passo: cg.py plan")
    return 0


# --------------------------------------------------------------------------- #
# classification
# --------------------------------------------------------------------------- #


# Terms that are unambiguous on their own: matching one is as strong a signal as
# a two-word phrase, so they count double.
STRONG = frozenset(
    {
        "nixos",
        "nixpkgs",
        "pacman",
        "systemd",
        "grub",
        "btrfs",
        "luks",
        "initramfs",
        "zram",
        "podman",
        "quadlet",
        "kubernetes",
        "traefik",
        "tailscale",
        "wireguard",
        "searxng",
        "anki",
        "irpf",
        "inss",
        "cpf",
        "cnh",
        "tesouro direto",
        "arduino",
        "esp32",
        "ableton",
        "minecraft",
        "netflix",
        "tinder",
        "skincare",
        "estagio",
        "vestibular",
        "enem",
        "aposentadoria",
    }
)
TOKEN_RE = re.compile(r"[a-z0-9+#]+")
_TERM_CACHE: dict[str, list[tuple[str, int]]] | None = None


def fold(text: str) -> str:
    """Casefold and strip accents/hyphens so 'musica' and 'música' are the same."""
    text = unicodedata.normalize("NFD", text.casefold())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return text.replace("-", " ").replace("_", " ")


def _grams(text: str) -> set[str]:
    """Words and 2/3-word windows, so matching is boundary-exact and O(1)."""
    words = TOKEN_RE.findall(fold(text))
    grams = set(words)
    for n in (2, 3):
        grams.update(
            " ".join(words[i : i + n]) for i in range(max(0, len(words) - n + 1))
        )
    return grams


def _term_index() -> dict[str, list[tuple[str, int]]]:
    global _TERM_CACHE
    if _TERM_CACHE is None:
        _TERM_CACHE = {
            project: [
                (fold(term), 2 if (" " in fold(term) or fold(term) in STRONG) else 1)
                for term in terms
            ]
            for project, terms in PROJECTS.items()
        }
    return _TERM_CACHE


def jitter(span: float) -> float:
    """Small random delay so requests do not march in lockstep.

    Not a security decision, hence the S311 waiver.
    """
    return random.uniform(0, span)  # noqa: S311  # nosec B311


def classify(text: str) -> tuple[str | None, int, int]:
    """Return (project, score, runner_up_score).

    Score is weighted: a phrase or an unambiguous token counts 2, a common word
    counts 1. A project needs at least 2 points to win, and the caller also
    demands a margin over the runner-up, so ambiguous chats land in review
    instead of being filed by a single accidental match.
    """
    grams = _grams(text)
    scores = {
        project: sum(weight for term, weight in terms if term in grams)
        for project, terms in _term_index().items()
    }
    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    best, score = ranked[0]
    runner = ranked[1][1] if len(ranked) > 1 else 0
    return (best if score >= PROJECT_MIN_HITS else None), score, runner


def bucket_of(row: sqlite3.Row, dupe_reason: str | None) -> str:
    # A listing from the API has no message bodies: absence of content is not
    # evidence that the chat is empty, so it must never be auto-archived.
    if not row["has_content"]:
        return "unknown"
    if row["turns"] == 0 or row["user_chars"] == 0:
        return "delete"
    if dupe_reason:
        return "archive"
    # one question, at most one answer, and a short question: the classic
    # throwaway chat that only adds noise to the sidebar.
    if row["user_turns"] <= 1 and row["turns"] <= 2 and row["user_chars"] < 300:
        return "archive"
    return "keep"


# --------------------------------------------------------------------------- #
# export helpers
# --------------------------------------------------------------------------- #


def slugify(name: str, maxlen: int = 80) -> str:
    text = WS.sub(" ", str(name or "")).strip()
    if not text:
        text = "sem-titulo"
    text = unicodedata.normalize("NFD", text.casefold())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    if not text:
        text = "sem-titulo"
    return text[:maxlen].strip("-") or "sem-titulo"


def project_folder_name(project: str) -> str:
    if not project or project == "Inbox":
        return "Inbox"
    # Keep human-readable but filesystem-safe
    name = WS.sub(" ", project).strip()
    name = unicodedata.normalize("NFD", name)
    name = "".join(c for c in name if unicodedata.category(c) != "Mn")
    name = re.sub(r'[<>:"/\\|?*]+', " ", name)
    name = WS.sub(" ", name).strip()
    return name or "Inbox"


def conv_to_markdown(conv: Conversation) -> str:
    out = []
    title = conv.title or "(sem título)"
    out.append(f"# {title}")
    out.append("")
    meta = []
    if conv.conv_id:
        meta.append(f"- ChatGPT: https://chatgpt.com/c/{conv.conv_id}")
    if conv.created:
        meta.append(f"- Criado: {conv.created.isoformat()}")
    if conv.archived:
        meta.append("- Arquivado: sim")
    if conv.project_id:
        meta.append(f"- Project ID: {conv.project_id}")
    if meta:
        out.extend(meta)
        out.append("")
    out.append("---")
    out.append("")
    if not conv.turns:
        out.append("_Sem conteúdo._")
        out.append("")
        return "\n".join(out)
    for turn in conv.turns:
        if turn.role == "user":
            out.append("## Pergunta")
        elif turn.role == "assistant":
            out.append("## Resposta")
        else:
            out.append(f"## {turn.role}")
        out.append("")
        text = turn.text.rstrip()
        out.append(text)
        out.append("")
    return "\n".join(out)


class RateLimited(SystemExit):
    """HTTP 429 during a bulk read: stop the whole run, do not hammer every row.

    Write commands already abort on 429. The read loops used to count the 429 as
    one failed row and keep going, which is exactly the pattern the backend
    throttles. Raising this unwinds the command with a clear message; the index
    is committed before it leaves.
    """


def fetch_conv_raw(
    base: str, token: str, conv_id: str, *, force: bool = False
) -> dict | None:
    CONV_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = CONV_CACHE_DIR / f"{conv_id}.json"
    if not force and cache.exists():
        try:
            return json.loads(cache.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            # A truncated or half-written cache is worse than none: drop it and
            # let the fetch below repopulate the file.
            log.debug("cache ilegível, refazendo: %s", cache.name)
            cache.unlink(missing_ok=True)
    url = f"{base}/backend-api/conversation/{conv_id}"
    status, body = http_json("GET", url, api_headers(token, base), retries=3)
    if status == 429:
        raise RateLimited(
            "error: HTTP 429 ao baixar conteúdo — o ChatGPT pediu pausa.\n"
            "  Nada foi perdido: rode o mesmo comando daqui a ~1h "
            "(o progresso fica salvo)."
        )
    if status in (401, 403):
        raise SystemExit(
            f"error: HTTP {status} ao baixar conteúdo — sessão expirada ou sem "
            "permissão."
        )
    if status != 200:
        log.warning("conversa %s: HTTP %d ao baixar o corpo", conv_id, status)
        return None
    try:
        data = json.loads(body)
    except ValueError:
        return None
    # Write through a temp file: a Ctrl+C in the middle must not leave a
    # half-written cache that the next run has to throw away.
    tmp = cache.with_name(f".{cache.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(data), encoding="utf-8")
        os.replace(tmp, cache)
    except OSError as exc:
        log.debug("não gravou o cache %s: %s", cache.name, exc)
        tmp.unlink(missing_ok=True)
    return data


def load_conv_full(
    con: sqlite3.Connection,
    row: sqlite3.Row,
    base: str | None,
    token: str | None,
    *,
    force: bool = False,
) -> tuple[Conversation, bool]:
    """Return (conversation, fetched_now). Cache is read unless `force`."""
    # Try cache first
    CONV_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = CONV_CACHE_DIR / f"{row['conv_id']}.json"
    raw = None
    if not force and cache.exists():
        try:
            raw = json.loads(cache.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            raw = None
    fetched = False
    if raw is None and base and token and row["conv_id"]:
        raw = fetch_conv_raw(base, token, row["conv_id"], force=force)
        fetched = raw is not None
    if raw is None:
        # Fall back to DB metadata only - no turns
        created = None
        if row["created_ts"]:
            try:
                created = datetime.fromtimestamp(row["created_ts"]).astimezone()
            except (OSError, OverflowError, ValueError):
                created = None
        return (
            Conversation(
                conv_id=row["conv_id"],
                title=row["title"] or "(sem título)",
                created=created,
                archived=bool(row["archived"]),
                project_id=row["project_id"],
                turns=[],
            ),
            fetched,
        )
    return parse_conversation(raw), fetched


def build_plan(rows: list[sqlite3.Row]) -> list[dict]:
    """Attach project + verdict to every conversation. Shared by plan/archive."""
    # Duplicates: identical transcript, or the identical opening question
    # (people restart a chat when the first answer goes sideways).
    by_sha: dict[str, list] = {}
    by_first: dict[str, list] = {}
    for r in rows:
        if r["body_sha"] and r["user_chars"] >= 200:
            by_sha.setdefault(r["body_sha"], []).append(r)
        if r["first_user"] and len(r["first_user"]) >= 40:
            by_first.setdefault(r["first_user"], []).append(r)

    dupes: dict[str, str] = {}
    for group in list(by_sha.values()) + list(by_first.values()):
        if len(group) > 1:
            ordered = sorted(group, key=lambda r: r["created_ts"] or 0)
            label = (
                "mesma conversa"
                if len({r["body_sha"] for r in ordered}) == 1
                else "mesma pergunta inicial"
            )
            for r in ordered[1:]:
                dupes.setdefault(r["conv_id"], label)

    plans = []
    for r in rows:
        # Titles carry strong signal ("Zram And Swapfile") and cost nothing to read.
        project, hits, runner = classify(f"{r['title']} {r['sample'] or ''}")
        verdict = bucket_of(r, dupes.get(r["conv_id"]))
        if verdict == "keep" and (project is None or hits - runner < 2):
            verdict = "review"
        plans.append(
            {
                "row": r,
                "project": project or "Inbox",
                "hits": hits,
                "verdict": verdict,
                "dupe": dupes.get(r["conv_id"]),
            }
        )
    return plans


def cmd_plan(args) -> int:
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        raise SystemExit("error: empty index — run `cg.py ingest <export>` first")

    now = datetime.now().astimezone()
    cutoff = now - timedelta(days=args.days)
    plans = build_plan(rows)

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = now.strftime("%Y%m%d-%H%M")
    md_path = REPORT_DIR / f"plan-{stamp}.md"
    tsv_path = REPORT_DIR / f"plan-{stamp}.tsv"

    def date_of(r) -> str:
        return (
            datetime.fromtimestamp(r["created_ts"]).strftime("%Y-%m-%d")
            if r["created_ts"]
            else "?"
        )

    def link(r) -> str:
        return f"https://chatgpt.com/c/{r['conv_id']}"

    def cell(text: str, width: int) -> str:
        return text.replace("|", "\\|")[:width]

    counts = {"keep": 0, "review": 0, "archive": 0, "delete": 0, "unknown": 0}
    per_project: dict[str, list] = {}
    for p in plans:
        counts[p["verdict"]] += 1
        if p["verdict"] in {"keep", "review"}:
            per_project.setdefault(p["project"], []).append(p)

    out = [
        f"# ChatGPT — plano de organização ({now.strftime('%Y-%m-%d %H:%M')})",
        "",
        f"Índice local: `{DB_PATH}` · {len(rows)} conversas. ",
        (
            "Caso queira atualizar, exporte de novo em chatgpt.com → "
            "Configurações → Controles de dados → Exportar dados."
        ),
        "",
        "| | |",
        "|---|---|",
        f"| manter / organizar | {counts['keep']} |",
        f"| revisar (classificação incerta) | {counts['review']} |",
        f"| arquivar | {counts['archive']} |",
        f"| vazias (sugeridas para checagem) | {counts['delete']} |",
        f"| sem conteúdo indexado | {counts['unknown']} |",
        "",
        (
            "Arquivar só tira da lista principal, mas fica em 'Arquivados' e dá pra "
            "restaurar depois.\n"
            "Nenhuma conversa é apagada por esse script. A seção de vazias é só pra "
            "você conferir no site."
        ),
        "",
        "## 1. Projects",
        "",
        (
            "Pra aplicar por lote: `cg organize` (simulação) e `cg organize --yes`.\n"
            "O que ficar sem encaixe vai parar no Project `Inbox`.\n"
            "Também dá pra mover manualmente pelo menu `…` → *Move to project*. "
            "Conversas de GPTs personalizados nem sempre permitem mover."
        ),
        "",
    ]

    for project in sorted(per_project, key=lambda p: -len(per_project[p])):
        items = per_project[project]
        out += [f"### {project} — {len(items)} conversas", ""]
        out += ["| conversa | criada | msgs |", "|---|---|---|"]
        for p in sorted(items, key=lambda p: p["row"]["created_ts"] or 0, reverse=True):
            r = p["row"]
            flag = " · revisar" if p["verdict"] == "review" else ""
            out.append(
                f"| [{cell(r['title'], 80)}]({link(r)}) "
                f"| {date_of(r)} | {r['turns']}{flag} |"
            )
        out.append("")

    def trash_section(title: str, needle: str, blurb: str) -> None:
        items = [p for p in plans if p["verdict"] == needle]
        out.extend([f"## {title} — {len(items)}", "", blurb, ""])
        if not items:
            out.extend(["_nada._", ""])
            return
        out.extend(["| conversa | criada | msgs | motivo |", "|---|---|---|---|"])
        for p in sorted(items, key=lambda p: p["row"]["created_ts"] or 0):
            r = p["row"]
            reason = p["dupe"] or (
                "sem mensagens" if r["turns"] == 0 else "pergunta única"
            )
            out.append(
                f"| [{cell(r['title'], 80)}]({link(r)}) "
                f"| {date_of(r)} | {r['turns']} | {reason} |"
            )
        out.append("")

    trash_section(
        "2. Arquivar",
        "archive",
        "One-shots (uma pergunta curta, no máximo uma resposta), duplicadas e "
        "conversas que não foram adiante.",
    )
    trash_section("3. Apagar", "delete", "Zero mensagens. Não tem o que perder.")

    unknown = [p for p in plans if p["verdict"] == "unknown"]
    if unknown:
        out.extend(
            [
                f"## 4. Sem conteúdo indexado — {len(unknown)}",
                "",
                "Vieram da API, que entrega só título e datas — o corpo das mensagens "
                "fica no endpoint individual. Ficaram sem classificação de propósito, "
                "para não arquivar conversa por engano. Rode `cg.py sync --deep` para "
                "baixar o conteúdo e gerar o plano completo.",
                "",
            ]
        )

    stale = [
        p
        for p in plans
        if p["verdict"] in {"keep", "review"}
        and p["row"]["created_ts"]
        and p["row"]["created_ts"] < cutoff.timestamp()
        and not p["row"]["archived"]
    ]
    if stale:
        out.extend(
            [
                f"## 4. Antigas e vivas — {len(stale)}",
                "",
                f"Mais de {args.days} dias e ainda sem Project. "
                "São as que mais poluem a lista.",
                "",
                "| conversa | criada | sugestão |",
                "|---|---|---|",
            ]
        )
        for p in sorted(stale, key=lambda p: p["row"]["created_ts"] or 0)[:40]:
            r = p["row"]
            out.append(
                f"| [{cell(r['title'], 80)}]({link(r)}) "
                f"| {date_of(r)} | {p['project']} |"
            )
        out.append("")

    md_path.write_text("\n".join(out), encoding="utf-8")

    tsv = ["project\tverdict\tturns\tuser_chars\tcreated\ttitle\turl"]
    for p in plans:
        r = p["row"]
        tsv.append(
            f"{p['project']}\t{p['verdict']}\t{r['turns']}\t{r['user_chars']}\t"
            f"{date_of(r)}\t{WS.sub(' ', r['title'])}\t{link(r)}"
        )
    tsv_path.write_text("\n".join(tsv) + "\n", encoding="utf-8")

    print(f"conversas  : {len(rows)}")
    print(f"manter     : {counts['keep']}  ({len(per_project)} projects sugeridos)")
    print(f"revisar    : {counts['review']}")
    print(f"arquivar   : {counts['archive']}")
    print(f"apagar     : {counts['delete']}")
    if counts["unknown"]:
        print(f"sem conteúdo: {counts['unknown']}  (rode: cg.py sync --deep)")
    print(f"\nplano      : {md_path}")
    print(f"tabela     : {tsv_path}")
    print("\nnada foi alterado no site — as ações são suas.")
    return 0


# --------------------------------------------------------------------------- #
# live actions — archive only, on purpose. There is no delete path in this file.
# --------------------------------------------------------------------------- #

DEFAULT_BASE = "https://chatgpt.com"
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/140.0.0.0 Safari/537.36"
)
SESSION_COOKIE = "__Secure-next-auth.session-token"


class Throttle:
    """Keep one request in flight and widen the gap whenever the server complains.

    The web app itself does roughly one request per second; the backend answers
    bursts with 429. Every call goes through `wait()` before it leaves and
    `observe()` after it returns, so a single 429 slows the whole run down
    instead of just the call that hit it.
    """

    def __init__(
        self,
        interval: float = 1.0,
        ceiling: float = 30.0,
        clock=time.monotonic,
        sleep=time.sleep,
        enabled: bool | None = None,
    ):
        self.floor = self.interval = max(0.0, interval)
        self.ceiling = ceiling
        self._clock = clock
        self._sleep = sleep
        self._next = 0.0
        self.enabled = (
            os.environ.get("CG_THROTTLE", "1").strip() not in {"0", "off", "false"}
            if enabled is None
            else enabled
        )

    def set_floor(self, interval: float) -> None:
        """The command decides the pace; 429 can only make it slower."""
        self.floor = self.interval = max(0.0, interval)
        self._next = 0.0

    def wait(self) -> None:
        if not self.enabled:
            return
        delay = self._next - self._clock()
        if delay > 0:
            log.debug(
                "throttle: esperando %.1fs (intervalo %.1fs)", delay, self.interval
            )
            self._sleep(delay)

    def pause(self, seconds: float) -> None:
        if self.enabled and seconds > 0:
            self._next = max(self._next, self._clock() + seconds)

    def observe(self, status: int, retry_after: float | None = None) -> None:
        now = self._clock()
        if status == 429:
            self.interval = min(
                self.ceiling, max(self.interval * 2, self.floor * 2, 2.0)
            )
            pause = retry_after if retry_after and retry_after > 0 else self.interval
            self.pause(max(pause, self.interval))
            log.warning(
                "HTTP 429 — intervalo agora %.1fs, pausa de %.1fs",
                self.interval,
                max(pause, self.interval),
            )
            return
        # Recover slowly (5% per good answer) and never faster than the floor.
        self.interval = max(self.floor, self.interval * 0.95)
        spread = 0.9 + jitter(0.2)  # 90-110% of the interval
        self._next = now + max(self.floor, self.interval * spread)


THROTTLE = Throttle()


def _retry_after(headers) -> float | None:
    """Retry-After is either seconds or an HTTP date; both mean "wait"."""
    raw = headers.get("Retry-After") if headers else None
    if not raw:
        return None
    try:
        return max(0.0, float(raw))
    except (TypeError, ValueError):
        pass
    try:
        when = parsedate_to_datetime(str(raw))
    except (TypeError, ValueError):
        return None
    if when.tzinfo is None:
        when = when.replace(tzinfo=UTC)
    return max(0.0, (when - datetime.now(UTC)).total_seconds())


def http_json(
    method: str,
    url: str,
    headers: dict,
    payload=None,
    timeout: int = 30,
    retries: int = 3,
) -> tuple[int, str]:
    if urllib.parse.urlsplit(url).scheme not in ("http", "https"):
        raise SystemExit(f"error: refusing non-http URL: {url}")
    data = json.dumps(payload).encode() if payload is not None else None

    status, body = 0, ""
    for attempt in range(retries + 1):
        req = Request(url, data=data, headers=headers, method=method)  # noqa: S310
        THROTTLE.wait()
        started = time.monotonic()
        retry_after = None
        try:
            # The scheme is validated above; the linters cannot see that dataflow.
            resp = urlopen(req, timeout=timeout)  # noqa: S310  # nosec B310
            with resp:
                status = resp.status
                body = resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            status = exc.code
            body = exc.read().decode("utf-8", "replace")
            retry_after = _retry_after(exc.headers)
            exc.close()
        except urllib.error.URLError as exc:
            log.error("%s %s falhou: %s", method, url, exc.reason)
            raise SystemExit(f"error: cannot reach {url}: {exc.reason}") from None

        took = (time.monotonic() - started) * 1000
        log.debug("%s %s -> %d (%.0f ms)", method, url, status, took)
        THROTTLE.observe(status, retry_after)

        if status in (429, 500, 502, 503) and attempt < retries:
            # A POST is not idempotent: retrying a 5xx can create the same
            # Project twice when the first request succeeded but the response
            # was lost. 429 means the request was rejected, so it is safe.
            if method == "POST" and status != 429:
                break
            wait = max(THROTTLE.interval * (2**attempt), retry_after or 0.0)
            THROTTLE.pause(wait)
            log.warning(
                "%s %s -> HTTP %d; tentando de novo em %.0fs (%d/%d)",
                method,
                url,
                status,
                wait,
                attempt + 1,
                retries,
            )
            continue
        break
    return status, body


COOKIE_NAME_RE = re.compile(r"^[A-Za-z0-9_.\-]+=")


def build_cookie(raw: str) -> str:
    """Normalize whatever was pasted into a Cookie header value.

    Accepts, in order of preference:
      * a whole `cookie:` request header (carries both chunked cookies)
      * `name=value` lines, one per cookie (chunks included)
      * two or more bare JWx chunks -> named .0 .1 .2 in order
      * one bare token -> the single unchunked session cookie
    """
    text = raw.strip()
    if text.lower().startswith("cookie:"):
        text = text[7:].lstrip()
    lines = [line.strip().rstrip(";") for line in text.splitlines() if line.strip()]
    if not lines:
        raise SystemExit("error: empty cookie")

    # A terminal that soft-wraps the copied header produces continuation lines
    # with no '=' in them; glue those back onto the cookie they belong to.
    merged: list[str] = []
    for line in lines:
        if (
            merged
            and not COOKIE_NAME_RE.match(line)
            and COOKIE_NAME_RE.match(merged[-1])
        ):
            merged[-1] += line
        else:
            merged.append(line)
    lines = merged

    named = [line for line in lines if COOKIE_NAME_RE.match(line)]
    if named and len(named) == len(lines):
        return "; ".join(lines)
    if len(lines) == 1 and ";" in lines[0] and "=" in lines[0]:
        return lines[0]

    if len(lines) == 1:
        token = lines[0]
        if 3900 <= len(token) <= 3933:
            raise SystemExit(
                f"error: that value is {len(token)} chars — the size of NextAuth's "
                "*first chunk*.\n"
                "  This session token is split across two cookies and the server needs "
                "both:\n"
                f"    {SESSION_COOKIE}.0\n"
                f"    {SESSION_COOKIE}.1\n"
                "  Easiest fix: DevTools -> Network -> any chatgpt.com request -> "
                "Request Headers,\n"
                "  right-click the `cookie:` header -> Copy value. Paste that whole "
                "line into the file.\n"
                "  Or put the two chunk values on two lines, .0 first."
            )
        return f"{SESSION_COOKIE}={token}"

    # Several bare chunks: rebuild the names the browser would have sent.
    return "; ".join(f"{SESSION_COOKIE}.{i}={chunk}" for i, chunk in enumerate(lines))


def resolve_cookie(args) -> str:
    raw = (getattr(args, "cookie", None) or os.environ.get("CG_COOKIE") or "").strip()
    path = getattr(args, "cookie_file", None)
    if not raw:
        p = Path(path).expanduser() if path else STATE_DIR / "session"
        if p.is_file():
            if p.stat().st_mode & 0o077:
                print(
                    f"warning: {p} is readable by others — chmod 600 {p}",
                    file=sys.stderr,
                )
            raw = p.read_text(encoding="utf-8")
        elif path:
            raise SystemExit(f"error: cookie file not found: {p}")
    if not raw:
        raise SystemExit(
            "error: no session cookie.\n"
            "  DevTools -> Network -> any chatgpt.com request -> Request Headers ->\n"
            "  right-click `cookie:` -> Copy value -> save it to a 600 file, or pass "
            "--cookie."
        )
    return build_cookie(raw)


def open_session(base: str, cookie: str) -> dict:
    status, body = http_json(
        "GET",
        f"{base}/api/auth/session",
        {"Cookie": cookie, "User-Agent": UA, "Accept": "application/json"},
    )
    if status != 200:
        raise SystemExit(
            f"error: session check failed (HTTP {status}) — "
            "cookie expired or wrong account."
        )
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise SystemExit(
            "error: /api/auth/session returned non-JSON — Cloudflare challenge?"
        ) from None
    if not data.get("accessToken"):
        raise SystemExit(
            "error: the server answered with an empty session — the cookie was "
            "rejected.\n"
            f"  Sent {len(cookie)} chars of cookie. Usual causes: expired session, or "
            "only the\n"
            "  first chunk (.0) was copied while .1 was left behind. "
            "Re-copy the whole\n"
            "  `cookie:` request header."
        )
    return data


def set_archived(
    base: str, token: str, conv_id: str, archived: bool
) -> tuple[int, str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": UA,
        "Origin": base,
        "Referer": f"{base}/",
    }
    return http_json(
        "PATCH",
        f"{base}/backend-api/conversation/{conv_id}",
        headers,
        {"is_archived": archived},
    )


def project_key(name: str) -> str:
    """Normalise a category/project name so 'Linux & Arch' == 'linux arch'."""
    return re.sub(r"[^a-z0-9]+", " ", fold(name)).strip()


# Projects are gizmos with a `g-p-` id; a bare `g-...` is a custom GPT. Moving a
# chat out of a GPT overwrites that association, so those chats are never touched.
PROJECT_ID_PREFIX = "g-p-"
# The id is pasted straight into a URL path: nothing but id characters gets in.
CONV_ID_RE = re.compile(r"[A-Za-z0-9_-]{8,64}")


def is_project(gizmo_id: str | None) -> bool:
    return bool(gizmo_id) and str(gizmo_id).startswith(PROJECT_ID_PREFIX)


def valid_conv_id(conv_id: str) -> bool:
    return bool(conv_id) and CONV_ID_RE.fullmatch(conv_id) is not None


def list_projects(base: str, token: str) -> list[dict]:
    """Projects are gizmos of type snorlax; the sidebar endpoint lists them."""
    url = (
        f"{base}/backend-api/gizmos/snorlax/sidebar?limit=50&conversations_per_gizmo=0"
    )
    status, body = http_json("GET", url, api_headers(token, base))
    if status != 200:
        raise SystemExit(f"error: HTTP {status} listing projects: {body[:200]}")
    projects = []
    for item in json.loads(body).get("items") or []:
        gizmo = (item.get("gizmo") or {}).get("gizmo") or {}
        pid = gizmo.get("id")
        if not pid:
            continue
        name = ((gizmo.get("display") or {}).get("name") or "").strip()
        projects.append({"id": pid, "name": name or pid})
    return projects


def create_project(base: str, token: str, name: str) -> tuple[int, str | None]:
    status, body = http_json(
        "POST",
        f"{base}/backend-api/projects",
        api_headers(token, base),
        {"name": name, "instructions": ""},
    )
    if status not in (200, 201):
        return status, None
    data = json.loads(body)
    gizmo = (data.get("resource") or {}).get("gizmo") or {}
    return status, gizmo.get("id")


def set_project(
    base: str, token: str, conv_id: str, project_id: str | None
) -> tuple[int, str]:
    """Move one chat in/out of a project. Never deletes anything."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": UA,
        "Origin": base,
        "Referer": f"{base}/",
    }
    return http_json(
        "PATCH",
        f"{base}/backend-api/conversation/{conv_id}",
        headers,
        {"gizmo_id": project_id},
    )


def move_confirmed(status: int, body: str, project_id: str | None) -> bool:
    """A 2xx is not enough: the PATCH echoes the conversation, so read it back.

    Some moves answer 200 while leaving the chat where it was. Recording that as
    done would make `unorganize` restore a state that never existed, so the echo
    wins whenever it carries `gizmo_id`.
    """
    if status not in (200, 201, 204):
        return False
    try:
        echoed = json.loads(body)
    except (TypeError, ValueError):
        return True
    if not isinstance(echoed, dict) or "gizmo_id" not in echoed:
        return True
    return (echoed.get("gizmo_id") or None) == (project_id or None)


@contextlib.contextmanager
def exclusive_run():
    """Refuse to run two write commands at once.

    Two overlapping `--yes` runs would interleave journals and re-send the same
    PATCH. The lock turns that into a hard error instead of a mess.
    """
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    handle = (STATE_DIR / "run.lock").open("w")
    try:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            handle.close()
            raise SystemExit(
                "error: outra execução do cg ainda está escrevendo (run.lock)."
            ) from None
        yield
    finally:
        handle.close()


def snapshot_db(con: sqlite3.Connection, tag: str) -> Path:
    """Copy the index before a write run, so a bad batch can be rolled back."""
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / f"{tag}-{datetime.now():%Y%m%d-%H%M%S}.db"
    dest = sqlite3.connect(path)
    try:
        con.backup(dest)
    finally:
        dest.close()
    return path


def index_age(con: sqlite3.Connection) -> float:
    """Minutes since the last sync/ingest that touched a row, or inf if empty."""
    raw = con.execute("SELECT MAX(indexed_at) FROM conversations").fetchone()[0]
    if not raw:
        return float("inf")
    try:
        return (datetime.now() - datetime.fromisoformat(raw)).total_seconds() / 60
    except ValueError:
        return float("inf")


def describe_age(minutes: float) -> str:
    if minutes == float("inf"):
        return "sem índice"
    if minutes < 90:
        return f"{minutes:.0f} min atrás"
    return f"{minutes / 60:.1f} h atrás"


def plan_projects(
    plans: list[dict],
    existing: dict[str, dict],
    aliases: dict[str, str],
    minimum: int,
    fallback: str | None = "Inbox",
) -> tuple[list[dict], list[dict]]:
    """Group the keeper chats by project, reusing projects whose names match.

    `project_id=None` means the project still has to be created. Categories
    under `minimum` chats are skipped so the sidebar does not fill up with
    projects holding one chat each.

    Chats the classifier could not place (verdict `review`) go to `fallback`
    instead of being left loose in the sidebar; that bucket is always created,
    whatever its size. Rows without content are never moved.
    """
    fallback_key = project_key(fallback) if fallback else None

    groups: dict[str, dict] = {}
    for p in plans:
        r = p["row"]
        if not r["has_content"] or r["archived"] or r["gone"]:
            continue
        # Only settle chats the plan wants to keep. Filing something slated for
        # delete/archive just moves the problem into a project.
        if p["verdict"] not in {"keep", "review"}:
            continue
        # A bare `g-...` is a custom GPT, not a project: moving that chat would
        # overwrite the GPT association, which no undo can restore.
        if r["project_id"] and not is_project(r["project_id"]):
            continue
        if fallback and (p["verdict"] == "review" or p["project"] == "Inbox"):
            category = fallback
        elif p["verdict"] == "keep" and p["project"] and p["project"] != "Inbox":
            category = p["project"]
        elif fallback:
            category = fallback
        else:
            continue
        key = project_key(category)
        groups.setdefault(key, {"category": category, "items": []})["items"].append(p)

    merged: dict[str, dict] = {}
    skipped: list[dict] = []
    for key, group in groups.items():
        category, items = group["category"], group["items"]
        name = aliases.get(key) or category
        found = existing.get(project_key(name))
        # the fallback pile exists even with a single chat
        if found is None and key != fallback_key and len(items) < minimum:
            skipped.append({"category": category, "name": name, "items": items})
            continue
        slot = merged.setdefault(
            project_key(name),
            {
                "name": name,
                "project_id": found["id"] if found else None,
                "categories": [],
                "items": [],
            },
        )
        if category not in slot["categories"]:
            slot["categories"].append(category)
        slot["items"].extend(items)

    targets = sorted(merged.values(), key=lambda t: -len(t["items"]))
    if fallback_key:
        # a triage pile belongs at the bottom, not above the real topics
        targets.sort(key=lambda t: project_key(t["name"]) == fallback_key)
    return targets, skipped


CHROMIUM_STORES = (
    "~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/*/Cookies",
    "~/.config/BraveSoftware/Brave-Browser/*/Cookies",
    "~/.config/chromium/*/Cookies",
    "~/.config/google-chrome/*/Cookies",
)
FIREFOX_STORES = (
    "~/.var/app/io.gitlab.librewolf-community/config/librewolf/librewolf/*/cookies.sqlite",
    "~/.mozilla/firefox/*/cookies.sqlite",
    "~/.librewolf/*/cookies.sqlite",
)
OSCRYPT_PASSWORDS = ("peanuts", "Brave Safe Storage", "Chrome Safe Storage")
HOST_DIGEST = 32  # SHA256(host_key) prefix added to cookie plaintext in Chromium 127+


def _decrypt_chromium(blob: bytes) -> str | None:
    """v10/v11 = AES-128-CBC, key = PBKDF2(password, 'saltysalt', 1)."""
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    except ImportError:
        raise SystemExit(
            "error: python-cryptography is required to read browser cookies.\n"
            "  pacman -S python-cryptography   (or paste the cookie header manually)"
        ) from None
    if blob[:3] not in (b"v10", b"v11"):
        return None
    for password in OSCRYPT_PASSWORDS:
        key = hashlib.pbkdf2_hmac("sha1", password.encode(), b"saltysalt", 1, 16)
        dec = Cipher(algorithms.AES(key), modes.CBC(b" " * 16)).decryptor()
        raw = dec.update(blob[3:]) + dec.finalize()
        pad = raw[-1]
        if 0 < pad <= 16:
            raw = raw[:-pad]
        # Some builds prefix the plaintext with a 32-byte host digest, some don't.
        for cut in (HOST_DIGEST, 0):
            try:
                text = raw[cut:].decode("utf-8")
            except UnicodeDecodeError:
                continue
            if text and text.isprintable() and "\x00" not in text:
                return text
    return None


def _cookies_from_chromium(path: Path) -> dict[str, str]:
    import shutil
    import sqlite3

    snapshot = STATE_DIR / "cookies.snapshot"
    shutil.copy2(path, snapshot)  # live DB is locked by the running browser
    con = sqlite3.connect(snapshot)
    rows = con.execute(
        "SELECT name, encrypted_value, value FROM cookies "
        "WHERE host_key LIKE '%chatgpt.com' OR host_key LIKE '%openai.com'"
    ).fetchall()
    con.close()
    snapshot.unlink(missing_ok=True)

    out: dict[str, str] = {}
    for name, encrypted, plain in rows:
        if plain:
            out[name] = plain
            continue
        value = _decrypt_chromium(bytes(encrypted)) if encrypted else None
        if value:
            out[name] = value
    return out


def _cookies_from_firefox(path: Path) -> dict[str, str]:
    import shutil
    import sqlite3

    snapshot = STATE_DIR / "cookies.snapshot"
    shutil.copy2(path, snapshot)
    con = sqlite3.connect(snapshot)
    rows = con.execute(
        "SELECT name, value FROM moz_cookies "
        "WHERE host LIKE '%chatgpt.com' OR host LIKE '%openai.com'"
    ).fetchall()
    con.close()
    snapshot.unlink(missing_ok=True)
    return {name: value for name, value in rows if value}


def harvest_cookie(store: Path | None) -> tuple[str, Path]:
    """Build a Cookie header from whichever browser profile is logged in."""
    from glob import glob

    candidates: list[Path] = []
    if store:
        candidates = [store.expanduser()]
    else:
        for pattern in CHROMIUM_STORES + FIREFOX_STORES:
            candidates.extend(
                Path(p) for p in sorted(glob(str(Path(pattern).expanduser())))
            )
    if not candidates:
        raise SystemExit(
            "error: no browser cookie store found. Pass --store PATH.\n"
            "  chromium: <profile>/Cookies   firefox: <profile>/cookies.sqlite"
        )

    for path in candidates:
        if not path.is_file():
            continue
        cookies = (
            _cookies_from_firefox(path)
            if path.name == "cookies.sqlite"
            else _cookies_from_chromium(path)
        )
        chunks = sorted(
            (k for k in cookies if k.startswith(f"{SESSION_COOKIE}.")),
            key=lambda k: int(k.rsplit(".", 1)[-1]),
        )
        if chunks or SESSION_COOKIE in cookies:
            return "; ".join(f"{k}={v}" for k, v in cookies.items()), path
    raise SystemExit(
        "error: no ChatGPT session cookie in any browser profile — log in first."
    )


def cmd_login(args) -> int:
    base = args.base_url.rstrip("/")
    cookie, store = harvest_cookie(Path(args.store) if args.store else None)
    chunks = cookie.count(f"{SESSION_COOKIE}.")
    print(f"origem  : {store}")
    print(f"cookies : {cookie.count('=')} valores · sessão em {chunks or 1} parte(s)")

    session = open_session(base, cookie)
    user = session.get("user") or {}

    target = Path(args.save).expanduser() if args.save else STATE_DIR / "session"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(cookie + "\n", encoding="utf-8")
    os.chmod(target, 0o600)

    print(f"conta   : {user.get('email')}")
    print(f"plano   : {user.get('planType') or '?'}")
    print(f"expira  : {session.get('expires')}")
    print(f"salvo   : {target} (600)")
    print("\npronto — `cg.py archive` usa esse arquivo sozinho.")
    return 0


def api_headers(token: str, base: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": UA,
        "Origin": base,
        "Referer": f"{base}/",
    }


def cmd_sync(args) -> int:
    """Index the account through the same endpoints the sidebar uses.

    The list endpoint returns one object per chat but with an empty `mapping`,
    so it only yields id/title/dates/archived. `--deep` then fetches each chat
    individually for the message bodies. Deep sync is resumable: it only visits
    chats whose content was never fetched.
    """
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]

    THROTTLE.set_floor(args.sleep)
    con = connect()
    now = datetime.now().isoformat(timespec="seconds")
    offset, total, new, updated = 0, 0, 0, 0

    while True:
        url = (
            f"{base}/backend-api/conversations?offset={offset}&limit=100"
            "&order=updated&hide_snorlax=false"
        )
        status, body = http_json("GET", url, api_headers(token, base))
        if status in (401, 403):
            raise SystemExit(
                f"error: HTTP {status} on the list endpoint — session expired."
            )
        if status != 200:
            raise SystemExit(f"error: HTTP {status} on the list endpoint: {body[:200]}")
        data = json.loads(body)
        items = data.get("items") or []
        total = data.get("total") or 0
        for raw in items:
            conv = parse_conversation(raw)
            if not conv.conv_id:
                continue
            if record(con, conv, f"api:{base}", now):
                new += 1
            else:
                updated += 1
        offset += len(items)
        if not items or offset >= total:
            break

    con.commit()
    indexed = con.execute("SELECT COUNT(*) FROM conversations").fetchone()[0]
    log.info("sync: %d listadas, %d novas, %d atualizadas", offset, new, updated)
    print(f"conta  : {session.get('user', {}).get('email')}")
    print(f"listadas: {offset} de {total}")
    print(f"novas  : {new} · atualizadas: {updated}")
    print(f"índice : {indexed} conversas")

    if not args.deep:
        todo = con.execute(
            "SELECT COUNT(*) FROM conversations WHERE has_content = 0 AND gone = 0"
        ).fetchone()[0]
        if todo:
            print(f"conteúdo: {todo} conversas sem corpo (rode: cg.py sync --deep)")
        else:
            print("\npróximo passo: cg.py plan")
        return 0

    pending = [
        row[0]
        for row in con.execute(
            "SELECT conv_id FROM conversations WHERE has_content = 0 AND gone = 0 "
            "ORDER BY created_ts DESC"
        )
    ]
    remaining = 0
    if args.limit and args.limit > 0 and len(pending) > args.limit:
        remaining = len(pending) - args.limit
        pending = pending[: args.limit]
    if not pending:
        print("\nconteúdo: tudo já indexado — rode `cg.py plan`.")
        return 0

    THROTTLE.set_floor(args.deep_sleep)
    print(
        f"\nbaixando conteúdo de {len(pending)} conversas "
        f"(~{round(len(pending) * (args.deep_sleep + 0.6) / 60)} min)"
    )
    done = failed = missing = 0
    try:
        for i, conv_id in enumerate(pending, 1):
            url = f"{base}/backend-api/conversation/{conv_id}"
            status, body = http_json(
                "GET", url, api_headers(token, base), retries=args.max_retries
            )
            if status in (401, 403):
                con.commit()
                raise SystemExit(f"error: HTTP {status} — session expired.")
            if status == 429:
                con.commit()
                raise RateLimited(
                    f"error: HTTP 429 — rate limit com {done} conversas baixadas.\n"
                    "  Progresso salvo; espere ~1h e rode o mesmo comando para "
                    "retomar daqui."
                )
            if status == 404:
                missing += 1
                mark_gone(con, conv_id)
            elif status != 200:
                failed += 1
            else:
                conv = parse_conversation(json.loads(body))
                if conv.conv_id:
                    record(con, conv, f"api:{base}", now, fetched=True)
                    done += 1
                else:
                    missing += 1
            if i % 20 == 0 or i == len(pending):
                con.commit()
                print(f"  {i}/{len(pending)} · {done} ok · {failed} erros", flush=True)
    except KeyboardInterrupt as exc:
        con.commit()
        print(f"\ninterrompido em {done} conversas — retome com o mesmo comando.")
        return 128 + getattr(exc, "signum", 2)

    con.commit()
    log.info("deep: %d ok, %d falhas, %d sumidas", done, failed, missing)
    print(f"conteúdo: {done} baixadas · {failed} falhas · {missing} sumidas")
    if remaining:
        print(f"faltam  : {remaining} (rode o mesmo comando para continuar)")
    print("\npróximo passo: cg.py plan")
    return 0


def cmd_auth(args) -> int:
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    user = session.get("user") or {}
    print(f"conta   : {user.get('email') or user.get('name') or '?'}")
    print(f"plano   : {(user.get('planType') or '?')}")
    print(f"expira  : {session.get('expires') or '?'}")
    print(f"base    : {base}")
    print("\nsessão válida. `cg.py archive` pode rodar.")
    return 0


def archive_targets(rows) -> list[dict]:
    return [
        p
        for p in build_plan(rows)
        if p["verdict"] in {"archive", "delete"} and not p["row"]["archived"]
    ]


def row_date(row) -> str:
    return (
        datetime.fromtimestamp(row["created_ts"]).strftime("%Y-%m-%d")
        if row["created_ts"]
        else "?"
    )


def trash_reason(plan: dict) -> str:
    """Why a chat landed in the trash pile — same wording as the plan report."""
    if plan["dupe"]:
        return plan["dupe"]
    return "sem mensagens" if plan["row"]["turns"] == 0 else "pergunta única"


def archive_summary(rows: list[sqlite3.Row]) -> dict[str, int]:
    plans = build_plan(rows)
    candidates = [
        p
        for p in plans
        if p["verdict"] in {"archive", "delete"} and not p["row"]["archived"]
    ]
    reasons = {"duplicada": 0, "vazia": 0, "one-shot": 0}
    for p in candidates:
        if p["dupe"]:
            reasons["duplicada"] += 1
        elif p["row"]["turns"] == 0:
            reasons["vazia"] += 1
        else:
            reasons["one-shot"] += 1
    return {
        "indexed": len(rows),
        "archived": sum(1 for r in rows if r["archived"]),
        "candidates": len(candidates),
        "unknown": sum(1 for p in plans if p["verdict"] == "unknown"),
        **reasons,
    }


def archive_list(args) -> int:
    # Read-only and offline: this is the "what do I have?" view, before any
    # PATCH is sent. The archived flag is only as fresh as the last sync.
    con = connect()
    try:
        rows = con.execute(
            "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
        ).fetchall()
    finally:
        con.close()
    if not rows:
        raise SystemExit("error: empty index — run `cg.py ingest <export>` first")

    if args.candidates:
        items = archive_targets(rows)
        title = "candidatas a arquivar"
    else:
        items = sorted(
            (p for p in build_plan(rows) if p["row"]["archived"]),
            key=lambda p: p["row"]["created_ts"] or 0,
            reverse=True,
        )
        title = "arquivadas (estado do último sync)"

    shown = items[: args.limit] if args.limit > 0 else items
    print(f"{title}: {len(items)}")
    for p in shown:
        r = p["row"]
        reason = f"  {trash_reason(p)}" if args.candidates else ""
        url = f"  https://chatgpt.com/c/{r['conv_id']}" if args.urls else ""
        print(
            f"  {r['conv_id'][:8]}  {row_date(r)}  {r['turns']:>3} msgs  "
            f"{r['title'][:60]}{reason}{url}"
        )
    if len(items) > len(shown):
        print(f"  … e mais {len(items) - len(shown)} (use --limit 0 para ver todas)")
    if not items and not args.candidates:
        print("  nada aqui ainda — `cg archive` mostra o que entraria.")
    return 0


def archive_show(args) -> int:
    con = connect()
    try:
        needle = args.id.strip()
        rows = con.execute(
            "SELECT * FROM conversations WHERE conv_id LIKE ?", (needle + "%",)
        ).fetchall()
        everything = con.execute(
            "SELECT * FROM conversations WHERE gone = 0"
        ).fetchall()
    finally:
        con.close()
    if not rows:
        raise SystemExit(f"error: nenhum conv_id começa com {needle!r}")
    if len(rows) > 1:
        print(f"{len(rows)} conversas começam com {needle!r}:")
        for r in rows[:20]:
            print(f"  {r['conv_id']}  {r['title'][:60]}")
        raise SystemExit("error: informe mais caracteres do id.")

    row = rows[0]
    plan = next(
        (p for p in build_plan(everything) if p["row"]["conv_id"] == row["conv_id"]),
        None,
    )

    print(f"id       : {row['conv_id']}")
    print(f"título   : {row['title']}")
    print(f"criada   : {row_date(row)}")
    print(
        f"mensagens: {row['turns']}"
        f" ({row['user_turns']} suas, {row['user_chars']} chars)"
    )
    print(f"arquivada: {'sim' if row['archived'] else 'não'}")
    print(f"project  : {row['project_id'] or '—'}")
    if plan:
        why = (
            f" — {trash_reason(plan)}"
            if plan["verdict"] in {"archive", "delete"}
            else ""
        )
        print(f"veredito : {plan['verdict']}{why}")
    if row["first_user"]:
        print(f"primeira : {row['first_user'][:100]}")
    print(f"link     : https://chatgpt.com/c/{row['conv_id']}")
    return 0


def archive_stats(args) -> int:
    con = connect()
    try:
        rows = con.execute("SELECT * FROM conversations WHERE gone = 0").fetchall()
    finally:
        con.close()
    if not rows:
        raise SystemExit("error: empty index — run `cg.py ingest <export>` first")

    s = archive_summary(rows)
    print(f"índice      : {s['indexed']} conversas")
    print(f"arquivadas  : {s['archived']}")
    print(f"candidatas  : {s['candidates']}")
    print(f"  duplicadas: {s['duplicada']}")
    print(f"  one-shot  : {s['one-shot']}")
    print(f"  vazias    : {s['vazia']}")
    if s["unknown"]:
        print(f"sem conteúdo: {s['unknown']} (rode: cg sync --deep)")
    return 0


def cmd_archive(args) -> int:
    op = getattr(args, "archive_cmd", None)
    if op == "list":
        return archive_list(args)
    if op == "show":
        return archive_show(args)
    if op == "stats":
        return archive_stats(args)
    with exclusive_run():
        return archive_run(args)


def archive_run(args) -> int:
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        raise SystemExit("error: empty index — run `cg.py ingest <export>` first")

    targets = archive_targets(rows)
    if args.ids:
        wanted = {
            line.strip()
            for line in Path(args.ids)
            .expanduser()
            .read_text(encoding="utf-8")
            .splitlines()
            if line.strip()
        }
        targets = [p for p in targets if p["row"]["conv_id"] in wanted]

    limit = args.limit if args.limit and args.limit > 0 else len(targets)
    batch = targets[:limit]

    if not batch:
        print("nada a arquivar — o índice já está limpo.")
        return 0

    if not args.yes:
        print(f"arquivaria {len(batch)} conversas (de {len(targets)} candidatas):")
        for p in batch[:15]:
            r = p["row"]
            print(
                f"  [{trash_reason(p)}] {r['title'][:64]}  https://chatgpt.com/c/{r['conv_id']}"
            )
        if len(batch) > 15:
            print(f"  … e mais {len(batch) - 15}")
        print("\ndry-run: nada foi enviado. aplicar com --yes (limite: --limit N)")
        return 0

    THROTTLE.set_floor(args.sleep)
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = REPORT_DIR / f"archive-{stamp}.jsonl"
    backup = snapshot_db(con, "archive-backup")
    done = failed = 0

    with log_path.open("a", encoding="utf-8") as journal:
        for i, p in enumerate(batch, 1):
            r = p["row"]
            cid = r["conv_id"]
            if not valid_conv_id(cid):
                failed += 1
                print(f"[{i:>3}/{len(batch)}] id inválido  {cid!r}")
                continue
            status, _body = set_archived(base, token, cid, True)

            if status in (401, 403):
                print(f"\nabortado: HTTP {status} — sessão inválida ou sem permissão.")
                print(f"arquivadas até aqui: {done}. log: {log_path}")
                return 2
            if status == 429:
                print("\nabortado: HTTP 429 — rate limit. Espere ~1h e rode de novo.")
                print(f"arquivadas: {done}. log: {log_path}")
                return 3

            ok = status in (200, 201, 204)
            journal.write(
                json.dumps(
                    {
                        "conv_id": cid,
                        "status": status,
                        "ok": ok,
                        "at": datetime.now().isoformat(timespec="seconds"),
                    }
                )
                + "\n"
            )
            journal.flush()
            if ok:
                done += 1
                con.execute(
                    "UPDATE conversations SET archived = 1 WHERE conv_id = ?", (cid,)
                )
                con.commit()
                print(f"[{i:>3}/{len(batch)}] ok        {r['title'][:60]}")
            else:
                failed += 1
                print(f"[{i:>3}/{len(batch)}] HTTP {status}  {r['title'][:60]}")

    log.info("archive: %d ok, %d falhas", done, failed)
    print(f"\narquivadas: {done} · falhas: {failed}")
    print(f"log      : {log_path}")
    print(f"backup   : {backup}")
    print(f"desfazer : cg.py unarchive --log {log_path}")
    return 0 if not failed else 1


def cmd_unarchive(args) -> int:
    with exclusive_run():
        return _unarchive(args)


def _unarchive(args) -> int:
    base = args.base_url.rstrip("/")
    if args.log:
        ids = []
        for line in (
            Path(args.log).expanduser().read_text(encoding="utf-8").splitlines()
        ):
            if not line.strip():
                continue
            entry = json.loads(line)
            # `unarchive --log` only understands archive journals. Passing an
            # organize log here used to send ids that were never archived.
            if entry.get("kind", "archive") != "archive":
                continue
            if entry.get("ok") and valid_conv_id(entry.get("conv_id")):
                ids.append(entry["conv_id"])
    elif args.all:
        con = connect()
        ids = [
            r["conv_id"]
            for r in con.execute(
                "SELECT conv_id FROM conversations WHERE archived = 1 AND gone = 0"
            ).fetchall()
            if valid_conv_id(r["conv_id"])
        ]
    else:
        raise SystemExit("error: pass --log <archive-*.jsonl> or --all")

    if not ids:
        print("nada para desarquivar.")
        return 0

    THROTTLE.set_floor(args.sleep)
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]
    con = connect()
    done = 0
    for i, cid in enumerate(ids, 1):
        status, _ = set_archived(base, token, cid, False)
        if status in (200, 201, 204):
            done += 1
            con.execute(
                "UPDATE conversations SET archived = 0 WHERE conv_id = ?", (cid,)
            )
            con.commit()
            print(f"[{i:>3}/{len(ids)}] restaurada  {cid}")
        elif status in (401, 403):
            print(f"\nabortado: HTTP {status} — sessão inválida.")
            return 2
        elif status == 429:
            print("\nabortado: HTTP 429 — rate limit.")
            return 3
        else:
            print(f"[{i:>3}/{len(ids)}] HTTP {status}  {cid}")
    print(f"\nrestauradas: {done}/{len(ids)}")
    return 0


def cmd_projects(args) -> int:
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    projects = list_projects(base, session["accessToken"])

    con = connect()
    counts = {
        row[0]: row[1]
        for row in con.execute(
            "SELECT project_id, COUNT(*) FROM conversations "
            "WHERE project_id IS NOT NULL AND gone = 0 GROUP BY project_id"
        )
    }
    loose = con.execute(
        "SELECT COUNT(*) FROM conversations WHERE project_id IS NULL AND gone = 0"
    ).fetchone()[0]

    print(f"projetos: {len(projects)}")
    for p in sorted(projects, key=lambda p: -counts.get(p["id"], 0)):
        print(f"  {p['name'][:30]:30} {counts.get(p['id'], 0):>3} conversas  {p['id']}")
    print(f"\nfora de Projects: {loose} conversas indexadas")
    return 0


def cmd_organize(args) -> int:
    with exclusive_run():
        return _organize(args)


def _organize(args) -> int:
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        raise SystemExit("error: empty index — run `cg.py sync` first")

    THROTTLE.set_floor(args.sleep)
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]
    projects = list_projects(base, token)
    existing = {project_key(p["name"]): p for p in projects}

    aliases: dict[str, str] = {}
    for spec in args.map or []:
        if "=" not in spec:
            raise SystemExit(f"error: --map espera Categoria=Projeto, veio {spec!r}")
        category, name = spec.split("=", 1)
        aliases[project_key(category)] = name.strip()

    fallback = None if args.no_fallback else args.fallback
    targets, skipped = plan_projects(
        build_plan(rows), existing, aliases, args.min, fallback
    )
    to_create = [t for t in targets if not t["project_id"]]
    pending = [
        (p, t)
        for t in targets
        for p in t["items"]
        # a project that does not exist yet means every chat is a move
        if t["project_id"] is None or p["row"]["project_id"] != t["project_id"]
    ]
    moves = len(pending)

    print(f"projetos existentes: {len(projects)}")
    print(
        f"categorias: {len(targets)} · a criar: {len(to_create)} · movimentos: {moves}"
    )
    for t in targets:
        names = ", ".join(t["categories"])
        mark = "+" if not t["project_id"] else "→"
        print(f"  {mark} {t['name'][:34]:34} {len(t['items']):>3} chats  ({names})")
    for s in skipped:
        print(
            f"  · {s['name'][:34]:34} {len(s['items']):>3} chats  "
            f"ignorado (--min {args.min})"
        )

    if not moves:
        print("\nnada a mover — os Projects já refletem o plano.")
        return 0

    if not args.yes:
        print("\ndry-run: nada foi enviado. aplicar com --yes")
        return 0

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = REPORT_DIR / f"organize-{stamp}.jsonl"
    limit = args.limit if args.limit and args.limit > 0 else moves
    backup = snapshot_db(con, "organize-backup")
    known = {p["id"] for p in projects}
    done = failed = gone = 0

    with log_path.open("a", encoding="utf-8") as journal:
        for t in to_create:
            status, pid = create_project(base, token, t["name"])
            ok = bool(pid)
            journal.write(
                json.dumps(
                    {
                        "kind": "project",
                        "name": t["name"],
                        "project_id": pid,
                        "status": status,
                        "ok": ok,
                        "at": datetime.now().isoformat(timespec="seconds"),
                    }
                )
                + "\n"
            )
            journal.flush()
            if not ok:
                print(f"abortado: não criou o Project {t['name']!r} (HTTP {status})")
                print(f"log: {log_path}")
                return 2
            t["project_id"] = pid
            known.add(pid)
            print(f"criado: {t['name']} ({pid})")

        queue = [
            (p, t)
            for t in targets
            for p in t["items"]
            if p["row"]["project_id"] != t["project_id"]
        ][:limit]

        for i, (p, t) in enumerate(queue, 1):
            r = p["row"]
            cid = r["conv_id"]
            if not valid_conv_id(cid):
                print(f"[{i:>3}/{len(queue)}] id inválido, pulando: {cid!r}")
                failed += 1
                continue
            if t["project_id"] not in known:
                print(f"[{i:>3}/{len(queue)}] projeto desconhecido: {t['project_id']}")
                failed += 1
                continue
            status, body = set_project(base, token, cid, t["project_id"])

            if status in (401, 403):
                print(f"\nabortado: HTTP {status} — sessão inválida.")
                print(f"movidas até aqui: {done}. log: {log_path}")
                return 2
            if status == 429:
                print("\nabortado: HTTP 429 — rate limit. Espere e rode de novo.")
                print(f"movidas: {done}. log: {log_path}")
                return 3

            ok = move_confirmed(status, body, t["project_id"])
            if status == 404:
                # Listed in the sidebar, but the server has no such chat.
                # Remember it so the next run does not ask again.
                gone += 1
                mark_gone(con, cid)
                con.commit()
            journal.write(
                json.dumps(
                    {
                        "kind": "move",
                        "conv_id": cid,
                        "from": r["project_id"],
                        "to": t["project_id"],
                        "project": t["name"],
                        "status": status,
                        "ok": ok,
                        "gone": status == 404,
                        "at": datetime.now().isoformat(timespec="seconds"),
                    }
                )
                + "\n"
            )
            journal.flush()
            if ok:
                done += 1
                con.execute(
                    "UPDATE conversations SET project_id = ? WHERE conv_id = ?",
                    (t["project_id"], cid),
                )
                con.commit()
                print(
                    f"[{i:>3}/{len(queue)}] ok       "
                    f"{t['name'][:20]:20} {r['title'][:44]}"
                )
            elif status == 404:
                print(f"[{i:>3}/{len(queue)}] sumiu    {r['title'][:44]}")
            elif status in (200, 201, 204):
                failed += 1
                print(f"[{i:>3}/{len(queue)}] sem confirmação  {r['title'][:44]}")
            else:
                failed += 1
                print(f"[{i:>3}/{len(queue)}] HTTP {status}  {r['title'][:44]}")

    log.info(
        "organize: %d movidas, %d falhas, %d sumidas, %d criadas",
        done,
        failed,
        gone,
        len(to_create),
    )
    summary = f"movidas: {done} · falhas: {failed} · criadas: {len(to_create)}"
    if gone:
        summary += f" · sumidas do site: {gone}"
    print(f"\n{summary}")
    print(f"log      : {log_path}")
    print(f"backup   : {backup}")
    print(f"desfazer : cg.py unorganize --log {log_path}")
    return 0 if not failed else 1


def cmd_unorganize(args) -> int:
    with exclusive_run():
        return _unorganize(args)


def _unorganize(args) -> int:
    path = Path(args.log).expanduser()
    if not path.is_file():
        raise SystemExit(f"error: {path} not found")

    moves = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        if entry.get("kind") == "move" and entry.get("ok"):
            moves.append(entry)
    if not moves:
        print("nada para desfazer nesse log.")
        return 0

    THROTTLE.set_floor(args.sleep)
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]
    con = connect()
    done = 0
    for i, entry in enumerate(moves, 1):
        cid = entry["conv_id"]
        status, _ = set_project(base, token, cid, entry.get("from"))
        if status in (401, 403):
            print(f"\nabortado: HTTP {status} — sessão inválida.")
            return 2
        if status == 429:
            print("\nabortado: HTTP 429 — rate limit.")
            return 3
        if status in (200, 201, 204):
            done += 1
            con.execute(
                "UPDATE conversations SET project_id = ? WHERE conv_id = ?",
                (entry.get("from"), cid),
            )
            con.commit()
            print(f"[{i:>3}/{len(moves)}] devolvida  {entry.get('project', '')}")
        else:
            print(f"[{i:>3}/{len(moves)}] HTTP {status}  {cid}")

    created = [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and json.loads(line).get("kind") == "project"
    ]
    print(f"\ndevolvidas: {done}/{len(moves)}")
    if created:
        print(
            "Projects criados por esta execução continuam existindo (nada é apagado):"
        )
        for c in created:
            print(f"  {c['name']}  {c.get('project_id') or ''}")
    return 0


def cmd_move(args) -> int:
    with exclusive_run():
        return _move(args)


def _move(args) -> int:
    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]

    THROTTLE.set_floor(args.sleep)
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        raise SystemExit(
            "error: empty index — run `cg.py sync` or `cg.py ingest` first"
        )

    projects = list_projects(base, token)
    existing = {project_key(p["name"]): p for p in projects}

    to_key = project_key(args.to)
    tgt = existing.get(to_key)
    if not tgt and args.create:
        status, pid = create_project(base, token, args.to.strip())
        if not pid:
            raise SystemExit(
                f"error: não foi possível criar o projeto '{args.to}' (HTTP {status})"
            )
        tgt = {"id": pid, "name": args.to.strip()}
        projects.append(tgt)
        existing[to_key] = tgt
        print(f"criado   : {tgt['name']} ({tgt['id']})")
    if not tgt:
        raise SystemExit(
            f"error: projeto de destino '{args.to}' não encontrado.\n"
            "  Veja com: cg projects\n"
            "  Ou crie com: cg move --to '{args.to}' --create ..."
        )

    from_key = None
    from_pid = None
    from_name = None
    from_unassigned = False
    from_arg = getattr(args, "from", None)
    if from_arg:
        from_str = str(from_arg).strip()
        if from_str.lower() in (
            "",
            "none",
            "null",
            "unassigned",
            "unknown",
            "sem projeto",
            "no project",
        ):
            from_unassigned = True
            from_name = "sem projeto"
        else:
            from_key = project_key(from_str)
            src = existing.get(from_key)
            if not src:
                raise SystemExit(
                    f"error: projeto de origem '{from_arg}' não encontrado.\n"
                    "  Veja com: cg projects"
                )
            from_pid = src["id"]
            from_name = src["name"]

    wanted = None
    if getattr(args, "ids", None):
        wanted = {
            line.strip()
            for line in Path(args.ids)
            .expanduser()
            .read_text(encoding="utf-8")
            .splitlines()
            if line.strip()
        }

    targets = []
    for r in rows:
        cid = r["conv_id"]
        if not cid:
            continue
        if wanted is not None and cid not in wanted:
            continue
        if from_unassigned:
            if r["project_id"] is not None:
                continue
        elif from_pid is not None:
            if r["project_id"] != from_pid:
                continue
        else:
            # If no source specified and no ids, be conservative - don't move everything
            if wanted is None:
                continue
        if r["project_id"] == tgt["id"]:
            continue
        targets.append(r)

    if not targets:
        print("nada para mover com esses filtros.")
        return 0

    limit = args.limit if args.limit and args.limit > 0 else len(targets)
    batch = targets[:limit]

    print(f"destino  : {tgt['name']} ({tgt['id']})")
    if from_name:
        print(f"origem   : {from_name}")
    elif wanted is not None:
        print(f"filtro   : {len(wanted)} ids")
    else:
        print("filtro   : sem projeto / conforme filtros")
    print(f"a mover  : {len(batch)} (de {len(targets)} candidatas)")
    for r in batch[:12]:
        print(f"  · {r['title'][:70]}  https://chatgpt.com/c/{r['conv_id']}")
    if len(batch) > 12:
        print(f"  … e mais {len(batch) - 12}")

    if not args.yes:
        print("\nsimulação: nada foi enviado. aplicar com --yes")
        return 0

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = REPORT_DIR / f"move-{stamp}.jsonl"
    backup = snapshot_db(con, "move-backup")
    done = failed = 0

    with log_path.open("a", encoding="utf-8") as journal:
        for i, r in enumerate(batch, 1):
            cid = r["conv_id"]
            if not valid_conv_id(cid):
                failed += 1
                print(f"[{i:>3}/{len(batch)}] id inválido  {cid!r}")
                continue
            status, _body = set_project(base, token, cid, tgt["id"])
            if status in (401, 403):
                print(f"\nabortado: HTTP {status} — sessão inválida.")
                print(f"movidas até aqui: {done}. log: {log_path}")
                return 2
            if status == 429:
                print("\nabortado: HTTP 429 — rate limit. Espere e rode de novo.")
                print(f"movidas: {done}. log: {log_path}")
                return 3
            ok = move_confirmed(status, _body, tgt["id"])
            journal.write(
                json.dumps(
                    {
                        "kind": "move",
                        "conv_id": cid,
                        "from": r["project_id"],
                        "to": tgt["id"],
                        "to_name": tgt["name"],
                        "from_name": from_name,
                        "status": status,
                        "ok": ok,
                        "at": datetime.now().isoformat(timespec="seconds"),
                    }
                )
                + "\n"
            )
            journal.flush()
            if ok:
                done += 1
                con.execute(
                    "UPDATE conversations SET project_id = ? WHERE conv_id = ?",
                    (tgt["id"], cid),
                )
                con.commit()
                print(f"[{i:>3}/{len(batch)}] ok       {r['title'][:64]}")
            else:
                failed += 1
                print(f"[{i:>3}/{len(batch)}] HTTP {status}  {r['title'][:64]}")

    log.info("move: %d movidas, %d falhas", done, failed)
    print(f"\nmovidas: {done} · falhas: {failed}")
    print(f"log     : {log_path}")
    print(f"backup  : {backup}")
    print(f"desfazer: cg unorganize --log {log_path}")
    return 0 if not failed else 1


def cmd_log(args) -> int:
    if args.path:
        print(LOG_PATH)
        return 0
    print(f"arquivo: {LOG_PATH}")
    if not LOG_PATH.exists():
        print("(vazio — rode qualquer comando para começar a registrar)")
        return 1
    lines = LOG_PATH.read_text(encoding="utf-8", errors="replace").splitlines()
    print("\n".join(lines[-args.lines :]))
    return 0


def write_note(path: Path, text: str, *, overwrite: bool) -> str:
    """Write a Markdown note without destroying edits made by hand.

    Returns "written", "unchanged" or "kept". "kept" means the file on disk has
    different content and `--overwrite` was not given, so the export leaves the
    user's version alone. Writes go through a temp file so an interrupted run
    never leaves a truncated note behind.
    """
    if path.exists():
        try:
            current = path.read_text(encoding="utf-8")
        except OSError:
            current = None
        if current == text:
            return "unchanged"
        if not overwrite:
            return "kept"
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)
    return "written"


def cmd_export(args) -> int:
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        raise SystemExit(
            "error: empty index — run `cg.py sync` or `cg.py ingest` first"
        )

    base = None
    token = None
    if args.fetch or args.deep_fetch:
        base = args.base_url.rstrip("/")
        session = open_session(base, resolve_cookie(args))
        token = session["accessToken"]
        THROTTLE.set_floor(args.sleep)

    outdir = Path(args.outdir).expanduser() if args.outdir else EXPORT_DIR
    outdir.mkdir(parents=True, exist_ok=True)

    plans = build_plan(rows)
    # build map conv_id -> project
    proj_map = {}
    for p in plans:
        proj_map[p["row"]["conv_id"]] = p["project"]

    done = 0
    skipped = 0
    kept = 0
    unchanged = 0
    fetched = 0
    for p in plans:
        r = p["row"]
        cid = r["conv_id"]
        if not cid:
            skipped += 1
            continue
        if args.only_project and proj_map.get(cid) != args.only_project:
            skipped += 1
            continue
        if args.verdict and p["verdict"] != args.verdict:
            skipped += 1
            continue
        if args.archived_only and not r["archived"]:
            skipped += 1
            continue
        if args.not_archived and r["archived"]:
            skipped += 1
            continue

        conv, did_fetch = load_conv_full(
            con,
            r,
            base,
            token,
            force=getattr(args, "deep_fetch", False),
        )
        fetched += int(did_fetch)
        if not conv.turns and args.skip_empty:
            skipped += 1
            continue

        project = proj_map.get(cid) or conv.project_id or "Inbox"
        folder = outdir / project_folder_name(project)
        folder.mkdir(parents=True, exist_ok=True)
        slug = slugify(conv.title)
        fname = f"{slug}-{cid[:8]}.md"
        path = folder / fname
        try:
            outcome = write_note(path, conv_to_markdown(conv), overwrite=args.overwrite)
        except OSError as e:
            log.error("falha ao escrever %s: %s", path, e)
            skipped += 1
            continue
        if outcome == "written":
            done += 1
        elif outcome == "unchanged":
            unchanged += 1
        else:
            kept += 1

    print(f"saída      : {outdir}")
    print(f"exportados : {done}")
    if unchanged:
        print(f"inalterados: {unchanged}")
    if kept:
        print(
            f"preservados: {kept} (o arquivo foi editado à mão; use --overwrite "
            "para substituir)"
        )
    if fetched:
        print(f"baixados   : {fetched} (sob demanda)")
    if skipped:
        print(f"ignorados  : {skipped}")
    print("\nfeito.")
    return 0


def cmd_status(args) -> int:
    con = connect()
    total = con.execute("SELECT COUNT(*) FROM conversations").fetchone()[0]
    src = con.execute(
        "SELECT path, seen_at, n_convs FROM sources ORDER BY seen_at DESC LIMIT 1"
    ).fetchone()
    print(f"índice : {total} conversas")
    gone = con.execute("SELECT COUNT(*) FROM conversations WHERE gone = 1").fetchone()[
        0
    ]
    if gone:
        print(f"sumidas: {gone} (404 no site — fora dos relatórios)")
    if src:
        print(
            f"último export: {Path(src['path']).name} · "
            f"{src['n_convs']} conversas · {src['seen_at']}"
        )
    print(f"banco  : {DB_PATH}")
    print(f"log    : {LOG_PATH}")
    return 0


# --------------------------------------------------------------------------- #
# shell completions
# --------------------------------------------------------------------------- #

# Flags whose value is a path: Tab completes the filesystem, not words.
DIR_FLAGS = frozenset({"--outdir"})
FILE_FLAGS = frozenset({"--ids", "--log", "--store", "--save", "--cookie-file"})
# Commands whose positional argument is a file (the export to ingest).
POSITIONAL_FILES = frozenset({"ingest"})


def _oneline(text: str | None, width: int = 68) -> str:
    line = " ".join((text or "").split())
    return line if len(line) <= width else line[: width - 1] + "…"


def subcommands(ap: argparse.ArgumentParser) -> dict[str, argparse.ArgumentParser]:
    """{name: parser} for the parser's subcommands; {} when it has none."""
    for action in ap._actions:
        choices = getattr(action, "choices", None)
        if isinstance(choices, dict):
            return choices
    return {}


def subcommand_help(ap: argparse.ArgumentParser) -> dict[str, str]:
    """{name: one-line help}. Aliases only live in `subcommands`, not here."""
    for action in ap._actions:
        if not isinstance(getattr(action, "choices", None), dict):
            continue
        return {
            choice.dest: _oneline(choice.help)
            for choice in getattr(action, "_choices_actions", [])
        }
    return {}


def real_commands(ap: argparse.ArgumentParser) -> list[str]:
    return sorted(subcommand_help(ap))


def every_parser(ap: argparse.ArgumentParser):
    yield ap
    for sub in subcommands(ap).values():
        yield from every_parser(sub)


def option_words(ap: argparse.ArgumentParser) -> list[str]:
    return sorted({word for a in ap._actions for word in a.option_strings})


def flags_with_values(
    ap: argparse.ArgumentParser,
) -> tuple[dict[str, list[str]], set[str]]:
    """Flags that complete a fixed list of values, and flags that eat a word."""
    listed: dict[str, list[str]] = {}
    eating: set[str] = set()
    for parser in every_parser(ap):
        for action in parser._actions:
            if not action.option_strings:
                continue
            if action.choices:
                for word in action.option_strings:
                    listed[word] = [str(choice) for choice in action.choices]
            elif action.nargs != 0:
                eating.update(action.option_strings)
    return listed, eating


def _zsh(text: str) -> str:
    clean = _oneline(text).replace("'", "").replace("[", "").replace("]", "")
    return clean.replace(":", " -")


def _fish(text: str) -> str:
    return _oneline(text).replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")


def _wrap(words: list[str], width: int) -> list[str]:
    rows, row = [], ""
    for word in words:
        if row and len(row) + 1 + len(word) > width:
            rows.append(row)
            row = word
        else:
            row = f"{row} {word}".strip()
    return [*rows, row] if row else rows


def completions_bash(ap: argparse.ArgumentParser) -> str:
    listed, eating = flags_with_values(ap)
    eat = "|".join(sorted(eating - FILE_FLAGS - DIR_FLAGS - set(listed)))
    lines = [
        "# completions para o cg — gerado por: cg completions bash",
        "# Estático de propósito: no Tab nada é executado e o índice não abre.",
        "_cg() {",
        "    local cur prev cmd i cmd_i=0 j sub",
        '    cur="${COMP_WORDS[COMP_CWORD]}"',
        '    prev="${COMP_WORDS[COMP_CWORD-1]}"',
        "",
        '    case "$prev" in',
        '        --outdir) COMPREPLY=( $(compgen -d -- "$cur") ); return ;;',
        f"        {'|'.join(sorted(FILE_FLAGS))}) "
        'COMPREPLY=( $(compgen -f -- "$cur") ); return ;;',
    ]
    for flag, values in sorted(listed.items()):
        lines.append(
            f'        {flag}) COMPREPLY=( $(compgen -W "{" ".join(values)}" '
            '-- "$cur") ); return ;;'
        )
    if eat:
        lines.append(f"        {eat}) COMPREPLY=(); return ;;")
    commands = " ".join(real_commands(ap))
    lines += [
        "    esac",
        "",
        "    for ((i = 1; i < COMP_CWORD; i++)); do",
        '        if [[ "${COMP_WORDS[i]}" != -* ]]; then',
        '            cmd="${COMP_WORDS[i]}"; cmd_i=$i; break',
        "        fi",
        "    done",
        "",
        '    if [[ -z "$cmd" ]]; then',
        f'        COMPREPLY=( $(compgen -W "{commands} --debug" -- "$cur") )',
        "        return",
        "    fi",
        "",
    ]
    for name in sorted(POSITIONAL_FILES):
        lines += [
            f'    if [[ "$cmd" == "{name}" && "$cur" != -* ]]; then',
            '        COMPREPLY=( $(compgen -f -- "$cur") )',
            "        return",
            "    fi",
            "",
        ]
    lines += [
        '    case "$cmd" in',
        *_bash_cases(ap),
        "    esac",
        "}",
        "complete -o nosort -F _cg cg",
        "",
    ]
    return "\n".join(lines)


def _bash_cases(ap: argparse.ArgumentParser) -> list[str]:
    out = []
    for name in real_commands(ap):
        sub = subcommands(ap)[name]
        children = real_commands(sub)
        flags = " ".join(option_words(sub))
        if not children:
            out.append(
                f'        "{name}") COMPREPLY=( $(compgen -W "{flags}" '
                '-- "$cur") ); return ;;'
            )
            continue
        both = " ".join(children + option_words(sub))
        out += [
            f'        "{name}")',
            "            for ((j = cmd_i + 1; j < COMP_CWORD; j++)); do",
            '                if [[ "${COMP_WORDS[j]}" != -* ]]; then',
            '                    sub="${COMP_WORDS[j]}"; break',
            "                fi",
            "            done",
            '            if [[ -z "$sub" ]]; then',
            f'                COMPREPLY=( $(compgen -W "{both}" -- "$cur") )',
            "                return",
            "            fi",
            '            case "$sub" in',
        ]
        for child in children:
            child_flags = " ".join(option_words(subcommands(sub)[child]))
            out.append(
                f'                "{child}") COMPREPLY=( $(compgen -W '
                f'"{child_flags}" -- "$cur") ); return ;;'
            )
        out += [
            f'                *) COMPREPLY=( $(compgen -W "{flags}" '
            '-- "$cur") ); return ;;',
            "            esac",
            "            ;;",
        ]
    return out


def completions_zsh(ap: argparse.ArgumentParser) -> str:
    listed, eating = flags_with_values(ap)
    helps = subcommand_help(ap)
    lines = [
        "#compdef cg",
        "# completions para o cg — geradas por: cg completions zsh",
        "# Estático de propósito: no Tab nada é executado e o índice não abre.",
        "",
        "_cg() {",
        "    local -a comandos sub opts",
        "    local i cmdpos=0",
        "",
        "    for (( i = 2; i < CURRENT; i++ )); do",
        "        if [[ $words[i] != -* ]]; then cmdpos=$i; break; fi",
        "    done",
        "",
        "    if (( ! cmdpos )); then",
        "        comandos=(",
    ]
    for name in real_commands(ap):
        lines.append(f"            '{name}:{_zsh(helps[name])}'")
    lines += [
        "            '--debug:log detalhado em ~/.cache/cg/cg.log'",
        "        )",
        "        _describe -t comando 'comando' comandos",
        "        return",
        "    fi",
        "",
        "    case $words[cmdpos] in",
    ]
    for name in real_commands(ap):
        sub = subcommands(ap)[name]
        children = real_commands(sub)
        flags = option_words(sub)
        if name in POSITIONAL_FILES:
            lines += [
                f"        {name})",
                "            if (( CURRENT == cmdpos + 1 )); then _files; return; fi",
                *_zsh_opts(flags, 12),
                "            ;;",
            ]
        elif not children:
            lines += [f"        {name})", *_zsh_opts(flags, 12), "            ;;"]
        else:
            lines += [
                f"        {name})",
                "            if (( CURRENT == cmdpos + 1 )); then",
                "                sub=(",
            ]
            for child in children:
                desc = _zsh(subcommand_help(sub)[child])
                lines.append(f"                    '{child}:{desc}'")
            lines += [
                "                )",
                "                _describe -t subcomando 'subcomando' sub",
                "                return",
                "            fi",
                "            case $words[cmdpos+1] in",
            ]
            for child in children:
                child_flags = option_words(subcommands(sub)[child])
                lines += [
                    f"                {child})",
                    *_zsh_opts(child_flags),
                    "                    ;;",
                ]
            lines += [
                "                *)",
                *_zsh_opts(flags),
                "                    ;;",
                "            esac",
                "            ;;",
            ]
    lines += [
        "        *)",
        "            opts=()",
        "            ;;",
        "    esac",
        "",
        "    case $words[CURRENT-1] in",
        "        --outdir) _directories; return ;;",
        f"        {'|'.join(sorted(FILE_FLAGS))}) _files; return ;;",
    ]
    for flag, values in sorted(listed.items()):
        lines.append(f"        {flag}) _values 'valor' {' '.join(values)}; return ;;")
    eat = sorted(eating - FILE_FLAGS - DIR_FLAGS - set(listed))
    if eat:
        lines.append(f"        {'|'.join(eat)}) return ;;")
    lines += [
        "    esac",
        "",
        "    (( ${#opts} )) && compadd -- $opts",
        "}",
        "",
    ]
    return "\n".join(lines)


def _zsh_opts(flags: list[str], indent: int = 20) -> list[str]:
    pad = " " * indent
    rows = [f"{pad}opts=("]
    rows += [f"{pad}    {row}" for row in _wrap(flags, 64)]
    rows.append(f"{pad})")
    return rows


def completions_fish(ap: argparse.ArgumentParser) -> str:
    helps = subcommand_help(ap)
    lines = [
        "# completions para o cg — geradas por: cg completions fish",
        "# Estático de propósito: no Tab nada é executado e o índice não abre.",
        "complete -c cg -f",
        "",
    ]
    for name in real_commands(ap):
        lines.append(
            f'complete -c cg -n "__fish_use_subcommand" -a {name} '
            f'-d "{_fish(helps[name])}"'
        )
    lines.append(
        'complete -c cg -n "__fish_use_subcommand" -l debug '
        '-d "log detalhado em ~/.cache/cg/cg.log"'
    )
    lines.append("")

    for name in real_commands(ap):
        sub = subcommands(ap)[name]
        children = real_commands(sub)
        if children:
            cond = _fish_parent(name, children)
            for child in children:
                desc = _fish(subcommand_help(sub)[child])
                lines.append(f'complete -c cg -n "{cond}" -a {child} -d "{desc}"')
            lines += _fish_options(sub, cond)
            for child in children:
                lines += _fish_options(
                    subcommands(sub)[child],
                    f"__fish_seen_subcommand_from {child}",
                )
        else:
            if name in POSITIONAL_FILES:
                lines.append(
                    f'complete -c cg -n "__fish_seen_subcommand_from {name}" -F'
                )
            lines += _fish_options(sub, f"__fish_seen_subcommand_from {name}")
        lines.append("")

    return "\n".join(lines)


def _fish_parent(name: str, children: list[str]) -> str:
    seen = f"__fish_seen_subcommand_from {name}"
    if name == "archive":
        seen += f"; and not __fish_seen_subcommand_from {' '.join(children)}"
    return seen


def _fish_options(ap: argparse.ArgumentParser, cond: str) -> list[str]:
    out = []
    for action in ap._actions:
        words = action.option_strings
        if not words:
            continue
        parts = [f'complete -c cg -n "{cond}"']
        for word in words:
            if word.startswith("--"):
                parts.append(f"-l {word[2:]}")
            else:
                parts.append(f"-s {word[1:]}")
        if action.nargs != 0:
            parts.append("-r")
            if words[0] in FILE_FLAGS or words[0] in DIR_FLAGS:
                parts.append("-F")
            if action.choices:
                parts.append(f'-a "{" ".join(map(str, action.choices))}"')
        parts.append(f'-d "{_fish(action.help)}"')
        out.append(" ".join(parts))
    return out


SHELLS = {
    "bash": completions_bash,
    "zsh": completions_zsh,
    "fish": completions_fish,
}


def cmd_completions(args) -> int:
    shell = args.shell or Path(os.environ.get("SHELL", "")).name
    script = SHELLS.get(shell)
    if script is None:
        raise SystemExit(
            "error: shell desconhecido — use `cg completions bash|zsh|fish`"
        )
    print(script(build_parser()).rstrip("\n"))
    return 0


def _add_auth_args(parser) -> None:
    parser.add_argument(
        "--cookie",
        help="cookie de sessão avulso (prefira `cg login`, que salva uma vez)",
    )
    parser.add_argument(
        "--cookie-file",
        help="arquivo 600 com o cookie (padrão: ~/.local/state/cg/session)",
    )
    parser.add_argument(
        "--base-url", default=DEFAULT_BASE, help="URL base (só para testes)"
    )


def setup_logging(verbose: bool) -> None:
    """Always keep a rotating file; only mirror it to the terminal with --debug."""
    if log.handlers:
        return
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.chmod(0o700)  # the log carries chat ids and titles
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s", "%H:%M:%S")
    handler = RotatingFileHandler(
        LOG_PATH, maxBytes=2_000_000, backupCount=3, encoding="utf-8"
    )
    LOG_PATH.touch(mode=0o600, exist_ok=True)
    LOG_PATH.chmod(0o600)
    handler.setFormatter(fmt)
    log.addHandler(handler)
    log.setLevel(logging.DEBUG if verbose else logging.INFO)
    log.propagate = False
    if verbose:
        console = logging.StreamHandler()
        console.setFormatter(fmt)
        log.addHandler(console)


def _safe_argv(argv: list[str]) -> str:
    """Never let the session cookie reach the log file."""
    out, secret = [], False
    for arg in argv:
        if secret:
            out.append("***")
            secret = False
        elif arg == "--cookie":
            out.append(arg)
            secret = True
        else:
            out.append(arg)
    return " ".join(out)


def cmd_help(ap: argparse.ArgumentParser) -> int:
    ap.print_help()
    print(
        "\nprimeiros passos\n"
        "  1. cg login                  pega a sessão do Brave/LibreWolf (uma vez)\n"
        "  2. cg sync --deep            indexa a conta; pode parar e retomar\n"
        "  3. cg plan                   relatório com o que organizar/arquivar\n"
        "  4. cg organize               mostra o que seria movido (dry-run)\n"
        "  5. cg archive                idem, para as conversas sem valor\n"
        "\n"
        "  Nada é apagado: arquivar esconde da lista e mover é reversível.\n"
        "  Para aplicar qualquer passo, repita o comando com --yes.\n"
        "\n"
        f"  índice : {DB_PATH}\n"
        f"  log    : {LOG_PATH}   (veja com `cg log -n 40`)\n"
        "  ajuda de um comando: cg <comando> --help\n"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        prog="cg",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=(
            "Organiza e limpa o histórico do ChatGPT web.\n"
            "Indexa as conversas, classifica por assunto, move para Projects e\n"
            "arquiva o que não presta. Não existe comando que apague conversas."
        ),
        epilog=(
            "fluxo completo\n"
            "  cg login                    salva a sessão do navegador\n"
            "  cg sync --deep              baixa lista + conteúdo (retomável)\n"
            "  cg plan                     lê o relatório em "
            "~/.local/state/cg/reports\n"
            "  cg organize --yes           move para Projects (reversível)\n"
            "  cg archive --yes            arquiva o resto (reversível)\n"
            "\n"
            "desfazer\n"
            "  cg unorganize --log <organize-*.jsonl>\n"
            "  cg unarchive  --log <archive-*.jsonl>\n"
            "\n"
            "log de depuração: cg log -n 40   ·   ~/.cache/cg/cg.log\n"
            "ajuda detalhada: cg <comando> --help"
        ),
    )
    ap.add_argument(
        "--debug",
        action="store_true",
        help="mostrar o log detalhado no terminal (também CG_DEBUG=1)",
    )
    sub = ap.add_subparsers(dest="cmd", metavar="comando", title="comandos")

    ing = sub.add_parser(
        "ingest",
        help="indexar um export oficial (zip, json ou pasta)",
        description=(
            "Lê o export de dados do ChatGPT e guarda as conversas no índice.\n"
            "Use quando já baixou o zip; para a conta ao vivo prefira `cg sync`."
        ),
        epilog="exemplo\n  cg ingest ~/Downloads/chatgpt-export.zip",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ing.add_argument("source", type=Path, help="zip, conversations.json ou pasta")
    ing.set_defaults(func=cmd_ingest)

    pl = sub.add_parser(
        "plan",
        help="relatório do que organizar, arquivar e apagar",
        description=(
            "Cruza o índice com as regras de classificação e escreve dois arquivos\n"
            "em ~/.local/state/cg/reports: um .md para ler e um .tsv para filtrar.\n"
            "Não altera nada na conta."
        ),
        epilog=(
            "exemplos\n"
            "  cg plan\n"
            "  cg plan --days 200    considera 'antiga' o que passou de 200 dias"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pl.add_argument(
        "--days",
        type=int,
        default=120,
        help="idade para a seção 'antigas e vivas' (padrão: 120)",
    )
    pl.set_defaults(func=cmd_plan)

    st = sub.add_parser(
        "status",
        help="o que já está indexado e onde ficam os arquivos",
        description=(
            "Resumo rápido: quantas conversas existem no índice, qual foi a última\n"
            "origem e os caminhos do banco e do log."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    st.set_defaults(func=cmd_status)

    sy = sub.add_parser(
        "sync",
        help="baixar a conta pela API da web (lista e, com --deep, o conteúdo)",
        description=(
            "Fala com os mesmos endpoints da barra lateral do ChatGPT.\n"
            "A lista traz id, título e datas; o corpo das mensagens exige uma\n"
            "requisição por conversa, por isso --deep é lento e retomável.\n"
            "Respeita o rate limit: uma requisição por vez, com pausa entre elas."
        ),
        epilog=(
            "exemplos\n"
            "  cg sync                     só a lista (segundos)\n"
            "  cg sync --deep              baixa o conteúdo que falta\n"
            "  cg sync --deep --limit 50   baixa 50 e para; rode de novo para seguir\n"
            "\ninterromper com Ctrl+C é seguro: o progresso fica salvo."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sy.add_argument(
        "--sleep", type=float, default=1.0, help="pausa entre páginas da lista (1.0s)"
    )
    sy.add_argument(
        "--deep", action="store_true", help="baixar também o corpo de cada conversa"
    )
    sy.add_argument(
        "--limit",
        type=int,
        default=200,
        help=(
            "com --deep, parar depois de N conversas (padrão: 200; 0 = todas). "
            "O progresso fica salvo"
        ),
    )
    sy.add_argument(
        "--max-retries",
        type=int,
        default=4,
        help="tentativas extra em 429/5xx antes de desistir (padrão: 4)",
    )
    sy.add_argument(
        "--deep-sleep",
        type=float,
        default=2.0,
        help=(
            "pausa entre conversas no --deep (padrão: 2.0s; o servidor limita ~1 req/s)"
        ),
    )
    _add_auth_args(sy)
    sy.set_defaults(func=cmd_sync)

    au = sub.add_parser(
        "login",
        help="salvar a sessão do navegador (sem colar cookie na mão)",
        description=(
            "Lê os cookies do Brave/Chromium ou do LibreWolf/Firefox, valida com\n"
            "/api/auth/session e grava em ~/.local/state/cg/session (modo 600).\n"
            "Depois disso nenhum comando precisa de --cookie."
        ),
        epilog=(
            "exemplos\n"
            "  cg login\n"
            "  cg login --store ~/.config/BraveSoftware/Brave-Browser/Default/Cookies"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    au.add_argument(
        "--store", help="caminho do Cookies/cookies.sqlite (auto-detectado)"
    )
    au.add_argument("--save", help="onde salvar (padrão: ~/.local/state/cg/session)")
    au.add_argument(
        "--base-url", default=DEFAULT_BASE, help="URL base (só para testes)"
    )
    au.set_defaults(func=cmd_login)

    au = sub.add_parser(
        "auth",
        help="testar se a sessão salva ainda vale",
        description="Uma chamada de leitura; mostra conta, plano e validade.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    _add_auth_args(au)
    au.set_defaults(func=cmd_auth)

    pr = sub.add_parser(
        "projects",
        help="listar os Projects da conta e quantas conversas há em cada um",
        description=(
            "Só leitura. Mostra nome, id e quantas conversas do índice estão no\n"
            "Project, além de quantas ainda estão fora de qualquer Project."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    _add_auth_args(pr)
    pr.set_defaults(func=cmd_projects)

    og = sub.add_parser(
        "organize",
        help="mover conversas para Projects (dry-run por padrão)",
        description=(
            "Agrupa as conversas 'manter' por categoria e move cada uma para o\n"
            "Project de mesmo nome, criando os que faltam. Reaproveita Projects\n"
            "existentes quando o nome bate (sem diferenciar maiúsculas/acentos).\n"
            "Sem --yes apenas mostra o plano; nada sai do lugar."
        ),
        epilog=(
            "exemplos\n"
            "  cg organize                          ver o plano\n"
            "  cg organize --yes                    aplicar\n"
            "  cg organize --min 5                  criar só Projects com 5+ chats\n"
            "  cg organize --fallback Triagem      nome do Project de fallback\n"
            '  cg organize --map "Linux & Arch=nix"  usar um Project que já existe\n'
            "\nProjects criados nunca são apagados pelo cg."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    og.add_argument(
        "--yes", action="store_true", help="aplicar de verdade (sem isso é dry-run)"
    )
    og.add_argument(
        "--limit", type=int, default=100, help="máximo de conversas por execução"
    )
    og.add_argument(
        "--min",
        type=int,
        default=3,
        help="mínimo de conversas para criar um Project novo (padrão: 3)",
    )
    og.add_argument(
        "--map",
        action="append",
        metavar="CATEGORIA=PROJETO",
        help="reusar um Project existente com outro nome (repetível)",
    )
    og.add_argument(
        "--fallback",
        default="Inbox",
        metavar="PROJETO",
        help="Project que recebe o que não se encaixa em nenhuma categoria",
    )
    og.add_argument(
        "--no-fallback",
        action="store_true",
        help="deixar as conversas sem categoria fora de qualquer Project",
    )
    og.add_argument("--sleep", type=float, default=1.5, help="pausa entre chamadas")
    _add_auth_args(og)
    og.set_defaults(func=cmd_organize)

    uo = sub.add_parser(
        "unorganize",
        help="desfazer: devolver as conversas ao Project anterior",
        description=(
            "Lê o log de uma execução de `organize` e devolve cada conversa ao\n"
            "Project de onde saiu. Projects criados naquela execução continuam\n"
            "existindo — apague à mão se não quiser nenhum."
        ),
        epilog=(
            "exemplo\n  cg unorganize --log ~/.local/state/cg/reports/organize-*.jsonl"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    uo.add_argument("--log", required=True, help="log gerado por `cg organize`")
    uo.add_argument("--sleep", type=float, default=1.5)
    _add_auth_args(uo)
    uo.set_defaults(func=cmd_unorganize)

    mv = sub.add_parser(
        "move",
        help="mover conversas entre Projects (dry-run por padrão)",
        description=(
            "Move um lote explícito de conversas para um Project.\n"
            "Use --ids com uma lista de conv_id, ou --from para filtrar pela\n"
            "origem. Sem --yes nada sai do lugar; o log permite desfazer com\n"
            "`cg unorganize --log`."
        ),
        epilog=(
            "exemplos\n"
            "  cg move --to 'Linux & Arch' --from 'Inbox'\n"
            "  cg move --to 'Agents' --ids lista.txt --yes --limit 50\n"
            "  cg move --to 'Triagem' --from none --create --yes"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    mv.add_argument("--to", required=True, metavar="PROJETO", help="Project de destino")
    mv.add_argument("--from", metavar="PROJETO", help="Project de origem")
    mv.add_argument("--ids", help="arquivo com um conv_id por linha")
    mv.add_argument(
        "--create", action="store_true", help="criar o Project de destino se faltar"
    )
    mv.add_argument(
        "--yes", action="store_true", help="aplicar de verdade (sem isso é dry-run)"
    )
    mv.add_argument(
        "--limit", type=int, default=100, help="máximo por execução (0 = todas)"
    )
    mv.add_argument("--sleep", type=float, default=1.5, help="pausa entre chamadas")
    _add_auth_args(mv)
    mv.set_defaults(func=cmd_move)

    def archive_options(p: argparse.ArgumentParser) -> None:
        p.add_argument(
            "--yes", action="store_true", help="aplicar de verdade (sem isso é dry-run)"
        )
        p.add_argument(
            "--limit", type=int, default=100, help="máximo por execução (0 = todas)"
        )
        p.add_argument("--sleep", type=float, default=1.5, help="pausa entre chamadas")
        p.add_argument(
            "--ids", help="arquivo com um conv_id por linha (filtra a seleção)"
        )
        _add_auth_args(p)

    ar = sub.add_parser(
        "archive",
        help="arquivar conversas sem valor (reversível)",
        description=(
            "Arquiva one-shots, duplicadas e conversas vazias conforme o plano.\n"
            "Arquivar só esconde da lista: dá para restaurar com `cg unarchive`.\n"
            "Nada é apagado, e conversas sem conteúdo indexado nunca entram.\n\n"
            "Sem subcomando, `cg archive` é o dry-run de `run`."
        ),
        epilog=(
            "exemplos\n"
            "  cg archive                    ver o que seria arquivado\n"
            "  cg archive list               listar as já arquivadas\n"
            "  cg archive list --candidates  listar o que entraria\n"
            "  cg archive stats              resumo por motivo\n"
            "  cg archive show 6ae22dd8      detalhes de uma conversa\n"
            "  cg archive run --yes --limit 50"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    archive_options(ar)
    ar.set_defaults(func=cmd_archive)

    ar_sub = ar.add_subparsers(
        dest="archive_cmd", metavar="subcomando", title="subcomandos"
    )

    ar_run = ar_sub.add_parser(
        "run",
        help="aplicar o plano (dry-run sem --yes)",
        description="O mesmo que `cg archive` sem subcomando.",
        epilog=(
            "exemplos\n"
            "  cg archive run\n"
            "  cg archive run --yes --limit 50\n"
            "  cg archive run --yes --ids lista.txt"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    archive_options(ar_run)
    ar_run.set_defaults(func=cmd_archive)

    ar_list = ar_sub.add_parser(
        "list",
        help="listar arquivadas ou candidatas (offline)",
        description=(
            "Lê só o índice local, sem falar com o ChatGPT.\n"
            "O estado de 'arquivada' reflete o último sync ou `cg archive run`."
        ),
        epilog=(
            "exemplos\n"
            "  cg archive list\n"
            "  cg archive list --candidates\n"
            "  cg archive list --urls --limit 0"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ar_list.add_argument(
        "--candidates",
        action="store_true",
        help="listar o que o plano sugere arquivar, em vez das já arquivadas",
    )
    ar_list.add_argument(
        "--limit", type=int, default=50, help="quantas mostrar (0 = todas)"
    )
    ar_list.add_argument(
        "--urls", action="store_true", help="incluir o link de cada conversa"
    )

    ar_show = ar_sub.add_parser(
        "show",
        help="detalhes de uma conversa (aceita prefixo do id)",
        description="Lê só o índice local. Serve para conferir antes de arquivar.",
        epilog=(
            "exemplos\n  cg archive show 6ae22dd8\n  cg archive show 6ae22dd8-b474"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ar_show.add_argument("id", help="conv_id ou prefixo único")

    ar_sub.add_parser(
        "stats",
        help="resumo: arquivadas, candidatas e motivo de cada uma",
        description="Contagens do índice local, sem rede.",
    )

    un = sub.add_parser(
        "unarchive",
        help="desfazer: restaurar conversas arquivadas",
        description=(
            "Devolve conversas à lista normal. Use --log para desfazer exatamente\n"
            "uma execução de `archive`, ou --all para restaurar tudo que o índice\n"
            "marcou como arquivado."
        ),
        epilog=(
            "exemplos\n"
            "  cg unarchive --log ~/.local/state/cg/reports/archive-*.jsonl\n"
            "  cg unarchive --all"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    un.add_argument("--log", help="log gerado por `cg archive`")
    un.add_argument(
        "--all",
        action="store_true",
        help="restaurar tudo que está marcado como arquivado",
    )
    un.add_argument("--sleep", type=float, default=1.5)
    _add_auth_args(un)
    un.set_defaults(func=cmd_unarchive)

    lg = sub.add_parser(
        "log",
        help="ver o log de depuração (~/.cache/cg/cg.log)",
        description=(
            "Mostra o fim do log rotativo. Cada requisição HTTP aparece com\n"
            "método, URL, status e duração; cookies nunca são gravados.\n"
            "Use --debug nos outros comandos para ver o mesmo no terminal."
        ),
        epilog=(
            "exemplos\n"
            "  cg log                 últimas 60 linhas\n"
            "  cg log -n 200          últimas 200\n"
            "  cg log --path          só o caminho do arquivo"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    lg.add_argument("-n", "--lines", type=int, default=60, help="quantas linhas (60)")
    lg.add_argument("--path", action="store_true", help="imprimir só o caminho")
    lg.set_defaults(func=cmd_log)

    ex = sub.add_parser(
        "export",
        help="exportar conversas para Markdown, organizadas por projeto",
        description=(
            "Gera arquivos .md por conversa, em pastas com o nome do Project.\n"
            "Usa o índice local; se faltar o corpo completo, pode baixar sob demanda\n"
            "pela API com --fetch (precisa de sessão salva via `cg login`).\n\n"
            "Nunca sobrescreve um .md que você editou à mão: se o conteúdo mudou,\n"
            "o arquivo é preservado e contado no resumo. Use --overwrite para\n"
            "substituir de propósito."
        ),
        epilog=(
            "exemplos\n"
            "  cg export                           padrão: ~/Documents/ChatGPT\n"
            "  cg export --outdir ~/backup/chatgpt\n"
            "  cg export --only-project 'Linux & Arch'\n"
            "  cg export --fetch                   baixa conteúdo que falta pela API\n"
            "  cg export --deep-fetch              ignora o cache e busca de novo\n"
            "  cg export --overwrite               substitui .md editados à mão\n"
            "  cg export --skip-empty              pula conversas sem conteúdo\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ex.add_argument("--outdir", help="pasta de destino (padrão: ~/Documents/ChatGPT)")
    ex.add_argument("--only-project", help="exportar apenas um projeto/categoria")
    ex.add_argument(
        "--verdict",
        choices=["keep", "review", "archive", "delete", "unknown"],
        help="filtrar por veredito do plano",
    )
    ex.add_argument(
        "--archived-only", action="store_true", help="apenas conversas arquivadas"
    )
    ex.add_argument(
        "--not-archived", action="store_true", help="apenas conversas não arquivadas"
    )
    ex.add_argument(
        "--fetch",
        action="store_true",
        help="baixar conteúdo faltante pela API (usa sessão salva)",
    )
    ex.add_argument(
        "--deep-fetch",
        action="store_true",
        help="forçar busca pela API mesmo se cache existir",
    )
    ex.add_argument(
        "--skip-empty", action="store_true", help="pular conversas sem mensagens"
    )
    ex.add_argument(
        "--overwrite",
        action="store_true",
        help=(
            "substituir .md existentes que você editou à mão "
            "(sem isso eles são preservados)"
        ),
    )
    ex.add_argument(
        "--sleep", type=float, default=1.5, help="pausa entre requisições ao buscar"
    )
    _add_auth_args(ex)
    ex.set_defaults(func=cmd_export)

    at = sub.add_parser(
        "auto",
        help="atribuir conversas sem projeto automaticamente",
        description=(
            "Olha só conversas sem projeto, classifica pelo título + conteúdo "
            "e move para o Project mais coerente. Cria projetos se solicitado."
        ),
        epilog=(
            "exemplos\n"
            "  cg auto                     ver sugestão\n"
            "  cg auto --create            criar projetos novos se necessário\n"
            "  cg auto --yes --create      aplicar de verdade\n"
            "  cg auto --fallback Triagem  nome do Inbox alternativo\n"
            "  cg auto --map 'AI & Agents=Agents'\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    at.add_argument("--yes", action="store_true", help="aplicar de verdade")
    at.add_argument(
        "--create", action="store_true", help="criar projetos que não existirem"
    )
    at.add_argument("--limit", type=int, default=100, help="máximo por execução")
    at.add_argument("--min", type=int, default=3, help="mínimo para criar projeto novo")
    at.add_argument(
        "--map",
        action="append",
        metavar="CATEGORIA=PROJETO",
        help="mapear categoria para projeto existente",
    )
    at.add_argument(
        "--fallback",
        default="Inbox",
        metavar="PROJETO",
        help="projeto para dúvidas/incertas",
    )
    at.add_argument(
        "--no-fallback", action="store_true", help="não mover o que cair no fallback"
    )
    at.add_argument("--sleep", type=float, default=1.5, help="pausa entre chamadas")
    at.add_argument(
        "--max-age",
        type=int,
        default=720,
        metavar="MIN",
        help="recusar um índice mais velho que isso antes de escrever (0 desliga)",
    )
    _add_auth_args(at)
    at.set_defaults(func=cmd_auto)

    co = sub.add_parser(
        "completions",
        aliases=["tab"],
        help="gerar completions de shell (bash, zsh, fish)",
        description=(
            "Imprime um script de completion para o seu shell (atalho: `cg tab`).\n"
            "O script é estático: no Tab ele não executa o cg, não abre o índice\n"
            "e não toca na rede — só lista as palavras que o parser já conhece.\n\n"
            "Nada é instalado: o texto vai para stdout e você escolhe onde mora."
        ),
        epilog=(
            "exemplos\n"
            "  cg completions        detecta o shell pelo $SHELL\n"
            "  cg completions zsh > ~/.local/share/zsh/site-functions/_cg\n"
            "  cg completions bash > ~/.local/share/bash-completion/completions/cg\n"
            "  cg completions fish > ~/.config/fish/completions/cg.fish\n"
            "\n"
            "bash: requer o pacote bash-completion; abra um shell novo depois.\n"
            "zsh : o diretório precisa estar no $fpath (o padrão do Arch já está).\n"
            "fish: abrir um shell novo basta."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    co.add_argument(
        "shell",
        nargs="?",
        choices=sorted(SHELLS),
        help="shell alvo (padrão: $SHELL)",
    )
    co.set_defaults(func=cmd_completions)

    return ap


def cmd_auto(args) -> int:
    with exclusive_run():
        return _auto(args)


def _auto(args) -> int:
    con = connect()
    rows = con.execute(
        "SELECT * FROM conversations WHERE project_id IS NULL AND has_content = 1 "
        "AND archived = 0 AND gone = 0 ORDER BY created_ts"
    ).fetchall()
    if not rows:
        print("Nada pra atribuir: não tem conversas sem projeto com conteúdo indexado.")
        print("Dica: rode `cg sync --deep` pra garantir que tem o corpo das mensagens.")
        return 0

    age = index_age(con)
    if args.yes and args.max_age > 0 and age > args.max_age:
        raise SystemExit(
            f"error: o índice está {describe_age(age)} — o site pode ter mudado.\n"
            "  Rode `cg sync` antes de aplicar (ou use --max-age 0 para ignorar)."
        )

    base = args.base_url.rstrip("/")
    session = open_session(base, resolve_cookie(args))
    token = session["accessToken"]
    THROTTLE.set_floor(args.sleep)

    projects = list_projects(base, token)
    existing = {project_key(p["name"]): p for p in projects}

    aliases: dict[str, str] = {}
    for spec in args.map or []:
        if "=" not in spec:
            raise SystemExit(f"error: --map espera Categoria=Projeto, veio {spec!r}")
        category, name = spec.split("=", 1)
        aliases[project_key(category)] = name.strip()

    fallback = None if args.no_fallback else args.fallback

    plans_all = build_plan(rows)
    targets, skipped = plan_projects(plans_all, existing, aliases, args.min, fallback)

    to_create = [t for t in targets if not t["project_id"]]
    if not args.create:
        to_create = []
    pending = []
    for t in targets:
        if args.create is False and t["project_id"] is None:
            continue
        for p in t["items"]:
            if (
                p["row"]["project_id"] is None
                and p["row"]["has_content"]
                and not p["row"]["archived"]
            ):
                pending.append((p, t))

    targets_show = (
        targets if args.create else [t for t in targets if t["project_id"] is not None]
    )

    print(f"sem projeto: {len(rows)}")
    print(f"índice  : {describe_age(age)}")
    print(f"projetos existentes: {len(projects)}")
    if args.create:
        print(
            f"categorias sugeridas: {len(targets)} · a criar: {len(to_create)}"
            f" · movimentos: {len(pending)}"
        )
    else:
        print(
            f"categorias sugeridas: {len(targets_show)}"
            f" · movimentos: {len(pending)} (criação desativada)"
        )
    for t in targets if args.create else targets_show:
        names = ", ".join(t["categories"])
        mark = "+" if not t["project_id"] else "→"
        print(f"  {mark} {t['name'][:34]:34} {len(t['items']):>3} chats  ({names})")
    for s in skipped:
        print(
            f"  · {s['name'][:34]:34} {len(s['items']):>3} chats  "
            f"ignorado (--min {args.min})"
        )

    if not pending:
        print("\nnada pra mover — já está tudo bem alocado ou sem match claro.")
        return 0

    limit = args.limit if args.limit and args.limit > 0 else len(pending)
    queue = pending[:limit]

    print(f"\nserão movidas: {len(queue)} (limite {limit})")
    for p, t in queue[:10]:
        r = p["row"]
        print(f"  → {t['name'][:24]:24}  {r['title'][:56]}")
    if len(queue) > 10:
        print(f"  … e mais {len(queue) - 10}")

    if not args.yes:
        print("\nsimulação: nada foi enviado. aplicar com --yes")
        print("pra criar projetos novos: adicione --create")
        return 0

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = REPORT_DIR / f"auto-{stamp}.jsonl"
    backup = snapshot_db(con, "auto-backup")
    known = {p["id"] for p in projects}
    done = failed = gone = 0

    with log_path.open("a", encoding="utf-8") as journal:
        if args.create:
            for t in to_create:
                status, pid = create_project(base, token, t["name"])
                ok = bool(pid)
                journal.write(
                    json.dumps(
                        {
                            "kind": "project",
                            "name": t["name"],
                            "project_id": pid,
                            "status": status,
                            "ok": ok,
                            "at": datetime.now().isoformat(timespec="seconds"),
                        }
                    )
                    + "\n"
                )
                journal.flush()
                if not ok:
                    print(
                        f"abortado: não criou o Project {t['name']!r} (HTTP {status})"
                    )
                    print(f"log: {log_path}")
                    return 2
                t["project_id"] = pid
                known.add(pid)
                print(f"criado: {t['name']} ({pid})")

        for i, (p, t) in enumerate(queue, 1):
            if not t["project_id"]:
                continue
            r = p["row"]
            cid = r["conv_id"]
            # Never write to an id we would not put in a URL, and never write a
            # project id that the server did not just hand us.
            if not valid_conv_id(cid):
                print(f"[{i:>3}/{len(queue)}] id inválido, pulando: {cid!r}")
                failed += 1
                continue
            if t["project_id"] not in known:
                print(f"[{i:>3}/{len(queue)}] projeto desconhecido: {t['project_id']}")
                failed += 1
                continue
            status, body = set_project(base, token, cid, t["project_id"])
            if status in (401, 403):
                print(f"\nabortado: HTTP {status} — sessão inválida.")
                print(f"movidas até aqui: {done}. log: {log_path}")
                return 2
            if status == 429:
                print("\nabortado: HTTP 429 — rate limit. Espere e rode de novo.")
                print(f"movidas: {done}. log: {log_path}")
                return 3
            ok = move_confirmed(status, body, t["project_id"])
            if status == 404:
                gone += 1
                mark_gone(con, cid)
                con.commit()
            journal.write(
                json.dumps(
                    {
                        "kind": "move",
                        "conv_id": cid,
                        "from": r["project_id"],
                        "to": t["project_id"],
                        "to_name": t["name"],
                        "status": status,
                        "ok": ok,
                        "gone": status == 404,
                        "at": datetime.now().isoformat(timespec="seconds"),
                    }
                )
                + "\n"
            )
            journal.flush()
            if ok:
                done += 1
                con.execute(
                    "UPDATE conversations SET project_id = ? WHERE conv_id = ?",
                    (t["project_id"], cid),
                )
                con.commit()
                print(
                    f"[{i:>3}/{len(queue)}] ok       "
                    f"{t['name'][:22]:22} {r['title'][:48]}"
                )
            elif status == 404:
                print(f"[{i:>3}/{len(queue)}] sumiu    {r['title'][:48]}")
            elif status in (200, 201, 204):
                failed += 1
                print(f"[{i:>3}/{len(queue)}] sem confirmação  {r['title'][:48]}")
            else:
                failed += 1
                print(f"[{i:>3}/{len(queue)}] HTTP {status}  {r['title'][:48]}")

    log.info("auto: %d movidas, %d falhas, %d sumidas", done, failed, gone)
    print(
        f"\nmovidas: {done} · falhas: {failed}"
        + (f" · sumidas do site: {gone}" if gone else "")
        + (f" · criadas: {len(to_create)}" if args.create else "")
    )
    print(f"log     : {log_path}")
    print(f"backup  : {backup}")
    print(f"desfazer: cg unorganize --log {log_path}")
    return 0 if not failed else 1


def _silence_stdout() -> None:
    """The reader went away (`cg plan | head`); stop Python from complaining."""
    with contextlib.suppress(OSError, ValueError):
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())


class Interrupted(KeyboardInterrupt):
    """A signal asked us to stop, but as an exception, so cleanup still runs."""

    def __init__(self, signum: int, signal_name: str) -> None:
        super().__init__(f"{signal_name} ({signum})")
        self.signum = signum
        self.signal_name = signal_name


_STOPPING = False


def _on_stop_signal(signum: int, _frame) -> None:
    global _STOPPING
    try:
        name = signal.Signals(signum).name
    except ValueError:
        name = f"signal {signum}"
    if _STOPPING:
        # A second Ctrl-C means "now": drop the handler and let the signal kill us.
        signal.signal(signum, signal.SIG_DFL)
        os.kill(os.getpid(), signum)
        return
    _STOPPING = True
    raise Interrupted(signum, name)


def install_signal_handlers() -> None:
    """Turn SIGINT/SIGTERM/SIGHUP into a normal unwind.

    Without this, a `kill` or a closed terminal tears the process down mid-run:
    no `finally`, no commit, and no word about what was already done. With it the
    command returns from its loop, the journal closes and the run lock drops.
    """
    for name in ("SIGINT", "SIGTERM", "SIGHUP"):
        sig = getattr(signal, name, None)
        if sig is not None:
            # ValueError if this is not the main thread: leave the default alone.
            with contextlib.suppress(ValueError, OSError):
                signal.signal(sig, _on_stop_signal)


def main() -> int:
    install_signal_handlers()
    ap = build_parser()
    args = ap.parse_args()
    setup_logging(
        bool(getattr(args, "debug", False))
        or os.environ.get("CG_DEBUG", "").strip() == "1"
    )
    if not getattr(args, "cmd", None):
        return cmd_help(ap)

    log.info("cg %s", _safe_argv(sys.argv[1:]))
    try:
        return args.func(args)
    except Interrupted as exc:
        log.warning("interrompido por %s", exc.signal_name)
        print(
            f"\nparando em {exc.signal_name}: o que já foi feito está salvo.",
            file=sys.stderr,
        )
        print(f"relatórios: {REPORT_DIR}", file=sys.stderr)
        return 128 + exc.signum
    except KeyboardInterrupt:
        log.warning("interrompido")
        print("\nparando: o que já foi feito está salvo.", file=sys.stderr)
        return 130
    except BrokenPipeError:
        _silence_stdout()
        return 0
    except SystemExit as exc:
        if exc.code not in (0, None):
            log.error("abortado: %s", exc.code)
        raise
    except OSError as exc:
        if exc.errno in {errno.ENOSPC, getattr(errno, "EDQUOT", errno.ENOSPC)}:
            log.error("disco cheio: %s", exc)
            print(
                "error: disco cheio — libere espaço e rode o mesmo comando de novo.",
                file=sys.stderr,
            )
            return 1
        raise
    except Exception:
        log.exception("erro inesperado")
        raise


if __name__ == "__main__":
    sys.exit(main())
