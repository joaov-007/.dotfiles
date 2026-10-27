---
title: "Memory Layout and Trade-offs"
tags:
  - c
  - memory
  - performance
  - data-structures
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[01-thinking-about-data-before-parsing]]"
  - "[[03-strings-slices-and-ownership]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[10-performance-measurement-without-myths]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Layout de memória e trade-offs: array contíguo x lista ligada, arena x malloc por nó, stack x heap."
language: pt-BR
audience: developer
scope: "layout de memória e trade-offs"
keywords:
  - c
  - "memória"
  - arena
  - malloc
  - layout
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Memory Layout and Trade-offs

> [!summary]
> Performance em C puro, na prática, tem muito mais a ver com **localidade de cache (spatial/temporal)** do que com micro-otimizações. O objetivo aqui é entender como organizar dados em memória para favorecer acessos sequenciais, escolher entre stack/heap, array/lista, e quando usar **arenas** — sempre com trade-offs explícitos.

## 1) O que realmente impacta performance

Em CPUs modernas, acessar memória RAM é **ordens de magnitude** mais lento que acessar registradores/L1. O cache tenta compensar carregando **linhas de cache** (geralmente 64 bytes).

**Leis práticas:**

1. **Acesso sequencial contíguo = ótimo** (prefetch funciona bem)
2. **Acesso saltado (pointer chasing) = ruim** (muitas misses de cache)
3. **Menos alocações = menos fragmentação + menos overhead**
4. **Layout previsível = melhor pro branch predictor + cache**

> [!tip]
> **Regra de ouro:** Prefira **dados contíguos em arrays** sempre que iterar na maioria das vezes.

## 2) Stack vs Heap

| Aspecto | Stack | Heap (`malloc/free`) |
|---|---|---|
| **Velocidade de alocação** | Extremamente rápida (AP + offset) | Mais lenta (gerenciador, busca blocos, metadata) |
| **Liberacão** | Automática (scope) | Manual (`free`) — fácil esquecer |
| **Tamanho** | Limitado (thread stack, KB–MB) | Muito maior (limitado por RAM/virtual) |
| **Lifetime** | Fixo ao escopo | Arbitrário |
| **Fragmentação** | Zero | Possível com muitas alocs pequenas/mistas |
| **Cache/localidade** | Ótimo p/ dados temporários pequenos | Variável (depende de alocador + ordem) |
| **Risco** | Stack overflow (recursão profunda) | Leaks, use-after-free, double-free |

### Quando usar cada um

- **Stack:** temporários, buffers pequenos, structs locais, arrays fixos conhecidos. Ideal p/ lexer/token temporários, não pra AST inteira grande.
- **Heap:** dados que sobrevivem ao escopo, tamanho dinâmico desconhecido no compile-time (tokens/AST/valores).

> [!warning]
> **Recursive descent + input grande?** Cuidado com recursão profunda (expressões aninhadas). Stack pode estourar. Em C, prefira **limite prático** ou considere iterative se árvore muito profunda (raro em JSON-like). Para aprendizado, RD é perfeito.

## 3) Arrays contíguos vs Listas ligadas

É a escolha mais importante p/ **filtragem/iteração**.

### Array contíguo (AOS: Array of Structs)

```c
typedef struct { int id; double val; } Item;
Item *arr = malloc(n * sizeof(Item));
for (i=0; i<n; i++) if (arr[i].val > 10.0) ...  // stride = sizeof(Item)
```

- **Layout:** `[Item0][Item1][Item2]...` byte-a-byte contíguo
- **Acesso sequencial:** **excelente** (1 linha de cache carrega vários itens)
- **Indexação:** `O(1)`, `arr[i]` = base + i*sizeof
- **Inserção no meio:** O(n) (move elementos)
- **Remoção no meio:** O(n)
- **Append:** O(1) amortizado (com capacity)

### Lista ligada (Linked List)

```c
typedef struct Node { int id; double val; struct Node *next; } Node;
Node *head;
for (Node *p=head; p; p=p->next) if (p->val>10.0)... // pointer chasing
```

- **Layout:** Nós espalhados no heap (fragmentados)
- **Acesso sequencial:** **ruim** (segue ponteiros aleatórios no heap)
- **Indexação por i:** O(n)
- **Inserção/remoção meio:** O(1) se tem ponteiro
- **Append fim (tail):** O(1)
- **Overhead:** +1 ponteiro por nó (8 bytes x86_64) + padding

### Comparação prática (iteração 90% do tempo)

| Métrica | Array contíguo | Lista ligada | Vencedor |
|---|---|---|---|
| **Localidade de cache** | Muito alta | Baixa–muito baixa | **Array** |
| **Throughput (scan)** | Muito melhor | Pior (10–50x+ em casos reais) | **Array** |
| **Memória útil/overhead** | Menor | Maior (ponteiros + alinhamento) | **Array** |
| **Flex p/ inserir/remover meio** | Ruim | Bom | **Lista** |
| **Previsibilidade (prefetch)** | Excelente | Ruim | **Array** |

> [!warning]
> Para **parsear + filtrar/consultar**, 99% das vezes **array contíguo vence**. Só use lista ligada se você **insere/remove no meio constantemente** e **nunca itera tudo sequencialmente**.

## 4) AOS vs SOA (Array of Structs vs Struct of Arrays)

Mudar organização por **campos** ao invés de por **registros**.

### AOS (padrão)

```c
typedef struct { int id; float x,y,z; } P;
P pts[1024];
for(i=0;i<n;i++){ if(pts[i].x>0.f) ... } // lê id,x,y,z juntos (desperdiça cache)
```

Lê struct inteira (com `id,y,z`) só pra filtrar por `x`.

### SOA (Data-Oriented)

```c
typedef struct {
    int   *ids;
    float *xs,*ys,*zs;
    size_t n,cap;
} Pts;
for(i=0;i<n;i++){ if(pts.xs[i]>0.f) ... } // lê APENAS array xs (denso)
```

**Vantagem:** Filtrar por **um campo** acessa array contíguo **puramente daquele campo** (melhor densidade de cache). Ótimo p/ filtros seletivos.

**Desvantagem:** Menos coeso (fácil desalinhar). Acesso "registro completo" (`id,x,y,z` do mesmo i) dá 4 acessos separados (ainda pode ser ok com bom layout).

| Caso de uso | Recomendado | Explicação |
|---|---|---|
| **Iterar registro completo (ler tudo)** | **AOS** | Menos ponteiros/offsets, mais natural |
| **Filtrar por 1–2 campos com seletividade alta** | **SOA** | Evita "carregar lixo" no cache line |
| **n pequeno (centenas)** | **AOS** | Diferença irrelevante, simplicidade vence |
| **n grande + filtros específicos** | **SOA** | Pode dar ganho real (10–20%+) |

> [!tip]
> Pra um **parser + filtros genéricos**, **AOS (array de structs)** é muito mais legível e seguro. SOA vale a pena só com **medição real** ([[10-performance-measurement-without-myths]]).

## 5) Alinhamento, padding e tamanho

Structs têm **padding** p/ alinhamento de campos (evita acessos não alinhados, mais rápidos/seguros).

Exemplo ilustrativo (x86_64, típico):

```c
typedef struct {
    char c;  // 1
    // +7 pad
    int  i;  // 4 (alinha 4)
    char d;  // 1
    // +3 pad -> total 16
} A;
```

**Consequência:** Array de `A[1000]` tem buracos. Isso **desperdiça cache** e aumenta memória.

### Reduzir padding

Ordem campos por **tamanho decrescente** (maiores primeiro):

```c
typedef struct {
    int  i;  // 8? ou 4, alinhar
    char c;
    char d;
    // +2 pad (menor)
} A_optimized;
```

Diferença pequena em structs pequenos, pode somar com milhares.

> [!info]
> Otimização de padding é **baixa prioridade**. Faça só se medir e for relevante. Clareza > salvar 3 bytes.

## 6) Arenas (Memory Arenas) — chave p/ parsers

Parser gera **muitos** nós (tokens, AST nodes, strings owned). Fazer `malloc/free` por nó é caro e fragmenta.

**Arena** = bloco grande alocado uma vez, você faz **bump allocation** (apenas avança um ponteiro). Libera **tudo de uma vez** no fim.

### Bump arena (linear allocator)

```c
typedef struct {
    char *base;
    char *cur;
    char *end;
    size_t cap;
} Arena;

static void *arena_alloc(Arena *a, size_t n) {
    size_t rem = (size_t)(a->end - a->cur);
    if (n > rem) return NULL; // crescer depois
    void *p = a->cur;
    a->cur += n;
    // alinhar opcional p/ 8/16
    return p;
}

static void arena_reset(Arena *a) {
    a->cur = a->base; // tudo "liberado"
}
```

**Uso típico em parser:**

```c
Arena tok_arena, ast_arena, str_arena;
arena_init(&ast_arena, 1<<20); // 1MB
Node *n = arena_alloc(&ast_arena, sizeof(Node));
```

No fim: `arena_free(&ast_arena)` (libera bloco inteiro) ou `arena_reset` (reutiliza).

### Prós/Contras Arena

| Prós | Contras |
|---|---|---|
| **Muito rápido** (só `cur += n`, sem busca/free por objeto) | **Não libera objetos individuais** (só reset/tudo) |
| **Baixo overhead de metadata** | Precisa estimar/tamanho inicial ou crescer |
| **Menos fragmentação** | Crescimento com `realloc` pode copiar (cuidado com ponteiros) |
| **Cache-friendly (bloco contíguo)** | Dangling se resetar e ainda usar ponteiros antigos |
| **Perfeito p/ parse batch (input -> AST -> usar -> descartar tudo)** | Não indicado p/ lifetimes muito heterogêneos/longos |

> [!tip]
> **Parser é caso de uso perfeito p/ arena.** Você parseia um buffer, consome AST, depois joga tudo fora. Reset é O(1).

### Dicas práticas de arena

1. **Separe arenas por lifetime.** Ex: `tokens_arena` (curto), `ast_arena` (médio), `strings_owned_arena` (até fim). Evita misturar lifetimes.
2. **Alinhamento.** Faça `cur = ALIGN_UP(cur, align)` (8 ou 16 bytes) p/ evitar unaligned acessos.
3. **Crescimento.** Comece com 256KB–1MB. Se estourar, `realloc` + atualizar **base/end/cur** (mas **ponteiros absolutos** dentro da arena quebram). Solução: prefira **offsets** (`base + off`) ou crescer com cuidado.
4. **Reset vs free.** `reset` reutiliza bloco (bom p/ múltiplos parses). `free` devolve RAM.

### Arena simples com alinhamento

```c
#include <stdint.h>
#include <stddef.h>

static inline size_t align_up(size_t v, size_t a) {
    return (v + (a-1)) & ~(a-1);
}

void *arena_alloc_aligned(Arena *a, size_t n, size_t align) {
    size_t p = (size_t)a->cur;
    size_t ap = align_up(p, align);
    ptrdiff_t need = (ptrdiff_t)ap + (ptrdiff_t)n - (ptrdiff_t)a->cur;
    if (need > (ptrdiff_t)(a->end - a->cur)) return NULL;
    a->cur = (char *)ap + n;
    return (void *)ap;
}
```

Padrão: alinhar a 8 bytes (x86_64 pointers/long long).

## 7) Outras estratégias de alocação

| Estratégia | Veloc | Fragment | Libera indiv. | Uso |
|---|---|---|---|---|
| `malloc/free` por objeto | Baixa–Média | Média–Alta | **Sim** | Geral |
| **Bump Arena** | **Muito alta** | Baixa | **Não** (bulk) | Batch, parsers, AST, temp |
| **Pool allocator** (slab p/ tamanho fixo) | Alta | Baixa | **Sim** | Muitos objetos mesmo tamanho (tokens iguais) |
| **Region/arena com mark-release** | Alta | Baixa | Parcial (até mark) | Hierárquico (scopes) |
| **Buddy allocator** | Média | Baixa | Sim | Sistemas |
| **Realloc em array + cap** | Alta | Baixa | Bulk | Arrays dinâmicos (`Vec`-like) |

**Recomendação p/ parser:** **Bump arena** + **arrays com `cap/count`** (growth exponencial). Combinação simples e eficiente.

## 8) Layout e Cache: exemplos práticos

### Ex. 1: Percorrer struct array (bom)

```c
struct V { float x,y,z; };
struct V *v = ...; // contíguo
for(i=0;i<n;i++){ s += v[i].x + v[i].y + v[i].z; } // stride 12, linear
```

Cada linha de cache (64B) carrega ~5 structs. **Ótimo**.

### Ex. 2: Array de ponteiros (ruim)

```c
struct V **vp = ...;
for(i=0;i<n;i++){ s += vp[i]->x + vp[i]->y + vp[i]->z; } // vp[i] ok, -> salta
```

`vp` é contíguo, mas `vp[i]` aponta pra qualquer lugar (heap espalhado). **Pointer chasing** + misses.

### Ex. 3: Filtrar seletivo com SOA (ótimo p/ densidade)

```c
float *xs = ...; // 4*n bytes densos
for(i=0;i<m;i++){ if(xs[i]>t) process(i); } // só lê xs
```

Se seletividade 10%, carrega 10x menos dados úteis por linha.

> [!info]
> **Densidade de dados úteis** (useful bytes / cache line bytes) importa muito em scans pesados.

## 9) Trade-offs: clareza vs performance

Nunca escolha "mais rápido" às cegas.

| Escolha | +Performance | +Clareza/DX | +Segurança | Veredito |
|---|---|---|---|---|
| **Array contíguo** | Alto | Alto | Alto | **Recomendada (default)** |
| **Lista ligada** | Baixo (scan) | Médio | Médio | Só p/ inserts no meio constantes |
| **AOS** | Bom | **Muito bom** | Alto | **Default p/ parser** |
| **SOA** | Melhor (filtros) | Menor | Médio | Só com prova por medição |
| **malloc/free por nó** | Baixo | Bom | Médio | Evite p/ milhares de nós |
| **Bump Arena** | **Muito alto** | Bom | Alto (bulk) | **Altamente recomendado p/ parser** |
| **Owned strings** | Neutro–pior | Alto (seguro) | **Alto** | Depende lifetime |
| **String views** | **Melhor** | Bom | Baixo (lifetime) | Ótimo se lifetime claro |

## 10) Diretrizes práticas (regra 80/20)

- **Default:** `T *arr + count + cap` (array dinâmico estilo `Vec`). Crescimento exponencial (`cap = cap*2 + 8`).
- **Parser:** **Arena única ou 2–3 arenas** por lifetimes. Bump allocation.
- **Iteração:** **sempre sequencial** quando possível (`for i`).
- **Evite ponteiros aninhados desnecessários.** 1–2 níveis ok, 3+ costuma complicar + piora cache.
- **Arrays > ponteiros espalhados** para dados lidos juntos.
- **Não otimize padding/soa cedo.** Mantenha **legível primeiro**.
- **Lifetime explícito.** Documente: "AST vive até fim de `parse_and_query()`".

## 11) Checklist prático

- [ ] Uso **array contíguo** p/ listas que serão iteradas/filtradas?
- [ ] Evitei lista ligada pra "ler tudo"?
- [ ] Considerei **arena** se > 10^3 alocações pequenas?
- [ ] Separei lifetimes (tokens vs AST vs strings)?
- [ ] Prefiro **acesso sequencial** vs saltos?
- [ ] Ordenei structs p/ reduzir padding (só se relevante)?
- [ ] Escolhi **AOS vs SOA** com base em **queries reais** ([[01-thinking-about-data-before-parsing]])?
- [ ] Tenho plano claro p/ **liberação** (reset/free)?

## 12) Conexão com próximas notas

- [[03-strings-slices-and-ownership]] – Aplica lifetimes (views vs owned) com segurança
- [[05-ast-structuring-without-overengineering]] – Coloca nós em arena com layout enxuto
- [[09-filtering-querying-over-structured-data]] – Explora SOA/AOS + iteração cache-friendly
- [[10-performance-measurement-without-myths]] – Mede para validar essas escolhas
- [[11-mini-json-like-parser-with-filters]] – Implementa arena + arrays práticos

## Exercício prático

Input: 10.000 registros `{id,x,y}`. Queries: (a) média de `x` onde `y>5.0`, (b) filtrar todos com `x<0`.

1. Modele com **AOS** (array de structs). Como fica loop?
2. Modele com **SOA** (3 arrays). Qual lê menos bytes por iteração em (a)?
3. Liste **1 prós + 1 contras** de arena vs `malloc` por registro.
4. Por que **lista ligada** seria ruim aqui? Cite cache.

**Resposta esperada:** Foque em **localidade + densidade de dados úteis**.

## Próximo passo

Vá para: [[03-strings-slices-and-ownership]] – string views, zero-copy, ownership e como evitar dangling pointers com segurança.