---
title: "Performance Measurement Without Myths"
tags:
  - c
  - performance
  - benchmarking
  - profiling
  - tutorial
type: guide
status: evergreen
created: 2026-10-15
updated: 2026-10-15
review_after: 2027-04-15
related:
  - "[[02-memory-layout-and-tradeoffs]]"
  - "[[09-filtering-querying-over-structured-data]]"
  - "[[11-mini-json-like-parser-with-filters]]"
  - "[[12-tradeoffs-cheatsheet]]"
description: "Medir performance sem mitos: como evitar benchmarks enganosos."
language: pt-BR
audience: developer
scope: "medição de performance"
keywords:
  - c
  - performance
  - benchmark
platform:
  - C
  - Linux
cssclasses:
  - nota-longa
last_reviewed: 2026-10-15
---
# Performance Measurement Without Myths

> [!summary]
> **Mensure antes de otimizar.** A regra é clara: hipótese -> medição -> decisão. Foco em: como medir realisticamente em C puro, evitar armadilhas comuns, usar ferramentas simples (`time`, `perf`, `valgrind`), fazer microbenchmarks honestos e distinguir "mais rápido teoricamente" de "impacto real".

## 1) Mentalidade certa

- **"Premature optimization is the root of evil"** — mas **ignorar layout é pior** ([[02-memory-layout-and-tradeoffs]])
- **Otimize gargalos observados**, não intuições
- **Legibilidade primeiro**. Só troque por mais rápido com **ganho mensurável**
- **10x em microbench irrelevante** pode ser 0.1% no todo
- **Dados reais > dados sintéticos**

## 2) O que medir?

Foque em **caminho crítico** do seu parser:

1. **I/O** – ler arquivo inteiro
2. **Lexer** – varrer bytes, gerar tokens
3. **Parser** – construir AST
4. **Query/Filter** – iterar + predicados
5. **Alocações** – `malloc` vs arena
6. **Cache misses** – localidade

**Pergunte:** "Onde tempo realmente vai?"

## 3) Ferramentas simples

| Ferramenta | Uso | Notas |
|---|---|---|
| **`time`** | Medição wall/user/sys | Simples, suficiente p/ visão geral |
| **`perf stat`** | Instruções, ciclos, cache-misses, branches | Ótimo p/ entender **por quê** |
| **`perf record/report`** | Flamegraph-like, hotspots | Ver onde gasta mais |
| **`valgrind --tool=callgrind`** | Call counts + instruções | Preciso, mais lento |
| **`valgrind --tool=massif`** | Uso heap ao longo do tempo | Ótimo p/ alocações |
| **`hyperfine`** | Benchmark estatístico (múltiplas runs) | Evita ruído |
| **`clock_gettime(CLOCK_MONOTONIC)`** | Timing interno em C | Preciso p/ microbench isolado |

## 4) Medição externa com `time` / `hyperfine`

Simples e realista.

```bash
time ./mini-json data.json
```

```bash
hyperfine --warmup 3 './mini-json data.json'
```

**`hyperfine`** roda várias vezes, mostra média + desvio. **Recomendado**.

## 5) Medição interna com `clock_gettime`

Pra isolar fases:

```c
#include <time.h>

static double now_ms(void){
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec*1000.0 + ts.tv_nsec/1e6;
}

int main(){
    double t0=now_ms();
    // lex
    double t1=now_ms(); printf("lex: %.2fms\n", t1-t0);
    // parse
    double t2=now_ms(); printf("parse: %.2fms\n", t2-t1);
    // query
    double t3=now_ms(); printf("query: %.2fms\n", t3-t2);
}
```

**Dica:** rode várias vezes ou com input maior. Evite medir I/O junto se quiser isolar parser.

## 6) Criando dataset realista

**Não** use `[1,2,3,...,1000]` trivial. Use variações reais:

- Pequeno (1–10KB)
- Médio (100–500KB)
- Grande (1–5MB) — se relevante
- Com strings, objetos aninhados, arrays longos

**Mesmo gerador simples ajuda:**

```python
import json,sys
items=[{"id":i,"name":f"u{i}","active":i%2==0,"vals":[i,i*2]} for i in range(int(sys.argv[1]))]
print(json.dumps(items))
```

## 7) Microbenchmarks honestos

**Erros comuns:**

- Medir com **O2** desligado
- Rodar **1 vez só**
- Incluir `printf` no loop medido
- Compilar com debug flags
- Medir código "vazio" por engano
- Ignorar cache warmup

**Boas práticas:**

- Compile com `-O2 -DNDEBUG`
- Faça **warmup** (1–3 runs ignorados)
- Mínimo 10–20 runs
- Desative output no path medido
- Use `hyperfine` ou média estatística
- Isolar função exata

## 8) Exemplo: comparar arena vs malloc por nó

Hipótese: **arena** mais rápida p/ criar 10^4 nodes.

**Teste:**

1. Versão A: `malloc(sizeof(Node))` por token/val
2. Versão B: `arena_alloc` bump

Medir **apenas** fase de alocação/construção.

```bash
hyperfine --warmup 3 './mini-json-malloc big.json' './mini-json-arena big.json'
```

Se diferença < 1–2%, **não vale** trocar legibilidade.

## 9) Entendendo `perf stat`

```bash
perf stat -e cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses ./mini-json data.json
```

Métricas chave:

| Métrica | Significado | Interpretação |
|---|---|---|
| **cycles** | Tempo relativo (CPU cycles) | Menor = geralmente melhor |
| **instructions/cycle (IPC)** | Eficiência | >1 bom, depende CPU |
| **cache-misses / cache-refs** | Taxa de misses | **Baixo** melhor (localidade) |
| **branch-misses / branch-instr** | Branch mispredict | Alto ruim (muitos `if` imprevisíveis) |

**Foco em:** **cache-misses** (reflete localidade) e **time** total.

## 10) Detectando hotspots com `perf record`

```bash
perf record -g ./mini-json big.json
perf report -g 'percent,flat,call'
```

Ver top funções: `lex_next`, `parse_value`, `sv_eq`, etc.

**Flamegraphs** também ótimos visualmente.

## 11) Mitos comuns

### Mito 1: "Função inline sempre melhor"

Verdade: evita call overhead. Mas com `-O2`, **compilador inlineia** automaticamente quando benéfico. Forçar `inline` nem sempre ajuda.

### Mito 2: "Evitar `if`"

`if` barato. **Branch mispredict** custa. Mas loops lineares com `if` previsível (ex: fim de string) ok.

### Mito 3: "Ponteiros são lentos"

Ponteiros são necessários. **Pointer chasing** (seguir muitos ponteiros aleatórios) é lento por **cache miss**.

### Mito 4: "SOA sempre mais rápido que AOS"

Só quando filtra **muito seletivamente** por **poucos campos** com **n grande**. Pra acesso "registro completo", **AOS** vence.

### Mito 5: "Otimize loops primeiro"

Muitas vezes **alocações + cópias strings** dominam, não o loop em si.

### Mito 6: "Medir em debug (-O0)"

Completamente irrelevante. Sempre meça com **-O2** (ou -O3 se quiser, mas -O2 realista).

## 12) Exemplo prático: testar localidade

Comparar iterar array contíguo vs array de ponteiros ([[02-memory-layout-and-tradeoffs]]).

Gerar 10^4 structs, medir loop simples:

```c
// AOS
for(i=0;i<n;i++) sum += arr[i].x;

// vs
// APO (array of ptrs)
for(i=0;i<n;i++) sum += ptrs[i]->x;
```

Com `perf stat` verá **cache-misses muito maior** em APO.

## 13) Quando **NÃO** otimizar

- Ganho < **2–5%** em caso real
- Código fica **menos legível**
- Só aparece em microbench
- Feature/correção mais importante
- Input pequeno sempre

**Regra prática:** só otimizar se resolve **dor percebida** ou mede **impacto claro**.

## 14) Checklist medição

- [ ] Compile com `-O2 -Wall -Wextra`
- [ ] Use `hyperfine` p/ múltiplas runs
- [ ] Meça **fases separadas** quando útil
- [ ] Use dataset **realista**
- [ ] Verifique com `perf stat` (ciclos + cache-misses)
- [ ] Rode warmup
- [ ] Não mede `printf` excessivo
- [ ] Comparação justa (mesmo input/compiler)
- [ ] Documente resultado (antes/depois + input)
- [ ] Prefira **legível** se empate

## 15) Exemplo roteiro

1. **Baseline:** `hyperfine` time total
2. **Profile:** `perf record` -> hotspots
3. **Hipótese:** "arena reduz alocações"
4. **Teste controlado:** medir só construção AST
5. **Medição:** `hyperfine` + `perf stat`
6. **Decisão:** manter simples ou aplicar
7. **Validar:** não quebrou legibilidade?

## 16) Conexão com próximas notas

- [[11-mini-json-like-parser-with-filters]] – Aplica medições no projeto completo
- [[12-tradeoffs-cheatsheet]] – Resumo rápido performance
- [[09-filtering-querying-over-structured-data]] – Onde medir queries

## Exercício prático

1. Rode `time` em seu mini-parser com 2 tamanhos diferentes
2. Use `perf stat` e olhe `cache-misses`
3. Crie dataset com `python` (1000 itens)
4. Compare leitura com `fread` vs alternativas? (só observar)
5. Liste **3 hotspots prováveis** num parser e por quê

## Próximo passo

Vá para: [[11-mini-json-like-parser-with-filters]] – juntar tudo num mini-projeto funcional com lexer+parser+arena+filtros + medições básicas.