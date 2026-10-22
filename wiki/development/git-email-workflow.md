---
title: "Git Email Workflow"
description: "How to create, send, and receive patches with git format-patch, git send-email, and TUI email clients like himalaya and neomutt."
tags:
  - git
  - email
  - patches
  - workflow
  - terminal
  - tui
  - himalaya
  - neomutt
  - development
type: guide
status: draft
created: 2026-09-28
updated: 2026-10-12
related:
  - arch-setup
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document git email workflow"
ai-review: pending
language: en
audience: developer
scope: git patch submission by email
keywords:
  - git
  - git format-patch
  - git send-email
  - patches
platform:
  - Linux
  - Git
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Git Email Workflow

This tutorial teaches the complete email-based patch workflow used by Linux kernel developers and many open-source projects. You will learn how to create patches with `git format-patch`, send them with `git send-email`, and manage email in your terminal with TUI clients like himalaya and neomutt.

## Why Email-Based Development?

Many open-source projects — especially the Linux kernel, Git itself, and various GNU projects — accept contributions via email patches rather than pull requests. This workflow has advantages:

- Works offline and across unreliable networks
- No dependency on a central platform (GitHub, GitLab)
- Full control over patch formatting and threading
- Decades of tooling built around it

The core tools are `git format-patch` (create patches), `git send-email` (send them), and `git am` (apply received patches).

## Prerequisites

Before starting, ensure you have the necessary tools installed:

```bash
# Debian/Ubuntu
sudo apt install git git-email

# Fedora
sudo dnf install git git-email

# Arch
sudo pacman -S git

# himalaya (Rust-based TUI email client)
cargo install himalaya
# or via package manager if available

# neomutt (Mutt fork)
sudo apt install neomutt    # Debian/Ubuntu
sudo pacman -S neomutt      # Arch
```

Verify your installation:

```bash
git --version
git send-email --version
```

## Part 1: Configuring Git for Email

### Setting Your Identity

Git needs to know who you are for both commits and patches:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Configuring send-email

`git send-email` needs SMTP settings. Configure them globally or per-repository:

```bash
# Global configuration
git config --global sendemail.smtpServer "smtp.gmail.com"
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser "your.email@gmail.com"
git config --global sendemail.smtpPass "your-app-password"
```

For Gmail, you must use an [App Password](https://support.google.com/accounts/answer/185833) since regular passwords no longer work with SMTP.

### Testing Your Configuration

Send a test email to yourself:

```bash
git send-email --to="your.email@gmail.com" --subject="Test" /dev/null
```

If you receive the email, your configuration is correct.

## Part 2: Creating Patches with git format-patch

### What is a Patch?

A patch is a plain-text file that represents one or more commits. It includes:
- Commit message
- Author information
- Diff (the actual changes)
- Metadata for proper threading

### Creating a Patch for the Latest Commit

To create a patch from your most recent commit:

```bash
git format-patch -1 HEAD
```

This creates a file named `0001-<commit-subject>.patch` in the current directory.

### Creating Patches for Multiple Commits

To create patches for the last N commits:

```bash
git format-patch -3 HEAD
```

This creates three patch files, one for each of the last three commits.

### Creating Patches Relative to a Branch

To create patches for all commits on your current branch that are not in `main`:

```bash
git format-patch main
```

Or using `origin/main`:

```bash
git format-patch origin/main
```

### Creating a Patch Series with Cover Letter

For multi-patch series, include a cover letter:

```bash
git format-patch --cover-letter origin/main
```

This creates:
- `0000-cover-letter.patch` — an introductory email describing the series
- `0001-first-commit.patch`
- `0002-second-commit.patch`
- etc.

### Customizing Output Directory

Send patches to a specific directory:

```bash
git format-patch -o outgoing/ origin/main
```

### Patch for Specific Commit Range

```bash
git format-patch abc1234..def5678
```

### Patch for a Single Specific Commit

```bash
git format-patch -1 abc1234
```

### Inspecting a Patch File

A patch file looks like this:

```
From 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t Mon Sep 17 00:00:00 2001
From: Your Name <your.email@example.com>
Date: Mon, 28 Sep 2026 10:00:00 -0300
Subject: [PATCH 1/2] Fix memory leak in buffer handling

---
 src/buffer.c | 4 ++++
 1 file changed, 4 insertions(+)

diff --git a/src/buffer.c b/src/buffer.c
index abc1234..def5678 100644
--- a/src/buffer.c
+++ b/src/buffer.c
@@ -45,6 +45,10 @@ void buffer_init(struct buffer *b) {
     b->data = malloc(256);
     b->size = 256;
     b->len = 0;
+    if (!b->data) {
+        fprintf(stderr, "Failed to allocate buffer\n");
+        exit(1);
+    }
 }
-- 
2.45.0
```

Key parts:
- `From <hash>` — the commit hash
- `Subject: [PATCH 1/2]` — indicates this is patch 1 of 2
- `---` — separates commit message from diff
- `diff --git` — the actual changes
- `-- 2.45.0` — signature with git version

## Part 3: Sending Patches with git send-email

### Sending a Single Patch

```bash
git send-email 0001-fix-memory-leak.patch
```

### Sending a Patch Series

```bash
git send-email outgoing/
```

Or specify the directory:

```bash
git send-email outgoing/*.patch
```

### Sending with Cover Letter

When sending a series with a cover letter, send them together:

```bash
git send-email outgoing/
```

`git send-email` automatically detects the cover letter (the one starting with `0000-`) and sends it first.

### Specifying Recipients

```bash
git send-email --to="maintainer@example.com" --cc="mailing-list@example.com" outgoing/
```

### Sending to Multiple Recipients

```bash
git send-email \
  --to="maintainer@example.com" \
  --cc="reviewer1@example.com" \
  --cc="reviewer2@example.com" \
  --cc="mailing-list@example.com" \
  outgoing/
```

### Dry Run (Preview Without Sending)

Always do a dry run first:

```bash
git send-email --dry-run outgoing/
```

This shows what would be sent without actually sending.

### Threading and In-Reply-To

When sending a revised version of a patch, use `--in-reply-to` to maintain threading:

```bash
git send-email --in-reply-to="<message-id-from-original>" outgoing/
```

The Message-ID can be found in the headers of the email you received.

### Common send-email Options

| Option | Description |
|--------|-------------|
| `--to` | Primary recipient |
| `--cc` | Carbon copy |
| `--bcc` | Blind carbon copy |
| `--subject` | Override subject line |
| `--in-reply-to` | Message-ID for threading |
| `--annotate` | Edit each patch before sending |
| `--dry-run` | Preview without sending |
| `--confirm=always` | Confirm before sending each email |
| `--suppress-from` | Do not add From header |
| `--transfer-encoding` | Set encoding (8bit, quoted-printable, base64) |

### Editing Patches Before Sending

Use `--annotate` to open each patch in your editor before sending:

```bash
git send-email --annotate outgoing/
```

This lets you add comments, fix typos, or add `Reviewed-by` tags.

## Part 4: Receiving and Applying Patches with git am

### What is git am?

`git am` (apply mailbox) reads a patch file and creates commits from it. It preserves authorship, dates, and commit messages.

### Applying a Single Patch

```bash
git am 0001-fix-memory-leak.patch
```

### Applying a Patch Series

```bash
git am outgoing/*.patch
```

Or apply an entire mbox file:

```bash
git am patches.mbox
```

### Applying with Sign-off

Add your `Signed-off-by` line (required by many projects):

```bash
git am --signoff 0001-fix-memory-leak.patch
```

### Handling Conflicts

If `git am` encounters conflicts:

```bash
# Fix the conflicts in your editor, then:
git add <resolved-files>
git am --continue

# Or skip this patch:
git am --skip

# Or abort the entire operation:
git am --abort
```

### Three-Way Merge

For patches that do not apply cleanly, use three-way merge:

```bash
git am -3 0001-fix-memory-leak.patch
```

This requires the blob objects referenced in the patch to be present in your repository.

## Part 5: TUI Email Clients for the Workflow

### Why TUI Email Clients?

When working with patches via email, you need a client that:
- Handles plain-text email perfectly (no HTML mangling)
- Preserves whitespace and formatting
- Integrates with command-line tools
- Works in terminal multiplexer sessions (tmux, screen)

### himalaya

himalaya is a modern TUI email client written in Rust. It supports IMAP, SMTP, and multiple accounts.

#### Installation

```bash
# Via cargo
cargo install himalaya

# Via package manager (if available)
# Check your distribution's repositories
```

#### Configuration

Create the configuration file at `~/.config/himalaya/config.toml`:

```toml
[accounts.personal]
email = "your.email@example.com"
display-name = "Your Name"
default = true

[accounts.personal.backend]
type = "imap"
host = "imap.gmail.com"
port = 993
encryption = "tls"
login = "your.email@example.com"
passwd = { type = "command", value = "pass show email/gmail" }

[accounts.personal.sender]
type = "smtp"
host = "smtp.gmail.com"
port = 587
encryption = "starttls"
login = "your.email@example.com"
passwd = { type = "command", value = "pass show email/gmail" }
```

#### Basic Usage

Launch himalaya TUI:

```bash
himalaya tui
```

Key bindings in the TUI:

| Key | Action |
|-----|--------|
| `q` | Quit |
| `j` / `k` | Navigate up/down |
| `Enter` | Open email |
| `c` | Compose new email |
| `r` | Reply |
| `R` | Reply all |
| `f` | Forward |
| `d` | Delete |
| `s` | Save attachment |
| `?` | Show help |

#### Working with Patches in himalaya

When you receive a patch email:
1. Open the email
2. Save the patch content to a file (or copy from the email body)
3. Apply with `git am`

You can pipe email content directly to `git am`:

```bash
# In himalaya, view the raw email and save to file
# Then in terminal:
git am < saved-patch.patch
```

### neomutt

neomutt is the modern fork of Mutt, a classic TUI email client. It is highly configurable and has decades of community support.

#### Installation

```bash
# Debian/Ubuntu
sudo apt install neomutt

# Arch
sudo pacman -S neomutt

# Fedora
sudo dnf install neomutt
```

#### Configuration

Create `~/.muttrc` (or `~/.config/neomutt/muttrc`):

```ini
# Identity
set from = "your.email@example.com"
set realname = "Your Name"

# IMAP settings
set imap_user = "your.email@gmail.com"
set imap_pass = "`pass show email/gmail`"

# SMTP settings
set smtp_url = "smtp://your.email@gmail.com@smtp.gmail.com:587/"
set smtp_pass = "`pass show email/gmail`"

# Folders
set folder = "imaps://imap.gmail.com:993"
set spoolfile = "+INBOX"
set postponed = "+[Gmail]/Drafts"
set record = "+[Gmail]/Sent Mail"

# Behavior
set edit_headers = yes
set charset = "utf-8"
set send_charset = "utf-8-ascii"

# Plain text only (critical for patches)
set mime_forward = no
set forward_decode = yes

# PGP (optional)
set pgp_sign_as = "your-key-id"
```

#### Basic Usage

Launch neomutt:

```bash
neomutt
```

Key bindings:

| Key | Action |
|-----|--------|
| `q` | Quit |
| `j` / `k` | Navigate |
| `Enter` | Open email |
| `m` | Compose new email |
| `r` | Reply |
| `g` | Reply all |
| `f` | Forward |
| `d` | Delete |
| `s` | Save attachment |
| `i` | Go to inbox |
| `?` | Show help |

#### Working with Patches in neomutt

When viewing a patch email:
1. Press `v` to view attachments
2. Press `s` to save the patch file to disk
3. Exit neomutt and apply with `git am`

Or use neomutt's `display-filter` to pipe patches directly:

```ini
# In .muttrc
display-filter "^diff --git" "cat"
```

### aerc (Alternative)

aerc is another excellent TUI email client written in Go, specifically designed for the patch workflow.

#### Installation

```bash
# Debian/Ubuntu
sudo apt install aerc

# Arch
sudo pacman -S aerc

# From source
git clone https://git.sr.ht/~rjarry/aerc
cd aerc
make
sudo make install
```

#### Configuration

aerc uses INI-style config at `~/.config/aerc/aerc.conf`:

```ini
[general]
default-save-path = ~/Downloads

[accounts.personal]
source = imaps://your.email@gmail.com@imap.gmail.com:993
default = INBOX
from = Your Name <your.email@gmail.com>

[accounts.personal.smtp]
source = smtps://your.email@gmail.com@smtp.gmail.com:587
```

#### Patch Workflow in aerc

aerc has built-in support for the git patch workflow:
- View patches with syntax highlighting
- Pipe patches directly to `git am` using `:pipe`
- Apply patches with `:apply-patch` (if configured)

## Part 6: Complete Workflow Example

### Scenario: Contributing a Bug Fix

#### Step 1: Set Up Your Repository

```bash
git clone https://github.com/example/project.git
cd project
git checkout -b fix-memory-leak
```

#### Step 2: Make Your Changes

Edit files, then commit:

```bash
git add src/buffer.c
git commit -m "Fix memory leak in buffer handling

The buffer_init function allocates memory but does not check
for allocation failure. This patch adds a NULL check and
exits gracefully if allocation fails.

Signed-off-by: Your Name <your.email@example.com>"
```

#### Step 3: Generate the Patch

```bash
git format-patch -1 HEAD -o outgoing/
```

#### Step 4: Review the Patch

```bash
cat outgoing/0001-fix-memory-leak.patch
```

#### Step 5: Send the Patch

```bash
# Dry run first
git send-email --dry-run \
  --to="maintainer@example.com" \
  --cc="mailing-list@example.com" \
  outgoing/

# Send for real
git send-email \
  --to="maintainer@example.com" \
  --cc="mailing-list@example.com" \
  outgoing/
```

#### Step 6: Address Review Feedback

If the maintainer requests changes:

```bash
# Make your edits
vim src/buffer.c

# Amend the commit
git add src/buffer.c
git commit --amend

# Generate v2 of the patch
git format-patch -1 HEAD -o outgoing/ --v2

# Send the revised patch
git send-email \
  --to="maintainer@example.com" \
  --cc="mailing-list@example.com" \
  --in-reply-to="<original-message-id>" \
  outgoing/
```

### Scenario: Sending a Patch Series

#### Step 1: Create Multiple Commits

```bash
git checkout -b feature-branch

# First commit
git add src/new-feature.c
git commit -m "Add new feature skeleton"

# Second commit
git add src/new-feature.c tests/test-new-feature.c
git commit -m "Implement new feature logic"

# Third commit
git add README.md
git commit -m "Document new feature"
```

#### Step 2: Generate Series with Cover Letter

```bash
git format-patch --cover-letter origin/main -o outgoing/
```

#### Step 3: Edit the Cover Letter

```bash
vim outgoing/0000-cover-letter.patch
```

Add a description of the series:

```
This series adds a new feature to handle X.

Patch 1 adds the skeleton.
Patch 2 implements the core logic.
Patch 3 updates documentation.

Tested on: x86_64, Linux 6.6
```

#### Step 4: Send the Series

```bash
git send-email \
  --to="maintainer@example.com" \
  --cc="mailing-list@example.com" \
  outgoing/
```

## Part 7: Advanced Topics

### Using git send-email with msmtp

If you prefer a separate SMTP client, use msmtp as the sendmail replacement:

```bash
# Install msmtp
sudo apt install msmtp-mta

# Configure msmtp at ~/.msmtprc
account default
host smtp.gmail.com
port 587
from your.email@gmail.com
auth on
user your.email@gmail.com
password your-app-password
tls on
tls_starttls on

# Configure git to use msmtp
git config --global sendemail.sendmailcmd "msmtp -t"
```

### Using git send-email with OfflineIMAP + msmtp

For a fully offline workflow:

1. Sync mail with OfflineIMAP
2. Read and compose with neomutt/himalaya
3. Send with msmtp

### Patch Review Workflow

When reviewing patches from others:

```bash
# Save the patch from your email client
# Then apply it:
git am -3 0001-review.patch

# Test the changes
make test

# Reply with feedback
git send-email --in-reply-to="<original-message-id>" reply.patch
```

### Using b4 for Patch Series

`b4` is a tool specifically designed for patch series handling:

```bash
# Install b4
pip install b4

# Download a patch series from a mailing list
b4 am <message-id>

# Apply the series
git am ./series.mbox
```

## Part 8: Troubleshooting

### Common Issues

**Patch does not apply cleanly:**
```bash
git am -3 patch.patch
# or
git apply --3way patch.patch
```

**Whitespace errors:**
```bash
git am --whitespace=fix patch.patch
```

**Encoding issues:**
```bash
git send-email --transfer-encoding=8bit patch.patch
```

**SMTP authentication failure:**
- Verify your app password
- Check if your provider requires TLS/STARTTLS
- Test with `git send-email --dry-run`

**Patches appear as attachments instead of inline:**
- Some email clients MIME-encode patches
- Use `git send-email` which sends patches as `text/plain`
- In TUI clients, view raw message source

### Getting Help

```bash
git format-patch --help
git send-email --help
git am --help
```

## Summary

The complete git email workflow:

1. **Configure**: Set up git identity and SMTP settings
2. **Create**: Use `git format-patch` to generate patches
3. **Send**: Use `git send-email` to deliver patches
4. **Receive**: Use `git am` to apply received patches
5. **Manage**: Use TUI clients (himalaya, neomutt, aerc) for email

This workflow gives you full control over your contributions and works with any project that accepts email patches.
