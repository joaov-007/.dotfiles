---
title: "himalaya"
description: "A modern CLI and TUI email client written in Rust, supporting IMAP, SMTP, multiple accounts, and scriptable commands."
tags:
  - email
  - tui
  - terminal
  - himalaya
  - client
  - rust
  - linux
categories: email
type: reference
status: draft
created: 2026-09-28
updated: 2026-10-12
related:
  - git-email-workflow
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document himalaya email client"
ai-review: pending
language: en
audience: user
scope: the Himalaya CLI email client
keywords:
  - himalaya
  - CLI
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

# himalaya

himalaya is a modern email client written in Rust that provides both a command-line interface (CLI) and a terminal user interface (TUI). It is designed to be fast, scriptable, and easy to integrate into terminal-based workflows.

## Features

- CLI-first design with TUI mode
- IMAP and SMTP support
- Multiple account management
- Scriptable and automatable
- Message composition in external editor
- Attachment handling
- Message filtering and search
- Rust-based performance and safety

## Installation

### Via Cargo

```bash
cargo install himalaya
```

### Via Package Manager

```bash
# Arch (AUR)
yay -S himalaya

# Homebrew (macOS/Linux)
brew install himalaya

# Nix
nix-env -iA nixpkgs.himalaya
```

### Verify Installation

```bash
himalaya --version
```

## Configuration

himalaya uses a TOML configuration file at `~/.config/himalaya/config.toml`.

### Minimal Configuration

```toml
# ~/.config/himalaya/config.toml

[accounts.personal]
email = "your.email@example.com"
display-name = "Your Name"
default = true

[accounts.personal.backend]
type = "imap"
host = "imap.gmail.com"
port = 993
encryption = "tls"
login = "your.email@gmail.com"
passwd = { type = "raw", value = "your-app-password" }

[accounts.personal.sender]
type = "smtp"
host = "smtp.gmail.com"
port = 587
encryption = "starttls"
login = "your.email@gmail.com"
passwd = { type = "raw", value = "your-app-password" }
```

### Using a Password Manager

For better security, fetch passwords from a command:

```toml
[accounts.personal.backend]
type = "imap"
host = "imap.gmail.com"
port = 993
encryption = "tls"
login = "your.email@gmail.com"
passwd = { type = "command", value = "pass show email/gmail" }

[accounts.personal.sender]
type = "smtp"
host = "smtp.gmail.com"
port = 587
encryption = "starttls"
login = "your.email@gmail.com"
passwd = { type = "command", value = "pass show email/gmail" }
```

### Multiple Accounts

```toml
[accounts.personal]
email = "personal@gmail.com"
display-name = "Your Name"
default = true

[accounts.personal.backend]
type = "imap"
host = "imap.gmail.com"
port = 993
encryption = "tls"
login = "personal@gmail.com"
passwd = { type = "command", value = "pass show email/gmail" }

[accounts.personal.sender]
type = "smtp"
host = "smtp.gmail.com"
port = 587
encryption = "starttls"
login = "personal@gmail.com"
passwd = { type = "command", value = "pass show email/gmail" }

[accounts.work]
email = "you@company.com"
display-name = "Your Name (Work)"

[accounts.work.backend]
type = "imap"
host = "mail.company.com"
port = 993
encryption = "tls"
login = "you@company.com"
passwd = { type = "command", value = "pass show email/work" }

[accounts.work.sender]
type = "smtp"
host = "smtp.company.com"
port = 587
encryption = "starttls"
login = "you@company.com"
passwd = { type = "command", value = "pass show email/work" }
```

### Backend Types

himalaya supports multiple backend types:

| Type | Description |
|------|-------------|
| `imap` | IMAP for receiving mail |
| `smtp` | SMTP for sending mail |
| `maildir` | Local maildir storage |
| `notmuch` | Notmuch email database |

## CLI Commands

himalaya is CLI-first. All operations can be performed from the command line.

### Account Management

```bash
# List configured accounts
himalaya account list

# Check account configuration
himalaya account check personal
```

### Reading Email

```bash
# List messages in inbox
himalaya envelope list

# List messages in a specific folder
himalaya envelope list --folder "INBOX"

# List with pagination
himalaya envelope list --page 1 --page-size 20

# Search messages
himalaya envelope list --filter "from:github.com"

# Read a specific message
himalaya message read <id>

# Read message as raw source
himalaya message read <id> --raw
```

### Composing and Sending

```bash
# Compose a new message (opens in $EDITOR)
himalaya message new

# Compose with preset recipients
himalaya message new --to "friend@example.com" --subject "Hello"

# Send a message from a file
himalaya message send < message.txt

# Reply to a message
himalaya message reply <id>

# Reply to all
himalaya message reply <id> --all

# Forward a message
himalaya message forward <id>
```

### Managing Messages

```bash
# Mark as read
himalaya message mark <id> --read

# Mark as unread
himalaya message mark <id> --unread

# Move to folder
himalaya message move <id> --folder "Archive"

# Delete a message
himalaya message delete <id>

# Copy to another folder
himalaya message copy <id> --folder "Backup"
```

### Attachments

```bash
# Download attachments from a message
himalaya attachment download <id>

# Download to specific directory
himalaya attachment download <id> --dir ~/Downloads
```

### Folders

```bash
# List all folders
himalaya folder list

# Add a folder to the list
himalaya folder add "Lists/Linux-Kernel"

# Expunge (permanently delete) messages marked for deletion
himalaya folder expunge
```

## TUI Mode

Launch the interactive TUI:

```bash
himalaya tui
```

### TUI Layout

```
┌─────────────────────────────────────────────────────────┐
│  himalaya — personal@gmail.com                          │
├──────────┬──────────────────────────────┬───────────────┤
│ Folders  │  Messages                    │  Preview      │
│          │                              │               │
│ INBOX 12 │  ● John Doe     Fix bug      │  From: John   │
│ Drafts   │    Jane Smith   Re: PR #123  │  To: me       │
│ Sent     │    Bob Wilson   Meeting      │  Subject:...  │
│ Archive  │    Alice Brown  Patch v2     │               │
│ Trash    │                              │  <body>       │
│          │                              │               │
└──────────┴──────────────────────────────┴───────────────┘
```

### TUI Key Bindings

| Key | Action |
|-----|--------|
| `q` | Quit |
| `j` / `k` | Navigate down / up |
| `h` / `l` | Focus left / right pane |
| `Enter` | Open selected message |
| `c` | Compose new message |
| `r` | Reply |
| `R` | Reply all |
| `f` | Forward |
| `d` | Delete |
| `m` | Move to folder |
| `s` | Star / unstar |
| `g` | Go to folder |
| `a` | Add folder |
| `e` | Expunge folder |
| `?` | Help |
| `Tab` | Next pane |
| `Shift+Tab` | Previous pane |
| `Ctrl+R` | Refresh |

## Working with Patches

himalaya integrates well with the git email workflow (see [git-email-workflow](git-email-workflow.md)).

### Receiving Patches via CLI

```bash
# Find the patch email
himalaya envelope list --filter "subject:[PATCH]"

# Read the patch
himalaya message read <id> --raw > 0001-fix.patch

# Apply it
git am 0001-fix.patch
```

### Receiving Patches via TUI

1. Open the patch email in himalaya TUI
2. Press `v` to view raw source
3. Copy the patch content
4. Save to a file and apply with `git am`

### Sending Patches

himalaya can send patches, but `git send-email` is recommended for patch delivery to ensure patches are not modified:

```bash
# Generate patches
git format-patch origin/main -o outgoing/

# Send with git send-email (recommended)
git send-email --to="maintainer@example.com" outgoing/

# Or send via himalaya (for regular email)
himalaya message new --to "maintainer@example.com" \
  --subject "[PATCH] Fix memory leak" \
  --body-file outgoing/0001-fix.patch
```

## Scripting and Automation

himalaya's CLI design makes it ideal for scripting.

### Sync and Check for New Mail

```bash
#!/bin/bash
# ~/bin/check-mail.sh

himalaya envelope list --filter "is:unread" | while read -r line; do
    echo "New mail: $line"
    notify-send "New email" "$line"
done
```

### Auto-Download Attachments

```bash
#!/bin/bash
# ~/bin/fetch-attachments.sh

himalaya envelope list --filter "has:attachment" | while read -r id; do
    himalaya attachment download "$id" --dir ~/Downloads
done
```

### Cron Job for Periodic Sync

```cron
# Sync every 15 minutes
*/15 * * * * himalaya envelope list --folder INBOX > /dev/null 2>&1
```

## Advanced Configuration

### Custom Editor

```toml
[composer]
editor = "vim"
```

### Message Format

```toml
[composer]
format = "plain"  # or "html"
```

### Default Folders

```toml
[folders]
inbox = "INBOX"
sent = "Sent"
drafts = "Drafts"
trash = "Trash"
archive = "Archive"
```

### Signing (PGP)

```tl
[pgp]
key-id = "YOUR_KEY_ID"
auto-sign = true
auto-encrypt = false
```

## Troubleshooting

### Cannot Connect to IMAP

```bash
# Test connectivity
openssl s_client -connect imap.gmail.com:993

# Check if app password is required
# Gmail requires app passwords for third-party clients
```

### Authentication Failure

- Gmail: use an [App Password](https://support.google.com/accounts/answer/185833)
- Outlook: enable SMTP AUTH in account settings
- Check if your provider requires OAuth2 (himalaya may not support it)

### Messages Not Syncing

```bash
# Force a refresh
himalaya envelope list --refresh

# Check folder subscriptions
himalaya folder list
```

### TUI Rendering Issues

```bash
# Reset terminal
reset

# Try with a different TERM value
TERM=xterm-256color himalaya tui
```

## Tips and Tricks

### Integration with git send-email

Use himalaya for reading and git send-email for sending patches:

```bash
# Read patches in himalaya
himalaya tui

# Send patches via CLI
git send-email outgoing/*.patch
```

### Integration with tmux

```bash
# Start himalaya in a tmux session
tmux new-session -s mail -d 'himalaya tui'

# Attach later
tmux attach -t mail
```

### Quick Search

```bash
# Search by sender
himalaya envelope list --filter "from:linus@kernel.org"

# Search by subject
himalaya envelope list --filter "subject:[PATCH]"

# Search by date
himalaya envelope list --filter "after:2026-09-01"
```

### Export Messages

```bash
# Export a message as raw MIME
himalaya message export <id> --output message.eml

# Export entire folder
himalaya folder export INBOX --output inbox.mbox
```

## Summary

himalaya is a fast, scriptable email client that excels in terminal-based workflows. Its CLI-first design makes it ideal for automation, while the TUI provides an interactive experience. For the git email workflow, it pairs well with `git send-email` for sending patches and `git am` for applying them.

## Resources

- [himalaya GitHub Repository](https://github.com/pimalaya/himalaya)
- [himalaya Documentation](https://pimalaya.org/himalaya/)
- [Git Email Workflow](git-email-workflow.md)
