---
title: "Project Organization in Pure C"
tags:
  - c
  - project-structure
  - headers
  - modules
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[03-strings-slices-and-ownership]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Organizar um projeto em C puro: arquivos, headers, build e convenções."
language: pt-BR
audience: developer
scope: "organização do projeto em C"
keywords:
  - c
  - projeto
  - headers
  - build
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Project Organization in Pure C

> [!summary]
> Manter projeto enxuto, legível e navegável. Foco em: separar responsabilidades (lexer/ast/parser/arena/sv/err), headers mínimos com include guards, `static` p/ símbolos internos, forward decls, evitar includes circulares e trade-offs entre "monolito" vs "muitos arquivos".

## 1) Objetivo

Criar estrutura simples p/ crescer sem virar bagunça:

```text
mini-json/
├── src/
│   ├── main.c
│   ├── sv.c/h        // string view
│   ├── arena.c/h     // bump arena
│   ├── lex.c/h       // lexer + tokens
│   ├── ast.c/h       // AST + helpers
│   ├── parser.c/h    // recursive descent
│   └── err.c/h       // errors + context
├── build.sh (opcional)
└── README.md (opcional)
```

**KISS:** poucos módulos, responsabilidades claras.

## 2) Princípios

- **Single Responsibility:** cada `.c/.h` faz **uma coisa**
- **Minimal includes:** inclua só o necessário
- **Hide internals:** use `static` em `.c`
- **Opaque where useful:** evite expor structs internas se não precisa
- **Forward declarations:** quebram ciclos, reduzem includes
- **Include guards:** `#ifndef ... #define ... #endif`

## 3) Módulos e responsabilidades

| Módulo | Foco | Observação |
|---|---|---|
| **sv** | `StrView` helpers | Comparação, range, trim, eq_cstr |
| **arena** | Bump allocator | `alloc`, `reset`, `free` |
| **err** | Erros + contexto visual | Mensagens + `print_ctx` |
| **lex** | Tokenização + spans | Gera `TokList` ou stream |
| **ast** | Tipos AST + construtores | `Val/Arr/Obj`, `mk_*` |
| **parser** | RD + validação sintática | Converte tokens->AST |
| **main** | I/O + orquestração | Read all, parse, query, dump |

## 4) Headers: o que expor?

**`.h` deve expor API pública.** Não exponha detalhes de implementação.

Exemplo `sv.h`:

```c
#ifndef SV_H
#define SV_H

#include <stddef.h>

typedef struct { const char *data; size_t len; } StrView;

static inline int sv_eq(StrView a,StrView b){ ... }
StrView sv_trim(StrView v); // pode ser inline ou não

#endif
```

`sv.c` implementa helpers não-inline.

## 5) Include guards vs `#pragma once`

Ambos válidos. `#ifndef` é **portátil** (puro C). `#pragma once` comum mas não 100% universal.

**Recomendado:** `#ifndef` style.

```c
#ifndef MINI_JSON_SV_H
#define MINI_JSON_SV_H
...
#endif
```

Use prefixo único p/ evitar colisões.

## 6) `static` p/ símbolos internos

Tudo que **não** vai ser usado fora do `.c`: `static`.

```c
// lex.c
static void adv(Lexer *l){ ... }
static Token lex_num(Lexer *l){ ... }
static Token mk_tok(...){ ... }
```

**Benefícios:** evita linkage, menor namespace, melhor otimização.

## 7) Forward declarations

Quebra dependências.

`ast.h` sem incluir `sv.h`? Se usa `StrView` por valor, precisa definição completa. Então inclua `sv.h`.

`parser.h` pode forward-declarar `Arena`, `Val`:

```c
// parser.h
struct Arena; struct Val;
typedef struct Parser Parser;
int parse_json(Parser*, struct Arena*, struct Val**);
```

Ou incluir headers mínimos.

**Trade-off:** menos includes = compila um pouco mais rápido, mas menos claro. P/ projeto pequeno, **incluir o necessário** é ok.

## 8) Evitando includes circulares

Cenário comum:

- `ast.h` inclui `sv.h`
- `parser.h` inclui `ast.h` e `lex.h`
- `lex.h` inclui `sv.h` — ok

Circular: `a.h` inclui `b.h`, `b.h` inclui `a.h`? Evitar com forward decl.

**Regra:** inclua **"downward"** (low-level -> high-level). `sv`, `arena`, `err` sem depender de outros.

## 9) Organização por arquivo

### `sv.h` / `sv.c`

```c
// sv.h
#ifndef MJ_SV_H
#define MJ_SV_H
#include <stddef.h>
typedef struct{const char*p;size_t l;} Sv;
int sv_eq(Sv,Sv); int sv_eqc(Sv,const char*); ...
#endif

// sv.c
#include "sv.h"
#include <string.h>
int sv_eq(Sv a,Sv b){ if(a.l!=b.l)return 0; return memcmp(a.p,b.p,a.l)==0; }
```

### `arena.h` / `arena.c`

```c
// arena.h
#ifndef MJ_ARENA_H
#define MJ_ARENA_H
#include <stddef.h>
typedef struct Arena Arena;
Arena* arena_new(size_t cap);
void*  arena_alloc(Arena*,size_t, size_t align);
void   arena_reset(Arena*);
void   arena_free(Arena*);
#endif
```

Oculta campos: `struct Arena { char *base,*cur,*end; };` em `.c`.

**Opaque** evita mexer direto. Bom p/ encapsulamento.

### `err.h` / `err.c`

```c
// err.h
#ifndef MJ_ERR_H
#define MJ_ERR_H
#include <stddef.h>
#include <stdio.h>
typedef struct{ int has; const char*msg; size_t line,col,start,end; } Err;
void err_clear(Err*);
void err_print(FILE*, const Err*, const char*, size_t);
#endif
```

### `lex.h` / `lex.c`

```c
// lex.h
#ifndef MJ_LEX_H
#define MJ_LEX_H
#include "sv.h"
#include "err.h"
typedef enum{...} TokType;
typedef struct{ TokType t; Sv text; size_t line,col,start,end; } Tok;
typedef struct{ Tok*v; size_t n,c; } TokList;
int lex_all(const char*src,size_t len, TokList*, Err*, const char**srcp,size_t*lenp);
void toklist_free(TokList*);
#endif
```

Nota: pode repassar `src/len` p/ erro contextual.

### `ast.h` / `ast.c`

```c
// ast.h
#ifndef MJ_AST_H
#define MJ_AST_H
#include "sv.h"
struct Arr; struct Obj;
typedef enum{ V_NULL,...,V_ERR } VType;
typedef struct{
  VType type;
  union{ int b; double num; Sv str; struct Arr*arr; struct Obj*obj; } u;
} Val;
...
Val vnull(void);
#endif
```

Construtores podem retornar `Val` por valor (barato). Ou alocar via arena — mas `ast.h` não conhece `Arena`. Solução: ter versão arena-aware em `parser` ou incluir `arena.h`.

**Opção limpa:** `ast.c` conhece `arena`, expor `Val* mk_null(Arena*)` em `parser` context? Ou criar `ast_arena.h`.

P/ minimalismo: `parser.c` usa `arena.h` + `ast.h` e faz `mk_*` helpers `static`.

## 10) `main.c`: orquestração mínima

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sv.h"
#include "arena.h"
#include "lex.h"
#include "ast.h"
#include "parser.h"
#include "err.h"

char *read_all(const char *path, size_t *n){
  FILE *f=fopen(path,"rb"); if(!f)return NULL;
  fseek(f,0,SEEK_END); *n=ftell(f); fseek(f,0,SEEK_SET);
  char *b=malloc(*n+1); if(!b){fclose(f);return NULL;}
  fread(b,1,*n,f); b[*n]='\0'; fclose(f); return b;
}

int main(int argc,char**argv){
  if(argc<2){ fprintf(stderr,"usage: %s file.json\n",argv[0]); return 1; }
  size_t n; char *buf=read_all(argv[1],&n);
  if(!buf){ perror("read"); return 1; }
  // lex
  TokList tl={0}; Err e={0};
  if(!lex_all(buf,n,&tl,&e,&buf,&n)){ err_print(stderr,&e,buf,n); toklist_free(&tl); free(buf); return 1; }
  // parse
  Arena *a=arena_new(1<<20);
  Parser p={tl.v,tl.n,0,e,buf,n};
  Val *root=NULL;
  if(!parse_json(&p,a,&root)){ err_print(stderr,&p.err,buf,n); toklist_free(&tl); arena_free(a); free(buf); return 1; }
  // use root: dump/filter
  dump_val(root,0);
  // cleanup
  toklist_free(&tl); arena_free(a); free(buf);
  return 0;
}
```

## 11) Build: simples e direto

`build.sh` mínimo:

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
cc -Wall -Wextra -std=c99 -O2 -g -o build/mini-json src/*.c
```

Ou `make` trivial:

```makefile
CC=cc
CFLAGS=-Wall -Wextra -std=c99 -O2 -g
SRC=$(wildcard src/*.c)
OBJ=$(SRC:.c=.o)

mini-json: $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f src/*.o mini-json
```

**Ambos válidos.** Shell script é suficiente p/ aprender.

## 12) Includes: ordem e visibilidade

Em `.c`:

```c
// main.c: includes do sistema primeiro? ou próprios
#include <stdio.h>
#include <stdlib.h>
...
#include "sv.h"
#include "arena.h"
...
```

**Convenção comum:** std headers, depois project headers.

Em `.h`, **não** inclua `.c`. Nunca.

## 13) Dependências mínimas

- Evite `#include <windows.h>` etc (puro POSIX/Linux ok)
- Use só: `<stddef.h>`, `<stdint.h>`, `<stdlib.h>`, `<string.h>`, `<stdio.h>`, `<ctype.h>`, `<errno.h>` se precisar
- Menos headers = menos acoplamento

## 14) Trade-offs: monolito vs multi-arquivo

| Critério | 1–2 arquivos | 6–8 módulos | Veredito |
|---|---|---|---|
| **Prototipagem** | **Rápido** | Mais setup | Monolito inicial |
| **Legibilidade** | Cai ao crescer | **Clara** | Multi p/ >300–400 linhas |
| **Navegação** | Difícil | **Fácil** | Multi |
| **Compilação** | 1 objeto | Incremental | Multi vence após mudanças |
| **Testes** | Menos isolado | **Mais testável** | Multi |
| **Didático** | Menos "modular" | **Ensina organização** | **Multi aqui** |

**Recomendado p/ esta série:** **multi-módulo enxuto** (6–8 arquivos). Ensina lições reais sem exagero.

## 15) Opaque structs: quando usar?

Expor `struct Arena` em `.h` permite stack? Ou melhor ocultar.

**Expor campos (menos comum):**

```c
// arena.h
typedef struct{ char*b,*c,*e; } Arena; // permite Arena a; arena_init(&a,...)
```

**Opaque + new/free:**

```c
// arena.h
typedef struct Arena Arena;
Arena* arena_new(size_t);
```

**Trade-off:**

- **Exposto:** stack allocation possível, menos heap
- **Opaque:** encapsulamento, pode mudar impl sem quebrar API

**P/ didático:** **opaque** é limpo. `arena_new` simples.

## 16) Const-correctness

Use `const` onde não modifica:

```c
int sv_eq(const StrView a, const StrView b);
void err_print(FILE*, const Err*, const char*, const size_t len); // len const
void dump_val(const Val *v, int indent);
```

Passar ponteiros `const` evita bugs e comunica intenção.

## 17) Checklist organização

- [ ] Cada módulo tem `foo.h` + `foo.c`
- [ ] Include guards presentes
- [ ] `static` em símbolos privados `.c`
- [ ] Headers expõem **só** API necessária
- [ ] Sem includes circulares
- [ ] Forward decls usados quando evitam include
- [ ] `main.c` só orquestra
- [ ] Const-correctness aplicado
- [ ] Nomes curtos e consistentes
- [ ] Build simples funciona

## 18) Exemplo estrutura mínima testável

```text
mini-json/
├── src/sv.h
├── src/sv.c
├── src/arena.h
├── src/arena.c
├── src/err.h
├── src/err.c
├── src/lex.h
├── src/lex.c
├── src/ast.h
├── src/ast.c
├── src/parser.h
├── src/parser.c
└── src/main.c
```

Compila com `cc src/*.c -o mini-json`.

## 19) Conexão com próximas notas

- [[09-filtering-querying-over-structured-data]] – Usar API organizada p/ filtrar
- [[10-performance-measurement-without-myths]] – Medir com build limpo
- [[11-mini-json-like-parser-with-filters]] – Código completo nesta estrutura
- [[12-tradeoffs-cheatsheet]] – Resumo

## Exercício prático

1. Crie `sv.h/sv.c` com `sv_eq`, `sv_eqc`
2. Crie `arena.h/c` com bump minimal
3. Pense: por que `static` evita conflitos?
4. Liste **2 vantagens** de separar `lex` e `parser`
5. Quando **justificaria** juntar tudo num arquivo?

## Próximo passo

Vá para: [[09-filtering-querying-over-structured-data]] – iteradores, predicados, views e data-oriented thinking p/ consultar dados eficientemente.