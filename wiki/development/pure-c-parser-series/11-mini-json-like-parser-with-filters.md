---
title: "Mini JSON-like Parser With Filters"
tags:
  - c
  - parser
  - project
  - json-like
  - tutorial
  - example
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[00-pure-c-parser-overview]]"
  - "[[05-ast-structuring-without-overengineering]]"
  - "[[06-parsing-recursive-descent-tradeoffs]]"
  - "[[07-error-reporting-and-developer-experience]]"
  - "[[08-project-organization-in-pure-c]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[10-performance-measurement-without-myths]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Projeto final: um mini parser JSON-like com filtros."
language: pt-BR
audience: developer
scope: mini parser JSON-like com filtros
keywords:
  - c
  - parser
  - json-like
  - projeto
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Mini JSON-like Parser With Filters

> [!summary]
> Juntamos tudo: lexer com spans, AST com tagged union, recursive descent, arena, StrView, erros com contexto, filtros iterativos e organização modular. Exemplo completo, pragmático e comentado — suficiente p/ entender trade-offs na prática e extender.

## 1) Objetivo

Implementar **mini parser JSON-like** com:

- Input: arquivo inteiro
- Lexer: tokens + `StrView` + spans (line/col)
- Parser: RD fail-fast
- AST: `Val/Arr/Obj` arrays contíguos
- Arena: bump
- Erros: mensagem + linha + caret
- Queries: filtrar por chave/valor
- Build: simples (`cc *.c`)

Subset: `null,true,false,number,string,array,object` (números double simples).

## 2) Estrutura de arquivos

```text
mini-jl/
├── sv.h
├── sv.c
├── arena.h
├── arena.c
├── err.h
├── err.c
├── lex.h
├── lex.c
├── ast.h
├── ast.c
├── parser.h
├── parser.c
├── query.h
├── query.c
└── main.c
```

## 3) sv.h / sv.c

```c
// sv.h
#ifndef MJ_SV_H
#define MJ_SV_H
#include <stddef.h>
#include <string.h>
#include <ctype.h>

typedef struct { const char *p; size_t l; } Sv;

static inline int sv_eq(Sv a,Sv b){
  if(a.l!=b.l) return 0;
  return memcmp(a.p,b.p,a.l)==0;
}
static inline int sv_eqc(Sv a,const char *c){
  size_t cl=strlen(c);
  if(a.l!=cl) return 0;
  return memcmp(a.p,c,cl)==0;
}
static inline Sv sv_range(const char*p,size_t s,size_t l){ return (Sv){p+s,l}; }
static inline Sv sv_cstr(const char*c){ return c?(Sv){c,strlen(c)}:(Sv){0}; }
#endif
```

## 4) arena.h / arena.c

```c
// arena.h
#ifndef MJ_ARENA_H
#define MJ_ARENA_H
#include <stddef.h>
typedef struct Arena Arena;
Arena* arena_new(size_t cap);
void*  arena_alloc(Arena*,size_t n,size_t align);
void   arena_reset(Arena*);
void   arena_free(Arena*);
#endif

// arena.c
#include "arena.h"
#include <stdlib.h>
#include <stdint.h>
struct Arena{char*b,*c,*e;};
static size_t align_up(size_t v,size_t a){return (v+(a-1))&~(a-1);}
Arena* arena_new(size_t cap){Arena*a=malloc(sizeof* a); if(!a)return NULL; a->b=malloc(cap); if(!a->b){free(a);return NULL;} a->c=a->b; a->e=a->b+cap; return a;}
void* arena_alloc(Arena*a,size_t n,size_t al){if(!a)return NULL; uintptr_t p=(uintptr_t)a->c; uintptr_t ap=(p+(al-1))&~(al-1); ptrdiff_t need=(ptrdiff_t)ap+n-(ptrdiff_t)a->c; if(need>(a->e-a->c)){/*simpl: no grow*/ return NULL;} a->c=(char*)ap+n; return (void*)ap;}
void arena_reset(Arena*a){if(a) a->c=a->b;}
void arena_free(Arena*a){if(!a)return; free(a->b); free(a);}
```

> [!note]
> Sem grow dinâmico aqui (didático). Para inputs maiores, adicionar `realloc` com cuidado (offsets).

## 5) err.h / err.c

```c
// err.h
#ifndef MJ_ERR_H
#define MJ_ERR_H
#include <stddef.h>
#include <stdio.h>
typedef struct{int has; const char*msg; size_t line,col,start,end;} Err;
void err_clear(Err*e){e->has=0;e->msg="";e->line=e->col=e->start=e->end=0;}
void err_print(FILE*f,const Err*e,const char*src,size_t len){
  if(!e->has)return;
  fprintf(f,"parse error: %s at line %zu, col %zu\n",e->msg,e->line,e->col);
  if(!src) return;
  // ctx
  size_t ls=0,ln=1; for(size_t j=0;j<len&&ln<e->line;j++){if(src[j]=='\n'){ln++;ls=j+1;}}
  size_t le=ls; while(le<len&&src[le]!='\n'&&src[le]!='\r') le++;
  fwrite(src+ls,1,le-ls,f); fputc('\n',f);
  for(size_t k=0;k<e->col&&k<(le-ls+2);k++) fputc(' ',f); fputc('^',f); fputc('\n',f);
}
#endif
```

## 6) lex.h / lex.c (tokens + lexer)

```c
// lex.h
#ifndef MJ_LEX_H
#define MJ_LEX_H
#include "sv.h"
#include "err.h"
typedef enum{T_EOF,T_LB,T_RB,T_LC,T_RC,T_COM,T_COL,T_STR,T_NUM,T_IDENT,T_TRUE,T_FALSE,T_NULL,T_ERR} TokType;
typedef struct{TokType t;Sv txt; size_t line,col,start,end;} Tok;
typedef struct{Tok*v;size_t n,c;} TokList;
int lex_all(const char*src,size_t len,TokList*,Err*);
void tl_free(TokList*);
#endif

// lex.c
#include "lex.h"
#include <stdlib.h>
#include <ctype.h>
typedef struct{const char*s;size_t l,i,line,col;} L;
static void adv(L*l){ if(l->i<l->l&&l->s[l->i]=='\n'){l->line++;l->col=1;}else l->col++; l->i++;}
static char pk(L*l,int k){size_t j=l->i+k; return j<l->l?l->s[j]:'\0';}
static void sk(L*l){ while(l->i<l->l){char c=l->s[l->i]; if(c==' '||c=='\t'||c=='\r'||c=='\n'||c=='\v'||c=='\f'){adv(l);}else break;}}
static Tok mt(L*l,TokType t,size_t st,size_t sln,size_t scl,size_t en){Tok x={t,sv_range(l->s,st,en-st),sln,scl,st,en}; return x;}
static Tok me(L*l,const char*m,size_t st){Tok x={T_ERR,(Sv){m,strlen(m)},l->line,l->col,st,l->i}; return x;}
static Tok lstr(L*l){
  size_t st=l->i,sln=l->line,scl=l->col; adv(l);
  while(l->i<l->l){char c=pk(l,0); if(c=='"'){adv(l); return mt(l,T_STR,st,sln,scl,l->i);} if(c=='\\'){adv(l); if(l->i<l->l) adv(l); continue;} if(c=='\n'||c=='\r') return me(l,"unclosed string",st); adv(l);} return me(l,"unclosed string",st);
}
static Tok lnum(L*l){
  size_t st=l->i,sln=l->line,scl=l->col;
  if(pk(l,0)=='-'||pk(l,0)=='+') adv(l);
  if(!isdigit((unsigned char)pk(l,0))&&pk(l,0)!='.'){ adv(l); return me(l,"bad number",st);} while(isdigit((unsigned char)pk(l,0))) adv(l);
  if(pk(l,0)=='.'){ adv(l); if(!isdigit((unsigned char)pk(l,0))) return me(l,"bad number",st); while(isdigit((unsigned char)pk(l,0))) adv(l);}
  if(pk(l,0)=='e'||pk(l,0)=='E'){ adv(l); if(pk(l,0)=='+'||pk(l,0)=='-') adv(l); if(!isdigit((unsigned char)pk(l,0))) return me(l,"bad number",st); while(isdigit((unsigned char)pk(l,0))) adv(l);}
  return mt(l,T_NUM,st,sln,scl,l->i);
}
static int id0(char c){return isalpha((unsigned char)c)||c=='_'||c=='$';}
static int id1(char c){return isalnum((unsigned char)c)||c=='_'||c=='$';}
static Tok lid(L*l){
  size_t st=l->i,sln=l->line,scl=l->col; if(!id0(pk(l,0))) return me(l,"bad ident",st); while(id1(pk(l,0))) adv(l); size_t e=l->i; Sv v=sv_range(l->s,st,e-st);
  if(sv_eqc(v,"true")) return mt(l,T_TRUE,st,sln,scl,e); if(sv_eqc(v,"false")) return mt(l,T_FALSE,st,sln,scl,e); if(sv_eqc(v,"null")) return mt(l,T_NULL,st,sln,scl,e); return mt(l,T_IDENT,st,sln,scl,e);
}
static Tok nxt(L*l){
  sk(l); if(l->i>=l->l){size_t p=l->i; return mt(l,T_EOF,p,l->line,l->col,p);}
  char c=pk(l,0); size_t st=l->i,sln=l->line,scl=l->col;
  switch(c){ case '{': adv(l); return mt(l,T_LC,st,sln,scl,l->i); case '}': adv(l); return mt(l,T_RC,st,sln,scl,l->i); case '[': adv(l); return mt(l,T_LB,st,sln,scl,l->i); case ']': adv(l); return mt(l,T_RB,st,sln,scl,l->i); case ',': adv(l); return mt(l,T_COM,st,sln,scl,l->i); case ':': adv(l); return mt(l,T_COL,st,sln,scl,l->i); case '"': return lstr(l); case '-': case '+': return lnum(l); default: if(isdigit((unsigned char)c)) return lnum(l); if(id0(c)) return lid(l); adv(l); return me(l,"unexpected char",st);}
}
static void tl_push(TokList*tl,Tok t){ if(tl->n+1>=tl->c){size_t nc=tl->c?tl->c*2:64; tl->v=realloc(tl->v,nc*sizeof(Tok)); tl->c=nc;} tl->v[tl->n++]=t;}
int lex_all(const char*src,size_t len,TokList*tl,Err*e){ L l={src,len,0,1,1}; err_clear(e); tl->n=tl->c=0; tl->v=NULL; for(;;){ Tok t=nxt(&l); tl_push(tl,t); if(t.t==T_ERR){ e->has=1;e->msg=t.txt.p;e->line=t.line;e->col=t.col;e->start=t.start;e->end=t.end; return 0;} if(t.t==T_EOF) break;} return 1;}
void tl_free(TokList*tl){free(tl->v); tl->v=NULL; tl->n=tl->c=0;}
```

## 7) ast.h / ast.c

```c
// ast.h
#ifndef MJ_AST_H
#define MJ_AST_H
#include "sv.h"
struct Arr; struct Obj;
typedef enum{V_NULL,V_BOOL,V_NUM,V_STR,V_ARR,V_OBJ,V_ERR} VType;
typedef struct{VType t; union{int b;double num;Sv str;struct Arr*arr;struct Obj*obj;}u;} Val;
typedef struct{Sv k; Val v;} Pair;
struct Arr{Val*it;size_t n,c;};
struct Obj{Pair*p;size_t n,c;};
Arr* mk_arr(void*);
Obj* mk_obj(void*);
Val  vnull(void); Val vbool(int); Val vnum(double); Val vstr(Sv); Val varr(struct Arr*); Val vobj(struct Obj*);
void arr_push(Arr*,Val,void*);
void obj_push(Obj*,Pair,void*);
#endif

// ast.c
#include "ast.h"
#include <stdlib.h>
#include "arena.h"
Arr* mk_arr(void*a){(void)a; Arr*x=malloc(sizeof* x); *x=(Arr){0}; return x;} // heap p/ grow; ou arena se fix
Obj* mk_obj(void*a){(void)a; Obj*x=malloc(sizeof* x); *x=(Obj){0}; return x;}
Val vnull(){return (Val){V_NULL,{0}};} Val vbool(int b){return (Val){V_BOOL,{.b=b}};} Val vnum(double n){return (Val){V_NUM,{.num=n}};} Val vstr(Sv s){return (Val){V_STR,{.str=s}};} Val varr(struct Arr*ar){return (Val){V_ARR,{.arr=ar}};} Val vobj(struct Obj*o){return (Val){V_OBJ,{.obj=o}};}
void arr_push(Arr*ar,Val v,void*a){(void)a;if(ar->n+1>=ar->c){size_t nc=ar->c?ar->c*2:8; ar->it=realloc(ar->it,nc*sizeof(Val)); ar->c=nc;} ar->it[ar->n++]=v;}
void obj_push(Obj*o,Pair pr,void*a){(void)a;if(o->n+1>=o->c){size_t nc=o->c?o->c*2:8; o->p=realloc(o->p,nc*sizeof(Pair)); o->c=nc;} o->p[o->n++]=pr;}
```

> [!note]
> `mk_arr/mk_obj` + `arr_push/obj_push` usam `malloc/realloc` (grow fácil). Em projeto didático está ok. Podemos migrar p/ arena com chunking depois.

## 8) parser.h / parser.c

```c
// parser.h
#ifndef MJ_PARSER_H
#define MJ_PARSER_H
#include "lex.h"
#include "ast.h"
#include "arena.h"
#include "err.h"
typedef struct{Tok*t;size_t n,i; Err err; const char*src;size_t slen;} P;
int parse_json(P*p,Arena*a,Val**out);
#endif

// parser.c
#include "parser.h"
#include <stdlib.h>
#include <string.h>
static Tok cur(P*p){ return p->i<p->n?p->t[p->i]:(Tok){T_EOF,{0},0,0,0,0};}
static void adv(P*p){ if(p->i<p->n) p->i++;}
static Val verr(P*p,const char*m,Tok t){ if(!p->err.has){ p->err.has=1;p->err.msg=m; p->err.line=t.line;p->err.col=t.col;p->err.start=t.start;p->err.end=t.end;} return (Val){V_ERR,{0}};}
static double to_num(Sv s){ char tmp[128]; size_t m=s.l<127?s.l:127; memcpy(tmp,s.p,m); tmp[m]='\0'; return strtod(tmp,NULL);}
static Val pv(P*p,Arena*a);
static Arr* pa(P*p,Arena*a){
  Tok lb=cur(p); if(lb.t!=T_LB) return NULL;
  adv(p); Arr*ar=mk_arr(a);
  if(cur(p).t==T_RB){ adv(p); return ar;}
  for(;;){
    Val v=pv(p,a); if(v.t==V_ERR){ return ar; }
    arr_push(ar,v,a);
    if(cur(p).t==T_RB){ adv(p); break;}
    if(cur(p).t==T_COM){ adv(p); continue;}
    verr(p,"expected ',' or ']'", cur(p)); break;
  }
  return ar;
}
static Obj* po(P*p,Arena*a){
  if(cur(p).t!=T_LC) return NULL; adv(p); Obj*o=mk_obj(a);
  if(cur(p).t==T_RC){ adv(p); return o;}
  for(;;){
    Tok k=cur(p); if(k.t!=T_STR){ verr(p,"object key must be string",k); break;}
    adv(p);
    if(cur(p).t!=T_COL){ verr(p,"expected ':' after key",cur(p)); break;}
    adv(p);
    Val v=pv(p,a); if(v.t==V_ERR){ /* keep */ }
    obj_push(o,(Pair){k.txt,v},a);
    if(cur(p).t==T_RC){ adv(p); break;}
    if(cur(p).t==T_COM){ adv(p); continue;}
    verr(p,"expected ',' or '}'", cur(p)); break;
  }
  return o;
}
static Val pv(P*p,Arena*a){
  Tok c=cur(p);
  switch(c.t){
    case T_NULL: adv(p); return vnull();
    case T_TRUE: adv(p); return vbool(1);
    case T_FALSE: adv(p); return vbool(0);
    case T_NUM: adv(p); return vnum(to_num(c.txt));
    case T_STR: adv(p); return vstr(c.txt);
    case T_LB: return varr(pa(p,a));
    case T_LC: return vobj(po(p,a));
    case T_EOF: return verr(p,"unexpected end of input",c);
    default: adv(p); return verr(p,"unexpected token in value",c);
  }
}
int parse_json(P*p,Arena*a,Val**out){ p->i=0; err_clear(&p->err); Val*v=pv(p,a); if(!v.t==V_ERR && cur(p).t!=T_EOF){ /* optional: trailing */ } if(v.t==V_ERR){ *out=NULL; p->err.line = v.t==V_ERR? p->err.line:p->err.line; return 0;} *out=v; if(cur(p).t!=T_EOF){ /* ignore trailing? or ok */ } return 1;}
```

## 9) query.h / query.c (filtros simples)

```c
// query.h
#ifndef MJ_QUERY_H
#define MJ_QUERY_H
#include "ast.h"
#include "sv.h"
typedef int (*Pred)(const Val*,void*);
const Val* obj_get(const Obj*,Sv key);
int is_null(const Val*v); int is_bool(const Val*v); int is_num(const Val*v); int is_str(const Val*v); int is_arr(const Val*v); int is_obj(const Val*v);
double numv(const Val*v); int boolv(const Val*v); Sv strv(const Val*v);
// filtros
size_t count_arr_if(const Arr*,Pred,void*);
void   dump_val(const Val*,int);
void   dump_jsonlike(const Val*,int); // simples
#endif

// query.c
#include "query.h"
#include <stdio.h>
const Val* obj_get(const Obj*o,Sv k){ if(!o) return NULL; for(size_t i=0;i<o->n;i++) if(sv_eq(o->p[i].k,k)) return &o->p[i].v; return NULL;}
int is_null(const Val*v){return v&&v->t==V_NULL;} int is_bool(const Val*v){return v&&v->t==V_BOOL;} int is_num(const Val*v){return v&&v->t==V_NUM;} int is_str(const Val*v){return v&&v->t==V_STR;} int is_arr(const Val*v){return v&&v->t==V_ARR;} int is_obj(const Val*v){return v&&v->t==V_OBJ;}
double numv(const Val*v){return is_num(v)?v->u.num:0.0;} int boolv(const Val*v){return is_bool(v)?v->u.b:0;} Sv strv(const Val*v){return is_str(v)?v->u.str:(Sv){0};}
size_t count_arr_if(const Arr*a,Pred fn,void*ctx){ size_t c=0; if(!a) return 0; for(size_t i=0;i<a->n;i++) if(fn(&a->it[i],ctx)) c++; return c;}
void dump_val(const Val*v,int ind){
  switch(v->t){
    case V_NULL: printf("null"); break;
    case V_BOOL: printf("%s",v->u.b?"true":"false"); break;
    case V_NUM: printf("%.6g",v->u.num); break;
    case V_STR: printf("\""); for(size_t i=0;i<v->u.str.l;i++){char ch=v->u.str.p[i]; if(ch=='\\'||ch=='"') printf("\\%c",ch); else if(ch=='\n') printf("\\n"); else if(ch=='\t') printf("\\t"); else putchar(ch);} printf("\""); break;
    case V_ARR:{ printf("["); for(size_t i=0;i<v->u.arr->n;i++){ if(i) printf(","); dump_val(&v->u.arr->it[i],ind+1);} printf("]"); break;}
    case V_OBJ:{ printf("{"); for(size_t i=0;i<v->u.obj->n;i++){ if(i) printf(","); printf("\""); fwrite(v->u.obj->p[i].k.p,1,v->u.obj->p[i].k.l,stdout); printf("\":"); dump_val(&v->u.obj->p[i].v,ind+1);} printf("}"); break;}
    default: printf("null"); break;
  }
}
```

## 10) main.c (I/O + exemplos de filtros)

```c
// main.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sv.h"
#include "arena.h"
#include "lex.h"
#include "ast.h"
#include "parser.h"
#include "query.h"
#include "err.h"

char* read_all(const char*path,size_t*n){
  FILE*f=fopen(path,"rb"); if(!f)return NULL; fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET); char*b=malloc(sz+1); if(!b){fclose(f);return NULL;} fread(b,1,sz,f); b[sz]='\0'; fclose(f); *n=sz; return b;
}

// pred: age >= lim
struct AgeCtx{double lim;};
static int pred_age_geq(const Val*v,void*ctx){ struct AgeCtx*c=ctx; if(!is_obj(v)) return 0; const Val*av=obj_get(v->u.obj,sv_cstr("age")); return av&&is_num(av)&&av->u.num>=c->lim;}

int main(int argc,char**argv){
  if(argc<2){ fprintf(stderr,"usage: %s file.jsonl_or_json\n",argv[0]); return 1;}
  size_t n; char*buf=read_all(argv[1],&n); if(!buf){ perror("read"); return 1;}
  TokList tl={0}; Err e={0};
  if(!lex_all(buf,n,&tl,&e)){ err_print(stderr,&e,buf,n); tl_free(&tl); free(buf); return 1;}
  Arena*a=arena_new(1<<20);
  P p={tl.v,tl.n,0,{0},{0},buf,n};
  Val*root=NULL;
  if(!parse_json(&p,a,&root)){ err_print(stderr,&p.err,buf,n); tl_free(&tl); arena_free(a); free(buf); return 1;}
  // dump
  dump_val(root,0); putchar('\n');
  // exemplo: filtrar array
  if(is_arr(root)){
    struct AgeCtx c={30.0};
    size_t m=count_arr_if(root->u.arr,pred_age_geq,&c);
    printf("count age>=30: %zu\n", m);
  }
  tl_free(&tl); arena_free(a); free(buf); return 0;
}
```

## 11) Build + teste

```bash
mkdir -p build
cc -Wall -Wextra -std=c99 -O2 -g -o build/mini-jl sv.c arena.c err.c lex.c ast.c parser.c query.c main.c
```

Teste 1 (JSON simples):

```json
[{"name":"Ana","age":25},{"name":"Bruno","age":31}]
```

```bash
./build/mini-jl data.json
# [{"name":"Ana","age":25},{"name":"Bruno","age":31}]
# count age>=30: 1
```

Teste 2 (erros com contexto):

```json
{"age": }
```

```text
parse error: expected value, got '}' at line 1, col 8
{"age": }
        ^
```

Teste 3 (primitivos + aninhado):

```json
{"items":[true,null,{"v":-1.5}]}
```

OK.

## 12) Trade-offs neste exemplo

| Escolha | Prós | Contras |
|---|---|---|
| **Arrays heap (`realloc`) p/ Arr/Obj** | Grow fácil, simples | Mais malloc vs arena 100% |
| **StrView (Sv)** | Zero-copy | Lifetime vinculado a `buf` |
| **Fail-fast** | DX clara | 1 erro só |
| **RD manual** | Didático, sem deps | Código manual |
| **Subset mínimo** | Foco nos conceitos | Sem unicode `\u` completo |
| **Double p/ números** | Simples | Perde precisão ints grandes |

**Pragmático:** equilíbrio bom p/ aprender.

## 13) Extensões naturais

- `Sv` com hash p/ intern/chaves
- Arena 100% p/ AST (estimar cap)
- Suporte `\uXXXX` básico
- Iteradores `ArrIter/ObjIter`
- `obj_get_cstr` helper
- Trailing comma? não (JSON strict) — opcional

## 14) Checklist funcional

- [ ] Lê arquivo inteiro
- [ ] Lexer gera tokens corretos
- [ ] Erros com linha/col + caret
- [ ] Parse primitivos, array, objeto
- [ ] AST usável (arrays contíguos)
- [ ] Dump JSON-like funciona
- [ ] Filtro `count_arr_if` ok
- [ ] Sem leaks óbvios (malloc+free básicos)
- [ ] Build limpa com -Wall

## 15) Próximo passo

Vá para: [[12-tradeoffs-cheatsheet]] – referência rápida consolidada de todas as decisões.