---
title: "Thinking About Data Before Parsing"
tags:
  - c
  - parser
  - data-modeling
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[00-pure-c-parser-overview]]"
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Pensar em dados antes do código: quais campos, quais invariantes e que forma a estrutura deve ter."
language: pt-BR
audience: developer
scope: modelagem de dados antes de codificar
keywords:
  - c
  - parser
  - modelagem de dados
  - design
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Thinking About Data Before Parsing

> [!summary]
> **Regra de ouro:** Não comece escrevendo `struct Token { ... }`. Comece descrevendo **o que você precisa representar**. Modelar domínio, invariantes e acessos antes de escolher structs evita over-engineering e torna o parser muito mais fácil de filtrar depois.

## 1) Domínio primeiro, código depois

Antes de tokenizar, pergunte-se:

- **Qual é o formato?** Texto simples, linha-based, delimitado, hierárquico (JSON-like), etc.
- **Quais entidades importam?** Objetos, listas, valores, chaves, identificadores...
- **O que vou **fazer** com esses dados?** Apenas imprimir? Filtrar por chave? Buscar por id? Contar? Ordenar? Iterar muito?
- **Qual o volume?** Centenas, milhares, milhões de entradas? Isso muda decisões de layout.
- **Preciso preservar **texto original**?** Ou só valores semânticos?

> [!tip]
> **Acesso define estrutura.** Se você vai buscar por `id` 90% das vezes, array ordenado ou tabela por chave compensa muito mais que lista ligada.

## 2) Exemplo prático: "lista de pessoas"

Vamos supor um input simples:

```text
{"name":"Ana","age":25}
{"name":"Bruno","age":31}
{"name":"Clara","age":27}
```

**Perguntas práticas:**

1. Preciso manter `name` como cópia ou só uma referência ao texto original?
2. Vou filtrar por `age >= 30`? Por `name` começando com 'B'?
3. Preciso iterar **sequencialmente** sempre? Ou acessar por índice?
4. É imutável depois do parse?

Essas respostas guiam tudo.

## 3) Invariantes

**Invariante** = algo que SEMPRE deve ser verdade após parse bem-sucedido.

Exemplos:

- `"name"` nunca é NULL
- `age >= 0` (se válido)
- Índices dentro de arrays são válidos
- `next`/`prev` só existem em listas duplamente ligadas e são coerentes
- `type` de um `Value` casa com a `union`

> [!warning]
> Quanto mais invariantes claras você tem, menos checagens espalhadas pelo código. Você valida **na borda** (parser) e confia **no interior** (filtros/consultas).

## 4) Pensando em "shape" (forma)

Pense nos dados como **formas** geométricas de memória:

| Forma | Quando usar | Observação |
|---|---|---|
| **Array plano (`[T; N]` ou `vec<T>`)** | Iteração sequencial, filtros lineares, bulk ops | Ótimo pra **cache line**. Melhor pra performance geral. |
| **Array de ponteiros (`T*[]`)** | Precisa reordenar sem mover objetos grandes | Move ponteiros, não dados. Troca flexibilidade por indireção. |
| **Lista ligada (`next/prev`)** | Inserção/remoção frequente no meio | **Péssimo** pra cache. Evite se 95% é "ler e filtrar". |
| **Tabela (index by key)** | Busca por chave única | Pode ser array + linear scan (pequeno) ou simples `strcmp` + loop. Overkill cedo. |
| **Tagged union** | Valores heterogêneos (string/num/bool/null) | Clássico em parsers. Enxuto e eficiente. |

**Regra pragmática:** Comece com **array contíguo**. Só mude se tiver evidência concreta.

## 5) Exemplo: modelando "Pessoa"

### Opção A: Minimalista (ótima pra filtrar)

```c
typedef struct {
    const char *name; // view para texto original OU cópia
    int age;
} Person;
```

Se tivermos `Person *list` + `count`, conseguimos:

```c
for (int i = 0; i < count; i++) {
    if (list[i].age >= 30) { ... }  // acessa contíguo -> cache-friendly
}
```

**Trade-off:** Simples, direto, rápido pra scan.

### Opção B: Com "id" e ponteiros

```c
typedef struct Person {
    int id;
    const char *name;
    int age;
    struct Person *next; // talvez desnecessário
} Person;
```

**Trade-off:** `next` adiciona indireção e piora localidade. Só vale se realmente inserir/remover no meio **muito**.

## 6) Escolha entre "view" vs "owned copy"

Em parsers de texto, muito comum: apontar pra substring do buffer original.

```c
// View: não aloca novo char[]
typedef struct {
    const char *data;
    size_t len; // evita strlen toda vez
} StrView;
```

```c
// Owned: aloca e copia
typedef struct {
    char *data;  // strdup
    size_t len;
} StrOwn;
```

| Critério | View (`const char* + len`) | Owned (`char* + len`) |
|---|---|---|
| **Memória** | 0 cópias extras | +1 cópia por string |
| **Velocidade** | Mais rápido | Um pouco mais lento no parse |
| **Lifetime** | Depende do **buffer original** permanecer vivo | Independente |
| **Mutabilidade** | Read-only | Pode editar livremente |
| **Segurança** | Cuidado: buffer pode ser `free`'d depois | Seguro após parse |
| **Uso típico** | Parse -> filtrar/consultar **antes** de descartar input | Parse -> guardar resultado por tempo indefinido |

> [!warning]
> **Lifetime é real em C.** Se você libera o `char *input` mas mantém `const char* name` apontando pra dentro dele, vira dangling pointer. Tenha clareza sobre quem "dono" é.

**Pragmatismo:** Se você consome os dados **imediatamente** após parse (filtra, imprime), **view** é ótimo. Se precisa guardar em estrutura persistente, **owned** compensa.

## 7) "Representação interna" vs "representação externa"

Muitas vezes confundimos **formato de entrada** com **modelo interno**.

**Entrada:** `{"name":"Ana","age":25}` (JSON-esque)

**Modelo interno:** Só o que interessa

```c
typedef enum { VAL_STR, VAL_NUM, VAL_BOOL, VAL_NULL } VType;

typedef struct {
    VType type;
    union {
        const char *s; // VAL_STR (view)
        long long n;   // VAL_NUM
        int b;         // VAL_BOOL
        int nil;       // VAL_NULL (pode ser 0)
    } u;
} Value;

typedef struct {
    Value key;   // quase sempre VAL_STR
    Value val;   // qualquer um
} Pair;

typedef struct {
    Pair *pairs;
    size_t count;
    size_t cap;
} Obj;

typedef struct {
    Value *items;
    size_t count;
    size_t cap;
} Arr;
```

> [!info]
> Você **não** precisa espelhar 1:1 a sintaxe. Precisa espelhar **o significado** pra facilitar acesso.

## 8) "Query-first" thinking

Antes de escrever a primeira `struct`, imagine **queries reais**:

```text
1. "Pessoas com idade > 30"
2. "Primeiro elemento"
3. "Buscar por nome exato"
4. "Contar quantas têm nome com mais de 3 letras"
5. "Filtrar apenas nomes"
```

Agora veja como seu modelo facilita isso:

- Com **array contíguo**: `for(i...) if(cond)` é trivial, legível, veloz.
- Com **lista ligada**: precisa `cur = head; while(cur)...` menos previsível pra cache.
- Com **index**: se raríssimo buscar por nome, **não** crie mapa. Linear scan é O(n) e n pequeno.

**Pragmatismo:** Para n < 10k, **linear scan sobre array** quase sempre vence em simplicidade + performance percebida.

## 9) Trade-offs: modelagem prematura vs pragmática

| Abordagem | Prós | Contras | Quando |
|---|---|---|---|
| **"Modelar tudo"** (herança-like, muitos tipos) | Genérico, parece "correto" | Complexo, indireção excessiva, difícil debugar | Raramente vale em C puro pra parserzinho |
| **"Modelar mínimo viável"** (suficiente pras queries) | Legível, direto, fácil de filtrar | Pode faltar extensão depois | **Ideal pra aprender e pra maioria dos casos** |
| **"Data-oriented" (pensar em arrays)** | Ótimo pra cache, fácil iterar | Menos "intuitivo" vindo de OO | Altamente recomendado aqui |
| **"OO-style em C" (vtable, base struct)** | Familiar | Indireção, padding, menos previsível | Quase nunca compensa pra parser simples |

> [!tip]
> **Data-oriented mindset simplificado:** Em vez de "uma pessoa tem nome/idade", pense "**arrays de nomes** e **arrays de idades**". Funciona absurdamente bem pra filtros.

Exemplo data-oriented minimal:

```c
typedef struct {
    const char **names;
    int *ages;
    size_t count;
    size_t cap;
} People;
```

**Vantagem:** Ao filtrar por `age>=30`, você acessa **apenas** o array `ages` (muito mais denso em cache). Ótimo.

**Desvantagem:** Menos coeso. Fácil "desalinhar" arrays se não cuidar.

## 10) Checklist antes de escrever structs

Antes de partir pro lexer:

- [ ] **Liste queries reais.** 2–5 casos concretos que **realmente** vão acontecer.
- [ ] **Defina entidades.** Quais structs são **inevitáveis**?
- [ ] **Defina invariantes.** O que deve ser sempre verdade?
- [ ] **Escolha layout.** Array contíguo > lista ligada (a não ser que haja motivo forte).
- [ ] **Decida view vs owned.** Baseado em **lifetime** dos dados.
- [ ] **Pense em iteração.** "for i in 0..n" deve ser natural e eficiente.
- [ ] **Mantenha enxuto.** Menos campos = menos estado = menos bugs.
- [ ] **Evite generalização precoce.** Só abstraia quando repetir 3x **com variação real**.

## 11) Erro comum: "parsear pra AST perfeita"

Muitos tentam criar uma AST ultra-genérica antes de saber como vão **usar**. Resultado: structs aninhadas, ponteiros pra todo lado, difícil de filtrar.

**Alternativa pragmática:** Crie uma **representação "ready to query"**. Às vezes é a própria AST simplificada. Às vezes é um array plano derivado.

> [!info]
> **Não existe "correto". Existe "adequado ao propósito".** Se seu único propósito é "filtrar linhas que batem critério X", nem precisa de AST completa. Se precisa validar estrutura hierárquica, AST faz sentido.

## 12) Conexão com as próximas notas

- [[02-memory-layout-and-tradeoffs]] – Tradução prática dessas ideias pra memória real (cache, alinhamento, arenas)
- [[03-strings-slices-and-ownership]] – Detalha `StrView` x `StrOwn` com exemplos seguros
- [[05-ast-structuring-without-overengineering]] – Aplica modelagem pra criar AST enxuta
- [[09-filtering-querying-over-structured-data]] – Mostra como tornar seu modelo **bom pra consultar**

## Exercício prático

Pegue esse mini-input:

```json
[
  {"id":1,"user":"alice","active":true},
  {"id":2,"user":"bob","active":false},
  {"id":3,"user":"carol","active":true}
]
```

Responda por escrito (mentalmente vale):

1. **Queries:** Quais 2 filtros você **certamente** faria?
2. **Layout:** Array plano ou lista ligada? Por quê?
3. **Strings:** `user` como view ou owned? Considere que vai processar e talvez imprimir.
4. **Invariantes:** Liste pelo menos 2.
5. **Struct mínima:** Escreva **só** o estritamente necessário.

**Dica:** A resposta certa é a **mais simples que resolve suas queries**.

## Próximo passo

Vá para: [[02-memory-layout-and-tradeoffs]] – entendendo heap vs stack, arrays vs listas, arenas e impacto real em cache.