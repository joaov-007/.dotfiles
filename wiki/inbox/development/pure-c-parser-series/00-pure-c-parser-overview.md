---
title: "Pure C Parser Series: Overview"
tags:
  - c
  - parser
  - tutorial
  - data-structures
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[01-thinking-about-data-before-parsing]]"
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[10-performance-measurement-without-myths]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Visão geral da série: como construir um parser em C puro, passo a passo, equilibrando dados, memória e performance."
language: pt-BR
audience: developer
scope: "visão geral da série de parser em C puro"
keywords:
  - c
  - parser
  - "série"
  - trade-offs
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Pure C Parser Series: Overview

> [!summary]
> Esta série ensina, passo a passo, como criar um parser em **C puro** com foco em: modelar dados, organizar memória, estruturar com clareza, filtrar/consultar e manter performance sem sacrificar developer experience (DX). O ponto central são os **trade-offs**.

## Objetivo

Ao final desta série você deverá ser capaz de:

- Pensar em **dados** antes de pensar em código: quais campos, quais invariantes, qual "forma" faz sentido.
- Escolher entre **array contíguo x lista ligada**, **arena x `malloc` por nó**, **stack x heap** de forma consciente.
- Trabalhar com **strings sem cópias desnecessárias** (`string view`), entender ownership e lifetime.
- Escrever um **lexer** pragmático com spans (linha/coluna) pra bons erros.
- Modelar uma **AST** enxuta com `enum + union` (tagged union).
- Implementar um **recursive descent** simples e entender seus limites.
- Organizar um projeto C pequeno, legível e fácil de navegar.
- **Filtrar e iterar** sobre dados estruturados com iteradores minimalistas.
- **Medir** performance de forma realista e decidir quando otimizar.
- Construir um **mini parser JSON-like** funcional, com filtros, usando arena.

## Pré-requisitos

- Conhecimento básico de C: tipos, ponteiros, arrays, structs, enums, `malloc/free`.
- Noções de leitura de arquivos texto.
- Vontade de entender **porquê**, não só copiar.

> [!tip]
> Não precisa saber teoria pesada de compiladores. Vamos pelo caminho pragmático: resolver um problema real com código enxuto.

## Mental Model

Todo parser, por mais simples, segue esse fluxo:

1. **Input** – Bytes/texto bruto (`char*`, tamanho conhecido)
2. **Lexing (tokenização)** – Quebra em tokens com tipo + lexeme + span
3. **Parsing (estruturação)** – Transforma tokens em uma **estrutura organizada** (AST ou árvore de valores)
4. **Representation (organização)** – Aloca em memória com layout pensados pra acesso
5. **Query/Filter (consulta)** – Itera, seleciona, transforma sem reescrever tudo
6. **Output/Use** – Usa os dados estruturados com clareza

A diferença entre código "funciona" e código "bom pra manter e veloz" está em **como** você organiza os passos 3–5.

## Roadmap

| Etapa | Nota | Quando ler |
|---|---|---|
| 1 | [[01-thinking-about-data-before-parsing]] | **Obrigatório.** Antes de abrir o editor pra escrever structs. |
| 2 | [[02-memory-layout-and-tradeoffs]] | Essencial pra entender performance prática. |
| 3 | [[03-strings-slices-and-ownership]] | Fundamental pra evitar cópias e bugs com lifetime. |
| 4 | [[04-lexing-tokenization-pragmatic]] | Base pra qualquer parser texto. |
| 5 | [[05-ast-structuring-without-overengineering]] | Como manter AST simples e útil. |
| 6 | [[06-parsing-recursive-descent-tradeoffs]] | Implementação pragmática + limites. |
| 7 | [[07-error-reporting-and-developer-experience]] | Torna debugging humano. |
| 8 | [[08-project-organization-in-pure-c]] | Mantém legível conforme cresce. |
| 9 | [[09-filtering-querying-over-structured-data]] | Foca em **usar** os dados depois de parsear. |
| 10 | [[10-performance-measurement-without-myths]] | Aprenda a medir ao invés de adivinhar. |
| 11 | [[11-mini-json-like-parser-with-filters]] | Junta tudo num exemplo concreto. |
| 12 | [[12-tradeoffs-cheatsheet]] | Use como consulta rápida. |

## Filosofia: "Performático + Boa DX"

Dois eixos guiam esta série:

- **Performance prática**: priorize **localidade de cache**, **menos alocações**, **layout previsível**. Otimize o que realmente impacta.
- **Developer Experience**: priorize **clareza**, **erros acionáveis**, **nomes curtos mas explícitos**, **poucos níveis de indireção**.

Esses eixos **conflitam**. É exatamente por isso que vamos falar tanto de trade-offs.

## Como usar esta série

1. **Leia na ordem**. Cada nota constrói sobre a anterior.
2. **Não pule os trade-offs**. Se vir uma tabela "Prós/Contras", leia com calma.
3. **Digite, não copie e cole cegamente**. Tentar reescrever com suas palavras fixa muito mais.
4. **Teste mentalmente**. Pergunte: *"Por que array e não lista? Por que arena e não malloc por nó?"*
5. **Mensure** quando duvidar. Vá pra [[10-performance-measurement-without-myths]].

> [!info]
> Esta série foi pensada pra ser lida no **Obsidian**. Os `[[wikilinks]]` permitem navegar entre notas sem quebrar o fluxo. Aproveite o grafo também.

## Referências rápidas

- [[12-tradeoffs-cheatsheet]] – Decisões práticas resumidas
- [[11-mini-json-like-parser-with-filters]] – Exemplo completo e comentado
- [[09-filtering-querying-over-structured-data]] – Focar em "como usar" seus dados

## Próximo passo

Comece por: [[01-thinking-about-data-before-parsing]]