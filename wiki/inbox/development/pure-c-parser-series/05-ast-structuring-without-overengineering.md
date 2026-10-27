---
title: "AST Structuring Without Overengineering"
tags:
  - c
  - ast
  - parser
  - data-structures
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[04-lexing-tokenization-pragmatic]]"
  - "[[06-parsing-recursive-descent-tradeoffs]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Estruturar a AST com enum+union (tagged union) sem over-engineering."
language: pt-BR
audience: developer
scope: AST e tagged unions
keywords:
  - c
  - ast
  - tagged union
  - union
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# AST Structuring Without Overengineering

> [!summary]
> **AST (Abstract Syntax Tree)** é a representação estruturada do input. Em C puro, o segredo é manter enxuta: use **tagged union** (`enum + union`), prefira **arrays contíguos** ([[02-memory-layout-and-tradeoffs]]), e aloque em **arena**. Não espelhe gramática 1:1 — modele pra **usar** depois (filtrar/consultar).

## 1) AST vs Parse Tree

- **Parse Tree (Concrete):** espelha tokens + regras (muito verboso)
- **AST (Abstract):** só o essencial semântico. Menor, mais prático

**Objetivo aqui:** AST minimalista e "query-friendly".

## 2) Comece pelo "valor", não pela "classe"

Pra JSON-like, tudo é **Value**: null, bool, number, string, array, object.

Tagged union é perfeita:

```c
typedef enum {
    VAL_NULL,
    VAL_BOOL,
    VAL_NUM,
    VAL_STR,
    VAL_ARR,
    VAL_OBJ
} VType;
```

## 3) Modelagem enxuta (JSON-like)

### Valores

Usando `StrView` ([[03-strings-slices-and-ownership]]):

```c
struct Arr;
struct Obj;

typedef struct {
    VType type;
    union {
        int b;           // VAL_BOOL
        double num;      // VAL_NUM
        StrView str;     // VAL_STR
        struct Arr *arr; // VAL_ARR
        struct Obj *obj; // VAL_OBJ
    } u;
} Val;
```

> [!tip]
> Forward decls evitam include circular entre `Val`, `Arr`, `Obj`.

### Array

```c
struct Arr {
    Val *items;
    size_t count;
    size_t cap;
};
```

**Vantagem:** array contíguo -> iteração/cache-friendly. Ótimo p/ filtros.

### Object (chave-valor)

```c
typedef struct {
    StrView key;
    Val val;
} Pair;

struct Obj {
    Pair *pairs;
    size_t count;
    size_t cap;
};
```

**Por que `Pair` separado?** Natural. Facilita iterar chaves/valores.

**Alternativa SOA?** [[02-memory-layout-and-tradeoffs]]: `StrView *keys + Val *vals`. Menos coeso, mas melhor densidade se filtrar só por chaves. Pra didático, **AOS (`Pair[]`) é mais legível**.

## 4) Alocação em Arena

Evitar `malloc` por nó. Use bump arena ([[02-memory-layout-and-tradeoffs]]).

```c
#include <stddef.h>

typedef struct {
    char *base, *cur, *end;
} Arena;

static void *arena_alloc(Arena *a, size_t n, size_t align) {
    // alinhamento simples
    uintptr_t p = (uintptr_t)a->cur;
    uintptr_t ap = (p + (align-1)) & ~(align-1);
    ptrdiff_t need = (ptrdiff_t)ap + (ptrdiff_t)n - (ptrdiff_t)a->cur;
    if (need > a->end-a->cur) return NULL;
    a->cur = (char*)ap + n;
    return (void*)ap;
}
```

Uso:

```c
Val *mk_null(Arena *a){ Val *v=arena_alloc(a,sizeof(Val),8); v->type=VAL_NULL; return v; }
Arr *mk_arr(Arena *a){ Arr *x=arena_alloc(a,sizeof(Arr),8); *x=(Arr){0}; return x; }
```

> [!info]
> Com arena, **não** chamamos `free` por `Val`. Libera-se bloco inteiro ao final.

## 5) Crescimento dinâmico (arrays)

`Arr.items` e `Obj.pairs` crescem. Use `cap/count` estilo C99+ prático.

```c
static void arr_push(Arr *arr, Val v, Arena *a) {
    (void)a; // se usar arena externa p/ items? ou alocar items em arena
    if (arr->count>=arr->cap){
        size_t nc = arr->cap? arr->cap*2:8;
        // ATENÇÃO: se items alocado em arena, realloc não é trivial
        Val *ni = realloc(arr->items, nc*sizeof(Val));
        arr->items=ni; arr->cap=nc;
    }
    arr->items[arr->count++]=v;
}
```

**Cuidado com arena + `realloc`:**

- Se `items` veio de `arena_alloc`, **não use `realloc`** (pode mover). Duas opções:
  1. **Pre-alocar** com cap razoável via arena: `items = arena_alloc(a,nc*sizeof(Val),8)`
  2. **Usar heap** p/ arrays dinâmicos que crescem muito (mais flexível)
  3. **Usar "arena scratch" + copiar** (menos comum)

**Pragmatismo p/ didático:** `Arr` com `items` alocado via `malloc/realloc` **OU** tudo via arena mas estimar cap inicial. Pra JSON pequeno, estimar funciona.

> [!tip]
> **Mix simples:** aloque **nós AST** (`Val/Arr/Obj/Pair`) em **arena**. Aloque **arrays mutáveis** (`items/pairs`) com `malloc/realloc` (fácil crescer). Ambos liberados no fim: `free` arrays + `arena_free` bloco.

## 6) Tagged union: acesso seguro

Sempre verifique `type` antes de acessar `u`.

```c
if (v->type == VAL_STR) {
    StrView s = v->u.str;
    // usa s
} else if (v->type == VAL_NUM) {
    double n = v->u.num;
    // ...
}
```

**Anti-padrão:** acessar `u.str` sem checar `type` -> UB em leitura.

> [!warning]
> Tagged union só é seguro se **invariante**: `type` corresponde exatamente ao campo usado.

## 7) Representação "flat" vs "deeply nested"

AST JSON é naturalmente **hierárquica** (aninhada). Isso é correto. O problema é **excesso de indireção**.

Exemplos aceitáveis:

- `Val` aponta `Arr*` aponta `Val*[]` — ok
- Evitar `Val***` etc
- Evitar structs com 6 níveis de ponteiros sem motivo

**Trade-off:** hierarquia clara vs localidade. Aceitável p/ maioria dos JSONs.

## 8) "AST-friendly" vs "Query-friendly"

**AST-friendly:** reflete gramática (facilita debug/parser)

**Query-friendly:** facilita filtros ([[09-filtering-querying-over-structured-data]])

Exemplo: queremos filtrar objetos com `age>30`.

Com modelo acima: iteramos `obj->pairs` procurando chave `"age"`, depois comparamos `val.u.num`.

Funciona e é legível.

**Alternativa mais query-friendly (SOA):** guardar campos indexados — mas complica parser.

> [!tip]
> **Comece com AST "natural".** Só otimize p/ query se perceber gargalo real ([[10-performance-measurement-without-myths]]).

## 9) Minimal vs Extensível

**Minimal (recomendado):**

- Só o necessário p/ JSON-like
- Poucos tipos
- Sem visitor genérico
- Sem vtable

**Extensível (overkill cedo):**

- `Node base` + `kind`
- Funções `accept`, `visit`
- 10+ "node kinds"

**Trade-off:** extensibilidade teórica vs complexidade real. Em C, **tagged union + switch** é direto, performático e fácil debugar.

## 10) Exemplo concreto: pequeno subset

Vamos modelar subset: `{ "name":"Ana", "items":[1, true, null] }`

Estrutura mental:

```text
Obj
  Pair("name", Val(STR,"Ana"))
  Pair("items", Val(ARR))
                -> Arr.items = [ Val(NUM,1), Val(BOOL,1), Val(NULL) ]
```

Em memória (ideia):

- `Obj` em arena/heap
- `pairs[]` contíguo
- `Arr` + `items[]` contíguo
- `StrView` aponta p/ buffer original

**Localidade razoável** se alocado junto.

## 11) Helpers pra construir AST

Mantenha construtores simples:

```c
static Val v_null(void){ Val v={VAL_NULL,{0}}; return v; }
static Val v_bool(int b){ Val v={VAL_BOOL,{.b=b}}; return v; }
static Val v_num(double n){ Val v={VAL_NUM,{.num=n}}; return v; }
static Val v_str(StrView s){ Val v={VAL_STR,{.str=s}}; return v; }
static Val v_arr(Arr *a){ Val v={VAL_ARR,{.arr=a}}; return v; }
static Val v_obj(Obj *o){ Val v={VAL_OBJ,{.obj=o}}; return v; }
```

Retornar por valor (`Val`) é barato (union+enum ~ (8+8)=16 bytes máx, tipicamente menos).

## 12) Evitando ciclos e ownership AST

AST JSON não tem ciclos. Ótimo. Ownership: se tudo em **arena**, "dono" é arena.

**Regra:** funções que constroem recebem `Arena*` (ou contexto). Funções que consomem recebem `const Val*`/`const Arr*`.

## 13) Debugging AST

Facilite inspeção:

- Função `dump_val(const Val*, int indent)` recursiva p/ print
- Validadores simples (type checks)
- Ao debugar gdb: `print v.type; print v.u.str`

> [!warning]
> Dump recursivo funciona bem pra JSON pequeno/médio. Se muito profundo, stack. Mas didático ok.

## 14) Trade-offs: struct vs ponteiros

| Decisão | Prós | Contras |
|---|---|---|
| **`Val` por valor em arrays** (`Val* items` ou `Val items[]`) | Menor indireção, cópia barata | `Val` tem union (16 bytes) — ok |
| **`Val*` sempre** | Uniforme | +indireção |
| **`Pair` por valor** | Contíguo | Ok |
| **`Arr/Obj` heap/arena** | Referenciados por múltiplos? raro | Indireção necessária |

**Recomendado:** `Arr` e `Obj` como **structs alocados** (`Arr*`). `Val` **por valor** dentro de arrays.

## 15) Anti-patterns a evitar

- **Node "base" genérico**: `struct Node { int kind; void *data; }` — obscurece tipos, casts everywhere
- **AST espelhando tokens 1:1**: inclui `COMMA`, `COLON`, `LBRACE` — desnecessário
- **Listas ligadas p/ items/pairs**: mata localidade ([[02-memory-layout-and-tradeoffs]])
- **`strdup` prematuro**: use `StrView` primeiro
- **Over-abstração:** `visitor`, `iterator` complexo antes de precisar filtrar simples
- **Múltiplos owners:** confunde lifetimes

## 16) Checklist

- [ ] Usei **tagged union** (`enum VType + union`)?
- [ ] `Arr.items` e `Obj.pairs` são **arrays contíguos**?
- [ ] `Val` acessado **só após checar type**?
- [ ] Evitei espelhar símbolos sintáticos na AST?
- [ ] Decidi **arena vs heap** conscientemente?
- [ ] Forward decls pra evitar ciclos?
- [ ] Construtores retornam `Val` ou alocam via arena?
- [ ] Modelo facilita **iterações sequenciais**?
- [ ] Mantive **mínimo viável** pras queries planejadas ([[01-thinking-about-data-before-parsing]])?

## 17) Exemplo minimal completo (visão)

```c
#include <stddef.h>
#include "sv.h" // StrView

typedef enum { V_NULL,V_BOOL,V_NUM,V_STR,V_ARR,V_OBJ } VType;

struct Arr;
struct Obj;

typedef struct {
    VType type;
    union {
        int b;
        double num;
        StrView str;
        struct Arr *arr;
        struct Obj *obj;
    } u;
} Val;

typedef struct {
    StrView key;
    Val val;
} Pair;

struct Arr {
    Val *items;
    size_t count, cap;
};

struct Obj {
    Pair *pairs;
    size_t count, cap;
};
```

**Simples, claro, performático o suficiente.**

## 18) Conexão com próximas notas

- [[06-parsing-recursive-descent-tradeoffs]] – Parser transforma tokens nessa AST
- [[08-project-organization-in-pure-c]] – Organizar em `ast.h/ast.c`
- [[09-filtering-querying-over-structured-data]] – Consultar essa estrutura eficientemente
- [[11-mini-json-like-parser-with-filters]] – Implementação real
- [[12-tradeoffs-cheatsheet]] – Resumo AST choices

## Exercício prático

1. Desenhe (mental) AST p/ `[{"id":1,"ok":true}, null]`
2. Por que **array contíguo** em `Arr/Obj` vs lista ligada?
3. Liste **2 vantagens** de tagged union vs `struct { int kind; void* data; }`
4. Quando **justificaria** SOA em vez de `Pair[]`?
5. Projete `mk_arr/mk_obj` recebendo `Arena*`. O que alocar onde?

## Próximo passo

Vá para: [[06-parsing-recursive-descent-tradeoffs]] – implementar recursive descent com lookahead, precedência e trade-offs.