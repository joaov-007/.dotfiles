#!/usr/bin/env python3
"""Tests for the classifier and the archive/deletion rules.

python3 -m unittest -v test_cg.py
"""

import argparse
import contextlib
import fcntl
import io
import json
import os
import shutil
import signal
import sqlite3
import tempfile
import unittest
import urllib.error
from datetime import UTC, datetime, timedelta
from email.utils import format_datetime
from pathlib import Path
from unittest import mock

import cg
import cg_services

CASES = {
    "pacman -Syu broke grub after the kernel update on arch linux": "Linux & Arch",
    "nixos flake with home-manager for my dotfiles": "NixOS & Dotfiles",
    "podman quadlet for searxng behind nginx on my vps": "Self-hosting",
    "python traceback when pip install fails, unit test with pytest": "Programming",
    "chatgpt vs claude prompt for mcp agents": "AI & Agents",
    "derivada e integral passo a passo": "Math & Study",
    "melhor configuração de anki para revisão espaçada": "Anki & Learning",
    "diferença entre crase e acento grave na gramática": "Language",
    "currículo para vaga de estágio, como responder entrevista": "Career & Education",
    "quanto investir em tesouro direto e cdb, irpf e imposto": "Money & Finance",
    "passaporte vencido, consulado e visto para imigração": "Legal & Bureaucracy",
    "receita de bolo de cenoura, forno e ingredientes": "Home & Kitchen",
    "quantas calorias e proteína por dia no jejum": "Food & Nutrition",
    "roteiro de viagem, passagem aérea e hotel em lisboa": "Travel & Places",
    "meu namoro está em conflito, família e ciúmes": "Relationships & Family",
    "treino de musculação e corrida para emagrecer": "Fitness & Sport",
    "corte de cabelo, barba e skincare": "Style & Appearance",
    "como escrever um roteiro com personagem e conflito": "Writing & Arts",
    "guitarra: acorde e escala musical, mixagem no ableton": "Music & Audio",
    "minecraft, xadrez e rpg de mesa com amigos na steam": "Games & Fun",
    "recomendação de filme, série e podcast no netflix": "Media & Entertainment",
    "buraco negro, relatividade e quântica no universo": "Science & Space",
    "eleição, governo e notícia de política": "Politics & Society",
    "estoicismo, sentido da vida e meditação": "Philosophy & Spirituality",
    "planejamento de vida: metas, hábitos e morar fora em 5 anos": (
        "Future & Life Planning"
    ),
    "minha horta, compostagem e semente de tomate": "Gardening & Nature",
    "meu cachorro não come a ração, veterinário": "Pets & Animals",
    "arduino esp32 com solda e multímetro": "DIY & Electronics",
    "pneu do carro, óleo do motor e mecânico": "Cars & Transport",
    "dor de cabeça, remédio e consulta médica": "Health & Personal",
    "vale a pena comprar um notebook com ssd e memória ram": "Hardware & Shopping",
}


class TestClassify(unittest.TestCase):
    def test_every_category_is_reachable(self):
        for text, expected in CASES.items():
            with self.subTest(expected):
                got, score, _runner = cg.classify(text)
                self.assertEqual(got, expected, f"{text!r} scored {score}")
                self.assertGreaterEqual(score, cg.PROJECT_MIN_HITS)

    def test_all_categories_have_a_case(self):
        self.assertEqual(set(CASES.values()), set(cg.PROJECTS))

    def test_accents_and_case_do_not_matter(self):
        for text in ("musica", "Música", "MÚSICA", "mu\u0301sica"):
            with self.subTest(text):
                self.assertEqual(cg.fold(cg.fold(text)), cg.fold(text))
                self.assertEqual(cg.classify(text)[0], "Music & Audio")

    def test_matching_is_boundary_exact(self):
        # "api"/"git" must not fire inside unrelated words.
        got, _score, _runner = cg.classify("rapid digitalisation of the rapper")
        self.assertIsNone(got)

    def test_empty_text_is_unclassified(self):
        self.assertIsNone(cg.classify("")[0])
        self.assertIsNone(cg.classify("   \n\t ")[0])

    def test_no_duplicate_terms_across_projects(self):
        seen: dict[str, str] = {}
        for project, terms in cg.PROJECTS.items():
            for term in terms:
                self.assertNotIn(
                    term, seen, f"{term!r} in {project} and {seen.get(term)}"
                )
                seen[term] = project

    def test_terms_are_stable_under_folding(self):
        for project, terms in cg.PROJECTS.items():
            for term in terms:
                folded = cg.fold(term)
                self.assertEqual(cg.fold(folded), folded, f"{project}: {term}")


class TestBuckets(unittest.TestCase):
    @staticmethod
    def row(**over):
        base = {
            "turns": 10,
            "user_turns": 5,
            "user_chars": 900,
            "has_content": 1,
            "archived": 0,
            "gone": 0,
        }
        base.update(over)
        return base

    def test_unfetched_rows_are_never_archived(self):
        self.assertEqual(
            cg.bucket_of(self.row(has_content=0, turns=0), None), "unknown"
        )

    def test_fetched_and_empty_is_deletable(self):
        self.assertEqual(cg.bucket_of(self.row(turns=0, user_turns=0), None), "delete")

    def test_one_question_one_answer_is_archivable(self):
        self.assertEqual(
            cg.bucket_of(self.row(turns=2, user_turns=1, user_chars=80), None),
            "archive",
        )

    def test_long_question_is_not_archived(self):
        self.assertEqual(
            cg.bucket_of(self.row(turns=2, user_turns=1, user_chars=900), None), "keep"
        )

    def test_duplicate_is_archived(self):
        self.assertEqual(cg.bucket_of(self.row(), "mesma conversa"), "archive")


class TestOrganize(unittest.TestCase):
    @staticmethod
    def plan(project, verdict="keep", project_id=None, **over):
        row = {
            "turns": 10,
            "user_turns": 5,
            "user_chars": 900,
            "has_content": 1,
            "archived": 0,
            "gone": 0,
            "project_id": project_id,
            "conv_id": f"c-{project}-{over.pop('n', 0)}",
        }
        row.update(over)
        return {"row": row, "project": project, "verdict": verdict, "hits": 3}

    def test_existing_project_is_reused_after_folding(self):
        plans = [self.plan("Linux & Arch") for _ in range(3)]
        targets, skipped = cg.plan_projects(
            plans,
            {cg.project_key("linux arch"): {"id": "g-1", "name": "Linux & Arch"}},
            {},
            3,
        )
        self.assertEqual(len(targets), 1)
        self.assertEqual(targets[0]["project_id"], "g-1")
        self.assertEqual(skipped, [])

    def test_small_categories_are_skipped_without_create(self):
        plans = [self.plan("Pets & Animals")]
        targets, skipped = cg.plan_projects(plans, {}, {}, 3)
        self.assertEqual(targets, [])
        self.assertEqual(skipped[0]["name"], "Pets & Animals")

    def test_alias_maps_category_to_another_project_name(self):
        plans = [self.plan("Writing & Arts") for _ in range(3)]
        targets, _ = cg.plan_projects(
            plans,
            {cg.project_key("redacao"): {"id": "g-9", "name": "redacao"}},
            {cg.project_key("Writing & Arts"): "redacao"},
            3,
        )
        self.assertEqual(targets[0]["project_id"], "g-9")

    def test_review_and_inbox_are_not_organized(self):
        plans = [
            self.plan("Programming", verdict="review"),
            self.plan("Inbox"),
            self.plan("Games & Fun"),
        ]
        targets, _ = cg.plan_projects(plans, {}, {}, 1, None)
        self.assertEqual([t["name"] for t in targets], ["Games & Fun"])

    def test_categories_sharing_a_project_are_merged(self):
        plans = [self.plan("NixOS & Dotfiles"), self.plan("Linux & Arch")]
        targets, _ = cg.plan_projects(
            plans,
            {},
            {cg.project_key("Linux & Arch"): "NixOS & Dotfiles"},
            1,
        )
        self.assertEqual(len(targets), 1)
        self.assertEqual(len(targets[0]["items"]), 2)

    def test_review_chats_land_in_the_fallback_bucket(self):
        plans = [self.plan("Programming", verdict="review") for _ in range(2)]
        targets, skipped = cg.plan_projects(plans, {}, {}, 3)
        self.assertEqual([t["name"] for t in targets], ["Inbox"])
        self.assertEqual(len(targets[0]["items"]), 2)
        self.assertEqual(skipped, [])

    def test_fallback_can_be_renamed(self):
        plans = [self.plan("Anything", verdict="review")]
        targets, _ = cg.plan_projects(plans, {}, {}, 3, "Triagem")
        self.assertEqual(targets[0]["name"], "Triagem")

    def test_fallback_can_be_disabled(self):
        plans = [self.plan("Programming", verdict="review")]
        targets, _ = cg.plan_projects(plans, {}, {}, 3, None)
        self.assertEqual(targets, [])

    def test_unfetched_rows_never_move(self):
        plans = [self.plan("Programming", verdict="review", has_content=0)]
        targets, _ = cg.plan_projects(plans, {}, {}, 3)
        self.assertEqual(targets, [])

    def test_fallback_is_listed_last(self):
        plans = [self.plan("Games & Fun"), self.plan("Z", verdict="review")]
        targets, _ = cg.plan_projects(plans, {}, {}, 1)
        self.assertEqual(targets[-1]["name"], "Inbox")

    def test_archived_chats_stay_out(self):
        plans = [self.plan("Programming", archived=1) for _ in range(4)]
        targets, _ = cg.plan_projects(plans, {}, {}, 1)
        self.assertEqual(targets, [])


class TestGone(unittest.TestCase):
    """A chat listed by the API but answered with 404 must not be retried."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._state, self._db = cg.STATE_DIR, cg.DB_PATH
        self.addCleanup(self._restore)
        cg.STATE_DIR = Path(self.tmp.name)
        cg.DB_PATH = cg.STATE_DIR / "cg.db"

    def _restore(self):
        cg.STATE_DIR, cg.DB_PATH = self._state, self._db

    def db(self):
        con = cg.connect()
        self.addCleanup(con.close)
        return con

    def insert(self, con, conv_id="c1"):
        con.execute(
            "INSERT INTO conversations (conv_id, title, turns, user_chars, body_sha,"
            " first_user, sample, indexed_at) VALUES (?,?,?,?,?,?,?,?)",
            (conv_id, "t", 0, 0, "", "", "", "now"),
        )

    def test_mark_gone_sets_the_flag(self):
        con = self.db()
        self.insert(con)
        cg.mark_gone(con, "c1")
        self.assertEqual(con.execute("SELECT gone FROM conversations").fetchone()[0], 1)

    def test_reseeing_a_chat_clears_the_mark(self):
        con = self.db()
        conv = cg.Conversation(
            conv_id="c2", title="t", created=None, turns=[cg.Turn("user", "hi")]
        )
        cg.record(con, conv, "api:x", "now", fetched=True)
        cg.mark_gone(con, "c2")
        cg.record(con, conv, "api:x", "now", fetched=True)
        self.assertEqual(con.execute("SELECT gone FROM conversations").fetchone()[0], 0)

    def test_migration_adds_gone_to_an_old_index(self):
        legacy = sqlite3.connect(cg.DB_PATH)
        legacy.executescript(
            """
            CREATE TABLE conversations (
                conv_id TEXT PRIMARY KEY, title TEXT NOT NULL, created_ts REAL,
                turns INTEGER NOT NULL, user_turns INTEGER NOT NULL DEFAULT 0,
                user_chars INTEGER NOT NULL, body_sha TEXT NOT NULL,
                first_user TEXT NOT NULL, sample TEXT NOT NULL,
                archived INTEGER NOT NULL DEFAULT 0,
                has_content INTEGER NOT NULL DEFAULT 0,
                project_id TEXT, source_file TEXT, indexed_at TEXT NOT NULL
            );
            """
        )
        legacy.commit()
        legacy.close()
        con = self.db()
        cols = {r[1] for r in con.execute("PRAGMA table_info(conversations)")}
        self.assertIn("gone", cols)

    def test_gone_chats_are_never_planned_into_a_project(self):
        plans = [TestOrganize.plan("Programming", gone=1) for _ in range(4)]
        targets, _ = cg.plan_projects(plans, {}, {}, 1)
        self.assertEqual(targets, [])


class TestArchiveSubcommands(unittest.TestCase):
    """`archive` grew subcommands; the bare form must still mean `run`."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._state, self._db, self._reports = cg.STATE_DIR, cg.DB_PATH, cg.REPORT_DIR
        self.addCleanup(self._restore)
        cg.STATE_DIR = Path(self.tmp.name)
        cg.DB_PATH = cg.STATE_DIR / "cg.db"
        cg.REPORT_DIR = cg.STATE_DIR / "reports"
        self.con = self.db()
        self.seed()

    def _restore(self):
        cg.STATE_DIR, cg.DB_PATH, cg.REPORT_DIR = self._state, self._db, self._reports

    def db(self):
        con = cg.connect()
        self.addCleanup(con.close)
        return con

    def insert(
        self,
        conv_id,
        *,
        created_ts=1_700_000_000.0,
        turns=2,
        user_turns=1,
        user_chars=80,
        body_sha=None,
        first_user="pergunta curta",
        archived=0,
        has_content=1,
    ):
        self.con.execute(
            "INSERT INTO conversations (conv_id, title, created_ts, turns,"
            " user_turns, user_chars, body_sha, first_user, sample, archived,"
            " has_content, gone, indexed_at)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,0,'now')",
            (
                conv_id,
                conv_id,
                created_ts,
                turns,
                user_turns,
                user_chars,
                f"sha-{conv_id}" if body_sha is None else body_sha,
                first_user,
                "",
                archived,
                has_content,
            ),
        )

    def seed(self):
        # Same transcript twice: the later one is the duplicate.
        self.insert(
            "dup-a",
            user_chars=300,
            body_sha="same",
            first_user="x" * 60,
            created_ts=1_700_000_000.0,
        )
        self.insert(
            "dup-b",
            user_chars=300,
            body_sha="same",
            first_user="x" * 60,
            created_ts=1_700_000_100.0,
        )
        self.insert("one", user_chars=80, body_sha="one")
        self.insert("empty", turns=0, user_turns=0, user_chars=0, body_sha="")
        self.insert("keep", turns=10, user_turns=5, user_chars=2000)
        self.insert(
            "nobody", turns=0, user_turns=0, user_chars=0, body_sha="", has_content=0
        )
        self.con.commit()

    def rows(self):
        return self.con.execute("SELECT * FROM conversations").fetchall()

    def test_summary_splits_candidates_by_reason(self):
        s = cg.archive_summary(self.rows())
        self.assertEqual(s["indexed"], 6)
        self.assertEqual(s["candidates"], 3)
        self.assertEqual((s["duplicada"], s["one-shot"], s["vazia"]), (1, 1, 1))
        self.assertEqual(s["unknown"], 1)

    def test_stats_reports_the_same_numbers_offline(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg.archive_stats(None), 0)
        text = out.getvalue()
        self.assertIn("candidatas  : 3", text)
        self.assertIn("duplicadas: 1", text)
        self.assertIn("sem conteúdo: 1", text)

    def test_list_candidates_is_exactly_what_run_would_touch(self):
        self.assertEqual(
            {p["row"]["conv_id"] for p in cg.archive_targets(self.rows())},
            {"dup-b", "one", "empty"},
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cg.archive_list(argparse.Namespace(candidates=True, limit=0, urls=False))
        text = out.getvalue()
        self.assertIn("candidatas a arquivar: 3", text)
        for cid in ("dup-b", "one", "empty"):
            self.assertIn(cid, text)

    def test_list_defaults_to_archived_and_can_add_links(self):
        self.con.execute("UPDATE conversations SET archived = 1 WHERE conv_id = 'keep'")
        self.con.commit()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            cg.archive_list(argparse.Namespace(candidates=False, limit=0, urls=True))
        text = out.getvalue()
        self.assertIn("arquivadas", text)
        self.assertIn("https://chatgpt.com/c/keep", text)
        self.assertNotIn("dup-b", text)

    def test_show_resolves_a_unique_prefix(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg.archive_show(argparse.Namespace(id="one")), 0)
        text = out.getvalue()
        self.assertIn("id       : one", text)
        self.assertIn("veredito : archive", text)

    def test_show_refuses_an_ambiguous_prefix(self):
        with (
            contextlib.redirect_stdout(io.StringIO()),
            self.assertRaises(SystemExit),
        ):
            cg.archive_show(argparse.Namespace(id="dup-"))

    def test_parser_keeps_the_bare_form_as_run(self):
        ap = cg.build_parser()
        bare = ap.parse_args(["archive", "--yes", "--limit", "5"])
        self.assertIsNone(bare.archive_cmd)
        self.assertTrue(bare.yes)
        self.assertEqual(bare.limit, 5)
        run = ap.parse_args(["archive", "run", "--yes"])
        self.assertEqual((run.archive_cmd, run.yes), ("run", True))
        listing = ap.parse_args(["archive", "list", "--candidates"])
        self.assertEqual((listing.archive_cmd, listing.candidates), ("list", True))

    def test_only_run_takes_the_lock(self):
        for op in ("list", "show", "stats"):
            with (
                mock.patch(f"cg.archive_{op}", return_value=0) as view,
                mock.patch("cg.exclusive_run") as lock,
            ):
                cg.cmd_archive(argparse.Namespace(archive_cmd=op))
            lock.assert_not_called()
            view.assert_called_once()
        for op in ("run", None):
            with (
                mock.patch("cg.archive_run", return_value=0) as run,
                mock.patch("cg.exclusive_run") as lock,
            ):
                cg.cmd_archive(argparse.Namespace(archive_cmd=op))
            lock.assert_called_once()
            run.assert_called_once()


class TestCompletions(unittest.TestCase):
    """Generated from the parser, so the word lists cannot rot."""

    def setUp(self):
        self.ap = cg.build_parser()
        self.scripts = {name: build(self.ap) for name, build in cg.SHELLS.items()}

    def test_every_shell_knows_every_command(self):
        for command in cg.real_commands(self.ap):
            for dialect, script in self.scripts.items():
                with self.subTest(dialect=dialect, command=command):
                    self.assertIn(command, script)

    def test_nested_archive_verbs_are_completed(self):
        self.assertIn("list run show stats", self.scripts["bash"])
        for child in ("run", "list", "show", "stats"):
            with self.subTest(child=child):
                self.assertIn(f"'{child}:", self.scripts["zsh"])
                self.assertIn(f"-a {child} ", self.scripts["fish"])

    def test_services_verbs_are_completed(self):
        verbs = (
            "register",
            "unregister",
            "status",
            "show",
            "list",
            "logs",
            "start",
            "stop",
            "restart",
            "run",
            "enable",
            "disable",
        )
        for verb in verbs:
            with self.subTest(verb=verb):
                self.assertIn(verb, self.scripts["bash"])
                self.assertIn(verb, self.scripts["zsh"])
                self.assertIn(verb, self.scripts["fish"])

    def test_the_tab_alias_works_but_is_not_advertised(self):
        self.assertIn("tab", cg.subcommands(self.ap))
        self.assertNotIn("tab", cg.real_commands(self.ap))

    def test_verdict_values_come_from_the_parser(self):
        expected = "keep review archive delete unknown"
        self.assertIn(expected, self.scripts["bash"])
        self.assertIn(expected, self.scripts["zsh"])
        self.assertIn(f'"{expected}"', self.scripts["fish"])

    def test_scripts_never_call_back_into_cg(self):
        # A completion must not run the tool: no DB, no network, no latency.
        for dialect in ("bash", "zsh"):
            with self.subTest(dialect=dialect):
                self.assertNotIn("$(cg", self.scripts[dialect])
                self.assertNotIn("`cg ", self.scripts[dialect])
        self.assertNotIn("(cg ", self.scripts["fish"])

    def test_shell_is_detected_from_the_environment(self):
        args = argparse.Namespace()
        args.shell = None
        with mock.patch.dict(os.environ, {"SHELL": "/usr/bin/zsh"}):
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(cg.cmd_completions(args), 0)
        self.assertIn("#compdef cg", out.getvalue())

    def test_unknown_shell_is_an_error(self):
        args = argparse.Namespace()
        args.shell = "tcsh"
        with self.assertRaises(SystemExit):
            cg.cmd_completions(args)


class TestSafety(unittest.TestCase):
    """Invariants that keep a --yes run from damaging the account."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._state, self._db, self._reports = (
            cg.STATE_DIR,
            cg.DB_PATH,
            cg.REPORT_DIR,
        )
        self.addCleanup(self._restore)
        cg.STATE_DIR = Path(self.tmp.name)
        cg.DB_PATH = cg.STATE_DIR / "cg.db"
        cg.REPORT_DIR = cg.STATE_DIR / "reports"

    def _restore(self):
        cg.STATE_DIR, cg.DB_PATH, cg.REPORT_DIR = self._state, self._db, self._reports

    def db(self):
        con = cg.connect()
        self.addCleanup(con.close)
        return con

    def test_ids_must_be_path_safe(self):
        self.assertTrue(cg.valid_conv_id("6ae22dd8-b474-83e9-815b-f1938585ef84"))
        for bad in ("", "../passwd", "a/b", "x?y=1", "short", "a" * 65):
            with self.subTest(bad):
                self.assertFalse(cg.valid_conv_id(bad))

    def test_only_gizmos_that_are_projects_count(self):
        self.assertTrue(cg.is_project("g-p-123"))
        self.assertFalse(cg.is_project("g-KpaoqUoH5"))
        self.assertFalse(cg.is_project(None))

    def test_move_is_confirmed_by_the_echo(self):
        self.assertTrue(cg.move_confirmed(200, '{"gizmo_id": "g-p-1"}', "g-p-1"))
        self.assertFalse(cg.move_confirmed(200, '{"gizmo_id": "g-p-2"}', "g-p-1"))
        self.assertFalse(cg.move_confirmed(200, '{"gizmo_id": null}', "g-p-1"))
        self.assertTrue(cg.move_confirmed(200, '{"title": "x"}', "g-p-1"))
        self.assertTrue(cg.move_confirmed(204, "", "g-p-1"))
        self.assertFalse(cg.move_confirmed(500, '{"gizmo_id": "g-p-1"}', "g-p-1"))

    def test_snapshot_copies_the_index(self):
        con = self.db()
        con.execute(
            "INSERT INTO conversations (conv_id, title, turns, user_chars, body_sha,"
            " first_user, sample, indexed_at) VALUES (?,?,?,?,?,?,?,?)",
            ("c1", "t", 1, 1, "", "", "", "now"),
        )
        con.commit()
        path = cg.snapshot_db(con, "test-backup")
        self.assertTrue(path.is_file())
        copy = sqlite3.connect(path)
        self.addCleanup(copy.close)
        self.assertEqual(
            copy.execute("SELECT COUNT(*) FROM conversations").fetchone()[0], 1
        )

    def test_the_index_waits_for_a_busy_writer(self):
        con = self.db()
        self.assertEqual(con.execute("PRAGMA busy_timeout").fetchone()[0], 30_000)
        self.assertEqual(
            con.execute("PRAGMA journal_mode").fetchone()[0].lower(), "wal"
        )

    def test_deep_sync_leaves_no_transaction_open_between_requests(self):
        # A 429 retry can sleep ~30s inside http_json; a write transaction left
        # open there is what starved the daemon (`database is locked`).
        con = self.db()
        for conv_id in ("c1", "c2", "c3"):
            con.execute(
                "INSERT INTO conversations (conv_id, title, turns, user_chars,"
                " body_sha, first_user, sample, indexed_at)"
                " VALUES (?,?,?,?,?,?,?,?)",
                (conv_id, "t", 0, 0, "", "", "", "now"),
            )
        con.commit()
        open_at_request = []

        def fake_http(method, url, headers, **kwargs):
            open_at_request.append(con.in_transaction)
            conv_id = url.rsplit("/", 1)[-1]
            return 200, json.dumps({"id": conv_id, "title": "t", "mapping": {}})

        args = argparse.Namespace(
            deep=True,
            limit=0,
            max_retries=4,
            deep_sleep=0.0,
            sleep=0.0,
            cookie=None,
            cookie_file=None,
            base_url="https://chatgpt.com",
        )
        with (
            mock.patch("cg.connect", return_value=con),
            mock.patch("cg.resolve_cookie", return_value=""),
            mock.patch("cg.open_session", return_value={"accessToken": "tok"}),
            mock.patch("cg.http_json", side_effect=fake_http),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(cg._sync(args), 0)
        self.assertEqual(len(open_at_request), 4)  # 1 list + 3 deep fetches
        self.assertEqual(set(open_at_request), {False})

    def test_the_lock_is_reentrant_inside_one_process(self):
        # The daemon holds it for a whole cycle and cmd_sync asks for it again;
        # a second flock on another handle would fail, so nested use is trusted.
        with cg.exclusive_run(), cg.exclusive_run():
            pass
        handle = (cg.STATE_DIR / "run.lock").open("w")
        self.addCleanup(handle.close)
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_another_handle_cannot_take_the_lock(self):
        handle = (cg.STATE_DIR / "run.lock").open("w")
        self.addCleanup(handle.close)
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with self.assertRaises(SystemExit), cg.exclusive_run():
            pass

    def test_every_write_command_takes_the_lock(self):
        for name, inner in (
            ("cmd_move", "_move"),
            ("cmd_unarchive", "_unarchive"),
            ("cmd_organize", "_organize"),
            ("cmd_sync", "_sync"),
        ):
            with (
                self.subTest(name),
                mock.patch(f"cg.{inner}", return_value=7) as run,
                mock.patch("cg.exclusive_run") as lock,
            ):
                self.assertEqual(getattr(cg, name)(argparse.Namespace()), 7)
            lock.assert_called_once()
            run.assert_called_once()

    def test_custom_gpt_chats_are_never_refiled(self):
        plans = [TestOrganize.plan("Programming", project_id="g-KpaoqUoH5")]
        targets, _ = cg.plan_projects(plans, {}, {}, 1)
        self.assertEqual(targets, [])

    def test_chats_slated_for_deletion_are_never_filed(self):
        plans = [TestOrganize.plan("Programming", verdict="delete") for _ in range(4)]
        targets, _ = cg.plan_projects(plans, {}, {}, 1)
        self.assertEqual(targets, [])

    def test_index_age_flags_a_stale_index(self):
        con = self.db()
        self.assertEqual(cg.index_age(con), float("inf"))
        old = (datetime.now() - timedelta(hours=3)).isoformat(timespec="seconds")
        con.execute(
            "INSERT INTO conversations (conv_id, title, turns, user_chars, body_sha,"
            " first_user, sample, indexed_at) VALUES (?,?,?,?,?,?,?,?)",
            ("c1", "t", 1, 1, "", "", "", old),
        )
        con.commit()
        self.assertGreater(cg.index_age(con), 170)
        self.assertIn("h atrás", cg.describe_age(cg.index_age(con)))


class TestRateLimitGuard(unittest.TestCase):
    """A 429 during a bulk read must stop the run, not retry every row."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._cache = cg.CONV_CACHE_DIR
        self.addCleanup(self._restore)
        cg.CONV_CACHE_DIR = Path(self.tmp.name) / "convs"

    def _restore(self):
        cg.CONV_CACHE_DIR = self._cache

    def test_429_raises_instead_of_returning_none(self):
        with (
            mock.patch("cg.http_json", return_value=(429, "")),
            self.assertRaises(cg.RateLimited),
        ):
            cg.fetch_conv_raw("https://chatgpt.com", "t", "conv0001")

    def test_expired_session_stops_the_fetch(self):
        with (
            mock.patch("cg.http_json", return_value=(401, "")),
            self.assertRaises(SystemExit),
        ):
            cg.fetch_conv_raw("https://chatgpt.com", "t", "conv0001")

    def test_force_ignores_a_cached_body(self):
        cache = cg.CONV_CACHE_DIR / "conv0001.json"
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text('{"title": "velho"}', encoding="utf-8")
        with mock.patch(
            "cg.http_json", return_value=(200, '{"title": "novo"}')
        ) as http:
            self.assertEqual(
                cg.fetch_conv_raw("https://chatgpt.com", "t", "conv0001", force=True),
                {"title": "novo"},
            )
        http.assert_called_once()
        self.assertEqual(cache.read_text(encoding="utf-8"), '{"title": "novo"}')


class TestExportIsNonDestructive(unittest.TestCase):
    """`export` writes notes; it must not eat notes that were edited by hand."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._state, self._db, self._reports = (
            cg.STATE_DIR,
            cg.DB_PATH,
            cg.REPORT_DIR,
        )
        self._cache = cg.CONV_CACHE_DIR
        self.addCleanup(self._restore)
        cg.STATE_DIR = Path(self.tmp.name)
        cg.DB_PATH = cg.STATE_DIR / "cg.db"
        cg.REPORT_DIR = cg.STATE_DIR / "reports"
        cg.CONV_CACHE_DIR = cg.STATE_DIR / "convs"
        con = cg.connect()
        self.addCleanup(con.close)
        self.con = con
        con.execute(
            "INSERT INTO conversations (conv_id, title, created_ts, turns,"
            " user_turns, user_chars, body_sha, first_user, sample, indexed_at)"
            " VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                "conv0001",
                "Minha conversa",
                1_700_000_000.0,
                2,
                1,
                80,
                "sha",
                "pergunta",
                "pergunta resposta",
                datetime.now().isoformat(timespec="seconds"),
            ),
        )
        con.commit()

    def _restore(self):
        cg.STATE_DIR, cg.DB_PATH, cg.REPORT_DIR = self._state, self._db, self._reports
        cg.CONV_CACHE_DIR = self._cache

    def args(self, **over):
        base = {
            "outdir": str(Path(self.tmp.name) / "out"),
            "only_project": None,
            "verdict": None,
            "archived_only": False,
            "not_archived": False,
            "fetch": False,
            "deep_fetch": False,
            "skip_empty": False,
            "overwrite": False,
            "sleep": 1.5,
        }
        base.update(over)
        return argparse.Namespace(**base)

    def note(self):
        files = list(Path(self.tmp.name, "out").rglob("*.md"))
        self.assertEqual(len(files), 1)
        return files[0]

    def run_export(self, **over):
        out = io.StringIO()
        with (
            mock.patch("cg.connect", return_value=self.con),
            contextlib.redirect_stdout(out),
        ):
            cg.cmd_export(self.args(**over))
        return out.getvalue()

    def test_edited_note_is_preserved_without_overwrite(self):
        self.run_export()
        path = self.note()
        path.write_text("nota minha, não mexa", encoding="utf-8")
        out = self.run_export()
        self.assertEqual(path.read_text(encoding="utf-8"), "nota minha, não mexa")
        self.assertIn("preservados: 1", out)

    def test_overwrite_replaces_an_edited_note(self):
        self.run_export()
        path = self.note()
        path.write_text("nota minha", encoding="utf-8")
        self.run_export(overwrite=True)
        self.assertNotEqual(path.read_text(encoding="utf-8"), "nota minha")

    def test_second_run_reports_unchanged_instead_of_rewriting(self):
        self.run_export()
        path = self.note()
        before = path.stat().st_mtime_ns
        out = self.run_export()
        self.assertEqual(path.stat().st_mtime_ns, before)
        self.assertIn("inalterados: 1", out)


class TestAutoNeverArchives(unittest.TestCase):
    """`auto --yes` may move chats; it must never archive or delete them."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._state, self._db, self._reports = (
            cg.STATE_DIR,
            cg.DB_PATH,
            cg.REPORT_DIR,
        )
        self.addCleanup(self._restore)
        cg.STATE_DIR = Path(self.tmp.name)
        cg.DB_PATH = cg.STATE_DIR / "cg.db"
        cg.REPORT_DIR = cg.STATE_DIR / "reports"
        con = cg.connect()
        self.addCleanup(con.close)
        self.con = con
        con.execute(
            "INSERT INTO conversations (conv_id, title, created_ts, turns,"
            " user_turns, user_chars, body_sha, first_user, sample, has_content,"
            " indexed_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (
                "conv0001",
                "pacman arch linux systemd",
                1_700_000_000.0,
                4,
                2,
                400,
                "sha",
                "como configurar o arch linux",
                "pacman arch linux systemd",
                1,
                datetime.now().isoformat(timespec="seconds"),
            ),
        )
        con.commit()

    def _restore(self):
        cg.STATE_DIR, cg.DB_PATH, cg.REPORT_DIR = self._state, self._db, self._reports

    def test_auto_moves_but_does_not_archive(self):
        args = argparse.Namespace(
            yes=True,
            max_age=720,
            base_url="https://chatgpt.com",
            create=False,
            map=None,
            fallback="Inbox",
            no_fallback=False,
            min=1,
            limit=10,
            sleep=0.0,
        )
        project = {"id": "g-p-1", "name": "Linux & Arch"}
        with (
            mock.patch("cg.connect", return_value=self.con),
            mock.patch("cg.open_session", return_value={"accessToken": "tok"}),
            mock.patch("cg.resolve_cookie", return_value="cookie"),
            mock.patch("cg.list_projects", return_value=[project]),
            mock.patch(
                "cg.set_project",
                return_value=(200, '{"gizmo_id": "g-p-1"}'),
            ) as move,
            mock.patch("cg.set_archived") as archive,
            mock.patch("cg.snapshot_db", return_value=Path(self.tmp.name, "b.db")),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(cg._auto(args), 0)
        move.assert_called_once()
        archive.assert_not_called()


class TestDaemon(unittest.TestCase):
    """The daemon stays in one process: ordered jobs, recorded failures."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self._reports = cg.REPORT_DIR
        self.addCleanup(setattr, cg, "REPORT_DIR", self._reports)
        cg.REPORT_DIR = Path(self.tmp.name) / "reports"

    def args(self, **over):
        base = {
            "yes": True,
            "once": False,
            "cycles": 0,
            "wait_min": 20.0,
            "wait_max": 50.0,
            "backoff": 60.0,
            "no_sync": False,
            "no_organize": False,
            "no_deep": False,
            "deep_limit": 50,
            "deep_sleep": 0.0,
            "max_retries": 4,
            "organize_limit": 100,
            "min": 3,
            "map": None,
            "fallback": "Inbox",
            "no_fallback": False,
            "sleep": 0.0,
            "cookie": None,
            "cookie_file": None,
            "base_url": "https://chatgpt.com",
        }
        base.update(over)
        return argparse.Namespace(**base)

    def quiet(self):
        return (
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        )

    def test_parser_defaults_are_safe(self):
        args = cg.build_parser().parse_args(["daemon", "--once"])
        self.assertFalse(args.yes)
        self.assertTrue(args.once)
        self.assertEqual((args.wait_min, args.wait_max), (20.0, 50.0))

    def test_sync_job_gets_the_deep_controls(self):
        args = self.args(no_deep=True, deep_limit=7, deep_sleep=0.25, max_retries=2)
        sync = cg._daemon_sync_args(args)
        self.assertFalse(sync.deep)
        self.assertEqual((sync.limit, sync.deep_sleep), (7, 0.25))
        self.assertEqual(sync.max_retries, 2)
        self.assertEqual(sync.base_url, args.base_url)

    def test_organize_job_gets_the_move_controls(self):
        args = self.args(organize_limit=5, min=2, fallback="Triagem", sleep=0.5)
        organize = cg._daemon_organize_args(args)
        self.assertTrue(organize.yes)
        self.assertEqual((organize.limit, organize.min), (5, 2))
        self.assertEqual((organize.fallback, organize.sleep), ("Triagem", 0.5))
        self.assertEqual(organize.base_url, args.base_url)

    def test_cycle_updates_index_before_organizing(self):
        calls = []
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch("cg.cmd_sync", side_effect=lambda a: calls.append("sync") or 0),
            mock.patch(
                "cg._organize", side_effect=lambda a: calls.append("organize") or 0
            ),
            out,
            err,
        ):
            jobs = cg._daemon_cycle(self.args(), 1)
        self.assertEqual(calls, ["sync", "organize"])
        self.assertEqual([job["job"] for job in jobs], ["sync", "organize"])
        self.assertEqual(cg._daemon_rc(jobs), 0)

    def test_failed_sync_skips_the_move(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch("cg.cmd_sync", side_effect=SystemExit("error: session expired")),
            mock.patch("cg._organize") as move,
            out,
            err,
        ):
            jobs = cg._daemon_cycle(self.args(), 1)
        move.assert_not_called()
        self.assertEqual(jobs[0]["rc"], 2)
        self.assertEqual(jobs[1]["job"], "organize")
        self.assertIn("skipped", jobs[1])

    def test_stop_codes_from_sync_skip_organize(self):
        # cmd_sync returns 128+signum after committing; not every code is a
        # failure to retry, and none of them should be followed by a move.
        for rc in sorted(cg._DAEMON_STOP_RCS):
            with self.subTest(rc=rc):
                out, err = self.quiet()
                with (
                    mock.patch(
                        "cg.exclusive_run",
                        side_effect=lambda: contextlib.nullcontext(),
                    ),
                    mock.patch("cg.cmd_sync", return_value=rc),
                    mock.patch("cg._organize") as move,
                    out,
                    err,
                ):
                    jobs = cg._daemon_cycle(self.args(), 1)
                move.assert_not_called()
                self.assertEqual([job["job"] for job in jobs], ["sync", "organize"])
                self.assertEqual(jobs[0]["rc"], rc)
                self.assertIn("skipped", jobs[1])
                self.assertTrue(cg._daemon_stopped(jobs))

    def test_only_signal_codes_count_as_stopped(self):
        for rc in (0, 1, 2, 3, 4):
            with self.subTest(rc=rc):
                self.assertFalse(cg._daemon_stopped([{"rc": rc}]))
        for rc in sorted(cg._DAEMON_STOP_RCS):
            with self.subTest(rc=rc):
                self.assertTrue(cg._daemon_stopped([{"rc": rc}]))

    def test_rate_limit_is_remembered_for_the_backoff(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch("cg.cmd_sync", side_effect=cg.RateLimited("error: HTTP 429")),
            out,
            err,
        ):
            jobs = cg._daemon_cycle(self.args(), 1)
        self.assertEqual(jobs[0]["rc"], 3)
        self.assertTrue(jobs[0]["rate_limited"])

    def test_a_crashing_job_does_not_kill_the_daemon(self):
        def boom():
            raise OSError("disk")

        out, err = self.quiet()
        with out, err:
            record = cg._daemon_job("sync", boom)
        self.assertEqual(record["rc"], 1)
        self.assertIn("OSError", record["error"])

    def test_a_locked_index_defers_the_cycle(self):
        def locked():
            raise sqlite3.OperationalError("database is locked")

        out, err = self.quiet()
        with out, err:
            record = cg._daemon_job("sync", locked)
        self.assertEqual(record["rc"], 4)
        self.assertIn("locked", record["error"])
        self.assertEqual(cg._daemon_rc([record]), 0)

    def test_deferred_cycle_retries_before_the_random_window(self):
        args = self.args(wait_min=20, wait_max=50)
        self.assertLessEqual(cg._daemon_wait(args, [{"rc": 4}]), cg._LOCK_RETRY_S)

    def test_busy_lock_defers_the_cycle_without_failing_it(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=SystemExit("error: run lock busy"),
            ),
            out,
            err,
        ):
            jobs = cg._daemon_cycle(self.args(), 1)
        self.assertEqual(jobs[0]["job"], "lock")
        self.assertEqual(jobs[0]["rc"], 4)
        self.assertEqual(cg._daemon_rc(jobs), 0)

    def test_wait_is_random_inside_the_window(self):
        args = self.args(wait_min=10, wait_max=20)
        waits = {cg._daemon_wait(args, []) for _ in range(50)}
        self.assertGreaterEqual(min(waits), 600)
        self.assertLessEqual(max(waits), 1200)
        self.assertGreater(len(waits), 1)

    def test_rate_limit_pushes_the_wait_to_the_backoff(self):
        args = self.args(wait_min=1, wait_max=1, backoff=90)
        self.assertEqual(cg._daemon_wait(args, [{"rate_limited": True}]), 5400)

    def test_once_runs_one_cycle_and_never_sleeps(self):
        runs = []
        out, err = self.quiet()
        with (
            mock.patch(
                "cg._daemon_cycle",
                side_effect=lambda a, n: runs.append(n) or [],
            ),
            mock.patch(
                "cg._daemon_sleep",
                side_effect=AssertionError("--once não deve dormir"),
            ),
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args(once=True)), 0)
        self.assertEqual(runs, [1])
        journals = list((Path(self.tmp.name) / "reports").glob("daemon-*.jsonl"))
        self.assertEqual(len(journals), 1)
        records = [
            json.loads(line) for line in journals[0].read_text().splitlines() if line
        ]
        self.assertEqual(
            [record["kind"] for record in records], ["start", "cycle", "stop"]
        )

    def test_cycles_stop_after_n_and_sleep_in_between(self):
        runs, sleeps = [], []
        out, err = self.quiet()
        with (
            mock.patch(
                "cg._daemon_cycle",
                side_effect=lambda a, n: runs.append(n) or [],
            ),
            mock.patch("cg._daemon_sleep", side_effect=sleeps.append),
            mock.patch("cg._daemon_wait", return_value=42.0),
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args(cycles=2)), 0)
        self.assertEqual(runs, [1, 2])
        self.assertEqual(sleeps, [42.0])

    def test_signal_that_ends_sync_stops_the_daemon(self):
        # cmd_sync catches the signal, commits and returns 128+signum; the
        # daemon must stop there instead of moving on to organize and sleeping.
        calls = []
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch(
                "cg.cmd_sync", side_effect=lambda a: calls.append("sync") or 143
            ),
            mock.patch(
                "cg._organize", side_effect=lambda a: calls.append("organize") or 0
            ),
            mock.patch(
                "cg._daemon_sleep",
                side_effect=AssertionError("parada não deve dormir"),
            ),
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args()), 143)
        self.assertEqual(calls, ["sync"])
        journal = next((Path(self.tmp.name) / "reports").glob("daemon-*.jsonl"))
        records = [
            json.loads(line) for line in journal.read_text().splitlines() if line
        ]
        cycle = next(record for record in records if record["kind"] == "cycle")
        self.assertEqual([job["job"] for job in cycle["jobs"]], ["sync", "organize"])
        self.assertIn("skipped", cycle["jobs"][1])
        self.assertEqual(records[-1]["kind"], "stop")
        self.assertEqual(records[-1]["rc"], 143)

    def test_stop_with_organize_disabled_does_not_sleep(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch("cg.cmd_sync", return_value=130),
            mock.patch("cg._organize") as move,
            mock.patch("cg._daemon_sleep") as sleep,
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args(no_organize=True)), 130)
        move.assert_not_called()
        sleep.assert_not_called()

    def test_ordinary_sync_failure_does_not_stop_the_loop(self):
        sleeps = []
        out, err = self.quiet()
        with (
            mock.patch("cg._daemon_cycle", return_value=[{"job": "sync", "rc": 2}]),
            mock.patch("cg._daemon_wait", return_value=10.0),
            mock.patch("cg._daemon_sleep", side_effect=sleeps.append),
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args(cycles=2)), 2)
        self.assertEqual(sleeps, [10.0])

    def test_interrupt_during_organize_unwinds_and_closes_the_journal(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg.exclusive_run",
                side_effect=lambda: contextlib.nullcontext(),
            ),
            mock.patch("cg.cmd_sync", return_value=0),
            mock.patch("cg._organize", side_effect=cg.Interrupted(15, "SIGTERM")),
            out,
            err,
            self.assertRaises(cg.Interrupted),
        ):
            cg._daemon(self.args(once=True))
        journal = next((Path(self.tmp.name) / "reports").glob("daemon-*.jsonl"))
        records = [
            json.loads(line) for line in journal.read_text().splitlines() if line
        ]
        self.assertEqual([record["kind"] for record in records], ["start", "stop"])
        self.assertEqual(records[-1]["rc"], 143)

    def test_signal_during_the_wait_closes_the_journal_with_its_code(self):
        out, err = self.quiet()
        with (
            mock.patch("cg._daemon_cycle", return_value=[]),
            mock.patch("cg._daemon_wait", return_value=60.0),
            mock.patch("cg._daemon_sleep", side_effect=cg.Interrupted(15, "SIGTERM")),
            out,
            err,
            self.assertRaises(cg.Interrupted),
        ):
            cg._daemon(self.args(cycles=2))
        journal = next((Path(self.tmp.name) / "reports").glob("daemon-*.jsonl"))
        records = [
            json.loads(line) for line in journal.read_text().splitlines() if line
        ]
        self.assertEqual(
            [record["kind"] for record in records], ["start", "cycle", "stop"]
        )
        self.assertEqual(records[-1]["rc"], 143)

    def test_once_returns_the_worst_job_code(self):
        out, err = self.quiet()
        with (
            mock.patch(
                "cg._daemon_cycle",
                return_value=[{"job": "sync", "rc": 3, "rate_limited": True}],
            ),
            out,
            err,
        ):
            self.assertEqual(cg._daemon(self.args(once=True)), 3)

    def test_bad_windows_are_rejected_before_touching_the_index(self):
        for over in (
            {"wait_min": 10, "wait_max": 5},
            {"wait_min": -1},
            {"cycles": -1},
            {"no_sync": True, "no_organize": True},
        ):
            with self.subTest(over=over), self.assertRaises(SystemExit):
                cg._daemon(self.args(**over))


class TestHttpRetries(unittest.TestCase):
    """A lost 500 on POST create must not fire the same request again."""

    @staticmethod
    def fail(status):
        return urllib.error.HTTPError(
            "https://chatgpt.com", status, "boom", {}, io.BytesIO(b"")
        )

    def call(self, method, status):
        with (
            mock.patch(
                "cg.urlopen", side_effect=lambda *a, **k: self.fail(status)
            ) as op,
            mock.patch.object(cg.THROTTLE, "enabled", False),
        ):
            got, _ = cg.http_json(method, "https://chatgpt.com/x", {}, retries=3)
        return got, op.call_count

    def test_post_is_not_retried_on_5xx(self):
        self.assertEqual(self.call("POST", 500), (500, 1))
        self.assertEqual(self.call("POST", 503), (503, 1))

    def test_get_is_retried_on_5xx(self):
        self.assertEqual(self.call("GET", 500), (500, 4))

    def test_post_is_retried_on_429(self):
        self.assertEqual(self.call("POST", 429), (429, 4))


class TestSignals(unittest.TestCase):
    """A Ctrl-C or a `kill` must unwind cleanly, not tear the process down."""

    def setUp(self):
        cg._STOPPING = False
        self.addCleanup(setattr, cg, "_STOPPING", False)

    def test_interrupted_is_a_keyboard_interrupt_with_an_exit_code(self):
        exc = cg.Interrupted(15, "SIGTERM")
        self.assertIsInstance(exc, KeyboardInterrupt)
        self.assertEqual((exc.signum, exc.signal_name), (15, "SIGTERM"))
        self.assertEqual(128 + exc.signum, 143)

    def test_handler_raises_with_the_signal_name(self):
        with self.assertRaises(cg.Interrupted) as ctx:
            cg._on_stop_signal(signal.SIGTERM, None)
        self.assertEqual(ctx.exception.signum, signal.SIGTERM)
        self.assertEqual(ctx.exception.signal_name, "SIGTERM")

    def test_handler_installs_itself_for_the_stop_signals(self):
        signals = [getattr(signal, n) for n in ("SIGINT", "SIGTERM", "SIGHUP")]
        before = {sig: signal.getsignal(sig) for sig in signals}

        def restore():
            for sig, handler in before.items():
                signal.signal(sig, handler)

        self.addCleanup(restore)
        cg.install_signal_handlers()
        for sig in signals:
            self.assertIs(signal.getsignal(sig), cg._on_stop_signal)

    def test_a_second_signal_stops_arguing(self):
        cg._STOPPING = True
        with mock.patch("os.kill") as kill, mock.patch("signal.signal") as sig:
            cg._on_stop_signal(signal.SIGINT, None)
        sig.assert_called_once_with(signal.SIGINT, signal.SIG_DFL)
        kill.assert_called_once_with(os.getpid(), signal.SIGINT)


class TestThrottle(unittest.TestCase):
    def make(self, interval=1.0, enabled=True):
        self.now = 0.0
        self.slept = []

        def clock():
            return self.now

        def sleep(seconds):
            self.slept.append(seconds)
            self.now += seconds

        return cg.Throttle(interval, clock=clock, sleep=sleep, enabled=enabled)

    def test_spaces_requests_out(self):
        th = self.make(2.0)
        th.observe(200)
        th.wait()
        self.assertGreaterEqual(sum(self.slept), 1.8)
        self.assertLessEqual(sum(self.slept), 2.2)

    def test_429_honours_retry_after(self):
        th = self.make(1.0)
        th.observe(429, 7)
        self.assertGreaterEqual(th.interval, 2.0)
        th.wait()
        self.assertGreaterEqual(self.slept[-1], 7.0)

    def test_429_without_header_doubles_the_gap(self):
        th = self.make(2.0)
        th.observe(429)
        th.wait()
        self.assertGreaterEqual(self.slept[-1], 4.0)

    def test_success_never_goes_below_the_floor(self):
        th = self.make(1.5)
        for _ in range(200):
            th.observe(200)
        self.assertAlmostEqual(th.interval, 1.5)

    def test_disabled_throttle_does_not_sleep(self):
        th = self.make(1.0, enabled=False)
        th.observe(429)
        th.wait()
        self.assertEqual(self.slept, [])

    def test_retry_after_parsing(self):
        self.assertEqual(cg._retry_after({"Retry-After": "5"}), 5.0)
        self.assertIsNone(cg._retry_after({"Retry-After": "soon"}))
        self.assertIsNone(cg._retry_after({}))

    def test_retry_after_accepts_an_http_date(self):
        when = datetime.now(UTC) + timedelta(seconds=40)
        raw = format_datetime(when, usegmt=True)
        self.assertAlmostEqual(cg._retry_after({"Retry-After": raw}), 40, delta=3)
        past = format_datetime(datetime.now(UTC) - timedelta(seconds=5), usegmt=True)
        self.assertEqual(cg._retry_after({"Retry-After": past}), 0.0)

    def test_cookie_is_redacted_from_the_log(self):
        self.assertEqual(
            cg._safe_argv(["--cookie", "super-secret", "sync", "--deep"]),
            "--cookie *** sync --deep",
        )


class TestServiceHelpers(unittest.TestCase):
    def test_durations_are_parsed(self):
        for text, seconds in {
            "30s": 30,
            "90m": 5400,
            "2h": 7200,
            "1d": 86400,
            " 1H ": 3600,
            "45": 45,
        }.items():
            with self.subTest(text=text):
                self.assertEqual(cg_services.parse_duration(text), seconds)

    def test_bad_durations_are_rejected(self):
        for text in ("", "0", "0m", "-5m", "1w", "soon", "1.5h"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                cg_services.parse_duration(text)

    def test_durations_are_formatted_compactly(self):
        for seconds, text in {
            30: "30s",
            60: "1m",
            7200: "2h",
            86400: "1d",
            72: "72s",
        }.items():
            with self.subTest(seconds=seconds):
                self.assertEqual(cg_services.format_duration(seconds), text)

    def test_randomized_delay_is_bounded(self):
        self.assertEqual(cg_services.jitter_delay(10), 1)
        self.assertEqual(cg_services.jitter_delay(3600), 300)
        self.assertEqual(cg_services.jitter_delay(86400), 300)

    def test_unit_quote_escapes_systemd_specials(self):
        self.assertEqual(cg_services.unit_quote("/usr/bin/cg"), "/usr/bin/cg")
        self.assertEqual(cg_services.unit_quote("a b"), '"a b"')
        self.assertEqual(cg_services.unit_quote('a"b'), '"a\\"b"')
        self.assertEqual(cg_services.unit_quote("100%"), '"100%%"')
        self.assertEqual(cg_services.unit_quote("$HOME"), '"$$HOME"')
        self.assertEqual(cg_services.unit_quote(""), '""')

    def test_exec_start_quotes_each_argument(self):
        self.assertEqual(
            cg_services.exec_start(["/usr/bin/cg", "daemon", "--name", "my cg"]),
            '/usr/bin/cg daemon --name "my cg"',
        )

    def test_spec_rejects_unsafe_names(self):
        for name in ("", "a/b", "../cg", "cg service", "cg;rm", ".cg"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                cg_services.ServiceSpec(name=name, cg_argv=["/bin/cg"])

    def test_spec_rejects_invalid_modes_and_windows(self):
        for over in (
            {"mode": "cron"},
            {"every": "soon"},
            {"wait_min": -1},
            {"wait_min": 10, "wait_max": 5},
        ):
            with self.subTest(over=over), self.assertRaises(ValueError):
                cg_services.ServiceSpec(cg_argv=["/bin/cg"], **over)

    def test_spec_paths_and_arguments(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        timer = cg_services.ServiceSpec(
            name="cg-test",
            apply=True,
            every="2h",
            unit_dir=tmp,
            cg_argv=["/bin/cg"],
        )
        self.assertEqual(timer.service_path, tmp / "cg-test.service")
        self.assertEqual(timer.timer_path, tmp / "cg-test.timer")
        self.assertEqual(timer.exec_argv(), ["/bin/cg", "daemon", "--once", "--yes"])

        daemon = cg_services.ServiceSpec(
            mode="daemon",
            wait_min=30,
            wait_max=90,
            unit_dir=tmp,
            cg_argv=["/bin/cg"],
        )
        self.assertEqual(
            daemon.exec_argv(),
            [
                "/bin/cg",
                "daemon",
                "--wait-min",
                "30",
                "--wait-max",
                "90",
            ],
        )
        self.assertFalse(daemon.uses_timer)
        self.assertTrue(timer.uses_timer)

    def test_detect_cg_argv_prefers_path_and_accepts_override(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        script = tmp / "cg"
        script.write_text("#!/bin/sh\n", encoding="utf-8")
        with mock.patch("cg_services.shutil.which", return_value=str(script)):
            self.assertEqual(cg_services.detect_cg_argv(), [str(script.resolve())])
        self.assertEqual(cg_services.detect_cg_argv(str(script)), [str(script)])

    def test_detect_cg_argv_falls_back_to_the_sibling_script(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        module = tmp / "cg_services.py"
        with (
            mock.patch("cg_services.shutil.which", return_value=None),
            mock.patch("cg_services.os.access", return_value=True),
            mock.patch("cg_services.__file__", str(module)),
        ):
            self.assertEqual(
                cg_services.detect_cg_argv(), [str((tmp / "cg.py").resolve())]
            )


class ServiceTempDir(unittest.TestCase):
    """Throwaway unit directory and spec builder; no real systemd involved."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def spec(self, **over):
        base = {
            "unit_dir": self.tmp,
            "cg_argv": ["/bin/cg"],
        }
        base.update(over)
        return cg_services.ServiceSpec(**base)


class TestServiceUnits(ServiceTempDir):
    def test_timer_mode_renders_a_oneshot_and_a_timer(self):
        spec = self.spec(apply=True)
        service = cg_services.render_service(spec)
        timer = cg_services.render_timer(spec)

        self.assertIn(cg_services.MARKER, service)
        self.assertIn("Type=oneshot", service)
        self.assertIn("ExecStart=/bin/cg daemon --once --yes", service)
        self.assertNotIn("[Install]", service)
        self.assertIn("OnUnitActiveSec=1h", timer)
        self.assertIn("RandomizedDelaySec=5m", timer)
        self.assertIn("Unit=cg.service", timer)
        self.assertIn("WantedBy=timers.target", timer)

    def test_daemon_mode_renders_a_restarting_service(self):
        spec = self.spec(mode="daemon", wait_min=15, wait_max=45)
        service = cg_services.render_service(spec)

        self.assertIn("Type=simple", service)
        self.assertIn("Restart=on-failure", service)
        self.assertIn("RestartSec=60", service)
        self.assertIn("SuccessExitStatus=143", service)
        self.assertIn("ExecStart=/bin/cg daemon --wait-min 15 --wait-max 45", service)
        self.assertIn("WantedBy=default.target", service)

    def test_show_returns_the_generated_files_on_stdout(self):
        spec = self.spec(every="30m")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg_services.show(spec), 0)
        text = out.getvalue()
        self.assertIn(str(spec.service_path), text)
        self.assertIn(str(spec.timer_path), text)
        self.assertIn("OnUnitActiveSec=30m", text)
        self.assertFalse(spec.service_path.exists())

    def test_write_and_remove_are_idempotent(self):
        path = self.tmp / "cg.service"
        self.assertTrue(cg_services.write_unit(path, "one\n"))
        self.assertFalse(cg_services.write_unit(path, "one\n"))
        self.assertTrue(cg_services.write_unit(path, "two\n"))
        self.assertEqual(path.read_text(encoding="utf-8"), "two\n")
        self.assertTrue(cg_services.remove_unit(path))
        self.assertFalse(cg_services.remove_unit(path))

    def test_managed_marker_and_discovery(self):
        managed = self.tmp / "cg.service"
        manual = self.tmp / "other.service"
        noise = self.tmp / "cg.conf"
        cg_services.write_unit(managed, f"{cg_services.MARKER}\n[Unit]\n")
        manual.write_text("[Unit]\n", encoding="utf-8")
        noise.write_text("x", encoding="utf-8")

        self.assertTrue(cg_services.is_managed(managed))
        self.assertFalse(cg_services.is_managed(manual))
        self.assertEqual(cg_services.discover_units(self.tmp), [managed])
        self.assertEqual(cg_services.discover_units(self.tmp / "missing"), [])


class TestServiceCommands(ServiceTempDir):
    def recorder(self):
        calls = []

        def fake(*args, **kwargs):
            calls.append((args, kwargs))
            return 0, ""

        return calls, fake

    def test_register_writes_units_and_activates_the_timer(self):
        calls, fake = self.recorder()
        spec = self.spec(apply=True)
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.register(spec), 0)

        self.assertTrue(spec.service_path.exists())
        self.assertTrue(spec.timer_path.exists())
        commands = [args for args, _kwargs in calls]
        self.assertIn(("daemon-reload",), commands)
        self.assertIn(("enable", "--now", "cg.timer"), commands)
        self.assertIn("--yes", spec.service_path.read_text(encoding="utf-8"))

    def test_register_can_skip_activation(self):
        calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.register(self.spec(), activate=False), 0)
        self.assertNotIn("enable", [args[0] for args, _kwargs in calls])

    def test_register_dry_run_writes_nothing(self):
        spec = self.spec()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg_services.register(spec, dry_run=True), 0)
        self.assertFalse(spec.service_path.exists())
        self.assertFalse(spec.timer_path.exists())
        text = out.getvalue()
        self.assertIn("+ systemctl --user daemon-reload", text)
        self.assertIn("+ systemctl --user enable --now cg.timer", text)

    def test_register_refuses_a_foreign_file_without_force(self):
        manual = self.tmp / "cg.service"
        manual.write_text("manual\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            cg_services.register(self.spec())
        self.assertEqual(manual.read_text(encoding="utf-8"), "manual\n")

        _calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.register(self.spec(), force=True), 0)
        self.assertIn(cg_services.MARKER, manual.read_text(encoding="utf-8"))

    def test_switching_to_daemon_stops_and_disables_the_stale_timer(self):
        timer_spec = self.spec()
        cg_services.write_unit(
            timer_spec.timer_path, cg_services.render_timer(timer_spec)
        )
        daemon = self.spec(mode="daemon")
        calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.register(daemon), 0)
        self.assertFalse(daemon.timer_path.exists())
        self.assertIn("Type=simple", daemon.service_path.read_text(encoding="utf-8"))
        commands = [args for args, _kwargs in calls]
        self.assertIn(("stop", "cg.service"), commands)
        self.assertIn(("disable", "--now", "cg.timer"), commands)

    def test_unregister_disables_and_removes_units(self):
        spec = self.spec()
        cg_services.write_unit(spec.service_path, cg_services.render_service(spec))
        cg_services.write_unit(spec.timer_path, cg_services.render_timer(spec))
        calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.unregister(spec), 0)
        self.assertFalse(spec.service_path.exists())
        self.assertFalse(spec.timer_path.exists())
        disabled = {args for args, _kwargs in calls if args[0] == "disable"}
        self.assertEqual(
            disabled,
            {
                ("disable", "--now", "cg.timer"),
                ("disable", "--now", "cg.service"),
            },
        )

    def test_unregister_is_idempotent_and_rejects_foreign_files(self):
        spec = self.spec()
        _calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.unregister(spec), 0)

        foreign = self.tmp / "cg.timer"
        foreign.write_text("manual\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            cg_services.unregister(spec)
        self.assertTrue(foreign.exists())

    def test_status_reports_files_and_states(self):
        spec = self.spec()
        cg_services.write_unit(spec.service_path, cg_services.render_service(spec))
        cg_services.write_unit(spec.timer_path, cg_services.render_timer(spec))

        def fake(*args, **kwargs):
            if args[0] == "is-active":
                return 0, "active"
            if args[0] == "is-enabled":
                return 0, "enabled"
            if args[0] == "show":
                return 0, "Wed 2026-10-28 22:00:00 -03"
            return 0, ""

        out = io.StringIO()
        with (
            mock.patch("cg_services.systemctl", side_effect=fake),
            contextlib.redirect_stdout(out),
        ):
            self.assertEqual(cg_services.status(spec), 0)
        text = out.getvalue()
        self.assertIn("modo    : timer", text)
        self.assertIn("ativo=active", text)
        self.assertIn("enabled=enabled", text)
        self.assertIn("próximo : Wed 2026-10-28 22:00:00 -03", text)

    def test_status_without_units_is_not_an_error(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg_services.status(self.spec()), 1)
        self.assertIn("nada registrado", out.getvalue())

    def test_actions_pick_the_timer_or_the_service(self):
        spec = self.spec()
        cg_services.write_unit(spec.service_path, cg_services.render_service(spec))
        cg_services.write_unit(spec.timer_path, cg_services.render_timer(spec))
        calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.action(spec, "start"), 0)
            self.assertEqual(cg_services.action(spec, "run"), 0)
            self.assertEqual(cg_services.action(spec, "stop"), 0)
        commands = [args for args, _kwargs in calls]
        self.assertIn(("start", "cg.timer"), commands)
        self.assertIn(("start", "cg.service"), commands)
        self.assertIn(("stop", "cg.timer"), commands)
        self.assertIn(("stop", "cg.service"), commands)

    def test_enable_now_and_disable_now(self):
        spec = self.spec()
        cg_services.write_unit(spec.service_path, cg_services.render_service(spec))
        cg_services.write_unit(spec.timer_path, cg_services.render_timer(spec))
        calls, fake = self.recorder()
        with mock.patch("cg_services.systemctl", side_effect=fake):
            self.assertEqual(cg_services.action(spec, "enable", now=True), 0)
            self.assertEqual(cg_services.action(spec, "disable", now=True), 0)
        commands = [args for args, _kwargs in calls]
        self.assertIn(("enable", "--now", "cg.timer"), commands)
        self.assertIn(("disable", "--now", "cg.timer"), commands)
        self.assertIn(("disable", "--now", "cg.service"), commands)

    def test_action_requires_registration(self):
        with self.assertRaises(SystemExit):
            cg_services.action(self.spec(), "start")

    def test_logs_uses_journalctl_for_the_service(self):
        spec = self.spec()
        proc = mock.Mock(returncode=0)
        with mock.patch("cg_services.subprocess.run", return_value=proc) as run:
            self.assertEqual(cg_services.logs(spec, lines=7, follow=True), 0)
        argv = run.call_args.args[0]
        self.assertEqual(argv[:4], ["journalctl", "--user", "-u", "cg.service"])
        self.assertEqual(argv[argv.index("-n") + 1], "7")
        self.assertIn("-f", argv)

    def test_logs_dry_run_does_not_spawn_journalctl(self):
        out = io.StringIO()
        with (
            mock.patch("cg_services.subprocess.run") as run,
            contextlib.redirect_stdout(out),
        ):
            self.assertEqual(cg_services.logs(self.spec(), dry_run=True), 0)
        run.assert_not_called()
        self.assertIn("+ journalctl --user -u cg.service", out.getvalue())

    def test_list_only_shows_managed_units(self):
        spec = self.spec()
        cg_services.write_unit(spec.service_path, cg_services.render_service(spec))
        cg_services.write_unit(spec.timer_path, cg_services.render_timer(spec))
        (self.tmp / "manual.service").write_text("manual\n", encoding="utf-8")

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cg_services.list_registered(self.tmp), 0)
        text = out.getvalue()
        self.assertIn("cg.service", text)
        self.assertIn("cg.timer", text)
        self.assertNotIn("manual.service", text)

    def test_systemctl_always_uses_the_user_manager(self):
        proc = mock.Mock(returncode=3, stdout="inactive\n")
        with mock.patch("cg_services.subprocess.run", return_value=proc) as run:
            rc, out = cg_services.systemctl("is-active", "cg.service")
        self.assertEqual((rc, out), (3, "inactive"))
        self.assertEqual(
            run.call_args.args[0],
            ["systemctl", "--user", "is-active", "cg.service"],
        )
        self.assertFalse(run.call_args.kwargs["capture_output"])

    def test_systemctl_dry_run_prints_without_running(self):
        out = io.StringIO()
        with (
            mock.patch("cg_services.subprocess.run") as run,
            contextlib.redirect_stdout(out),
        ):
            self.assertEqual(cg_services.systemctl("daemon-reload", dry_run=True)[0], 0)
        run.assert_not_called()
        self.assertIn("+ systemctl --user daemon-reload", out.getvalue())


class TestServicesParser(unittest.TestCase):
    def test_bare_services_means_status(self):
        args = cg.build_parser().parse_args(["services"])
        self.assertIsNone(args.services_cmd)
        self.assertIs(args.func, cg.cmd_services)

    def test_register_options_are_wired(self):
        args = cg.build_parser().parse_args(
            [
                "services",
                "register",
                "--mode",
                "daemon",
                "--every",
                "2h",
                "--wait-min",
                "30",
                "--wait-max",
                "90",
                "--yes",
                "--no-enable",
                "--dry-run",
            ]
        )
        self.assertEqual(args.services_cmd, "register")
        self.assertEqual((args.mode, args.every), ("daemon", "2h"))
        self.assertEqual((args.wait_min, args.wait_max), (30.0, 90.0))
        self.assertTrue(args.apply)
        self.assertTrue(args.no_enable)
        self.assertTrue(args.dry_run)

    def test_alias_and_action_flags(self):
        ap = cg.build_parser()
        self.assertEqual(ap.parse_args(["svc", "status"]).services_cmd, "status")
        args = ap.parse_args(["services", "enable", "--now"])
        self.assertTrue(args.now)
        args = ap.parse_args(["services", "logs", "-n", "5", "-f"])
        self.assertEqual((args.lines, args.follow), (5, True))

    def test_cmd_services_dispatches_register_with_a_spec(self):
        args = cg.build_parser().parse_args(
            ["services", "register", "--name", "cg-test", "--every", "30m"]
        )
        with (
            mock.patch("cg_services.detect_cg_argv", return_value=["/bin/cg"]),
            mock.patch("cg_services.register", return_value=0) as register,
        ):
            self.assertEqual(cg.cmd_services(args), 0)
        spec = register.call_args.args[0]
        self.assertEqual((spec.name, spec.every), ("cg-test", "30m"))
        self.assertEqual(spec.cg_argv, ["/bin/cg"])

    def test_cmd_services_dispatches_status_and_list(self):
        ap = cg.build_parser()
        with (
            mock.patch("cg_services.detect_cg_argv", return_value=["/bin/cg"]),
            mock.patch("cg_services.status", return_value=0) as status,
        ):
            self.assertEqual(cg.cmd_services(ap.parse_args(["services"])), 0)
        status.assert_called_once()

        with mock.patch("cg_services.list_registered", return_value=0) as listed:
            self.assertEqual(cg.cmd_services(ap.parse_args(["services", "list"])), 0)
        listed.assert_called_once()


if __name__ == "__main__":
    unittest.main()
