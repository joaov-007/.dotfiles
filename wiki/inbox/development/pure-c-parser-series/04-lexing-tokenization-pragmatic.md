---
title: "Lexing: Tokenization Pragmatic"
tags:
  - c
  - lexer
  - parser
  - tokenization
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[03-strings-slices-and-ownership]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[06-parsing-recursive-descent-tradeoffs]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Lexer pragmático com spans de linha/coluna para mensagens de erro úteis."
language: pt-BR
audience: developer
scope: "lexing e tokenização"
keywords:
  - c
  - lexer
  - "tokenização"
  - spans
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Lexing: Tokenization Pragmatic

> [!summary]
> **Lexer** transforma texto bruto em fluxo de tokens: `(type, lexeme/view, span)`. Foco aqui: minimalista, pragmático, bom pra DX (erros com linha/coluna), usar `StrView` com zero-copy e manter código previsível. Sem complicar com regex — só iteração caractere por caractere.

## 1) O que é lexing e por que separar?

- **Lexing:** quebra em **tokens** atômicos (palavras, números, símbolos, strings, etc.)
- **Parsing:** dá **estrutura** aos tokens (hierarquia)
- **Separar** deixa cada um mais simples, testável e fácil de debugar

**Trade-off:** separação custa um pouco (estrutura Token), mas paga em clareza.

## 2) Design minimalista

Precisamos de:

- **Input:** `const char *src, size_t len` (ou só ponteiro + fim)
- **Cursor/pos:** índice atual (ou ponteiro)
- **Line/col:** pra reportar erros úteis
- **Token stream:** array dinâmico de `Token` ou **stream** (pegar um por vez)
- **Skips:** whitespace, comentários (se houver)
- **Spans:** início/fim ou `StrView` direto

## 3) Definindo tipos de token

Mantenha enxuto. Comece com o estritamente necessário.

Exemplo JSON-like:

```c
typedef enum {
    TOK_EOF,
    TOK_LBRACE,  // {
    TOK_RBRACE,  // }
    TOK_LBRACK,  // [
    TOK_RBRACK,  // ]
    TOK_COMMA,   // ,
    TOK_COLON,   // :
    TOK_STRING,  // "..."
    TOK_NUMBER,  // -? digits [.exp]?
    TOK_IDENT,   // true/false/null (ou keywords)
    TOK_TRUE,
    TOK_FALSE,
    TOK_NULL,
    TOK_ERR      // token inválido p/ erro
} TokType;
```

> [!tip]
> **Não** crie 20 tipos antes de precisar. Adicione conforme parser exigir.

## 4) Token + Span

Usando `StrView` ([[03-strings-slices-and-ownership]]):

```c
#include <stddef.h>

typedef struct {
    size_t line;
    size_t col;
    size_t start; // offset no src
    size_t end;   // offset (exclusivo) ou inclusivo — escolha UM
} Span;

typedef struct {
    TokType type;
    StrView text; // view direto de src[start..end)
    Span    span;
} Token;
```

**Dica:** `text = (StrView){src+span.start, span.end-span.start}`. Ou calcule on-the-fly. Guardar `StrView` evita recomputar.

> [!info]
> **end exclusivo** (`[start,end)`) é menos propenso a off-by-one e combina bem com ranges.

## 5) Estado do Lexer

```c
typedef struct {
    const char *src;
    size_t len;
    size_t i;     // cursor (byte index)
    size_t line;
    size_t col;
    int    bol;   // beginning of line (opcional)
} Lexer;
```

Atualizar line/col ao consumir `\n`:

```c
static void adv(Lexer *l) {
    if (l->i < l->len && l->src[l->i] == '\n') {
        l->line++; l->col = 1;
    } else {
        l->col++;
    }
    l->i++;
}
```

Peek:

```c
static inline char peek(Lexer *l) {
    return l->i < l->len ? l->src[l->i] : '\0';
}
static inline char peek2(Lexer *l) {
    return (l->i+1 < l->len) ? l->src[l->i+1] : '\0';
}
```

## 6) Pular whitespace

Simples e direto:

```c
static void skip_ws(Lexer *l) {
    while (l->i < l->len) {
        char c = l->src[l->i];
        if (c==' '||c=='\t'||c=='\r'||c=='\n'||c=='\v'||c=='\f') {
            adv(l);
            continue;
        }
        break;
    }
}
```

> [!tip]
> Faça `skip_ws` **antes** de gerar próximo token (exceto casos raros). Mantém tokens limpos.

## 7) Números (pragmático)

Para JSON-like: `int`, `-123`, `123.45`, `1e10`, `-1.2e-3`. Não precisa validar IEEE 100%, mas detectar forma básica.

Abordagem: consumir enquanto `isdigit(c) || c=='.'||c=='e'||c=='E'||c=='+'||c=='-'` com regras mínimas.

```c
static Token lex_num(Lexer *l) {
    size_t start = l->i;
    if (peek(l)=='-' || peek(l)=='+') adv(l);
    if (!isdigit(peek(l)) && peek(l)!='.') {
        // erro: número malformado
        return mk_err(l,start,"expected digit after sign");
    }
    while (isdigit(peek(l))) adv(l);
    if (peek(l)=='.') {
        adv(l);
        if (!isdigit(peek(l))) return mk_err(l,start,"expected digit after dot");
        while (isdigit(peek(l))) adv(l);
    }
    if (peek(l)=='e'||peek(l)=='E') {
        adv(l);
        if (peek(l)=='+'||peek(l)=='-') adv(l);
        if (!isdigit(peek(l))) return mk_err(l,start,"expected digit in exp");
        while (isdigit(peek(l))) adv(l);
    }
    size_t end = l->i;
    return mk_tok(l, TOK_NUMBER, start, end);
}
```

> [!warning]
> Validação semântica (range `INT64_MAX`) fica melhor no **parser/valuator**. Lexer só checa **forma léxica**.

## 8) Strings com escapes

JSON tem `\" \\ \/ \b \f \n \r \t \uXXXX`. Pra um **mini parser didático**, você pode:

- **Nível 1 (mínimo):** aceitar apenas `\" \\` e `\n \t` básicos
- **Nível 2 (pragmático):** tratar escapes comuns ignorando validação `\u` completa

Importante: **não** consumir `"` interno incorretamente. Avançar caractere por caractere.

```c
static Token lex_str(Lexer *l) {
    size_t start = l->i;
    adv(l); // consome "
    while (l->i < l->len) {
        char c = peek(l);
        if (c == '"') { adv(l); break; } // fecha
        if (c == '\\') {
            // pula escape: \ + char seguinte
            adv(l);
            if (l->i < l->len) adv(l); // consome char escapado
            continue;
        }
        if (c == '\n' || c == '\r') {
            // string não fechada na linha
            return mk_err(l,start,"unclosed string");
        }
        adv(l);
    }
    size_t end = l->i;
    return mk_tok(l, TOK_STRING, start, end);
}
```

> [!info]
> Note: `text` inclui **aspas** (`"Ana"`). É comum no lexer. Parser pode extrair conteúdo puro depois. Ambas abordagens válidas — escolha **consistente**.

**Trade-off:** incluir aspas no lexeme simplifica lexer. Remover no parser dá "valor semântico" limpo.

## 9) Identificadores/keywords

`true`, `false`, `null` aparecem como literais. Podemos reconhecê-los:

```c
static int isid0(char c){ return isalpha((unsigned char)c)||c=='_'||c=='$'; }
static int isid(char c){ return isalnum((unsigned char)c)||c=='_'||c=='$'; }

static Token lex_ident(Lexer *l) {
    size_t start = l->i;
    if (!isid0(peek(l))) return mk_err(l,start,"bad ident");
    while (isid(peek(l))) adv(l);
    size_t end = l->i;
    // check keywords
    StrView v = sv_range(l->src,start,end-start); // ou via mk
    if (sv_eq_cstr(v,"true"))  return mk_typed(l,TOK_TRUE,start,end);
    if (sv_eq_cstr(v,"false")) return mk_typed(l,TOK_FALSE,start,end);
    if (sv_eq_cstr(v,"null"))  return mk_typed(l,TOK_NULL,start,end);
    return mk_tok(l,TOK_IDENT,start,end);
}
```

> [!tip]
> Teste keywords **por StrView** (evita alocar). Comparação por `len+memcmp` é barata.

## 10) Símbolos de 1 char

Muitos são triviais:

```c
static Token next_tok(Lexer *l) {
    skip_ws(l);
    if (l->i >= l->len) {
        size_t p = l->i;
        return mk_tok(l,TOK_EOF,p,p); // vazio
    }
    char c = peek(l);
    switch(c){
        case '{': adv(l); return mk_tok(l,TOK_LBRACE,l->i-1,l->i);
        case '}': adv(l); return mk_tok(l,TOK_RBRACE,l->i-1,l->i);
        case '[': adv(l); return mk_tok(l,TOK_LBRACK,l->i-1,l->i);
        case ']': adv(l); return mk_tok(l,TOK_RBRACK,l->i-1,l->i);
        case ',': adv(l); return mk_tok(l,TOK_COMMA,l->i-1,l->i);
        case ':': adv(l); return mk_tok(l,TOK_COLON,l->i-1,l->i);
        case '"': return lex_str(l);
        case '-': case '+': return lex_num(l);
        default:
            if (isdigit((unsigned char)c)) return lex_num(l);
            if (isid0(c)) return lex_ident(l);
            // desconhecido
            adv(l);
            return mk_err(l,l->i-1,"unexpected char");
    }
}
```

## 11) Helpers: mk_tok, mk_err

Mantenha centralizado.

```c
static Token mk_tok(Lexer *l, TokType t, size_t start, size_t end) {
    Token tok = {0};
    tok.type = t;
    tok.span.line = l->line; // linha atual? melhor guardar linha do start
    tok.span.col  = l->col;  // cuidado com avanço
    tok.span.start = start;
    tok.span.end   = end;
    // text view
    tok.text.data = l->src + start;
    tok.text.len  = end - start;
    return tok;
}
```

**Melhor prática:** registrar `line/col` **no momento de começar** o token, não depois de `adv`.

```c
static Token mk_tok_at(Lexer *l, TokType t, size_t start, size_t line, size_t col, size_t end) {
    Token tok = {0};
    tok.type=t; tok.span.start=start; tok.span.end=end;
    tok.span.line=line; tok.span.col=col;
    tok.text.data=l->src+start; tok.text.len=end-start;
    return tok;
}
```

Assim você preserva **posição exata** do lexema.

## 12) Stream vs Array

Duas formas:

- **Pull-style (stream):** `Token next(Lexer*)` — baixo consumo memória, bom p/ grandes inputs. Parser consome sob demanda.
- **Token list:** `Token *tokens + count` — fácil de debugar (ver todos), pode fazer lookahead por índice (`tokens[i]`), útil pra aprender.

**Recomendado p/ didático:** **array de tokens** primeiro. Depois evolui p/ stream.

Gerando lista:

```c
#include <stdlib.h>

typedef struct {
    Token *v;
    size_t count, cap;
} TokList;

static void tl_push(TokList *tl, Token t) {
    if (tl->count+1>=tl->cap){
        size_t nc = tl->cap? tl->cap*2:64;
        tl->v = realloc(tl->v, nc*sizeof(Token));
        tl->cap = nc;
    }
    tl->v[tl->count++]=t;
}

void lex_all(const char *src,size_t len, TokList *tl){
    Lexer l={src,len,0,1,1};
    for(;;){
        Token t = next_tok(&l);
        tl_push(tl,t);
        if (t.type==TOK_EOF) break;
        if (t.type==TOK_ERR) break; // ou continuar? depende DX
    }
}
```

> [!warning]
> Ao encontrar `TOK_ERR`, **parar** costuma ser melhor pra debug. "Error recovery" no lexer raramente compensa em parser simples.

## 13) Testando lexer isoladamente

Crie testes mínimos, manuais mesmo.

```c
const char *s = "{\"a\": 123, \"b\": true}";
TokList tl={0};
lex_all(s,strlen(s),&tl);
for(size_t i=0;i<tl.count;i++){
  Token *t=&tl.v[i];
  // imprimir: type, text, line,col
}
```

**O que observar:**

- Whitespace ignorado?
- Números corretos (inclusive `-` se tiver)
- Strings com aspas preservadas?
- Keywords viram `TOK_TRUE/FALSE/NULL`?
- EOF aparece?
- Spans line/col fazem sentido?

## 14) Boa DX: mensagens de erro úteis

Erros vagos matam tempo. Seja específico.

**Ruim:** `"unexpected char"`
**Melhor:** `"unexpected char 'x' at line 3 col 12"`

```c
typedef struct {
    int has;
    size_t line,col;
    const char *msg; // estático ou alocado
    StrView near;    // lexeme/contexto curto
} LexErr;

static Token mk_err(Lexer *l,size_t start,const char *msg){
    Token t={0};
    t.type=TOK_ERR;
    t.span.start=start; t.span.end=l->i;
    t.span.line=l->line; t.span.col=l->col;
    t.text.data=msg; // hack didático: usar text.data p/ msg? melhor campo separado
    // melhor: ter LexErr paralelo
    return t;
}
```

> [!tip]
> **Não** abuse de `text.data` p/ string estática. Crie `err.msg`. Em didático, até funciona, mas confuso.

Alternativa limpa: retornar `int ok` + `LexErr *err` por referência.

## 15) Trade-offs: lexer "dumb" vs "smart"

| Abordagem | Prós | Contras |
|---|---|---|
| **Dumb (só tokens)** | Simples, puro, reutilizável | Parser faz mais validação |
| **Smart (valida números/strings já)** | Menos trabalho no parser | Acopla regras sintáticas ao lexer |
| **Context-aware** | Resolve ambiguidade rara | Complica muito (não vale aqui) |

**Recomendado:** **"dumb but helpful"**. Valide **forma**, não **semântica**.

## 16) Lookahead e eficiência

- **1-token lookahead:** suficiente p/ recursive descent vasto (LL(1))
- **Array:** lookahead por índice `cur++`
- **Stream:** guardar `peek_tok` bufferizado

Para JSON-like, **LL(1)** cobre tudo. Não precisa de LL(k).

> [!info]
> **Eficiência prática:** lexer caractere-a-caractere é O(tamanho input). Com scans lineares e poucos branches, costuma ser rápido o suficiente.

## 17) Evitando cópias

- Use `StrView` direto do `src`
- Não duplique lexemes
- Array com `realloc` exponencial (evita realocs)
- Evite `strdup` no lexer

## 18) Checklist

- [ ] Uso `StrView` p/ `text` dos tokens?
- [ ] Mantenho `span` com `line/col/start/end`?
- [ ] `skip_ws` antes de cada token?
- [ ] Números detectam forma básica sem exagero?
- [ ] Strings tratam `\"` e `\\` minimamente?
- [ ] Keywords mapeados explicitamente?
- [ ] EOF tratado corretamente?
- [ ] Erro gera `TOK_ERR` com posição clara?
- [ ] Consumo de cursor é **consistente** (nunca avanço 2x sem querer)?
- [ ] Testei com input mínimo + casos inválidos?

## 19) Conexão com próximas notas

- [[05-ast-structuring-without-overengineering]] – Converte tokens em AST enxuta
- [[06-parsing-recursive-descent-tradeoffs]] – Usa token stream/list com lookahead
- [[07-error-reporting-and-developer-experience]] – Melhora mensagens com spans
- [[11-mini-json-like-parser-with-filters]] – Implementação concreta lexer+parser
- [[12-tradeoffs-cheatsheet]] – Decisões rápidas

## Exercício prático

Implemente mentalmente (ou codifique):

1. Lexer p/ `["a", -42, true]`
2. Liste tokens na ordem com `(type, text_view, line,col)`
3. Adicione detecção de string não fechada (`"abc`)
4. Por que **array de tokens** facilita debug vs stream?
5. Por que guardar `StrView` e não `strdup` no lexer?

**Meta:** entender fluxo `peek -> skip -> match -> advance -> emit`.

## Próximo passo

Vá para: [[05-ast-structuring-without-overengineering]] – modelar AST minimalista com tagged unions.