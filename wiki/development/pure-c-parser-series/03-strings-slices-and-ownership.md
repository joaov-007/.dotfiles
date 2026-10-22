---
title: "Strings, Slices, and Ownership"
tags:
  - c
  - strings
  - memory
  - ownership
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[04-lexing-tokenization-pragmatic]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Strings sem cópias desnecessárias: string views, ownership e lifetime em C."
language: pt-BR
audience: developer
scope: "strings, slices e ownership"
keywords:
  - c
  - strings
  - string view
  - ownership
  - lifetime
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Strings, Slices, and Ownership

> [!summary]
> Em parsers em C, o maior fonte de cópias desnecessárias (e de dangling pointers) são **strings**. A chave é distinguir **string view** (referência + comprimento) de **string owned** (cópia própria). Este capítulo mostra como fazer isso com segurança, zero-copy quando viável e clareza sobre **ownership** e **lifetime**.

## 1) O problema

Quando lemos um arquivo inteiro para um `char *buf`, os lexemas (`"name"`, `"Ana"`) existem **dentro** desse buffer. Se guardarmos apenas `const char*`, economizamos alocação e cópia. Mas se **liberarmos** `buf` antes de usar esses ponteiros, temos **use-after-free**.

**Dilema:** zero-copy vs independência.

## 2) String View (`StrView`)

Um "slice" de string: par (ponteiro + tamanho). Não assume posse.

```c
#include <stddef.h>

typedef struct {
    const char *data;
    size_t len;
} StrView;
```

**Vantagens:**

- **Zero-copy**: nenhum `malloc` + `memcpy`/`strdup`
- **Barato**: 2 * 8 bytes (ptr+len)
- **Eficiente p/ comparações**: pode comparar por `len` + `memcmp` (evita `strlen`)
- **Ideal p/ tokenização**: aponta direto pro input buffer

**Desvantagens:**

- **Lifetime vinculado** ao buffer original
- **Read-only** (`const char*`)
- **Não termina com '\0'** se cortado arbitrariamente (precisa cuidar)
- **Risco** se buffer for realocado/liberado

### Criando um StrView

```c
static inline StrView sv_from(char *s) {
    // cuidado: strlen percorre
    size_t len = 0;
    if (s) while (s[len]) len++;
    return (StrView){ s, len };
}

static inline StrView sv_range(const char *s, size_t start, size_t len) {
    return (StrView){ s + start, len };
}
```

### Comparação segura

```c
#include <string.h>

static inline int sv_eq(StrView a, StrView b) {
    if (a.len != b.len) return 0;
    return memcmp(a.data, b.data, a.len) == 0;
}

// comparar com string literal C (útil em testes)
static inline int sv_eq_cstr(StrView a, const char *c) {
    size_t clen = strlen(c);
    if (a.len != clen) return 0;
    return memcmp(a.data, c, clen) == 0;
}
```

> [!tip]
> **Prefira `memcmp` + `len`** ao invés de `strncmp`/`strcmp` quando possível. Evita depender de `\0` e é explícito.

## 3) Owned String (`StrOwn`)

Cópia alocada. Tem **posse** (ownership). Responsável por liberar.

```c
typedef struct {
    char *data;
    size_t len;
    size_t cap; // opcional, raro em "value"
} StrOwn;
```

Mínimo prático:

```c
typedef struct {
    char *data;
    size_t len;
} StrOwn;
```

### Criando owned a partir de view

```c
#include <stdlib.h>
#include <string.h>

static StrOwn sv_to_own(StrView v) {
    StrOwn o = {0};
    o.len = v.len;
    o.data = malloc(v.len + 1); // +1 se quiser manter '\0'-friendly
    if (!o.data) { o.len = 0; return o; }
    memcpy(o.data, v.data, v.len);
    o.data[v.len] = '\0';
    return o;
}

static void own_free(StrOwn *o) {
    free(o.data);
    o->data = NULL;
    o->len = 0;
}
```

**Por que `+1` e `\0`?** Facilita debug (`printf("%s", o.data)`) e interoperabilidade com APIs C que esperam `const char*` NUL-terminated. Se **nunca** passar pra `printf`/`strcmp` externo, pode omitir — mas adiciona pouco custo.

## 4) Ownership: quem é dono?

**Ownership = "quem deve chamar `free`?"**

Regras simples:

- **Allocator dono:** quem aloca, deve liberar (ou transferir)
- **Transferência clara:** se você passa posse, o antigo dono **não** deve liberar
- **Views não possuem:** nunca chame `free` em `StrView.data`
- **Arena muda tudo:** se usar arena, **não** chama `free` individual. Ownership vira "pertence à arena até reset"

> [!warning]
> **"Borrowing"** é natural aqui. Um `StrView` "empresta" do buffer. Documente isso.

Exemplo inseguro:

```c
char *input = read_file("data.txt"); // dono: input
StrView name = sv_range(input, 10, 3);
// ...
free(input);        // buffer morre
// usar name.data AGORA é use-after-free
```

Exemplo seguro:

```c
char *input = read_file("data.txt");
StrView name = sv_range(input, 10, 3);
// processar usando name ANTES de free
parse_and_query(input, ...);
// só agora libera
free(input);
```

Ou tornar owned se precisa guardar:

```c
char *input = read_file("data.txt");
StrView vname = sv_range(input, 10, 3);
StrOwn oname = sv_to_own(vname); // copia
free(input);                     // ok, oname indep
// usar oname por quanto quiser
own_free(&oname);
```

## 5) Lifetime em prática com parser

Fluxo típico:

```text
1. read_all("file") -> char *buf (owned by main)
2. lex(buf, len) -> gera lista de Token { type, sv: StrView{buf+off,len}, line,col }
3. parse(tokens) -> gera AST/Values referenciando sv OU convertendo p/ owned
4. query/filter sobre AST
5. free AST (arena reset/free) + free tokens + free buf
```

**Regra prática:** Enquanto `buf` vive, **todos StrView apontando pra ele são válidos**.

Se você vai **imprimir resultados depois de fechar arquivo/liberar buf**, **converta pra owned**.

## 6) Quando usar View vs Owned

| Situação | Recomendado | Motivo |
|---|---|---|
| **Tokens durante parsing** | **StrView** | Zero-copy, barato. Morrem junto com parse |
| **Chaves/valores guardados em AST p/ consulta imediata** | **StrView** | Rápido. Usa antes de liberar `buf` |
| **Resultados exportados (salvar em outro lugar)** | **StrOwn** | Independente do input |
| **Comparações internas repetidas** | **StrView** | OK + pode internar depois se quiser |
| **Strings construídas dinamicamente (concat)** | **StrOwn** | Precisa crescer |
| **Debug/logging após liberar buffer** | **StrOwn** | Evita dangling |
| **Passar substrings p/ funções puras** | **StrView** | Limpo, sem posse |

> [!tip]
> **Comece com StrView.** Só mude pra owned quando **realmente** precisar de vida independente.

## 7) Interning (string deduplication)

Se mesmo lexema aparece muitas vezes (`"id"`, `"name"`, chaves repetidas), podemos **internar**: guardar 1 cópia na arena e reapontar views pra ela.

**Ideia:**

- Ter `Arena *intern_arena`
- Buscar em mapa simples (linear scan pequeno) ou hash por `(data,len,hash)`
- Se não existe: `arena_alloc` + `memcpy` + gravar entrada
- Retornar `StrView` apontando pra cópia internada (ou `const char*`)

**Quando vale a pena:**

- Muitas **chaves idênticas** (JSON com muitos objetos iguais)
- Comparações por ponteiro `a.data==b.data` válidas após intern
- Quer reduzir uso de memória

**Quando NÃO vale:**

- Poucos repetidos
- Input pequeno
- Overhead de hash/map supera ganho

> [!info]
> **KISS:** Pra aprender, **não** implemente interning. Só entenda trade-off. Em JSON-like pequeno raramente necessário.

## 8) Evitando armadilhas comuns

### (a) Comparar StrView com `strcmp`

Errado se não NUL-terminated:

```c
StrView v = { "ab", 2 };
if (strcmp(v.data, "abc") == 0) ... // lê além de len? pode funcionar por sorte, perigoso
```

**Correto:** use `sv_eq_cstr` com `strlen`.

### (b) Passar StrView pra função que assume NUL

```c
void foo(const char *s); // assume s[len]=='\0'
StrView v = ...;
foo(v.data); // DANGEROUS se cortado
```

**Solução:** converter pra owned temporário OU exigir NUL-terminated.

### (c) Modificar buffer enquanto views existem

```c
char buf[256] = "hello world";
StrView v = sv_range(buf,0,5); // "hello"
buf[0] = 'X';                  // v.data[0] vira 'X' também
```

Isto é **aliasing** intencional (útil). Mas confuso. Seja explícito: views são **read-only** por contrato (`const char*`).

### (d) Lifetime cruzado entre arenas/buffers

Nunca armazene `StrView` de arena A em estrutura que sobrevive após `arena_reset(A)`.

**Dica:** Nomeie lifetimes: `input_life`, `parse_life`, `result_life`.

## 9) Zero-copy pragmático

**Zero-copy** = evitar cópias de bytes. Não = evitar alocações.

Em lexer:

```c
// Lê arquivo inteiro
size_t n; char *buf = read_all(path,&n);

// Para cada token: só guarda offset+len
Token t = { TOK_IDENT, {buf+start, end-start}, line,col };
```

**Zero cópias de string data.** Ótimo.

Se após parse você descartar `buf`, tudo ok. Se guardar resultados, copie.

## 10) Exemplo prático: Value com strings

Vamos modelar valores JSON-like com clareza.

### Opção A: Views (zero-copy, eficiente)

```c
typedef enum { V_NULL,V_BOOL,V_NUM,V_STR,V_ARR,V_OBJ } VType;

typedef struct Val {
    VType type;
    union {
        int b;
        double num;      // ou long long
        StrView str;     // view pro buf
        struct Arr *arr;
        struct Obj *obj;
    } u;
} Val;
```

**Uso:** parse -> query -> liberar buf + arena. **Rápido.**

### Opção B: Owned (independente)

```c
typedef struct Val {
    VType type;
    union {
        int b;
        double num;
        StrOwn str;      // copia
        struct Arr *arr;
        struct Obj *obj;
    } u;
} Val;
```

**Uso:** parse -> guardar resultado. **Seguro p/ lifetimes longos.**

### Híbrido pragmático

```c
// Durante parse: use views
// Ao "materializar" resultado estável: converta chaves/strings críticas p/ owned
```

> [!info]
> **Não seja purista.** Escolha pelo **caso real**: se você só filtra e imprime, **views** bastam.

## 11) Mini-helpers seguros

Crie helpers pequenos e óbvios:

```c
// sv.h (ideia)
static inline StrView sv_null(void){ return (StrView){NULL,0}; }
static inline int sv_valid(StrView v){ return v.data != NULL; }
static inline int sv_empty(StrView v){ return v.len == 0; }

// trim? cuidado com range
static inline StrView sv_trim(StrView v){
  size_t l=0,r=v.len;
  while(l<r && isspace((unsigned char)v.data[l])) l++;
  while(r>l && isspace((unsigned char)v.data[r-1])) r--;
  return (StrView){v.data+l, r-l};
}
```

> [!tip]
> `isspace` requer `<ctype.h>`. Sempre caste pra `unsigned char`.

## 12) Trade-offs: View vs Owned

| Fator | StrView | StrOwn |
|---|---|---|
| **Cópia** | 0 | 1 (malloc+memcpy) |
| **Velocidade parse** | **Melhor** | Ligeiramente pior |
| **Uso memória** | Mínimo | +bytes por string copiada |
| **Lifetime** | **Frágil** (depende buffer) | **Robusto** |
| **Debug** | Ótimo se buffer intacto | Ótimo sempre |
| **API limpa** | Sim, barato passar | Sim |
| **Risco dangling** | Alto se descuidado | Quase zero |
| **Zero-copy** | **Sim** | Não |
| **Interoperabilidade c/ APIs** | Precisa cuidado c/ NUL | Fácil (`data` NUL-term) |

## 13) Checklist

- [ ] Uso `StrView {const char*, size_t}` p/ substrings do input?
- [ ] Uso `memcmp` ao invés de `strcmp` p/ views?
- [ ] Tenho clareza: **quem aloca = quem libera**?
- [ ] Nunca libero buffer antes de terminar uso de views?
- [ ] Converto pra `StrOwn` só quando preciso de vida longa?
- [ ] Documento lifetimes em funções críticas (`// borrows from buf`)
- [ ] Se uso arena, evito `free` individual e evito manter views pós-reset?
- [ ] Caste `char` p/ `unsigned char` em `ctype.h`?

## 14) Conexão com próximas notas

- [[04-lexing-tokenization-pragmatic]] – Aplica StrView diretamente nos tokens
- [[05-ast-structuring-without-overengineering]] – Guarda strings em AST com lifetime consciente
- [[08-project-organization-in-pure-c]] – Coloca `sv.h`/`sv.c` organizados
- [[11-mini-json-like-parser-with-filters]] – Usa view durante parse, mostra trade-off prático
- [[12-tradeoffs-cheatsheet]] – Resumo view/owned

## Exercício prático

Dado `char buf[] = "{\"name\":\"Ana\",\"age\":25}";`

1. Crie `StrView vkey = sv_range(buf,2,4);` (`"name"`). É válido após `buf` sair de scope? Por quê?
2. Implemente `sv_eq` e teste com literal C via `sv_eq_cstr`.
3. Quando você **obrigatoriamente** usaria `StrOwn` ao invés de `StrView`?
4. Liste **2 riscos** reais de usar views indiscriminadamente.
5. Em um parser que lê arquivo inteiro, processa e sai: **view ou owned** p/ AST strings? Justifique.

## Próximo passo

Vá para: [[04-lexing-tokenization-pragmatic]] – tokenizar com spans, tipos claros e boa DX p/ erros.