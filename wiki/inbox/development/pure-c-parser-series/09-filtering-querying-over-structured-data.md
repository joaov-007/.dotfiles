---
title: "Filtering & Querying Over Structured Data"
tags:
  - c
  - filtering
  - iteration
  - data-oriented
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[10-performance-measurement-without-myths]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Filtrar e consultar dados estruturados com APIs simples e previsíveis."
language: pt-BR
audience: developer
scope: filtragem e consulta de dados
keywords:
  - c
  - filtragem
  - consulta
  - dados
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Filtering & Querying Over Structured Data

> [!summary]
> Parsear é só metade. **Usar** os dados é o motivo real. Foco em: iterar eficientemente sobre arrays contíguos, filtrar com predicados, criar "views" (subconjuntos), evitar cópias, pensar data-oriented quando fizer sentido e manter legível. Tudo pragmático em C puro.

## 1) Query-first: lembrete

Em [[01-thinking-about-data-before-parsing]] vimos: **estrutura deve facilitar queries**. Agora aplicamos com AST de [[05-ast-structuring-without-overengineering]].

**Pergunta chave:** "Como acessar só o que preciso com mínimo overhead?"

## 2) Iteração cache-friendly

Arrays contíguos são nosso melhor amigo ([[02-memory-layout-and-tradeoffs]]).

### Iterar array

```c
Arr *a = ...;
for (size_t i=0; i<a->count; i++) {
    Val *v = &a->items[i]; // acesso direto
    // processa
}
```

**Ótimo:** stride = `sizeof(Val)`, prefetch funciona.

### Iterar objeto

```c
Obj *o = ...;
for (size_t i=0; i<o->count; i++) {
    Pair *p = &o->pairs[i];
    // p->key, p->val
}
```

**Também bom** (AOS). Se filtrar **só por key**, podemos pensar SOA, mas raramente vale.

## 3) Predicados simples

Use função `int pred(const Val*, void *ctx)` estilo callback minimalista.

```c
typedef int (*Pred)(const Val *v, void *ctx);

int is_num_gt(const Val *v, void *ctx){
    double *lim = ctx;
    return v->type==VAL_NUM && v->u.num > *lim;
}
```

Aplicar:

```c
void filter_arr(const Arr *a, Pred fn, void *ctx){
    for(size_t i=0;i<a->count;i++){
        if(fn(&a->items[i], ctx)) dump(&a->items[i]);
    }
}
```

**Vantagens:** reutilizável, testável, legível.

## 4) "Views" ao invés de cópias

Não duplique `Val`. Crie **índices** ou **ponteiros** pro subconjunto.

### Opção A: array de índices

```c
typedef struct {
    size_t *idx;
    size_t n,c;
} IdxView;
```

```c
// preencher
for(i=0;i<a->count;i++) if(match(&a->items[i])) iv_push(&iv,i);
```

Depois iterar por índices:

```c
for(i=0;i<iv.n;i++){
    size_t j = iv.idx[i];
    process(&a->items[j]);
}
```

**Prós:** zero cópia dos `Val`, pode reusar array original
**Contras:** indireção extra `a->items[j]`

### Opção B: array de ponteiros

```c
Val **sel = malloc(n*sizeof(Val*));
sel[k++] = &a->items[i];
```

Mesma ideia. Ponteiros diretos.

**Quando usar view:** resultado intermediário, quer manter original intacto, ou evitar cópias grandes.

**Quando evitar:** resultado final pequeno e vai usar muito — ponteiro direto ok.

## 5) Encontrar por chave em objeto

Linear scan é simples e eficiente p/ n pequeno.

```c
const Val *obj_get(const Obj *o, Sv key){
    for(size_t i=0;i<o->count;i++){
        if(sv_eq(o->pairs[i].key, key)) return &o->pairs[i].val;
    }
    return NULL;
}
```

**Trade-off:** O(n). Se objeto tem 100 chaves, trivial. Se 10^4 e buscas repetidas, considerar **mapa** (hash por string). Mas premature.

> [!tip]
> Comece com **linear scan**. Só otimize com evidência ([[10-performance-measurement-without-myths]]).

## 6) Percorrer hierarquia com segurança

AST aninhada: precise checar tipos.

```c
// imprimir só strings em qualquer lugar? recursivo simples
static void walk_str(const Val *v){
    if(!v) return;
    switch(v->type){
        case V_STR: print_sv(v->u.str); break;
        case V_ARR:
            for(size_t i=0;i<v->u.arr->count;i++) walk_str(&v->u.arr->items[i]);
            break;
        case V_OBJ:
            for(size_t i=0;i<v->u.obj->count;i++) walk_str(&v->u.obj->pairs[i].val);
            break;
        default: break;
    }
}
```

**Recursivo:** legível. Cuidado com profundidade (stack) em JSON muito aninhado. Ver [[06-parsing-recursive-descent-tradeoffs]] trade-offs.

**Iterativo com pilha explícita:** mais código, evita stack overflow. Raro necessário.

## 7) Filtros composáveis

Combine predicados simples.

```c
int and_pred(const Val *v, void *ctx){
    struct C { Pred a,b; void *ca,*cb; } *c=ctx;
    return c->a(v,c->ca) && c->b(v,c->cb);
}
```

Ou só chamar direto no loop (mais explícito):

```c
for(...){
    if(is_str(v) && sv_eq_cstr(v->u.str,"Ana")) ...
}
```

**Clareza > abstração**. Direto no loop costuma melhor p/ C puro.

## 8) Data-Oriented: quando considerar SOA

Vimos [[02-memory-layout-and-tradeoffs]]. Aplicando a AST "ready to query".

Exemplo: lista de objetos homogêneos `{id,name,age}`. Quer filtrar por `age>30`.

**AOS (atual):** acessar `pairs` achando chave `age` -> indireção.

**SOA derivado:** pós-parse, extrair arrays planos:

```c
typedef struct {
    long long *id;
    Sv *name;
    int *age;
    size_t n,c;
} Rows;
```

Construir:

```c
// varre root, extrai
for each matching object: id[i]=..., age[i]=..., name[i]=vname (view)
```

**Vantagens:**

- Filtrar por `age`: loop puro sobre `age[]` — **altíssima densidade**
- Ótimo se muitas queries por mesmo campo
- Menor "stride" p/ campo alvo

**Desvantagens:**

- Custo extra pós-parse
- Dobra memória (referências)
- Perde estrutura original
- Mais complexo

**Quando vale:** n **muito grande** + filtros repetidos por poucos campos.

**Quando NÃO vale:** n pequeno, queries variadas, hierarquia importante.

> [!tip]
> **Na maioria dos casos didáticos: AOS (AST atual) é suficiente e mais claro.**

## 9) Evitar alocações em hot path

Em loops de filtro:

- **NÃO** faça `malloc` por item selecionado
- **NÃO** duplique strings
- **SIM** use views/índices
- **SIM** imprima direto ou acumule índices

```c
// bom
for(i=0;i<n;i++){
    if(pred(&arr[i],ctx)) printf("%g\n", arr[i].u.num);
}

// evitar
for(i=0;i<n;i++){
    if(pred(&arr[i],ctx)){
        Val *c = malloc(sizeof(Val)); *c = arr[i]; list_push(c); // cópia desnecessária
    }
}
```

## 10) Iteradores minimalistas

Criar iterator simples evita reescrever loops.

```c
typedef struct {
    Val *cur;
    size_t i;
    const Arr *a;
} ArrIter;

static void it_begin(ArrIter *it, const Arr *a){
    it->a=a; it->i=0; it->cur = a&&a->count? &a->items[0]:NULL;
}
static int it_next(ArrIter *it){
    if(!it->a||it->i>=it->a->count) return 0;
    it->cur = &it->a->items[it->i++];
    return 1;
}
```

Uso:

```c
ArrIter it;
for(it_begin(&it,arr); it_next(&it);){
    if(is_num(it.cur)) sum += it.cur->u.num;
}
```

**Prós:** encapsula indexação, legível
**Contras:** pequeno overhead (struct + função)

**Didático:** vale a pena mostrar conceito.

## 11) "Lazy" vs "Eager"

- **Eager:** filtra tudo agora -> guarda view (array de índices)
- **Lazy:** filtra sob demanda no loop (eval pred toda vez)

**Eager** compensa se:
- Mesmo filtro usado **múltiplas vezes**
- Predicado caro
- Quer materializar resultado pequeno

**Lazy** compensa se:
- Usa filtro **uma vez**
- Predicado barato (comparação)
- Quer evitar aloc view

**Default prático:** **lazy** (direto no `if`).

## 12) Query helpers úteis

Crie helpers pequenos e óbvios:

```c
static inline int is_null(const Val*v){ return v&&v->type==V_NULL; }
static inline int is_bool(const Val*v){ return v&&v->type==V_BOOL; }
static inline int is_num(const Val*v){ return v&&v->type==V_NUM; }
static inline int is_str(const Val*v){ return v&&v->type==V_STR; }
static inline int is_arr(const Val*v){ return v&&v->type==V_ARR; }
static inline int is_obj(const Val*v){ return v&&v->type==V_OBJ; }

static inline int bool_val(const Val*v){ return is_bool(v)?v->u.b:0; }
static inline double num_val(const Val*v){ return is_num(v)?v->u.num:0.0; }
static inline Sv str_val(const Val*v){ return is_str(v)?v->u.str:(Sv){0}; }
```

**Reduz boilerplate e melhora legibilidade.**

## 13) Exemplo prático: filtrar + contar

Input:

```json
[
  {"name":"Ana","age":25},
  {"name":"Bruno","age":31},
  {"name":"Clara","age":27}
]
```

Quer: contar com `age >= 30`

```c
int age_geq30(const Val *v, void *ctx){
    (void)ctx;
    if(!is_obj(v)) return 0;
    const Obj *o = v->u.obj;
    // buscar "age"
    const Val *agev = obj_get(o, sv_cstr("age"));
    return agev && is_num(agev) && agev->u.num >= 30.0;
}

void run_query(const Val *root){
    if(!is_arr(root)) return;
    size_t cnt=0;
    const Arr *a = root->u.arr;
    for(size_t i=0;i<a->count;i++){
        if(age_geq30(&a->items[i], NULL)) cnt++;
    }
    printf("%zu\n", cnt);
}
```

**Legível, eficiente, sem cópias.**

## 14) Trade-offs: legível vs "genérico demais"

| Abordagem | Clareza | Reuso | Overhead | Recomendado |
|---|---|---|---|---|
| **If inline direto** | **Máxima** | Baixo | Zero | **Ótimo p/ casos únicos** |
| **Predicado function** | Alta | Alto | Chamada função (barata) | **Bom equilíbrio** |
| **Visitor genérico** | Média | Alto | Indireção | Overkill aqui |
| **DSL/query mini-lang** | Baixa | Teórico | Complexo | **Não** |
| **Views (índices)** | Boa | Bom | Indireção | Só se reutilizar |

**Pragmatismo:** prefira **inline** ou **pequenos predicados**.

## 15) Performance mindset

- **Localidade > abstração:** iterar array contíguo
- **Evite pointer chasing:** menos `->` desnecessário
- **Branch predictor ajuda:** `if` simples ok
- **Mensure, não adivinhe:** [[10-performance-measurement-without-myths]]
- **Seletividade importa:** filtrar 90% vs 10% muda pouco, mas bom saber
- **Cache lines:** processar em ordem linear

## 16) Checklist p/ queries

- [ ] Itero **sequencialmente** sobre arrays
- [ ] Uso `const` p/ dados lidos
- [ ] Evito cópias (views/índices)
- [ ] Checo `type` antes de acessar union
- [ ] Predicados pequenos e focados
- [ ] Linear scan OK p/ n esperado
- [ ] Recursão só se hierarquia necessária
- [ ] Helpers `is_*`/`val_*` pra clareza
- [ ] Sem `malloc` em loop hot
- [ ] Resultados intermediários mínimos

## 17) Exemplo completo minimal

```c
// helpers
static inline int is_obj(const Val*v){ return v&&v->type==V_OBJ; }
static inline int is_num(const Val*v){ return v&&v->type==V_NUM; }
static inline const Val* get_key(const Obj*o,Sv k){
    for(size_t i=0;i<o->count;i++) if(sv_eq(o->pairs[i].key,k)) return &o->pairs[i].val;
    return NULL;
}

// query
const Arr *a = root->u.arr;
size_t over30=0;
for(size_t i=0;i<a->count;i++){
    const Val *v=&a->items[i];
    if(!is_obj(v)) continue;
    const Val *agev = get_key(v->u.obj, sv_cstr("age"));
    if(agev && is_num(agev) && agev->u.num>=30.0) over30++;
}
```

**Direto, eficiente, legível.**

## 18) Conexão com próximas notas

- [[10-performance-measurement-without-myths]] – Validar escolhas com medições reais
- [[11-mini-json-like-parser-with-filters]] – Aplicar queries no projeto completo
- [[12-tradeoffs-cheatsheet]] – Resumo filtros/iteração
- [[02-memory-layout-and-tradeoffs]] – Fundamentação cache

## Exercício prático

1. Filtrar array: retornar **apenas strings** (count + iterar)
2. Em objeto, buscar `"name"` com `obj_get`
3. Criar `IdxView` e filtrar `age<30`
4. Comparar: inline vs predicado — qual mais legível?
5. Quando **SOA derivado** justificaria esforço?

## Próximo passo

Vá para: [[10-performance-measurement-without-myths]] – medir sem mitos, ferramentas, benchmarks simples e evitar premature optimization.