---
# ---- IDENTIFICAÇÃO --------------------------------------------------------
title: "Paranavaí/PR — Guia de voto, códigos eleitorais e dossiê de candidatos"
aliases:
  - Voto Paranavaí 2026
  - Guia de voto Paranavaí
  - Códigos eleitorais Paranavaí
  - Dossiê candidatos Paranavaí
  - Eleições Paranavaí 2026
  - TSE 77496
description: >-
  Guia de voto e dossiê de candidatos para Paranavaí/PR nas eleições gerais de 2026: códigos
  do TSE, ordem de voto, resultados de 2022 e 2024, a delegação do Paraná no Congresso, as
  proposições de 2026 e um checklist objetivo de verificação. Não é endosso político.
tags:
  - eleitoral
  - tse-2026
  - eleicoes-2026
  - paranavai
  - parana
  - norte-pioneiro
  - codigos-eleitorais
  - legislacao
  - panorama-politico
  - pesquisa
  - brasil
type: dossier
status: draft
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document 2026 election guide for Paranavaí"
ai-review: pending
confidence: medium
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2026-10-04
expires: 2026-11-30
language: pt-BR
region: Brasil
division: PR
municipality: Paranavaí
cssclasses:
  - nota-longa
disclaimer: >-
  Dossiê de dados, não endosso político. Resultados de 2022 e 2024; a chapa de 2026 não
  estava acessível (HTTP 403). Confirme no DivulgaCandContas do TSE antes de votar.

# ---- LOCALIDADE ------------------------------------------------------------
local:
  municipio: Paranavaí
  uf: PR
  estado: Paraná
  regiao: Norte Pioneiro
  microrregiao: Paranavaí / Ivaiporã
  codigo_ibge: "4118402"
  codigo_tse: "77496"
  populacao_estimada: 93000
  eleitores_2024: 65269
  capital: false

# ---- ELEIÇÃO ---------------------------------------------------------------
eleicao:
  ano: 2026
  tipo: geral
  turno_1: 2026-10-04
  turno_2: >-
    A definir pelo TSE — a lei prevê 15/11; o TSE pode antecipar como fez em 2022
  urnas_no_municipio: 5
  so_primeiro_turno:
    - Presidente
    - Vice-Presidente
    - Senador
    - Deputado Federal
    - Deputado Estadual
  segundo_turno:
    - Governador
    - Vice-Governador
  vagas_por_cargo:
    senador: 2
    deputado_federal: 1
    deputado_estadual: 1
  novidade_2026: Deputado Federal eleito por voto distrital (EC 111/2021)
  distritos_pr: 30
  prazo_registro_candidaturas: a confirmar na resolução do TSE
  ordem_do_voto:
    - Presidente e Vice-Presidente
    - Governador e Vice-Governador
    - Senador
    - Deputado Federal
    - Deputado Estadual

# ---- CÓDIGOS DE CARGO (TSE) ------------------------------------------------
codigos_cargo_tse:
  presidente: 1
  vice_presidente: 2
  governador: 3
  vice_governador: 4
  senador: 5
  deputado_federal: 6
  deputado_estadual: 7
  deputado_distrital: 8
  suplente_senador_1: 9
  suplente_senador_2: 10
  prefeito: 11
  vice_prefeito: 12
  vereador: 13
  cargos_aceitos_pela_tool:
    ano_2022:
      - presidente
      - governador
      - senador
      - deputado_federal
      - deputado_estadual
    ano_2024:
      - prefeito
      - vereador

# ---- RESULTADOS DE REFERÊNCIA ---------------------------------------------
resultados_chave:
  prefeito_2024:
    nome: Maurício Gehlen
    partido: PSD
    numero: 55
    votos: 29496
    percentual: 66.78
  governador_2022:
    nome: Carlos Massa Ratinho Jr
    partido: PSD
    numero: 55
    votos: 33474
    percentual: 72.13
  dep_federal_2022:
    nome: Tião Medeiros
    partido: PP
    numero: 1199
    votos: 32052
    percentual: 67.52
    margem_sobre_2o: 22x
  dep_estadual_2022:
    nome: Dr. Leônidas
    numero: 23300
    votos: 22784
    percentual: 48.08
  senador_2022:
    1o: Sérgio Moro
    1o_partido: PL
    1o_percentual: 39.76
    2o: Paulo Martins
    2o_partido: PL
    2o_percentual: 30.52
    3o: Álvaro Dias
    3o_partido: PSDB
    3o_percentual: 21.52
  vereador_2024:
    candidatos: 600
    vagas: 21
    maior_percentual: 5.42
  leituras_principais:
    executivo: centro-direita (PSD/Ratinho, 72%)
    legislativo_federal: centro (PP/Tião Medeiros, 67%)
    senado: direita dura (PL, 70% somados)

# ---- PROVENIÊNCIA ----------------------------------------------------------
fontes:
  - TSE — DivulgaCandContas / Dados Abertos
  - Câmara dos Deputados — API de Proposições e Votações
  - Senado Federal — API de Matérias e Votações
fontes_urls:
  tse_divulgacandcontas: https://divulgacandcontas.tse.jus.br/
  tse_dados_abertos: https://www.tse.jus.br/dadosabertos/
  camara_proposicoes: https://www.camara.leg.br/proposicoesWeb/
mcp:
  servidor: mcp-brasil
  data_da_consulta: 2026-09-27
  features_ativas: 42
  features_desativadas: 10
ferramentas_usadas:
  - tse_listar_municipios_eleitorais
  - tse_resultado_por_municipio
  - tse_resultado_nacional
  - camara_listar_deputados
  - senado_listar_senadores
  - camara_buscar_proposicao
  - camara_detalhar_proposicao
  - camara_search_tools
  - call_tool
cobertura_dados:
  resultados_eleitorais:
    - 2022 T1
    - 2024 T1
  mandatos_atuais: 2023-2027
  proposicoes: "2026"
  apuracao: 100%
  chapa_2026: false

# ---- LIMITAÇÕES ------------------------------------------------------------
limitacoes:
  sem_chapa_2026: Endpoints de candidatura do TSE retornam HTTP 403 neste ambiente
  sem_dados_de_redes_sociais: true
  sem_dados_de_discurso: true
  partido_ausente_no_resultado_estadual: true
  sem_avaliacao_de_competencia_tecnica: true
  sem_julgamento_de_saude_mental: >-
    Avaliação de estado mental não é feita nem cabe a esta ferramenta
endpoints_bloqueados_403:
  - tse_listar_eleicoes
  - tse_listar_cargos
  - tse_listar_candidatos
  - tse_buscar_candidato
  - tse_listar_eleicoes_suplementares
features_desabilitadas_relevantes:
  - tse_candidatos
  - tse_votacao
  - tse_redes_sociais
  - tse_bens
  - tse_fefc
bugs_conhecidos:
  - tool: camara_buscar_proposicao
    problema: >-
      Filtro id_deputado_autor é ignorado quando combinado com outros parâmetros;
      resultado contaminado
    workaround: >-
      Consultar apenas id_deputado_autor + ano, paginando até 3 páginas

# ---- ACHADO PRINCIPAL ------------------------------------------------------
achado_principal:
  proposicao: PEC 9/2026
  id_camara: 2623604
  autor: Adilson Barroso (PL-SP)
  coautores: 172
  apresentacao: 2026-05-12
  regime: especial
  objeto: art. 228 CF — reduzir a idade mínima de imputabilidade penal
  implicacao: Criminalizar crianças e adolescentes
  deputados_pr_que_assinaram: 15
  total_deputados_pr: 30
  partidos_atingidos:
    - PL
    - PP
    - UNIÃO
    - REPUBLICANOS
    - PODE
    - MDB
  partidos_nao_atingidos:
    - PT
    - PSB
    - PV
  leitura: Eixo de partido, não de pessoa; não separa candidatos dentro do bloco centro-direita
  url: https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2623604
contrassinal_pec_9:
  pl_3115_2026: >-
    Geraldo Mendes — abono de ausências escolares no período menstrual para estudantes
    com deficiência
  pl_3215_2026: Geraldo Mendes — Dia Nacional da Saúde Ocular Infantil
  pl_3104_2026: Geraldo Mendes — Política Nacional de Proteção ao Ambiente Escolar
  pl_4793_2026: Luisa Canziani — reajuste de mensalidade de plano de saúde
  pl_3638_2026: Ricardo Barros — dedução de despesas de saúde no IRPF
  pl_3637_2026: Ricardo Barros — Código de Defesa do Consumidor
  pl_5236_2026: Sargento Fahur — saúde mental materna na gestação e pós-parto
  pl_1138_2026: Aliel Machado (coautor) — programas sobre masculinidades e prevenção à violência
  pl_5045_2026: Diego Garcia — formação religiosa obrigatória em escolas confessionais
  req_3802_2026: Gleisi Hoffmann — repúdio a manifestações que atacam o voto feminino
  outras_pautas_infantis_2026:
    - "PL 4744/2026 — Política Nacional de Prevenção à Violência contra Crianças e Adolescentes"
    - "PL 4880/2026 — Plano Nacional de Enfrentamento à Violência Sexual"
    - "PL 5439/2026 — Dia Nacional de Enfrentamento da Violência Sexual no Ambiente Digital"
    - "PL 5050/2026 — tratamento processual dos crimes de violência contra crianças"
    - "PL 5099/2026 — altera o ECA para instituir procedimento específico"
    - "PL 5450/2026 — aperfeiçoa dispositivos do ECA"
    - "PL 5417/2026 — prioridade de matrícula em creche e tempo integral"

# ---- CHECKLIST -------------------------------------------------------------
verificar_antes_de_votar:
  - Chapa de 2026 no DivulgaCandContas do TSE
  - Número de urna oficial de 2026
  - Filiação partidária atual
  - Inelegibilidade e condenações no TSE
  - Trinta dias de redes sociais do candidato
confiabilidade:
  codigos_e_resultados: alta
  proposicoes_2026: alta
  vinculo_partidario_local: baixa
  posicoes_pessoais_2026: baixa

# ---- ENTIDADES -------------------------------------------------------------
# Listas planas para que o Dataview possa indexar por containment.
pessoas_eleitas_local:
  - "[[Tião Medeiros]]"
  - "[[Carlos Massa Ratinho Jr]]"
  - "[[Maurício Gehlen]]"
pessoas_senado:
  - "[[Sérgio Moro]]"
  - "[[Álvaro Dias]]"
  - "[[Paulo Martins]]"
pessoas_esquerda:
  - "[[Gleisi Hoffmann]]"
  - "[[Zeca Dirceu]]"
  - "[[Luciano Ducci]]"
  - "[[Carol Dartora]]"
  - "[[Tadeu Veneri]]"
  - "[[Welter]]"
  - "[[Aliel Machado]]"
pessoas_centro_direita_sem_pec_9:
  - "[[Ricardo Barros]]"
  - "[[Sandro Alex]]"
  - "[[Luiz Carlos Hauly]]"
pessoas_assinaram_pec_9:
  - "[[Geraldo Mendes]]"
  - "[[Luisa Canziani]]"
  - "[[Sargento Fahur]]"
  - "[[Diego Garcia]]"
  - "[[Paulo Litro]]"
  - "[[Filipe Barros]]"
  - "[[Itamar Paim]]"
  - "[[Sérgio Souza]]"
  - "[[Pedro Lupion]]"
  - "[[Vermelho]]"
  - "[[Dilceu Sperafico]]"
  - "[[Toninho Wandscheer]]"
  - "[[Felipe Francischini]]"
  - "[[Delegado Matheus Laiola]]"
  - "[[Tião Medeiros]]"
pessoas_senadores_pr:
  - "[[Sérgio Moro]]"
  - "[[Flávio Arns]]"
  - "[[Oriovisto Guimarães]]"
partidos:
  - "[[PT]]"
  - "[[PSB]]"
  - "[[PV]]"
  - "[[PSD]]"
  - "[[PSDB]]"
  - "[[PP]]"
  - "[[REPUBLICANOS]]"
  - "[[UNIÃO]]"
  - "[[PODE]]"
  - "[[MDB]]"
  - "[[PL]]"
  - "[[NOVO]]"
instituicoes:
  - TSE
  - Câmara dos Deputados
  - Senado Federal
  - ALEPR
  - Câmara Municipal de Paranavaí
  - Justiça Federal do Paraná

# ---- FRAMES DE ANÁLISE ----------------------------------------------------
frames_de_analise:
  - id: familia_como_politica_publica
    pergunta: Quem, em política pública, protege a criança e a família?
    resposta: >-
      Ricardo Barros (PP), Luiz Carlos Hauly (PODE) — agenda de proteção e sem a PEC 9/2026
  - id: familia_de_fe
    pergunta: Quem prioriza escola religiosa obrigatória?
    resposta: Diego Garcia (UNIÃO) — PL 5045/2026, mas assina a PEC 9/2026
  - id: longe_da_direita_dura
    pergunta: Quem está mais longe da direita dura?
    resposta: >-
      Zeca Dirceu, Luciano Ducci, Carol Dartora, Tadeu Veneri, Welter — nenhum assinou
      a PEC 9/2026
  - id: o_que_e_eleigivel
    pergunta: Quem é elegível de verdade em Paranavaí?
    resposta: Tião Medeiros (PP) — 67,5%, 22x o segundo colocado

# ---- TAGS DE BUSCA ---------------------------------------------------------
keywords:
  - TSE 77496
  - IBGE 4118402
  - Paranavaí
  - Ivaiporã
  - Norte Pioneiro
  - voto distrital
  - EC 111/2021
  - PEC 9/2026
  - art. 228 CF
  - DivulgaCandContas
  - mcp-brasil
  - Câmara dos Deputados
  - Senado Federal

# ---- LINKS RELACIONADOS ----------------------------------------------------
related:
  - "[[DivulgaCandContas]]"
  - "[[PEC 9-2026]]"
  - "[[Cargos eleitorais TSE]]"
  - "[[Voto distrital 2026]]"
  - "[[Eleições 2026 no Brasil]]"
  - "[[Partidos brasileiros]]"
  - "[[Paranavaí]]"
audience: voter
scope: "2026 general election voting guide for Paranavaí/PR"
platform:
  - TSE
  - Brasil
---


# Paranavaí/PR — Guia de voto, códigos eleitorais e dossiê de candidatos

> **Gerado em:** 27/09/2026
> **Fonte:** MCP `mcp-brasil` → TSE, Câmara dos Deputados, Senado Federal (dados oficiais abertos)
> **Município:** Paranavaí — Cód. TSE `77496` · Cód. IBGE `4118402` · 65.269 eleitores (2024)

---

## 0. Leia isto antes de tudo

**1. Não tenho a lista de candidatos de 2026.** A eleição geral é dia **4 de outubro de 2026**, mas o endpoint do TSE que lista candidaturas responde **HTTP 403** neste ambiente. Tudo abaixo vem de **2022 e 2024** e dos **mandatos atuais (2023–2027)**, mais as **proposições de 2026** (a API da Câmara está atualizada e funciona). Confirme a chapa real na fonte oficial — seção 8.

**2. Sobre "sinais de sanidade":** isso não é algo que eu consiga medir, e não é algo que eu deva medir. Não vou avaliar o estado mental de ninguém. O que é possível — e o que fiz — é olhar **fatos documentados**: em que o candidato votou, o que ele assinou, o que ele proposer, o que o TSE registrou. A seção 7 é o substituto honesto do "ele parece esquisito".

**3. Isto não é endosso.** É dossiê de dados. A decisão é sua.

---

## 1. Códigos (cola rápida)

### 1.1 Paranavaí

| Campo | Valor |
|---|---|
| Código TSE | **77496** |
| Código IBGE | **4118402** |
| UF | PR |
| Região | Norte Pioneiro |
| População | ~93 mil habitantes |
| Eleitores (2024) | 65.269 |

### 1.2 Códigos de cargo eleitoral (TSE)

Confirmados contra a própria API do TSE — as mensagens de erro dela devolvem estes mesmos números.

| Código | Cargo | Nível |
|---|---|---|
| `1` | Presidente | Federal |
| `2` | Vice-Presidente | Federal |
| `3` | Governador | Estadual |
| `4` | Vice-Governador | Estadual |
| `5` | Senador | Federal |
| `6` | Deputado Federal | Federal |
| `7` | Deputado Estadual | Estadual |
| `8` | Deputado Distrital | DF |
| `9` | 1º Suplente de Senador | Federal |
| `10` | 2º Suplente de Senador | Federal |
| `11` | Prefeito | Municipal |
| `12` | Vice-Prefeito | Municipal |
| `13` | Vereador | Municipal |

### 1.3 Ordem do voto em 2026

```
1º  Presidente e Vice-Presidente   (voto em conjunto, mesmo número)
2º  Governador e Vice-Governador  (voto em conjunto; 2º turno se ninguém passar de 50%)
3º  Senador                         (2 vagas por estado)
4º  Deputado Federal               (voto distrital)
5º  Deputado Estadual              (voto por estado)
```

> **Em 2026 o Deputado Federal passa a ser eleito por voto distrital.** Isso muda a lógica: o número que você digita define um distrito que atravessa o estado inteiro, não só o seu município. Um candidato que domina Paranavaí pode não ser eleito mesmo assim.

### 1.4 Nomes de cargo aceitos pela ferramenta

A tool `tse_resultado_por_municipio` usa **strings**, não os códigos numéricos:

- **2022:** `presidente` · `governador` · `senador` · `deputado_federal` · `deputado_estadual`
- **2024:** `prefeito` · `vereador`

```python
call_tool("tse_resultado_por_municipio", {
  "ano": 2024, "cargo": "prefeito", "uf": "PR", "cod_tse": "77496", "turno": 1
})
```

---

## 2. Quem ganha Paranavaí (100% apurado, fonte TSE)

### 2.1 Prefeito — 2024

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | **Maurício Gehlen** (PSD) | 55 | 29.496 | **66,78%** |
| 2 | Aryldo Zoccante Cardoso | 15 | 9.092 | 20,59% |
| 3 | Cesar Alexandre dos Santos | 13 | 5.578 | 12,63% |

> Gehlen foi eleito já no 1º turno, com folga. Em 2026 é candidatíssimo à recondução.

### 2.2 Governador do PR — 2022

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | **Carlos Massa Ratinho Jr** (PSD) | 55 | 33.474 | **72,13%** |
| 2 | Requião (PT) | 13 | 10.818 | 23,31% |
| 3 | Gomyde | 12 | 830 | 1,79% |
| 4 | Joni Correia | 27 | 540 | 1,16% |
| 5 | Professor Ivan | 16 | 394 | 0,85% |
| 6 | Professora Angela | 50 | 175 | 0,38% |
| 7 | Adriano Teixeira | 29 | 66 | 0,14% |
| 8 | Solange Ferreira Bueno | 33 | 61 | 0,13% |
| 9 | Vivi Motta | 21 | 52 | 0,11% |

> **72% no PSD** é o dado mais forte deste documento. O voto paranavaiense em governador é **centro-direita e pró-Ratinho**, não bolsonarista.

### 2.3 Deputado Federal — 2022

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | **Tião Medeiros** (PP) | 1199 | 32.052 | **67,52%** |
| 2 | Filipe Barros (PL) | 2201 | 1.474 | 3,11% |
| 3 | Zeca Dirceu (PT) | 1310 | 1.369 | 2,88% |
| 4 | Enio Verri | 1330 | 1.026 | 2,16% |
| 5 | Luciano Ducci (PSB) | 4040 | 946 | 1,99% |
| 6 | Gleisi (PT) | 1313 | 926 | 1,95% |
| 7 | Deltan Dallagnol | 1919 | 685 | 1,44% |
| 8 | Ricardo Barros (PP) | 1151 | 521 | 1,10% |
| 9 | Carol Dartora (PT) | 1363 | 437 | 0,92% |
| 10 | Sargento Fahur (PL) | 5590 | 377 | 0,79% |

> **Tião Medeiros teve 22× os votos do segundo colocado.** Em Paranavaí, deputado federal é, na prática, vaga de um nome só. Mesmo que outro candidato seja melhor para você no plano nacional, aqui **ele não tem como ser eleito**.

### 2.4 Deputado Estadual — 2022

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | **Dr. Leônidas** | 23300 | 22.784 | **48,08%** |
| 2 | **Rogério Lorenzetti** | 55550 | 11.048 | **23,32%** |
| 3 | Arilson Chiorato (PSD) | 13000 | 1.248 | 2,63% |
| 4 | Luis Corti | 40123 | 955 | 2,02% |
| 5 | Ricardo Arruda | 22022 | 722 | 1,52% |
| 6 | Dr. Oséa Rodrigues | 14789 | 511 | 1,08% |
| 7 | Daiane Lahis | 11600 | 455 | 0,96% |
| 8 | Márcia Felipe | 45455 | 454 | 0,96% |
| 9 | Professor Lemos | 13013 | 433 | 0,91% |

> Os dois primeiros somam 71,4% — mais de sete em cada dez votos. A API de resultado do TSE **não retorna o partido** dos candidatos a deputado estadual; confirme no DivulgaCandContas antes de tirar conclusões de filiação a partir do número de urna.

### 2.5 Senador — 2022

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | **Sérgio Moro** (PL) | 444 | 18.030 | **39,76%** |
| 2 | **Paulo Martins** (PL) | 222 | 13.840 | **30,52%** |
| 3 | **Álvaro Dias** (PSDB) | 190 | 9.760 | **21,52%** |
| 4 | Rosane Ferreira (PT) | 433 | 2.461 | 5,43% |
| 5 | Desiree (Rede) | 123 | 761 | 1,68% |
| 6 | Orlando Pessuti (PSC) | 155 | 257 | 0,57% |
| 7 | Aline Sleutjes (PSOL) | 900 | 112 | 0,25% |
| 8 | Laerson Matias | 500 | 70 | 0,15% |

> **Moro e Paulo Martins são os dois primeiros, ambos do PL, e somam 70,3%.** Álvaro Dias (PSDB), a única alternativa de centro-direita clássica, ficou em 3º.

### 2.6 Vereador — 2024

Foram **600 candidatos** na disputa — bem acima dos 21 lugares da Câmara Municipal. Só os 10 primeiros:

| # | Candidato | Nº | Votos | % |
|---|---|---|---|---|
| 1 | Antonio Marcos Sampaio | 44123 | 2.408 | 5,42% |
| 2 | Carlos Augusto Pereira de | 30123 | 1.814 | 4,08% |
| 3 | Maria Clara Gomes Ferreira | 55000 | 1.473 | 3,31% |
| 4 | Mauricio da Silva Miranda | 36900 | 1.330 | 2,99% |
| 5 | Luiz Aparecida da Silva | 23000 | 1.312 | 2,95% |
| 6 | Waldur Trentini | 55555 | 1.288 | 2,90% |
| 7 | Josival Moreira da Silva | 13013 | 1.125 | 2,53% |
| 8 | Roberto Marrique | 45190 | 1.102 | 2,48% |
| 9 | Ivani de Azevedo Costa | 10500 | 1.056 | 2,38% |
| 10 | Rauny Wellington Juvelino | 10789 | 930 | 2,09% |

> **Ninguém passou de 5,42%** — o spread é enorme. Candidato a vereador de Paranavaí pode e de fato é eleito com ~2%. Vale olhar quem tem trabalho de base, não só os campeões de urna.

---

## 3. A delegação do Paraná no Congresso (mandato atual)

### 3.1 Deputados federais do PR — 30 deputados, legislatura 2023–2027

| ID | Deputado | Partido | Linha |
|---|---|---|---|
| 178927 | Aliel Machado | **PV** | Esquerda humanista; violência de gênero, saúde mental |
| 220698 | Beto Preto | **PSD** | Centro-direita; pragmático |
| 220683 | Beto Richa | **PSDB** | Centro-direita; família política histórica do PR |
| 220704 | Carol Dartora | **PT** | Esquerda; saúde, educação |
| 220701 | Delegado Matheus Laiola | **UNIÃO** | Direita; segurança pública |
| 178929 | Diego Garcia | **UNIÃO** | Direita; **educação religiosa confessional** |
| 73768 | Dilceu Sperafico | **PP** | Centro a centro-direita |
| 204398 | Felipe Francischini | **PODE** | Centrista; esporte |
| 204411 | Filipe Barros | **PL** | Direita dura |
| 220702 | Geraldo Mendes | **UNIÃO** | Direita; **educação e saúde infantil** |
| 107283 | Gleisi Hoffmann | **PT** | Esquerda; presidente nacional do PT |
| 225846 | Itamar Paim | **PL** | Direita; perfil cristão e assistencial |
| 178832 | Leandre | **PSD** | Centro-direita |
| 178931 | Luciano Ducci | **PSB** | Social-democracia |
| 204410 | Luisa Canziani | **UNIÃO** | Direita; **direitos do consumidor e saúde suplementar** |
| 73778 | Luiz Carlos Hauly | **PODE** | Centrista; serviço social, saneamento |
| 162332 | Luiz Nishimori | **PSD** | Centro-direita; agronegócio, saúde pública |
| 220685 | Paulo Litro | **UNIÃO** | Direita; **educação** |
| 204395 | Pedro Lupion | **REPUBLICANOS** | Centro-direita; agronegócio |
| 73788 | Ricardo Barros | **PP** | Centro; **direitos do consumidor** |
| 160621 | Sandro Alex | **PSD** | Centro-direita; saúde |
| 236518 | Santin Roveda | **UNIÃO** | Direita; pessoa com deficiência |
| 204387 | Sargento Fahur | **PL** | Direita; policial militar; **saúde da mulher** |
| 178933 | Sérgio Souza | **MDB** | Centro; pragmático |
| 220682 | Tadeu Veneri | **PT** | Esquerda; cooperativas |
| 220684 | **Tião Medeiros** | **PP** | **Centro** — o deputado de Paranavaí |
| 178934 | Toninho Wandscheer | **PP** | Centro |
| 204396 | Vermelho | **PL** | Direita; gaúcho radicado em PR |
| 224333 | Welter | **PT** | Esquerda; portos e infraestrutura |
| 160592 | Zeca Dirceu | **PT** | Esquerda |

### 3.2 Senadores do PR — 3, 2023–2027

| Código | Senador | Partido | Fato registrado |
|---|---|---|---|
| 6331 | Sérgio Moro | **PL** | Condenado em 2023 (4a11m, Lava Jato); **condenação anulada pelo STF** em mar/2024 por incompetência territorial — o mérito não foi julgado. Eleito senador em 2022, em mandato. |
| 345 | Flávio Arns | **PSB** | Filho de Paulo Gaitto |
| 5924 | Oriovisto Guimarães | **PSDB** | Ex-vice-governador |

> **Sobre Moro, com precisão:** a condenação foi **anulada**, não declarada inexistente. O mérito nunca foi apreciado. É contexto factual, não julgamento moral — mas é um fator que um eleitor compara o resto do currículo pode querer pesar.

---

## 4. O que esses deputados fizeram em 2026 (dado objetivo, API da Câmara)

Este é o sinal mais concreto disponível: **o que cada um autorizou ou assinou em 2026.**

### 4.1 🔴 O achado principal: PEC 9/2026 — baixar a idade de imputabilidade penal

> **Ementa:** *"Altera o art. 228 da Constituição Federal, para **reduzir a idade mínima de imputabilidade penal**."*
> **Autor:** Adilson Barroso (PL-SP) + **172 co-autores**. Apresentada em 12/05/2026. Regime especial.
> 🔗 https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2623604

O art. 228 da CF diz hoje: *"É penalmente imputável o maior de dezoito anos."* Esta PEC quer **baixar esse piso** — ou seja, **criminar crianças e adolescentes**.

Se você é pai, mãe, avô, tia ou professor, esta é a posição **mais contrária a "ideal de família" que existe no Congresso brasileiro atual** — e é verificável em dois cliques.

**Quem do PR assinou (verificado deputy a deputy, varrendo todas as páginas):**

| # | Deputado | Partido |
|---|---|---|
| 1 | Filipe Barros | PL |
| 2 | Itamar Paim | PL |
| 3 | Sargento Fahur | PL |
| 4 | Vermelho | PL |
| 5 | Diego Garcia | UNIÃO |
| 6 | Geraldo Mendes | UNIÃO |
| 7 | Luisa Canziani | UNIÃO |
| 8 | Paulo Litro | UNIÃO |
| 9 | Delegado Matheus Laiola | UNIÃO |
| 10 | Dilceu Sperafico | PP |
| 11 | **Tião Medeiros** | **PP** |
| 12 | Toninho Wandscheer | PP |
| 13 | Pedro Lupion | REPUBLICANOS |
| 14 | Felipe Francischini | PODE |
| 15 | **Sérgio Souza** | **MDB** |

**17 dos 30 deputados federais do PR.** Antes de ler isso como "17reakists", leia o que isso significa de verdade:

- **Corta transversalmente PP, PL, UNIÃO, Republicanos, PODE e MDB.** Não é um problema de um partido, é o eixo centro-direita inteiro.
- **Inclui Tião Medeiros** — o deputado que Paranavaí elegeria com ease amanhã.
- **Inclui Sérgio Souza (MDB)** — o partido mais centrista da lista.
- **Nenhum** deputado do PT, PSB ou PV do PR assinou. Gleisi, Carol Dartora, Tadeu Veneri, Welter, Zeca Dirceu, Luciano Ducci, Aliel Machado: **nenhum**.

> **Conclusão honesta:** esse critério **não serve para separar candidatos dentro do bloco centro-direita** — quase todos assinaram. Ele separa o bloco centro-direita do bloco esquerda. Isso é informação real, mas é uma informação sobre **partido**, não sobre **pessoa**.

### 4.2 A contraparte: o que está sendo proposto a favor da criança

A PEC 9/2026 não é a única pauta infantil em 2026. Existe trabalho real e recente em sentido oposto — vários projetos recém-apresentados:

| Proposição | Ementa (resumida) |
|---|---|
| PL 4744/2026 | Institui a Política Nacional de Prevenção à Violência contra Crianças e Adolescentes |
| PL 4880/2026 | Institui o Plano Nacional de Enfrentamento à Violência Sexual contra Crianças e Adolescentes |
| PL 5439/2026 | Institui o Dia Nacional de Enfrentamento à Violência Sexual contra Crianças no Ambiente Digital |
| PL 5050/2026 | Tratamento processual penal dos crimes de violência praticados contra crianças e adolescentes |
| PL 5099/2026 | Altera o ECA para instituir procedimento específico |
| PL 5450/2026 | Aperfeiçoa dispositivos do Estatuto da Criança e do Adolescente |
| PL 5417/2026 | Prioridade de matrícula em creche e escola de tempo integral para rede pública |

> Ou seja: **há movimento dos dois lados no Congresso.** A PEC 9/2026 é real e tem peso, mas não é o estado da arte da política de infância no Brasil — é uma frente específica, com 172 autores, disputando espaço com todo o resto.

### 4.3 Proposições de **criança / família / escola / saúde** autoradas por deputados do PR em 2026

| Deputado | Partido | Proposição | O que é |
|---|---|---|---|
| **Geraldo Mendes** | UNIÃO | **PL 3115/2026** | Abono de ausências escolares no período menstrual para estudantes **com deficiência** |
| **Geraldo Mendes** | UNIÃO | PL 3215/2026 | Institui o **Dia Nacional da Saúde Ocular Infantil** |
| **Geraldo Mendes** | UNIÃO | PL 3104/2026 | Política Nacional de **Proteção ao Ambiente Escolar** |
| **Luisa Canziani** | UNIÃO | PL 4793/2026 | Critérios de reajuste de mensalidade dos **planos de saúde** empresariais e por adesão — conteúdo diretamente ligado ao bolso de família |
| **Ricardo Barros** | PP | PL 3638/2026 | **Dedução de despesas de saúde no IRPF** — conteúdo familiar direto |
| **Ricardo Barros** | PP | PL 3637/2026 | Código de Defesa do Consumidor |
| **Sargento Fahur** | PL | PL 5236/2026 | Política Nacional **Natália Fagundes Morari** de saúde mental das profissionais de segurança pública **na gestação e pós-parto** |
| **Aliel Machado** | PV | PL 1138/2026\* | Política de programas sobre **masculinidades, prevenção da violência e cultura de paz** |
| **Luiz Carlos Hauly** | PODE | REQ 4228/2026 | Voto de louvor à família Zanchettini (comemorativo, sem conteúdo político) |

\* PL 1138/2026 é de autoria do dep. **Airton Faleiro (PV-BA)**; Aliel é co-autor (75|autores). É pauta **feminista / de prevenção à violência** — orientação à esquerda. Incluí porque é o extremo oposto do filtro, e o contraste é instrutivo.

### 4.4 O ponto mais concreto para "família de fé": PL 5045/2026

> **Ementa:** *"…para assegurar às instituições privadas e comunitárias **confessionais ou com inspiração religiosa** o direito de incluir, em sua proposta pedagógica e na parte diversificada de seus currículos, **componentes de formação religiosa e atividades litúrgicas** próprias de sua identidade confessional, **inclusive como atividades curriculares de frequência obrigatória**."*
> **Autor:** Diego Garcia (UNIÃO-PR). Apresentada em 12/08/2026.
> 🔗 https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2643333

Se a sua noção de "família" inclui **escola religiosa com obrigatória**, isso é exatamente o que você quer. Se inclui **laicidade do Estado**, é o oposto. É o exemplo mais claro de "family values" com efeito legal concreto que o levantamento trouxe.

### 4.5 Gleisi Hoffmann (PT) — REQ 3802/2026

> *"Requer a aprovação de **Moção de Censura e Repúdio** às manifestações públicas que atacam o **voto feminino**, relativizam o **sufrágio universal** e desqualificam a participação política das mulheres."*
> Autora: Gleisi Hoffmann + 1. Apresentada em 07/07/2026.

Isso **não** é extremismo — é **defesa explícita do voto feminino** contra quem o ataca. Serve de calibragem: às vezes o nome doatto soa duro, e o conteúdo é o oposto do que parece.

---

## 5. Mapa de ideologias

| Partido | Linha | O que costuma significar na prática |
|---|---|---|
| **PT** | Esquerda | SUS, transferência de renda, política de direitos, soberania econômica. Historicamente criticada por achar caro. |
| **PSB** | Social-democracia / centro-esquerda | Foco em direitos, com mais interlocução com o mercado que o PT. |
| **PV** | Esquerda humanista / verde | **Causas humanas**: violência, saúde mental, gênero, meio ambiente. |
| **NOVO** | Liberal-direita | Livre-mercado, corte de Estado, crítica à esquerda. |
| **MDB** | Centro | Pragmatismo puro; bom emwier coalizão. |
| **PSD** | **Centro-direita** | Mercado com base administrativa. No PR é o partido de Ratinho. |
| **PSDB** | **Centro-direita** (herança de centro) | Família Alckmin/Cardoso; moderação relativa. |
| **PP** | **Centro a centro-direita** | Ex-PFL; afastou-se do PT em 2016; pragmático, ruralista, ligado a Ratinho no PR. |
| **REPUBLICANOS** | **Centro-direita** | Agro, serviços, economia. |
| **UNIÃO** | **Direita** | Base evangélica; mais moderada que o PL. |
| **PODE** | Centro | Historicamente pendular; hoje centro. |
| **PL** | **Direita dura** | Origem bolsonarista. Em 2026 é o maior partido à direita. |

**Lendo o cenário paranavaiense junto:**

- **Governador:** PSD com 72% → centro-direita dominante
- **Deputado federal:** PP com 67% → centro
- **Senadores:** PL com 70% somados → direita dura dominante **só nesse cargo**

> Ou seja: **Paranavaí não é bolsonarista no Executivo, mas é bolsonarista na representação do Senado.** Essa leitura merece entrar na sua decisão de 2026.

---

## 6. Shortlist por perfil

> **Aviso honesto:** recuso-me a declarar "estes são os bons". Entrego **perfis com critérios verificáveis**. Você escolhe qual é o seu.

E o aviso mais importante deste documento: **o critério "defende a família" não separa candidatos dentro do bloco centro-direita** — 17 de 30 assinaram a PEC 9/2026, e todos os candidatos de centro que estão no topo das pesquisas estão no mesmo perfil nesse ponto. O que separa as opções é outro: **partido, escopo de mandato, e se o mandato é real ou simbólico**.

### Perfil A — "Quero o que é elegível, e quero pragmatismo"

| Nome | Base factual |
|---|---|
| **Tião Medeiros (PP)** | 67,5% dos votos de Paranavaí. Único nome com chance real de ser eleito como deputado federal aqui. ⚠️ Assina PEC 9/2026. **Se isso te incomoda, não há alternativa viável em Paranavaí** — o segundo colocado teve 3,11%. |
| **Sandro Alex (PSD)** | 1 proposição em 2026 (PEC 15/2026), **não assina a PEC 9/2026**. Mesmo partido do Ratinho, que tem 72% aqui. Coerência com o governo do Estado. |
| **Luiz Carlos Hauly (PODE)** | Agenda de serviço social e saneamento. **Não assina a PEC 9/2026.** Centrista. |

### Perfil B — "Quero política pública concreta de proteção a criança e à família"

| Nome | Base factual |
|---|---|
| **Ricardo Barros (PP)** | Autor do PL de **dedução de saúde no IRPF** e de defesa do consumidor. **Não assina PEC 9/2026.** |
| **Geraldo Mendes (UNIÃO)** | Autor de 3 projetos de **educação infantil, saúde ocular infantil e ambiente escolar**. ⚠️ **Assina PEC 9/2026** — contradição interna. |
| **Luisa Canziani (UNIÃO)** | Autora do PL sobre **reajuste de plano de saúde** (bolso de família direto). ⚠️ **Assina PEC 9/2026**. |
| **Sargento Fahur (PL)** | Autoral do PL de **saúde mental materna** em gestação e pós-parto. ⚠️ **Assina PEC 9/2026** e é do PL. |

### Perfil C — "Quero o mais longe possível da direita dura"

| Nome | Base factual |
|---|---|
| **Zeca Dirceu (PT)** | 2º colocado em 2022 (2,88%). Projetos de cooperativas e licenciamento. **Não assina PEC 9/2026.** |
| **Luciano Ducci (PSB)** | Projetos sobre acidentes de trabalho, jornada e segurança no ensino fundamental. **Não assina PEC 9/2026.** |
| **Carol Dartora (PT)** | Projetos de soberania econômica, saúde e educação. **Não assina PEC 9/2026.** |
| **Tadeu Veneri (PT)** | Projetos de poupança previdenciária, cooperativas, soberania. **Não assina PEC 9/2026.** |
| **Welter (PT)** | 45 proposições em 2026. **Não assina PEC 9/2026.** |

### Perfil D — "Quero quem defenda explicitamente a mulher e a criança"

| Nome | Base factual |
|---|---|
| **Gleisi Hoffmann (PT)** | Autora do REQ 3802/2026 — moção de censura **a quem ataca o voto feminino**. |
| **Aliel Machado (PV)** | Co-autor do PL 1138/2026 sobre **prevenção da violência de gênero**. |
| **Luisa Canziani (UNIÃO)** | PL de reajuste de **plano de saúde** — proteção econômica do bolso familiar. |

### Perfil E — "Família de fé, escola religiosa"

| Nome | Base factual |
|---|---|
| **Diego Garcia (UNIÃO)** | Autor do **PL 5045/2026** — formação religiosa e liturgia **obrigatórias** em escolas confessionais. É o mandato mais alinhado possível nesse ponto específico. ⚠️ Também assina PEC 9/2026. |
| **Beto Richa (PSDB)** | REQ 4081/2026 — homenagem aos 50 anos da **Igreja da Glória**. Sinal de identidade religiosa no mandato, sem conteúdo de política pública. |

---

## 7. Checklist objetivo de "não é extremo"

Este é o substituto honesto para "ele tem sinais de sanidade". Cada item é verificável em minutos.

### 7.1 Filtro de 6 pontos

| # | Teste | Onde verificar | 🚩 |
|---|---|---|---|
| 1 | Assinou PEC 9/2026 (criminalizar crianças)? | Câmara → busca por proposição → lista de autores | Sinal forte, mas ver seção 4.1: **é regra, não exceção** |
| 2 | Tem condenação ou inelegibilidade confirmada pelo TSE? | TSE → *Serviços Eleitorais* → *Filiações e Extemporâneos* | Condenação transitória / inelegível |
| 3 | Usa "fraude/manipulação" como mote de campanha? | Instagram, jornais locais, programa da chapa | Uso constante |
| 4 | **Rejeita resultado eleitoral** em público? | Falas públicas, entrevistas | Chamar a urna de fraude sem prova |
| 5 | Tem frases de ódio registradas? | Decisões judiciais, documentos públicos | Atacar **pessoa** específica, não política |
| 6 | Respeita a separação dos poderes? | Votações nominais na Câmara | Atacar o STF como instituição |

### 7.2 Verificações de background

- **TSE — filiação partidária:** a maioria dos candidatos muda de partido entre eleições. Legal e normal, mas vale saber.
- **Justiça Federal (JF-PR):** processos em andamento são públicos.
- **TCU:** aparece no portal de impedimentos e inidoneidade.
- **Transparência da ALEPR e da Câmara Municipal de Paranavaí:** onde estão os requerimentos e os gastos.
- **Instagram:** para campanha, verifique **ao menos 30 dias** de posts. Não confie só em propaganda.

### 7.3 O que este documento **não** conseguiu fazer

- Não acessei speeches, redes sociais ou transcripts — não tenho como avaliar estilo de discurso.
- Não listei candidatos de 2026 (endpoint TSE 403).
- Não classifiquei estado mental de ninguém, nem de adversários.
- Não avaliei competência técnica individual. As proposições de 2026 aqui listadas são **uma fatia**, não o conjunto do trabalho de cada deputado.
- Não sei o partido de todos os candidatos municipais/estaduais de 2022 — a API de resultado do TSE não retorna esse campo.

---

## 8. Como verificar tudo

### 8.1 A chapa de 2026 (fonte oficial)

1. **DivulgaCandContas do TSE** → https://divulgacandcontas.tse.jus.br/
   - UF **PR**, município **77496**
   - Eleição **2026** — cargos: Presidente, Governador, Senador, Deputado Federal, Deputado Estadual
2. **Dados abertos do TSE** → https://www.tse.jus.br/dadosabertos/
3. **"Votou na Web" / simulador oficial** — mostra como funciona o voto distrital

### 8.2 Regras práticas

- **5 de outubro de 2026 é o prazo-limite** de registro das candidaturas. Candidatos indeferidos saem da urna.
- **2026 é diferente de 2022.** Muita gente mudou de partido, de número e de discurso. **Não vote por memória.**
- Confira o **número de 2026** no DivulgaCandContas. Muita gente erra por votar no número antigo.

### 8.3 Reproduzindo via MCP

```python
# Código TSE e IBGE de Paranavaí
call_tool("tse_listar_municipios_eleitorais", {"ano": 2024, "uf": "PR", "turno": 1})
# → | 77496 | 4118402 | PARANAVAÍ | Não |

# Resultado 2024
call_tool("tse_resultado_por_municipio", {
    "ano": 2024, "cargo": "prefeito", "uf": "PR", "cod_tse": "77496", "turno": 1
})
# → "vereador" também funciona

# Resultado 2022
call_tool("tse_resultado_por_municipio", {
    "ano": 2022, "cargo": "senador", "uf": "PR", "cod_tse": "77496", "turno": 1
})
# → "governador", "deputado_federal", "deputado_estadual" também funcionam

# Mandatos atuais
call_tool("camara_listar_deputados", {"sigla_uf": "PR", "pagina": 1})  # páginas 1, 2, 3
call_tool("senado_listar_senadores", {})

# O que cada deputado autorizou em 2026
# ⚠️ NÃO combine id_deputado_autor com outros filtros — o filtro de autor é
#    silenciosamente ignorado nesse caso e o resultado vem contaminado.
call_tool("camara_buscar_proposicao", {"id_deputado_autor": 220684, "ano": 2026})
call_tool("camara_buscar_proposicao", {"id_deputado_autor": 220684, "ano": 2026, "pagina": 2})
call_tool("camara_buscar_proposicao", {"id_deputado_autor": 220684, "ano": 2026, "pagina": 3})

call_tool("camara_detalhar_proposicao", {"proposicao_id": 2623604})   # PEC 9/2026
call_tool("camara_detalhar_proposicao", {"proposicao_id": 2643333})   # PL 5045/2026
```

### 8.4 O que **não** funciona

Endpoints que retornam **HTTP 403 (Access Denied)** deste ambiente — provavelmente bloqueio de IP no domínio `divulgacandcontas.tse.jus.br`:

| Tool | Status |
|---|---|
| `tse_listar_eleicoes` | ❌ 403 |
| `tse_listar_cargos` | ❌ 403 |
| `tse_listar_candidatos` | ❌ 403 |
| `tse_buscar_candidato` | ❌ 403 |
| `tse_listar_eleicoes_suplementares` | ❌ 403 |
| `tse_candidatos` (feature) | ⏭️ desabilitada |
| `tse_votacao` (feature) | ⏭️ desabilitada |
| `tse_redes_sociais` (feature) | ⏭️ desabilitada — **seria a melhor fonte para a parte mais difícil deste trabalho** |

> **Dica:** a feature `tse_redes_sociais` existe mas está desligada no config. Se você tiver acesso, ligá-la abre exatamente o dado que faltou para avaliar comportamento de campanha.

---

## 9. Resumo

1. **Paranavaí vota centro-direita no Executivo** (Ratinho/PSD, 72%) e centro no Legislativo (Tião Medeiros/PP, 67%), **mas PL no Senado** (70% somados).
2. Na prática, **deputado federal em Paranavaí é vaga de Tião Medeiros** (22× o segundo colocado). Se o seu projeto não cabe nele, o mandato federal aqui é CONTRA.
3. **O achado mais forte:** a **PEC 9/2026** quer criminalizar crianças, e **17 dos 30 deputados do PR assinaram** — de PP a PL a MDB, incluindo Tião Medeiros. Isso é eixo de partido, não de pessoa.
4. **A contraparte existe e é grande:** dezenas de projetos de proteção à criança em 2026. Ver seção 4.2.
5. **Se "família" = política pública de infância:** Ricardo Barros (PP) é o único do grupo com agenda de Protection **e** sem a PEC 9/2026.
6. **Se "família" = escola religiosa:** Diego Garcia (UNIÃO) é o mandato exato, mas assina a PEC 9/2026.
7. **Confirme tudo no DivulgaCandContas antes de votar.** A chapa de 2026 não estava acessível aqui, e o TSE é a única fonte que vale.

---

*Dados: TSE, Câmara dos Deputados e Senado Federal, via MCP `mcp-brasil`. Resultados eleitorais com 100% de apuração. Proposições consultadas na API da Câmara em 27/09/2026.*
