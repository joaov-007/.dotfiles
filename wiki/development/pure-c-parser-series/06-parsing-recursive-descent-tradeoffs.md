---
title: "Parsing: Recursive Descent Trade-offs"
tags:
  - c
  - parser
  - recursive-descent
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[04-lexing-tokenization-pragmatic]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Parsing por recursive descent: quando a abordagem simples funciona e quais são os limites."
language: pt-BR
audience: developer
scope: recursive descent e trade-offs
keywords:
  - c
  - parser
  - recursive descent
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Parsing: Recursive Descent Trade-offs

> [!summary]
> **Recursive Descent (RD)** é o método pragmático ideal p/ aprender e p/ parsers pequenos/médios em C. Direto, legível, fácil debugar. Foco em: lookahead 1, mapeamento 1:1 com gramática, tratamento de erros simples e trade-offs (recursão vs iterativo, previsibilidade vs clareza).

## 1) Por que Recursive Descent?

- **Mapeamento claro:** cada regra gramatical vira uma função `parse_x()`
- **Legível:** segue estrutura da gramática
- **Lookahead mínimo:** geralmente LL(1) basta
- **Fácil testar:** testa regra por regra
- **Sem gerador pesado:** 100% mão, sem dependências
- **Ótimo p/ didático + prático**

## 2) Token stream com lookahead

Temos lista de tokens ([[04-lexing-tokenization-pragmatic]]) ou stream. Com **array + índice** é simples.

```c
typedef struct {
    Token *tokens;
    size_t count;
    size_t i; // current
} Parser;
```

Helpers:

```c
static inline Token cur(P *p){ return p->i<p->count ? p->tokens[p->i] : eof_tok(); }
static inline Token peek(P *p,int k){ size_t j=p->i+k; return j<p->count?p->tokens[j]:eof_tok(); }
static inline void adv(P *p){ if(p->i<p->count) p->i++; }
static inline void eat(P *p, TokType t){ /* consome se bate */ }
```

**Lookahead 1 (`cur()`) resolve maioria dos casos em JSON-like.**

## 3) Gramática mínima (JSON-like subset)

Focando em entender mapeamento:

```text
value   = null | bool | number | string | array | object
array   = '[' [ value { ',' value } ] ']'
object  = '{' [ pair { ',' pair } ] '}'
pair    = string ':' value
null    = 'null'
bool    = 'true' | 'false'
string  = TOK_STRING
number  = TOK_NUMBER
```

> [!tip]
> `[...]` opcional, `{...}` zero ou mais. Perfeito p/ loops.

## 4) Mapeando gramática -> funções

Cada produção vira função que **consome tokens** e retorna `Val*` (ou `Val` + arena).

```c
// p.h/impl
static Val *parse_value(Parser *p, Arena *a);
static Arr *parse_array(Parser *p, Arena *a);
static Obj *parse_object(Parser *p, Arena *a);
static Pair parse_pair(Parser *p, Arena *a); // ou aloca Pair
```

Padrão: `parse_x` **avança cursor** apenas quando consome com sucesso.

## 5) Parse value (disjunção)

```c
static Val *parse_value(Parser *p, Arena *a) {
    skip_ws_like(p); // se stream
    Token t = cur(p);
    switch (t.type) {
        case TOK_NULL:  adv(p); return mk_val(a, V_NULL, (U){0});
        case TOK_TRUE:  adv(p); return mk_val(a, V_BOOL, (U){.b=1});
        case TOK_FALSE: adv(p); return mk_val(a, V_BOOL, (U){.b=0});
        case TOK_NUMBER: adv(p); return mk_val(a, V_NUM,  num_from(t.text)); // parse double
        case TOK_STRING: adv(p); return mk_val(a, V_STR,  (U){.str=t.text});
        case TOK_LBRACK: return mk_val(a, V_ARR, (U){.arr=parse_array(p,a)});
        case TOK_LBRACE: return mk_val(a, V_OBJ, (U){.obj=parse_object(p,a)});
        default:
            // erro: token inesperado
            return parse_error(p,a,"unexpected token in value");
    }
}
```

> [!info]
> `num_from(StrView)` converte p/ `double`/`long long`. Pode usar `strtod` com cuidado (precisa NUL-term? ou usar `strtod` limitado). Alternativa: parse manual simples.

Se `text` não NUL-terminated, `strtod(t.text.data, &end)` lê até `\0`? Perigoso. Solução: copiar pra buffer temporário com `\0` OU usar `strtod` com `snprintf` pequeno? Ou parse manual.

**Pragmático:** pra didático, se garantimos NUL no `src` original, ok. Senão faça owned temp.

## 6) Parse array

```text
array = '[' [ value { ',' value } ] ']'
```

Implementação:

```c
static Arr *parse_array(Parser *p, Arena *a) {
    Token lb = cur(p);
    if (lb.type != TOK_LBRACK) { /* erro */ }
    adv(p); // consome [
    Arr *arr = mk_arr(a);
    // vazio?
    if (cur(p).type == TOK_RBRACK) {
        adv(p);
        return arr;
    }
    for (;;) {
        Val *v = parse_value(p,a);
        if (v->type == V_ERR) return arr; // propaga? ou marca
        arr_push_heap(arr, *v); // ou push em arena-aware
        if (cur(p).type == TOK_RBRACK) { adv(p); break; }
        if (cur(p).type == TOK_COMMA) { adv(p); continue; }
        // erro: esperado , ou ]
        parse_error_expect(p,a,", or ]");
        break;
    }
    return arr;
}
```

**Pontos:**

- Trata **array vazio** explicitamente (evita loop confuso)
- Usa `for(;;)` com `break`/`continue` — claro
- Em erro, **fail-fast** simples (suficiente p/ aprender). Error recovery opcional.

## 7) Parse object

```text
object = '{' [ pair { ',' pair } ] '}'
pair   = string ':' value
```

```c
static Obj *parse_object(Parser *p, Arena *a) {
    if (cur(p).type != TOK_LBRACE) { /* erro */ }
    adv(p); // {
    Obj *obj = mk_obj(a);
    if (cur(p).type == TOK_RBRACE) {
        adv(p);
        return obj;
    }
    for (;;) {
        Token k = cur(p);
        if (k.type != TOK_STRING) {
            parse_error_expect(p,a,"string key");
            break;
        }
        adv(p); // consome key string
        if (cur(p).type != TOK_COLON) {
            parse_error_expect(p,a,":");
            break;
        }
        adv(p); // consome :
        Val *v = parse_value(p,a);
        obj_push(obj, (Pair){k.text, *v}); // guarda key view + val
        if (cur(p).type == TOK_RBRACE) { adv(p); break; }
        if (cur(p).type == TOK_COMMA) { adv(p); continue; }
        parse_error_expect(p,a,", or }");
        break;
    }
    return obj;
}
```

**Observação:** guardamos `k.text` (StrView) direto do token. Coerente com [[03-strings-slices-and-ownership]].

## 8) Recursive Descent: por que funciona

RD é natural p/ gramáticas **LL(1)**: olhando **1 token à frente** decide qual regra entrar.

JSON-like é LL(1). Exemplos:

- `[` -> array
- `{` -> object
- `t/f/n` -> bool/null
- `"`, `digit`, `-` -> primitivo
- `]`/`}` -> fim

**Não** precisa backtrack. Isso simplifica muito.

## 9) Recursão vs Iterativo

RD usa **chamada recursiva** pra estruturas aninhadas: `value` chama `array` chama `value`...

### Prós recursão

- Código **muito legível** (espelha gramática)
- Menos estado explícito (pilha implícita)
- Menos boilerplate
- Ótimo p/ AST hierárquica

### Contras recursão

- **Stack depth limitado** (C stack)
- Input **muito aninhado** pode dar **stack overflow** (e.g. `[ [ ... [ 1 ] ... ] ]` com 10^4 níveis)
- Difícil iterar em ambientes restritos
- Debug stack trace menos óbvio às vezes

### Quando preocupar?

- JSON "normal": profundidade rara > 10^3. Stack x86_64 típico aguenta? Depende, mas pra aprendizado **irrelevante**.
- Se precisa parsear JSON gerado com aninhamento extremo: considerar **iterativo** com pilha explícita.
- Em **embedded** restrito, sim.
- Em desktop Linux p/ fins didáticos: **RD é correto**.

> [!warning]
> **Não evite RD por "teoria".** Entenda trade-off. Implemente RD primeiro, evolua depois se houver evidência.

### Iterativo: ideia geral

Usar pilha explícita (`Val* stack`, `state stack`). Mais código, menos legível, menos didático. Viável mas verboso.

## 10) Lookahead: 1 token basta?

JSON é LL(1):

- Primeiro(`value`) = `{ [ " digit - t f n`
- Decide sem ambiguidade

Se gramática tivesse ambiguidade (ex: `expr: expr '+' expr`), RD ingênuo falha. Mas podemos reescrever com **precedência**.

**Regra prática:** pra subset didático, **LL(1) + RD é perfeito**.

## 11) Tratamento de erros: pragmático

Dois extremos:

- **Panic-mode minimal:** ao erro, marca `V_ERR`/`TOK_ERR`, tenta avançar até `, ] }` pra "sincronizar"? Complica
- **Fail-fast:** reporta 1º erro com span (line/col) e aborta. **Melhor p/ DX aprendendo**

**Recomendado aqui:** **fail-fast com mensagem clara + span**.

```c
typedef struct {
    int ok;
    size_t line,col;
    const char *msg;
} PErr;

static Val *parse_error(Parser *p, Arena *a, const char *msg) {
    (void)a;
    // criar Val "error" marker? ou set global err
    static Val errv = {V_ERR,{0}};
    // preencher err context
    p->err.ok=0; p->err.msg=msg;
    p->err.line = cur(p).span.line; p->err.col = cur(p).span.col;
    return &errv;
}
```

> [!tip]
> Ter `V_ERR` no `VType` evita retornar NULL (NULL também usado?). Ou usar `Parser.err`. Ambas ok. Evitar ambiguidade.

Alternativa: retornar `int` + `Val* out`.

```c
// mais explícito
int parse_value(Parser *p,Arena *a, Val **out);
```

**Vantagem:** separa "sucesso/falha" de "valor".

## 12) Precedência e associatividade (fora do escopo básico)

JSON não tem operadores. Se fosse expressão numérica (`1+2*3`), RD clássico com `expr` direto é esquerda-recursivo? Ou precisa fatorar:

```text
expr = term { '+' term }
term = factor { '*' factor }
factor = number | '(' expr ')'
```

**Não vamos** entrar nisso agora. Foco em **JSON-like**.

## 13) Performance de RD

RD é **rápido o suficiente** na prática:

- Poucas chamadas
- Switch direto
- Lookahead O(1)
- Sem tabela de parsing grande

Comparado com table-driven (LALR), RD manual é **menor** e mais fácil otimizar localmente.

**Gargalos reais** em parser costumam ser:

1. **Alocações** ([[02-memory-layout-and-tradeoffs]]) — corrigido com arena
2. **I/O + cópias strings** ([[03-strings-slices-and-ownership]]) — views ajudam
3. **Muitos small malloc** — arena resolve

## 14) Testando incrementalmente

Teste por regra:

1. **Primitivos:** `null`, `true`, `false`, `123`, `"abc"`
2. **Array vazio:** `[]`
3. **Array simples:** `[1, "x"]`
4. **Object vazio:** `{}`
5. **Object simples:** `{"a":1}`
6. **Aninhado:** `[{"a":[true]}]`
7. **Inválidos:** `{a:1}`, `["a",]`, `[1,2`

**Fail-fast** deve dar erro claro com linha/col.

## 15) Boa DX no parser

- **Nomes claros:** `parse_value`, `parse_array` — óbvios
- **Poucos níveis:** evitar funções ultra-aninhadas
- **Erros acionáveis:** `"expected ':' after key"` > `"syntax error"`
- **Consumo previsível:** cada função ou consome token(s) ou chama outra
- **Sem side-effects ocultos** (exceto avançar cursor + arena)

## 16) Trade-offs: RD manual vs gerador

| Critério | RD Manual | Gerador (lemon/bison/yacc/re2c híbrido) |
|---|---|---|
| **Aprendizado** | **Ótimo** (entende tudo) | Menor entendimento interno |
| **Depêndencia** | Zero | +tool |
| **Debug** | **Fácil** (step into) | Mais indireto |
| **Manutenção** | Ótimo p/ pequeno | Ótimo p/ gramática grande |
| **Erros customizados** | **Total controle** | Limitado/verboso |
| **Performance** | Ótimo | Geralmente igual |
| **Código C puro** | **Sim** | Gera C |
| **Tamanho** | Pequeno | Pequeno+gerador |

**Veredito:** **RD manual** é imbatível p/ aprender e p/ subset prático.

## 17) Evitando left-recursion

RD direto não lida com **left-recursion**:

```text
expr = expr '+' term  // recursão infinita
```

Solução: transformar p/ **right-recursion** ou forma iterativa com loop.

```text
expr = term { '+' term }
```

**Não precisamos** aqui. Só fique ciente.

## 18) Checklist

- [ ] Mapeei **cada regra** p/ função `parse_x`
- [ ] Uso **lookahead 1** (`cur()`)
- [ ] Trato **vazio** (`[] {}`) explicitamente
- [ ] Avanço cursor **só ao consumir** token válido
- [ ] Erros com **span/linha/col** claros
- [ ] Recursão usada p/ **aninhamento natural** (value<->array/object)
- [ ] Consumo previsível (não avanço duplo)
- [ ] Testei casos felizes + inválidos mínimos
- [ ] Separei "parse" de "criação AST" (mk_*)
- [ ] Considerei **fail-fast** simples

## 19) Exemplo skeleton mínimo

```c
// parser.h (ideia)
typedef struct {
    Token *t; size_t n,i;
    PErr err;
} P;
int parse_json(P*,Arena*,Val**);

// parser.c
static Val *pv(P*p,Arena*a){
    Token c=cur(p);
    switch(c.type){
        case TOK_TRUE: adv(p); return vbool(a,1);
        case TOK_FALSE: adv(p); return vbool(a,0);
        case TOK_NULL: adv(p); return vnull(a);
        case TOK_NUMBER: adv(p); return vnum(a, num(c.text));
        case TOK_STRING: adv(p); return vstr(a, c.text);
        case TOK_LBRACK: return varr(a, pa(p,a));
        case TOK_LBRACE: return vobj(a, po(p,a));
        default: return perr(p,"bad value");
    }
}
// pa/po seguem padrão for(;;) com ] } ,
```

**Conciso e claro.**

## 20) Conexão com próximas notas

- [[07-error-reporting-and-developer-experience]] – Aprimora erros com contexto
- [[08-project-organization-in-pure-c]] – Divide em `lexer.h/c`, `ast.h/c`, `parser.h/c`
- [[09-filtering-querying-over-structured-data]] – Usa AST gerada
- [[10-performance-measurement-without-myths]] – Mede parser
- [[11-mini-json-like-parser-with-filters]] – Implementação completa funcional
- [[12-tradeoffs-cheatsheet]] – RD vs outros

## Exercício prático

1. Implemente `parse_value` p/ primitivos + `[]` vazio.
2. Adicione `parse_array` com `,` e `]`.
3. Teste `["a", true, 42]` passo mental: cursor avança corretamente?
4. Por que RD é mais legível que table-driven p/ aprender?
5. Em que caso real você **consideraria** iterativo ao invés de recursivo?

## Próximo passo

Vá para: [[07-error-reporting-and-developer-experience]] – tornar erros humanos, acionáveis e com bom span/contexto.