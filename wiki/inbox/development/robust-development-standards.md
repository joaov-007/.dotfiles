---
title: "Padrões robustos de desenvolvimento"
aliases:
  - robust development standards
  - padrões de desenvolvimento
  - engineering standards
description: >-
  Padrão curto do time para desenvolvimento robusto: controle de versão, revisão, testes, CI/CD,
  segurança, confiabilidade e documentação, adaptado ao fluxo NixOS/dotfiles.
tags:
  - development
  - standards
  - best-practices
  - security
  - ci-cd
  - testing
type: reference
status: draft
created: 2026-11-27
updated: 2026-11-27
last_reviewed: 2026-11-27
review_after: 2027-05-27
language: pt-BR
audience: maintainer
scope: Padrões mínimos de engenharia para o time Dev
related:
  - "[[Home]]"
  - "[[git-email-workflow]]"
  - "[[rust-tools]]"
cssclasses:
  - reference
keywords:
  - code review
  - testing
  - CI/CD
  - DevSecOps
  - NixOS
  - dotfiles
sources:
  - title: "Google Engineering Practices"
    url: "https://google.github.io/eng-practices/"
    kind: reference
    supports: "Revisão de código e práticas de engenharia"
  - title: "Microsoft Engineering Fundamentals Playbook"
    url: "https://microsoft.github.io/code-with-engineering-playbook/"
    kind: reference
    supports: "Checklist de fundamentos, CI/CD, testes, segurança"
  - title: "Software Engineering at Google"
    url: "https://abseil.io/resources/swe-book/html/ch09.html"
    kind: book
    supports: "Consistência e manutenibilidade de código"
  - title: "SWEBOK v4"
    url: "https://ieeecs-media.computer.org/media/education/swebok/swebok-v4.pdf"
    kind: reference
    supports: "Corpo de conhecimento de engenharia de software"
  - title: "MITRE DevSecOps Best Practices Guide"
    url: "https://saf.mitre.org/DevSecOps_Best_Practices_Guide.pdf"
    kind: guide
    supports: "Segurança integrada ao pipeline"
---

# Padrões robustos de desenvolvimento

> [!summary] Resumo
> Mudanças pequenas, versionadas, revisadas e verificáveis. Segurança e confiabilidade não são
> etapa final: entram no design, no código, no CI e na operação. No nosso fluxo, “feito” inclui
> evidência (build/test/lint) e comando de verificação/rollback quando aplicável.

## Princípios

- **Simples e explícito**: prefira a solução menor que resolve; evite complexidade sem ganho claro.
- **Reproduzível**: builds e scripts devem rodar do mesmo jeito localmente e no CI.
- **Menor privilégio**: acesso, segredos e permissões só no necessário.
- **Evidência antes de “done”**: valide com comando/resultado, não só opinião.
- **Falha segura**: trate erro, timeout e rollback; não exponha segredos em logs.

## Checklist por mudança

### 1) Controle de versão
- [ ] Mudança pequena e rastreável (commit/PR com contexto).
- [ ] Sem segredos, tokens, chaves privadas ou dados sensíveis no diff.
- [ ] `.gitignore` cobre artefatos gerados (`result`, `target/`, caches locais, etc.).
- [ ] Mensagem de commit descreve o *porquê*; inclua Co-authored-by quando aplicável.

### 2) Código e scripts
- [ ] Código legível: nomes claros, funções curtas, sem mágica desnecessária.
- [ ] Shell scripts: POSIX quando pedido, `set -eu` (ou equivalente consciente), quoting correto.
- [ ] Lint/format: `shellcheck` e teste com `dash` para scripts POSIX; formatter/linter da linguagem.
- [ ] Em NixOS/dotfiles: prefira mudança declarativa; evite instalar imperativamente no sistema.

### 3) Revisão
- [ ] Diff revisável (evite PR gigante sem necessidade).
- [ ] Revisor verifica correção, segurança, testes e impacto operacional.
- [ ] Comentários viram ação ou decisão explícita.

### 4) Testes e validação
- [ ] Rodar o teste/lint/build mais próximo da mudança.
- [ ] Para NixOS: `nixos-rebuild build --flake <path>#<host>` antes de switch quando possível.
- [ ] Registrar evidência: comando, resultado, e o que não foi verificado.
- [ ] Não declarar “funcionando” sem verificação.

### 5) CI/CD e entrega
- [ ] Pipeline deve rodar lint, testes e build em mudanças relevantes.
- [ ] Artefato/deploy reproduzível; versão rastreável.
- [ ] Plano de rollback claro (geração NixOS anterior, git revert, etc.).

### 6) Segurança (DevSecOps)
- [ ] Segredos em vault/env seguro; nunca em arquivo versionado.
- [ ] Dependências revisadas; evitar pacotes sem manutenção.
- [ ] Validar inputs e tratar caminhos/arquivos com cuidado.
- [ ] Logs úteis, sem vazar credenciais ou dados pessoais.
- [ ] Para mudanças de risco (delete/send/pay/auth): pedir confirmação explícita.

### 7) Confiabilidade e operação
- [ ] Timeouts/retries com limite onde houver rede/IO.
- [ ] Idempotência quando possível (scripts seguros para rodar de novo).
- [ ] Observabilidade mínima: logs claros, códigos de saída, mensagens de erro acionáveis.
- [ ] Documentar limitações e trade-offs.

## Definição de pronto (DoD)

Uma tarefa está pronta quando:

1. O requisito foi atendido ou o bloqueio está explicitado.
2. Há evidência de validação (comando + resultado).
3. Riscos/limitações foram reportados.
4. O próximo passo do usuário está claro (ex.: `run0 nixos-rebuild switch ...`).
5. Nenhum segredo foi exposto.

## Adaptação ao nosso fluxo (NixOS/dotfiles)

- **Config declarativa**: mudanças de sistema vão para módulos Nix; validar com build antes de switch.
- **Sem sudo cego**: rebuild/switch requer ação explícita do usuário.
- **Scripts**: POSIX + `shellcheck` + `dash` quando aplicável; usar `nix shell` para ferramentas de lint.
- **Wiki**: atualizar notas com cuidado, sem inventar; marcar estado verificado vs. pendente.
- **Segurança**: preferir ferramentas mantidas no nixpkgs; documentar ausências/limitações.

## Fontes

- Google Engineering Practices — https://google.github.io/eng-practices/
- Microsoft Engineering Fundamentals Playbook — https://microsoft.github.io/code-with-engineering-playbook/
- Software Engineering at Google — https://abseil.io/resources/swe-book/html/ch09.html
- SWEBOK v4 — https://ieeecs-media.computer.org/media/education/swebok/swebok-v4.pdf
- MITRE DevSecOps Best Practices Guide — https://saf.mitre.org/DevSecOps_Best_Practices_Guide.pdf
