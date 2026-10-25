---
title: "Email Clients — Recommendations"
description: "Curated recommendations for terminal-based email clients suitable for git patch workflows"
tags:
  - email
  - tui
  - terminal
  - recommendations
  - git
  - linux
categories: email
type: reference-list
status: draft
created: 2026-09-28
updated: 2026-10-12
related:
  - git-email-workflow
  - himalaya-email-client
  - matcha-email-client
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document email client recommendations"
ai-review: pending
language: en
audience: user
scope: terminal email client recommendations
keywords:
  - aerc
  - himalaya
  - matcha
  - neomutt
  - git send-email
platform:
  - Linux
  - terminal
cssclasses:
  - reference
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Email Clients — Recommendations

Top Recommendations

1. aerc — Best for Git patch workflow

- Written in Go, designed specifically for code review / patch-by-email workflows
- Built-in Git email patch support — can apply patches directly from the email view with :pipe or git am
- Tabbed TUI, supports IMAP/SMTP and JMAP
- Works great with git send-email and git format-patch
- Recommended by the Linux kernel community
- Install: sudo apt install aerc / sudo pacman -S aerc

2. NeoMutt — Most customizable

- The modern fork of Mutt, decades of ecosystem
- Works with git send-email via sendmail command configuration
- GPG support, complex filtering, macros
- Steeper learning curve but extremely powerful
- Install: sudo apt install neomutt

3. Himalaya — CLI-first, modern
- CLI email client with a TUI mode (via himalaya tui)
- Written in Rust, supports IMAP/SMTP
- Can be scripted to work with git send-email
- Install: cargo install himalaya or via package manager

4. matcha — Beautiful Bubble Tea TUI
- Newer client built with Go + Bubble Tea
- Modern UI, supports plugins, PGP, spellcheck
- Less mature for Git workflows but actively developed
