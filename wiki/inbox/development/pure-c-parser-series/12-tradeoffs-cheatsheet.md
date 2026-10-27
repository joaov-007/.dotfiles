---
title: "Trade-offs Cheatsheet"
tags:
  - c
  - parser
  - cheatsheet
  - tradeoffs
  - reference
type: cheatsheet
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
cssclasses:
  - cheatsheet
  - wide-table
related:
  - "[[00-pure-c-parser-overview]]"
  - "[[01-thinking-about-data-before-parsing]]"
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[03-strings-slices-and-ownership]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[06-parsing-recursive-descent-tradeoffs]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[10-performance-measurement-without-myths]]"
  - "[[11-mini-json-like-parser-with-filters]]"
description: "Cheatsheet de trade-offs para decisões rápidas ao projetar um parser em C puro."
language: pt-BR
audience: developer
scope: cheatsheet de trade-offs
keywords:
  - c
  - trade-offs
  - cheatsheet
platform:
  - C
  - Linux
last_reviewed: 2026-10-15
---
# Trade-offs Cheatsheet

> [!summary]
> Referência prática pra decisões rápidas. Não "melhor sempre", mas **adequado ao contexto**. Use como checklist ao projetar parser em C puro.

## 1) Modelagem de Dados

| Escolha | Quando usar | Evitar | Racional |
|---|---|---|---|
| **Array contíguo (`T[]`)** | Iteração/filtragem 90%+ | Inserts/removes constantes no meio | Cache-local, previsível |
| **Lista ligada** | Inserção no meio frequente, sem scan total | Quase tudo p/ "parse+query" | Pointer-chasing mata throughput |
| **AOS (Array of Structs)** | Registro completo acessado junto | Filtrar 1 campo só com n enorme | Legível + bom |
| **SOA (Struct of Arrays)** | Filtros seletivos por poucos campos | Queries mistas, n pequeno | Densidade alta p/ campo alvo |
| **Tagged union (`enum+union`)** | Valores heterogêneos | "Tudo é ponteiro void" | Seguro + eficiente |
| **Minimal MVP** | Aprendendo/prototipando | Generalizar cedo | Clareza > abstração |

## 2) Memória: Stack vs Heap vs Arena

| Aspecto | Stack | Heap `malloc/free` | **Arena (bump)** |
|---|---|---|---|
| **Velocidade** | ★★★★★ | ★★☆ | ★★★★★ |
| **Fragmentação** | Nenhuma | Média/Alta | Mínima |
| **Libera indiv.** | Auto (scope) | Sim | **Não** (bulk) |
| **Segurança lifetime** | Ótima (curto) | Cuidado | Ótima se lifetimes claros |
| **Crescimento** | Fixo | Dinâmico | Dinâmico (com grow) |
| **Ideal p/ parser** | Temp small | Geral | **Sim** (AST/tokens) |

**Recomendado:** **Arena** p/ lote (parse->query->descartar). Mix com heap p/ arrays mutáveis ok.

## 3) Strings: View vs Owned

| Fator | **StrView (`const char*+len`)** | **StrOwn (`char*+len`)** |
|---|---|---|
| **Zero-copy** | Sim | Não |
| **Parse speed** | Melhor | Ligeiro + lento |
| **Independente** | Não (depende buffer) | **Sim** |
| **Segurança dangling** | Baixa se descuidado | Alta |
| **Debug pós-free** | Ruim | Bom |
| **Memória** | Mínima | +cópias |
| **Interop c/ APIs NUL-term** | Cuidado | Fácil |

**Regra:** **View durante parse**. **Owned** só se precisa vida longa após liberar `buf`.

## 4) Lexer

| Decisão | Recom. | Por quê |
|---|---|---|
| **Char-by-char** | **Sim** | Simples, previsível, sem regex |
| **StrView nos tokens** | **Sim** | Zero-copy |
| **Spans (line/col/start/end)** | **Sim** | Essencial p/ erros bons |
| **Skip whitespace** | **Sim** | Tokens limpos |
| **Keywords explícitos** | **Sim** | Claro vs tabela |
| **TOK_ERR + mensagem** | **Sim** | Propaga bem |
| **Array de tokens (debug)** | **Sim** inicial | Facilita entender fluxo |
| **Stream pull-style** | Evoluir depois | Menor memória p/ muito grande |

## 5) AST

| Decisão | Recom. | Notas |
|---|---|---|
| **Tagged union** | **Sim** | Padrão C pragmático |
| **Arr.items[] contíguo** | **Sim** | Cache-friendly |
| **Obj.pairs[] contíguo** | **Sim** | Melhor p/ iteração |
| **Val por valor em arrays** | **Sim** | Menos indireção |
| **Arr/Obj alocados** | **Sim** | Referenciados via `Val` |
| **Não espelhar `, : [ ] { }`** | **Sim** | AST abstrata |
| **Forward decls** | **Sim** | Evita ciclos |
| **Arena p/ nós** | **Altamente** | Rápido + simples p/ parser |

## 6) Parser (Recursive Descent)

| Decisão | Recom. | Por quê |
|---|---|---|
| **RD manual** | **Sim** p/ aprender | Entende tudo, sem gerador |
| **LL(1) lookahead** | **Sim** | Suficiente p/ JSON-like |
| **Mapeamento 1:1 regra->função** | **Sim** | Legível, testável |
| **Fail-fast** | **Sim** inicial | DX clara, menos código |
| **Error recovery** | **Não** inicial | Complexo desnecessário |
| **Recursivo p/ aninhamento** | **Sim** | Natural, legível |
| **Iterativo com pilha** | Só se stack overflow real | Mais verboso |

**Cuidado:** recursão profunda em input extremo (raro).

## 7) Erros & DX

| Item | Recom. | Comentário |
|---|---|---|
| **"esperava X, vi Y"** | **Sim** | Acionável |
| **line/col 1-based** | **Sim** | Mais humano |
| **Span salvo** | **Sim** | Útil p/ tooling |
| **Linha + caret** | **Sim** | Imbatível p/ debug |
| **Manter 1º erro** | **Sim** | Evita ruído |
| **Tratar EOF explícito** | **Sim** | Comum |
| **Propagar erros lexer** | **Sim** | Não mascarar |

## 8) Organização Projeto

| Item | Recom. | Comentário |
|---|---|---|
| **Separar módulos** | **Sim** (sv/lex/ast/parser/...) | Navegação clara |
| **Include guards** | **Sim** (`#ifndef`) | Portátil |
| **`static` interno** | **Sim** | Oculta, evita conflitos |
| **Headers mínimos** | **Sim** | Menor acoplamento |
| **Forward decls** | **Quando evita include** | Útil |
| **Const-correctness** | **Sim** | Comunica intenção |
| **main só orquestra** | **Sim** | SRP |
| **Build simples** | **Sim** (`cc *.c`) | Foco em aprender |

## 9) Filtragem/Consulta

| Técnica | Quando | Notas |
|---|---|---|
| **Inline `if`** | Único uso | **Mais claro** |
| **Predicado `(*fn)(...)`** | Reutilizar | Bom equilíbrio |
| **Linear scan** | n < 10^3–10^4 | Quase sempre ok |
| **Índices (`size_t[]`)** | Reusar subconjunto | Zero-copy |
| **Ponteiros `Val**`** | Acesso direto | Ótimo |
| **SOA derivado** | n gigante + filtros repetidos | Esforço justificado só com medição |
| **Recursivo walk** | Hierarquia arbitrária | Cuidado stack |
| **Iterador minimal** | Abstrair loop | Legível |

## 10) Performance & Medição

| Ação | Recom. | Motivo |
|---|---|---|
| **Medir antes** | **Sempre** | Evita otimizar errado |
| **`-O2`** | **Sempre** p/ bench | Realista |
| **`hyperfine`** | **Recom.** | Estatístico |
| **`perf stat`** | **Recom.** | Entender cache/branch |
| **Dataset realista** | **Sim** | Evita ilusão |
| **Isolar fases** | **Quando dúvida** | Descobre gargalo |
| **Focar em cache-misses** | **Importante** | Reflete localidade |
| **Evitar premature opt** | **Sim** | Legibilidade > 1–2% |
| **Mantenha array contíguo** | **Default** | Maior ROI prático |

## 11) Decisões "Default Sugerido" p/ Série

| Área | Escolha padrão | Alternativa só se... |
|---|---|---|
| **Layout** | **AOS + arrays contíguos** | Medir vantagem SOA clara |
| **Memória** | **Arena + heap p/ grow arrays** | Tudo arena com cap estimado |
| **Strings** | **StrView** | Precisa guardar pós-liberar buf |
| **AST** | **Tagged union minimal** | Realmente precisar visitor genérico |
| **Parser** | **Recursive Descent fail-fast** | Gramática gigante justificar gerador |
| **Erros** | **linha+col+caret** | Tooling ultra-minimal |
| **Queries** | **Inline/predicado + linear scan** | n enorme + buscas massivas |
| **Org** | **Multi-módulo enxuto** | Protótipo de 50 linhas |

## 12) Checklist Rápido Antes de Commit

- [ ] **Modelou** com base em queries reais?
- [ ] **Array contíguo** p/ listas iteradas?
- [ ] **Arena** considerada p/ muitas alocs?
- [ ] **Lifetime** claro (view vs owned)?
- [ ] **Erros** acionáveis com posição?
- [ ] **Recursão** segura p/ caso esperado?
- [ ] **Checa types** antes de union?
- [ ] **`const`** onde apropriado?
- [ ] **`static`** p/ internos?
- [ ] **Mediu** se trocou por "mais rápido"?

## 13) Leituras rápidas por tópico

- Modelagem: [[01-thinking-about-data-before-parsing]]
- Memória/cache: [[02-memory-layout-and-tradeoffs]]
- Strings+ownership: [[03-strings-slices-and-ownership]]
- Lexer: [[04-lexing-tokenization-pragmatic]]
- AST: [[05-ast-structuring-without-overengineering]]
- RD: [[06-parsing-recursive-descent-tradeoffs]]
- Erros/DX: [[07-error-reporting-and-developer-experience]]
- Organização: [[08-project-organization-in-pure-c]]
- Filtros: [[09-filtering-querying-over-structured-data]]
- Medição: [[10-performance-measurement-without-myths]]
- Exemplo completo: [[11-mini-json-like-parser-with-filters]]

**Regra final:** **Clareza > cleverness. Medir > adivinhar. Simples > complexo.**