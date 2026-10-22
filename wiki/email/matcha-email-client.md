---
title: "matcha"
description: "A beautiful terminal email client built with Go and Bubble Tea, featuring plugins, PGP, spellcheck, and a modern TUI."
tags:
  - email
  - tui
  - terminal
  - matcha
  - client
  - linux
type: reference
status: draft
created: 2026-09-28
updated: 2026-10-12
related:
  - git-email-workflow
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document matcha email client"
ai-review: pending
language: en
audience: user
scope: the matcha terminal email client
keywords:
  - matcha
  - TUI
  - IMAP
  - SMTP
  - email
platform:
  - Linux
  - terminal
cssclasses:
  - reference
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# matcha

matcha is a modern, beautiful terminal email client written in Go using the Bubble Tea TUI framework. It aims to make email in the terminal pleasant and productive without leaving your command line.

## Features

- Modern, responsive TUI built with Bubble Tea
- Multiple account support
- PGP encryption and signing
- Plugin system for extensibility
- Spellcheck in compose mode
- Theme customization
- Notification support
- Cross-platform (Linux, macOS, BSD)

## Installation

### From Source

matcha is written in Go. To build from source:

```bash
# Clone the repository
git clone https://github.com/floatpane/matcha.git
cd matcha

# Build
go build -o matcha ./cmd/matcha

# Install to your GOPATH/bin
go install ./cmd/matcha
```

### Via Package Manager

Check if your distribution packages matcha:

```bash
# Arch (AUR)
yay -S matcha

# Nix
nix-env -iA nixpkgs.matcha
```

### Verify Installation

```bash
matcha --version
```

## Configuration

matcha uses a TOML configuration file. On first run, it creates a default config at:

- Linux: `~/.config/matcha/config.toml`
- macOS: `~/Library/Application Support/matcha/config.toml`

### Basic Configuration

```toml
# ~/.config/matcha/config.toml

[accounts.personal]
email = "your.email@example.com"
display-name = "Your Name"
default = true

[accounts.personal.imap]
host = "imap.gmail.com"
port = 993
username = "your.email@gmail.com"
password = "your-app-password"
tls = true

[accounts.personal.smtp]
host = "smtp.gmail.com"
port = 587
username = "your.email@gmail.com"
password = "your-app-password"
tls = "starttls"
```

### Using a Password Manager

For better security, use a command to fetch your password:

```toml
[accounts.personal.imap]
host = "imap.gmail.com"
port = 993
username = "your.email@gmail.com"
password = { command = "pass show email/gmail" }

[accounts.personal.smtp]
host = "smtp.gmail.com"
port = 587
username = "your.email@gmail.com"
password = { command = "pass show email/gmail" }
```

### Multiple Accounts

```toml
[accounts.personal]
email = "personal@gmail.com"
display-name = "Your Name"
default = true

[accounts.personal.imap]
host = "imap.gmail.com"
port = 993
username = "personal@gmail.com"
password = "app-password-1"

[accounts.personal.smtp]
host = "smtp.gmail.com"
port = 587
username = "personal@gmail.com"
password = "app-password-1"

[accounts.work]
email = "you@company.com"
display-name = "Your Name (Work)"

[accounts.work.imap]
host = "mail.company.com"
port = 993
username = "you@company.com"
password = "work-password"

[accounts.work.smtp]
host = "smtp.company.com"
port = 587
username = "you@company.com"
password = "work-password"
```

## Launching matcha

Simply run:

```bash
matcha
```

Or specify a config file:

```bash
matcha --config /path/to/config.toml
```

## Interface Overview

matcha uses a three-pane layout:

```
┌─────────────────────────────────────────────────────────┐
│  Account: personal@gmail.com          [Inbox]  12 new   │
├──────────┬──────────────────────────────┬───────────────┤
│ Folders  │  Message List                │  Message      │
│          │                              │  Preview      │
│ Inbox 12 │  ● John Doe  Fix bug         │               │
│ Drafts   │    Jane Smith  Re: PR #123   │  From: John   │
│ Sent     │    Bob Wilson  Meeting       │  Subject:...  │
│ Archive  │    Alice Brown  Patch v2     │               │
│ Trash    │                              │  <body>       │
│          │                              │               │
└──────────┴──────────────────────────────┴───────────────┘
```

### Panes

1. **Folder pane** (left) — navigate mailboxes
2. **Message list** (center) — see emails in selected folder
3. **Preview pane** (right) — read selected email

## Key Bindings

### Global

| Key | Action |
|-----|--------|
| `q` / `Ctrl+C` | Quit |
| `?` | Show help |
| `a` | Switch account |
| `r` | Refresh / sync mail |
| `c` | Compose new email |
| `e` | Archive selected email |
| `d` | Move to trash |
| `s` | Star / unstar email |
| `g` | Go to folder (prompt) |
| `Tab` | Cycle focus between panes |

### Navigation

| Key | Action |
|-----|--------|
| `j` / `Down` | Move down |
| `k` / `Up` | Move up |
| `h` / `Left` | Collapse / go left |
| `l` / `Right` | Expand / go right |
| `Enter` | Open selected email |
| `Esc` | Go back / close |
| `gg` | Jump to top |
| `G` | Jump to bottom |
| `Ctrl+D` | Page down |
| `Ctrl+U` | Page up |

### Compose Mode

| Key | Action |
|-----|--------|
| `Ctrl+S` | Send email |
| `Ctrl+C` | Cancel compose |
| `Ctrl+A` | Add attachment |
| `Ctrl+T` | Edit recipients |
| `Tab` | Next field |
| `Shift+Tab` | Previous field |

### Message List

| Key | Action |
|-----|--------|
| `v` | View raw message source |
| `f` | Forward email |
| `R` | Reply all |
| `r` | Reply to sender |
| `A` | Reply with attachment |
| `m` | Move to folder |
| `t` | Toggle read/unread |

## Composing Email

### New Email

Press `c` from the main view. This opens the compose screen:

```
To:      your.friend@example.com
Cc:
Bcc:
Subject: Hello from matcha

<body — type your message here>

[Ctrl+S] Send  [Ctrl+C] Cancel  [Ctrl+A] Attach
```

### Replying

With an email selected, press `r` to reply. matcha automatically:
- Sets `To:` to the original sender
- Sets `Subject:` to `Re: <original subject>`
- Quotes the original message in the body

### Forwarding

Press `f` to forward. The original message is included as an attachment.

### Attachments

Press `Ctrl+A` in compose mode to add attachments. Browse your filesystem and select files.

### Spellcheck

matcha includes built-in spellcheck in compose mode. Misspelled words are highlighted. Press `Ctrl+W` to cycle suggestions.

## Working with Patches

matcha can be used as part of the git email workflow (see [git-email-workflow](git-email-workflow.md)).

### Receiving Patches

When you receive a patch email:
1. Open the email in matcha
2. Press `v` to view raw source
3. Copy the patch content (from `From <hash>` to the end)
4. Save to a file: `0001-some-fix.patch`
5. Apply with `git am 0001-some-fix.patch`

### Sending Patches

1. Generate patches with `git format-patch`
2. Open matcha and compose a new email
3. Set `To:` and `Subject:` from the patch
4. Paste the patch body (plain text only)
5. Send with `Ctrl+S`

> **Important:** Always send patches as plain text. HTML formatting corrupts patches and they will not apply cleanly.

## PGP Encryption

matcha supports PGP for signing and encrypting emails.

### Setup

1. Generate a PGP key (if you do not have one):

```bash
gpg --full-generate-key
```

2. Configure matcha to use your key:

```toml
[pgp]
key-id = "YOUR_KEY_ID"
auto-sign = true
auto-encrypt = true
```

### Usage

- Emails are automatically signed if `auto-sign = true`
- If the recipient's public key is in your keyring, encryption is automatic
- Use `Ctrl+P` in compose mode to toggle sign/encrypt manually

## Plugins

matcha supports plugins written in Lua. Plugins can add commands, key bindings, and hooks.

### Installing Plugins

Place plugin scripts in `~/.config/matcha/plugins/`:

```bash
mkdir -p ~/.config/matcha/plugins
```

### Example Plugin

```lua
-- ~/.config/matcha/plugins/save-patch.lua
-- Adds a key binding to save the current email as a patch file

local M = {}

function M.save_patch()
    local filename = os.date("%Y%m%d-%H%M%S") .. ".patch"
    local path = os.getenv("HOME") .. "/patches/" .. filename
    -- Save current message body to path
    matcha.save_to_file(path)
    matcha.notify("Saved patch to " .. path)
end

function M.register()
    matcha.bind_key("Ctrl+P", M.save_patch)
end

return M
```

## Theming

matcha supports custom themes. Create a theme file:

```toml
# ~/.config/matcha/themes/dracula.toml

[colors]
background = "#282a36"
foreground = "#f8f8f2"
primary = "#bd93f9"
secondary = "#6272a4"
success = "#50fa7b"
warning = "#f1fa8c"
error = "#ff5555"
muted = "#6272a4"

[ui]
border-style = "rounded"
```

Activate a theme:

```toml
# ~/.config/maicha/config.toml
[ui]
theme = "dracula"
```

## Notifications

matcha can send desktop notifications for new mail:

```toml
[notifications]
enable = true
command = "notify-send"
title = "New email"
body = "From: %{from}\nSubject: %{subject}"
```

## Troubleshooting

### Cannot connect to IMAP server

- Verify hostname and port
- Check if your provider requires app-specific passwords
- Ensure TLS settings match your provider
- Test with `openssl s_client -connect imap.gmail.com:993`

### Authentication failure

- For Gmail: use an [App Password](https://support.google.com/accounts/answer/185833), not your regular password
- For Outlook: enable SMTP AUTH in account settings
- Check if your account requires OAuth2 (matcha may not support it yet)

### Emails not appearing

- Press `r` to force a sync
- Check folder subscriptions in your email provider's web interface
- Verify the folder exists and is not hidden

### Compose mode crashes

- Ensure your `EDITOR` environment variable is set
- Try setting `EDITOR=nano` or `EDITOR=vim` in your shell

## Tips and Tricks

### Integration with git send-email

Use matcha for reading and git send-email for sending:

```bash
# Read patches in matcha
matcha

# Send patches via command line
git send-email outgoing/*.patch
```

### Integration with tmux

Run matcha inside a tmux session for persistent email:

```bash
tmux new-session -s email -d 'matcha'
tmux attach -t email
```

### Quick Folder Navigation

Press `g` then type a folder name to jump directly to it:

```
g → Inbox → Enter
```

### Mark All as Read

Press `Shift+A` to mark all messages in the current folder as read.

## Summary

matcha is a modern, beautiful terminal email client that brings a polished TUI experience to email. It supports multiple accounts, PGP, plugins, and theming. While it can be used for the git email workflow, it pairs best with `git send-email` for sending patches to ensure they arrive unmodified.

## Resources

- [matcha GitHub Repository](https://github.com/floatpane/matcha)
- [Bubble Tea TUI Framework](https://github.com/charmbracelet/bubbletea)
- [Git Email Workflow](git-email-workflow.md)
