---
title: "Automated QEMU Testing for Dotfiles & Arch Linux Installation"
aliases:
  - QEMU dotfiles testing
  - automated Arch testing
  - dotfiles CI pipeline
  - niri automated setup
  - Arch QEMU automation
  - noctalia shell
  - multi-machine setup
  - mosh tmux
description: >-
  Pure-bash pipeline for testing dotfiles and Arch Linux installations in headless QEMU VMs.
  Direct qemu-system-x86_64 invocation, expect-driven serial console installs, qemu-img
  snapshots for clean-state rollbacks, and SSH-based assertion suites. No libvirt, no XML,
  no cloud-init, no archinstall JSON — just bash scripts that get the job done.
tags:
  - arch-linux
  - qemu
  - virtualization
  - testing
  - automation
  - ci
  - dotfiles
  - niri
  - noctalia
  - wayland
  - expect
  - stow
  - mosh
  - tmux
  - ssh
  - multi-machine
  - guide
type: guide
status: evergreen
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2027-03-27
language: en
audience: sysadmin
scope: automated testing pipeline for dotfiles and Arch installations
platform:
  - Arch Linux
  - Linux
  - QEMU
  - Wayland
keywords:
  - qemu-system-x86_64
  - qemu-img
  - qemu-nbd
  - expect script
  - serial console
  - hostfwd
  - GNU Stow
  - bare git repo
  - chezmoi
  - niri
  - noctalia
  - headless QEMU
  - CI/CD
  - qemu snapshot
  - KVM
  - dotfiles testing
  - idempotent scripts
  - reproducible builds
  - mosh
  - tmux
  - ssh config
  - multi-machine
  - clusterssh
  - terminal multiplexer
sources:
  - "[QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU)"
  - "[Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide)"
  - "[GNU Stow manual](https://www.gnu.org/software/stow/manual/)"
  - "[niri manual](https://github.com/YaLTeR/niri)"
  - "[QEMU qemu-img documentation](https://www.qemu.org/docs/master/tools/qemu-img.html)"
  - "[Scripted QEMU setup without libvirt — ArchWiki](https://wiki.archlinux.org/title/User:Nd43/Scripted_QEMU_setup_without_libvirt)"
source_retrieved: 2026-09-27
related:
  - "[[arch-setup]]"
  - "[[Vault Conventions]]"
  - "[[Home]]"
cssclasses:
  - nota-longa
  - reference
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document automated QEMU testing pipeline"
ai-review: pending
---

# Automated QEMU Testing for Dotfiles & Arch Linux Installation

> [!summary] The one-paragraph answer
> Create a qcow2 disk with `qemu-img`, boot the Arch ISO with `qemu-system-x86_64 -nographic`,
> drive the installation through the serial console with `expect`, snapshot the clean install
> with `qemu-img snapshot`, then for each test revert the snapshot, boot, deploy dotfiles over
> SSH, run assertions, and kill the VM. No libvirt, no XML, no archinstall JSON, no cloud-init.
> Just bash, QEMU, and `expect`. The full pipeline: **qemu-img create → expect install →
> qemu-img snapshot → revert → boot → stow → test → destroy**.

---

## Context

You maintain dotfiles and shell scripts that configure an Arch Linux desktop with niri (Wayland
compositor). Running them directly on your host is risky — a broken symlink or bad package install
can leave you without a working desktop. This guide builds an isolated, automated testing
environment using nothing but bash scripts and direct QEMU invocation.

The approach is deliberately low-level. We skip libvirt (no XML, no virsh, no snapshots),
skip archinstall's JSON API (no schema to track), and skip cloud-init (no genisoimage).
Instead:

1. **Create a raw qcow2 disk** with `qemu-img create`.
2. **Boot the Arch ISO** with `qemu-system-x86_64 -nographic` — serial console on stdio.
3. **Install Arch automatically** with an `expect` script that types pacstrap, configures
   the system, and reboots.
4. **Snapshot the clean install** with `qemu-img snapshot -c clean-install`.
5. **For each test**: revert the snapshot (`qemu-img snapshot -a clean-install`), boot,
   SSH in via `hostfwd`, deploy dotfiles with stow, run assertions, kill the VM.
6. **Destroy everything** by deleting the qcow2 file.

Everything is one bash script. It can be run manually, from a Git pre-commit hook, or from CI.

> [!tip] Why no libvirt?
> libvirt adds an abstraction layer (XML, virsh, storage pools, snapshots) that is powerful but
> heavy for a single-purpose test pipeline. With direct QEMU you see every flag, every byte
> goes where you expect, and the whole thing is debuggable with `ps` and `kill`. The tradeoff
> is more upfront work — but the scripts are simpler once written.

---

## Details

### 1. Prerequisites

#### 1.1 Host packages

```bash
# QEMU + tools (no libvirt)
sudo pacman -S qemu-full expect git stow

# qemu-full pulls: qemu-system-x86_64, qemu-img, qemu-nbd, edk2-ovmf
```

That's it. No libvirt, no virt-install, no virt-manager, no cloud-init.

#### 1.2 Verify KVM

```bash
lscpu | grep Virtualization   # should show VT-x or AMD-V
ls -la /dev/kvm               # should exist
```

If `/dev/kvm` is missing, enable virtualization in BIOS/UEFI.

#### 1.3 Download and pin the Arch ISO

```bash
# Pin a specific version for reproducible tests
ISO_URL="https://geo.mirror.pkgbuild.com/iso/2026.09.01/archlinux-2026.09.01-x86_64.iso"
curl -O "$ISO_URL"
curl -O "$ISO_URL.sig"

# Verify
gpg --keyserver-options auto-key-retrieve --verify archlinux-2026.09.01-x86_64.iso.sig
```

> [!warning] Always pin the ISO
> The `latest` symlink changes monthly and WILL break your `expect` scripts. Always use a
> dated ISO URL. When the ISO updates, update the expect script deliberately, not accidentally.

---

### 2. The QEMU Boot Script

The core of the approach is a single function that boots QEMU with the right flags. Save as
`/tmp/vm-boot.sh`:

```bash
#!/usr/bin/env bash
# vm-boot.sh — boot the test VM with serial console on stdio
# Usage: vm-boot.sh <disk.qcow2> <iso.file> [extra qemu args...]

set -euo pipefail

DISK="${1:?usage: vm-boot.sh <disk> <iso> [extra args...]}"
ISO="${2:?usage: vm-boot.sh <disk> <iso> [extra args...]}"
shift 2

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 2 \
  -m 4096 \
  -M q35 \
  -drive file="$DISK",format=qcow2,if=virtio,discard=unmap \
  -drive file="$ISO",media=cdrom \
  -boot d \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -nographic \
  -display none \
  -serial mon:stdio \
  -monitor none \
  -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd \
  "$@"
```

Key flags explained:

| Flag | Why |
|---|---|
| `-nographic` | Redirect serial to stdio — we talk to the guest over stdin/stdout |
| `-serial mon:stdio` | Serial console + QEMU monitor muxed on stdio (Ctrl+A C to switch) |
| `-display none` | No graphical output needed |
| `-netdev user,id=net0,hostfwd=tcp::2222-:22` | User-mode networking; host port 2222 forwards to guest SSH |
| `-bios /usr/share/edk2/x64/OVMF_CODE.4m.fd` | UEFI firmware (systemd-boot target) |
| `-drive ...,discard=unmap` | TRIM support for qcow2 |

#### 2.1 Create the disk

```bash
DISK="/tmp/arch-test.qcow2"
ISO="/tmp/archlinux-2026.09.01-x86_64.iso"

rm -f "$DISK"
qemu-img create -f qcow2 "$DISK" 30G
```

#### 2.2 Create a backing-file snapshot (clean install → test variants)

```bash
# After the clean install is done and snapshotted:
qemu-img create -f qcow2 -b "$DISK" -F qcow2 /tmp/arch-test-variant.qcow2
# Variant disk is copy-on-write; base disk stays pristine
```

---

### 3. Automated Install via Expect

The `expect` script types into the serial console exactly as if a human were at the keyboard.
This is the "more hardwork" part — but it's transparent and works with any ISO version.

Save as `/tmp/arch-install.exp`:

```tcl
#!/usr/bin/expect -f
# arch-install.exp — drive Arch installation over QEMU serial console
# Usage: ./arch-install.exp <disk.qcow2> <iso.file>

set timeout 1800
set disk [lindex $argv 0]
set iso  [lindex $argv 1]

# Start QEMU with serial on stdio
spawn qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 4096 -M q35 \
  -drive file=$disk,format=qcow2,if=virtio \
  -drive file=$iso,media=cdrom \
  -boot d \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -nographic -display none -serial mon:stdio -monitor none \
  -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd

# Wait for the Arch boot prompt
expect {
    "Arch Linux install medium" { }
    "boot:" { }
    timeout { puts "TIMEOUT waiting for boot menu"; exit 1 }
}

# Boot the default entry (wait for shell)
expect {
    "~#" { }
    "# " { }
    timeout { puts "TIMEOUT waiting for shell"; exit 1 }
}

send -- "su -\r"
expect "# "

# Partition the disk
send -- "parted -s /dev/vda mklabel gpt\r"
expect "# "
send -- "parted -s /dev/vda mkpart ESP fat32 1MiB 513MiB set 1 esp on\r"
expect "# "
send -- "parted -s /dev/vda mkpart primary 513MiB 100%\r"
expect "# "
send -- "mkfs.fat -F32 /dev/vda1\r"
expect "# "
send -- "mkfs.btrfs /dev/vda2\r"
expect "# "

# Mount
send -- "mount /dev/vda2 /mnt\r"
expect "# "
send -- "mkdir -p /mnt/boot\r"
expect "# "
send -- "mount /dev/vda1 /mnt/boot\r"
expect "# "

# Install base system
send -- "pacstrap -K /mnt base base-devel linux linux-firmware git stow vim openssh networkmanager\r"
expect "# "
send -- "genfstab -U /mnt >> /mnt/etc/fstab\r"
expect "# "
send -- "arch-chroot /mnt\r"
expect "# "

# Hostname
send -- "echo arch-test > /etc/hostname\r"
expect "# "

# Timezone
send -- "ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime\r"
expect "# "
send -- "hwclock --systohc\r"
expect "# "

# Locale
send -- "sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen\r"
expect "# "
send -- "locale-gen\r"
expect "# "
send -- "echo 'LANG=pt_BR.UTF-8' > /etc/locale.conf\r"
expect "# "

# Keymap
send -- "echo 'KEYMAP=br' > /etc/vconsole.conf\r"
expect "# "

# Bootloader (systemd-boot under UEFI)
send -- "bootctl install\r"
expect "# "
send -- "echo -e 'title Arch Linux\\nlinux /vmlinuz-linux\\ninitrd /initramfs-linux.img\\noptions root=/dev/vda2 rw' > /boot/loader/entries/arch.conf\r"
expect "# "

# Desktop packages
send -- "pacman -S --noconfirm niri waybar foot fuzzel swaybg swayidle swaylock wlogout xdg-desktop-portal xdg-desktop-portal-gtk polkit pipewire wireplumber btop htop curl wget jq ripgrep fd eza zsh bash-completion man-db man-pages texinfo reflector pacman-contrib chezmoi\r"
expect "# "

# Services
send -- "systemctl enable NetworkManager sshd pipewire wireplumber\r"
expect "# "

# Root password
send -- "echo 'root:test-root-pass' | chpasswd\r"
expect "# "

# Test user
send -- "useradd -m -G wheel -s /bin/bash tester\r"
expect "# "
send -- "echo 'tester:test-user-pass' | chpasswd\r"
expect "# "
send -- "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel\r"
expect "# "

# Exit chroot and reboot
send -- "exit\r"
expect "# "
send -- "umount -R /mnt\r"
expect "# "
send -- "reboot\r"

# Wait for QEMU to exit on reboot
expect eof
```

Run the install:

```bash
chmod +x /tmp/arch-install.exp
/tmp/arch-install.exp /tmp/arch-test.qcow2 /tmp/archlinux-2026.09.01-x86_64.iso
```

> [!tip] Expect debugging
> Add `exp_internal 1` at the top of the expect script to see exactly what it's matching
> against. When a script breaks after an ISO update, this shows you the new prompt.

---

### 4. Snapshot the Clean Install

After the install completes and the VM shuts down, snapshot the disk:

```bash
DISK="/tmp/arch-test.qcow2"

# Create internal qcow2 snapshot
qemu-img snapshot -c "$DISK" clean-install

# Verify
qemu-img snapshot -l "$DISK"
```

Expected output:

```
Snapshot list:
ID        TAG                 VM SIZE                DATE       VM CLOCK     ICOUNT
1         clean-install       2.3 GiB                2026-09-27 00:00:00.000 0
```

#### 4.1 Revert to clean state before each test

```bash
# Revert the disk to the clean-install snapshot (destructive — discards current state)
qemu-img snapshot -a "$DISK" clean-install
```

This is the key to fast, repeatable tests. Each test run starts from the exact same
disk state — no leftover configs, no stale packages.

#### 4.2 Alternative: backing-file snapshots

If you prefer not to use qcow2 internal snapshots, use a copy-on-write overlay:

```bash
# Create overlay (pristine base stays untouched)
qemu-img create -f qcow2 -b "$DISK" -F qcow2 /tmp/arch-test-overlay.qcow2

# Boot the overlay instead of the base
# When done, delete the overlay — base is still clean
rm -f /tmp/arch-test-overlay.qcow2
```

---

### 5. Dotfiles Deployment

#### 5.1 Dotfiles repo structure

Your dotfiles repo should be organized for GNU Stow:

```
dotfiles/
├── bash/
│   ├── .bashrc
│   └── .bash_profile
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── niri/
│   └── .config/
│       └── niri/
│           └── config.kdl
├── waybar/
│   └── .config/
│       └── waybar/
│           ├── config
│           └── style.css
├── foot/
│   └── .config/
│       └── foot/
│           └── foot.ini
├── fuzzel/
│   └── .config/
│       └── fuzzel/
│           └── fuzzel.ini
└── README.md
```

#### 5.2 Deploy script (runs inside VM)

Save as `/tmp/deploy-dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="git@github.com:youruser/dotfiles.git"

echo "==> Cloning dotfiles..."
git clone --depth 1 "$DOTFILES_REPO" /tmp/dotfiles
cd /tmp/dotfiles

echo "==> Deploying with stow..."
mkdir -p ~/.config
stow bash git niri waybar foot fuzzel

echo "==> Verifying symlinks..."
for f in ~/.config/niri/config.kdl ~/.config/waybar/config ~/.bashrc; do
  if [ -L "$f" ] || [ -f "$f" ]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

echo "==> Dotfiles deployed."
```

#### 5.3 Copy into VM and run

```bash
scp /tmp/deploy-dotfiles.sh tester@localhost:/tmp/ -P 2222
ssh tester@localhost -p 2222 'bash /tmp/deploy-dotfiles.sh'
```

#### 5.4 Advanced: chezmoi for templated dotfiles

chezmoi supports Go templates for per-machine differences — no conditional stow, no
duplicate files.

```bash
# Install
pacman -S chezmoi

# One-time init from your repo
chezmoi init git@github.com:youruser/dotfiles.git

# Apply (creates symlinks/copies as needed)
chezmoi apply

# See what would change before applying
chezmoi diff

# Update (pull + apply)
chezmoi update
```

Template example — `dotfiles/git/.gitconfig.tmpl`:

```ini
[user]
    name = {{ .name }}
    email = {{ .email }}
{{- if eq .chezmoi.hostname "work-laptop" }}
    signingkey = ABC123DEF456
{{- end }}

[core]
    editor = nvim
    autocrlf = input

[init]
    defaultBranch = main
```

chezmoi auto-detects hostname and makes it available as `.chezmoi.hostname` in templates.
Per-machine config lives in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
    name = "Joao"
    email = "joao@personal.com"

[data.hostname]
    "work-laptop" = "work"
    "home-desktop" = "home"
```

#### 5.5 Advanced: yadm (yet another dotfiles manager)

yadm is a git-based dotfiles manager with built-in encryption and alternate files:

```bash
# Install
pacman -S yadm

# Clone your dotfiles repo
yadm clone git@github.com:youruser/dotfiles.git

# Add a file
yadm add ~/.config/niri/config.kdl
yadm commit -m "Add niri config"
yadm push

# On a new machine
yadm clone git@github.com:youruser/dotfiles.git
yadm alt    # create per-machine alternates
yadm bootstrap  # run bootstrap script if present
```

Per-machine alternates — yadm auto-selects the right file based on hostname/class:

```
dotfiles/niri/config.kdl          # default
dotfiles/niri/config.kdl##class.desktop   # when yadm class = desktop
dotfiles/niri/config.kdl##hostname.work-laptop  # specific host
```

Create classes with `yadm config local.class desktop`.

#### 5.6 Advanced: bare git repo (no extra packages)

The original "hacker's dotfiles" method — just git with a custom work-tree:

```bash
# One-time setup on any machine
git init --bare $HOME/.dotfiles.git
alias df='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'

# Make the alias permanent
echo "alias df='/usr/bin/git --git-dir=\$HOME/.dotfiles.git --work-tree=\$HOME'" >> ~/.bashrc

# Track files
df add ~/.config/niri/config.kdl ~/.bashrc ~/.gitconfig
df commit -m "Initial dotfiles"
df remote add origin git@github.com:youruser/dotfiles.git
df push -u origin main

# On a new machine
git clone --bare git@github.com:youruser/dotfiles.git $HOME/.dotfiles.git
alias df='/usr/bin/git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
df checkout -f   # restore all tracked files
df status        # any untracked files are untracked dotfiles
```

#### 5.7 Advanced: GNU Stow — conflict handling and --adopt

Stow refuses to overwrite existing files. Use `--adopt` to take over an existing file:

```bash
# If ~/.bashrc already exists and you want stow to manage it:
stow --adopt bash

# This moves the existing ~/.bashrc into the stow package, then symlinks
# Review what changed:
cd ~/dotfiles
git diff   # shows the adopted file in the stow dir
```

Dry-run mode — see what stow WOULD do without doing it:

```bash
stow --dry-run -v bash 2>&1 | grep -E "LINK|UNLINK|CONFLICT"
```

#### 5.8 Advanced: dotfiles sync script (rsync-based)

For machines where stow/chezmoi/yadm are too much — plain rsync:

```bash
#!/usr/bin/env bash
# sync-dots.sh — sync dotfiles to a remote machine
set -euo pipefail

TARGET_HOST="${1:?usage: sync-dots.sh <host>}"
DOTFILES_DIR="$HOME/.local/share/dotfiles"

# Push local changes to remote
rsync -avz --delete \
  --exclude '.git/' \
  --exclude '.ssh/id_*' \
  --exclude '.gnupg/' \
  "$DOTFILES_DIR/" "$TARGET_HOST:$DOTFILES_DIR/"

# Pull remote changes back (if remote has newer files)
rsync -avz --delete \
  --exclude '.git/' \
  --exclude '.ssh/id_*' \
  --exclude '.gnupg/' \
  "$TARGET_HOST:$DOTFILES_DIR/" "$DOTFILES_DIR/"

echo "==> Synced dotfiles with $TARGET_HOST"
```

#### 5.9 Advanced: secrets management

Keep secrets out of git. Three approaches:

**Approach 1 — git-crypt (transparent encryption):**

```bash
pacman -S git-crypt

cd ~/dotfiles
git-crypt init
echo "secret.env filter=git-crypt diff=git-crypt" >> .gitattributes
git add .gitattributes secret.env
git commit -m "Add encrypted secret"

# On a new machine with the key:
git clone git@github.com:youruser/dotfiles.git
cd dotfiles
git-crypt unlock /path/to/keyfile
```

**Approach 2 — age (modern alternative):**

```bash
pacman -S age

# Generate a keypair
age-keygen -o ~/dotfiles-key.txt

# Encrypt a file
age -e -R ~/dotfiles-key.txt.pub -o secret.env.age secret.env

# Decrypt on target machine
age -d -i ~/dotfiles-key.txt secret.env.age > secret.env
```

**Approach 3 — chezmoi's built-in age integration:**

```bash
# In your dotfiles repo, a .env.tmpl file:
export API_KEY={{ (chezmoi.env).API_KEY | quote }}

# Set the env var before apply:
export API_KEY="sk-abc123"
chezmoi apply
```

#### 5.10 Advanced: dotfiles bootstrap script

A single `bootstrap.sh` that sets up a new machine from scratch:

```bash
#!/usr/bin/env bash
# bootstrap.sh — set up a new machine from dotfiles
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
REPO="git@github.com:youruser/dotfiles.git"

echo "==> Cloning dotfiles..."
if [ ! -d "$DOTFILES_DIR" ]; then
  git clone --depth 1 "$REPO" "$DOTFILES_DIR"
else
  git -C "$DOTFILES_DIR" pull
fi
cd "$DOTFILES_DIR"

echo "==> Installing packages..."
sudo pacman -S --needed --noconfirm $(cat packages.txt)

echo "==> Deploying dotfiles..."
stow --adopt bash git niri waybar foot fuzzel tmux ssh

echo "==> Setting shell..."
sudo chsh -s /bin/zsh "$USER"

echo "==> Done. Log out and back in."
```

`packages.txt`:

```
base-devel
git
stow
neovim
niri
waybar
foot
fuzzel
swaybg
swayidle
swaylock
wlogout
xdg-desktop-portal
xdg-desktop-portal-gtk
polkit
pipewire
wireplumber
networkmanager
openssh
btop
htop
curl
wget
jq
ripgrep
fd
eza
zsh
bash-completion
man-db
man-pages
texinfo
reflector
pacman-contrib
chezmoi
```

#### 5.11 Advanced: dotfiles pre-commit hooks

Validate dotfiles before committing:

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
set -euo pipefail

echo "==> Validating dotfiles..."

# Check shell scripts pass syntax check
for f in $(find . -name '*.sh' -o -name '*.bash'); do
  bash -n "$f" && echo "  OK: $f" || exit 1
done

# Validate KDL config (niri)
if command -v niri &>/dev/null; then
  if [ -f niri/.config/niri/config.kdl ]; then
    niri validate --config niri/.config/niri/config.kdl
    echo "  OK: niri config"
  fi
fi

# Check for trailing whitespace
if grep -rn ' $' --include='*.kdl' --include='*.sh' --include='*.bash' .; then
  echo "  FAIL: trailing whitespace found"
  exit 1
fi

# Check for secrets (basic patterns)
if grep -rnE '(password|secret|api_key|token)\s*=\s*["\047][^"\047]+' \
    --include='*.sh' --include='*.bash' --include='*.toml' \
    --exclude-dir=.git .; then
  echo "  WARNING: possible hardcoded secret"
  echo "  Use chezmoi templates or age encryption instead"
  exit 1
fi

echo "==> All checks passed"
```

```bash
chmod +x .git/hooks/pre-commit
```

---

### 6. Test Assertions

Save as `/tmp/test-assertions.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

assert() {
  local desc="$1"
  shift
  if "$@" &>/dev/null; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc"
    ((FAIL++))
  fi
}

echo "==> Testing dotfiles deployment..."

# Config files exist
assert "niri config exists" test -f ~/.config/niri/config.kdl
assert "waybar config exists" test -f ~/.config/waybar/config
assert "waybar CSS exists" test -f ~/.config/waybar/style.css
assert "foot config exists" test -f ~/.config/foot/foot.ini
assert "fuzzel config exists" test -f ~/.config/fuzzel/fuzzel.ini

# Symlinks (if using stow)
assert "niri is symlink" test -L ~/.config/niri/config.kdl

# Binaries exist
assert "niri binary" command -v niri
assert "waybar binary" command -v waybar
assert "foot binary" command -v foot
assert "fuzzel binary" command -v fuzzel
assert "swaybg binary" command -v swaybg
assert "swaylock binary" command -v swaylock

# Services enabled
assert "NetworkManager enabled" systemctl is-enabled NetworkManager
assert "sshd enabled" systemctl is-enabled sshd

# Git config
assert "git config user.name set" git config --global user.name
assert "git config user.email set" git config --global user.email

# niri config syntax check
assert "niri config validates" niri validate --config ~/.config/niri/config.kdl

echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

Run inside the VM:

```bash
scp /tmp/test-assertions.sh tester@localhost:/tmp/ -P 2222
ssh tester@localhost -p 2222 'bash /tmp/test-assertions.sh'
```

---

### 7. Full Test Pipeline Script

Save as `/tmp/test-pipeline.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DISK="/tmp/arch-test.qcow2"
ISO="/tmp/archlinux-2026.09.01-x86_64.iso"
SSH_PORT=2222
SSH_USER="tester"
SSH_HOST="localhost"

# SSH options — skip host key checking for throwaway VMs
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2"

echo "============================================"
echo "  Automated Dotfiles Test Pipeline"
echo "  Disk: $DISK"
echo "  Time: $(date -Iseconds)"
echo "============================================"

# Step 1: Revert to clean snapshot
echo ""
echo "==> Step 1: Reverting to clean-install snapshot..."
qemu-img snapshot -a "$DISK" clean-install

# Step 2: Start VM in background
echo ""
echo "==> Step 2: Starting VM..."
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 4096 -M q35 \
  -drive file="$DISK",format=qcow2,if=virtio,discard=unmap \
  -boot c \
  -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
  -device virtio-net,netdev=net0 \
  -nographic -display none -serial mon:stdio -monitor none \
  -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -pidfile /tmp/vm.pid &

VM_PID=$!
echo "  VM PID: $VM_PID"

cleanup() {
  echo ""
  echo "==> Cleaning up VM..."
  kill "$VM_PID" 2>/dev/null || true
  wait "$VM_PID" 2>/dev/null || true
  rm -f /tmp/vm.pid
}
trap cleanup EXIT

# Step 3: Wait for SSH
echo ""
echo "==> Step 3: Waiting for SSH on port $SSH_PORT..."
for i in $(seq 1 60); do
  if ssh $SSH_OPTS -p $SSH_PORT $SSH_USER@$SSH_HOST true 2>/dev/null; then
    echo "  SSH ready after ${i} attempts"
    break
  fi
  if ! kill -0 "$VM_PID" 2>/dev/null; then
    echo "  ERROR: VM died before SSH came up"
    exit 1
  fi
  sleep 2
done

# Verify SSH actually works
if ! ssh $SSH_OPTS -p $SSH_PORT $SSH_USER@$SSH_HOST true 2>/dev/null; then
  echo "  ERROR: SSH never became ready"
  exit 1
fi

# Step 4: Deploy dotfiles
echo ""
echo "==> Step 4: Deploying dotfiles..."
ssh $SSH_OPTS -p $SSH_PORT $SSH_USER@$SSH_HOST bash -s << 'REMOTE_SCRIPT'
  set -euo pipefail
  git clone --depth 1 git@github.com:youruser/dotfiles.git /tmp/dotfiles
  cd /tmp/dotfiles
  mkdir -p ~/.config
  stow bash git niri waybar foot fuzzel
REMOTE_SCRIPT

# Step 5: Run test assertions
echo ""
echo "==> Step 5: Running test assertions..."
ssh $SSH_OPTS -p $SSH_PORT $SSH_USER@$SSH_HOST bash -s << 'REMOTE_SCRIPT'
  set -uo pipefail
  PASS=0; FAIL=0
  assert() {
    local desc="$1"; shift
    if "$@" &>/dev/null; then
      echo "  PASS: $desc"
      ((PASS++))
    else
      echo "  FAIL: $desc"
      ((FAIL++))
    fi
  }

  assert "niri binary" command -v niri
  assert "waybar binary" command -v waybar
  assert "foot binary" command -v foot
  assert "fuzzel binary" command -v fuzzel
  assert "niri config exists" test -f ~/.config/niri/config.kdl
  assert "waybar config exists" test -f ~/.config/waybar/config
  assert "niri config validates" niri validate --config ~/.config/niri/config.kdl

  echo ""
  echo "  Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
REMOTE_SCRIPT

# Step 6: Graceful shutdown
echo ""
echo "==> Step 6: Shutting down VM..."
ssh $SSH_OPTS -p $SSH_PORT $SSH_USER@$SSH_HOST 'sudo poweroff' || true
sleep 5

echo ""
echo "============================================"
echo "  Test pipeline completed successfully"
echo "============================================"
```

Run it:

```bash
chmod +x /tmp/test-pipeline.sh
/tmp/test-pipeline.sh
```

---

### 8. CI Integration

#### 8.1 GitHub Actions

Save as `.github/workflows/test-dotfiles.yml`:

```yaml
name: Test Dotfiles

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install QEMU and dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-system-x86 expect genisoimage

      - name: Setup KVM
        run: |
          sudo chmod 666 /dev/kvm
          ls -la /dev/kvm

      - name: Download Arch ISO
        run: |
          curl -LO https://geo.mirror.pkgbuild.com/iso/2026.09.01/archlinux-2026.09.01-x86_64.iso

      - name: Run test pipeline
        run: |
          chmod +x scripts/test-dotfiles.sh
          ./scripts/test-dotfiles.sh

      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: logs/
```

#### 8.2 Local pre-commit hook

Save as `.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v qemu-system-x86_64 &>/dev/null; then
  echo "  WARNING: QEMU not installed — skipping VM test"
  exit 0
fi

if [ ! -e /dev/kvm ]; then
  echo "  WARNING: KVM not available — skipping VM test"
  exit 0
fi

scripts/test-dotfiles.sh
```

```bash
chmod +x .git/hooks/pre-commit
```

---

### 9. Advanced Topics

#### 9.1 Parallel VM Testing

Test multiple configurations simultaneously with different ports and disks:

```bash
#!/usr/bin/env bash
set -euo pipefail

run_test() {
  local name="$1"
  local disk="/tmp/arch-test-${name}.qcow2"
  local port="$2"

  qemu-img snapshot -a "$disk" clean-install 2>/dev/null || {
    echo "  Skipping $name — no snapshot yet"
    return
  }

  qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 2 -m 4096 -M q35 \
    -drive file="$disk",format=qcow2,if=virtio \
    -boot c \
    -netdev user,id=net0,hostfwd=tcp::${port}-:22 \
    -device virtio-net,netdev=net0 \
    -nographic -display none -serial mon:stdio -monitor none \
    -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -pidfile "/tmp/vm-${name}.pid" &

  # ... wait for SSH on $port, deploy, test, kill
}

run_test minimal 2222 &
run_test full    2223 &
run_test dev     2224 &
wait
```

#### 9.2 Inspect VM disk from host with qemu-nbd

Without booting the VM, mount and inspect the disk:

```bash
modprobe nbd max_part=16
qemu-nbd --connect=/dev/nbd0 /tmp/arch-test.qcow2

# List partitions
lsblk /dev/nbd0

# Mount the root partition
mkdir -p /mnt/vm-disk
mount /dev/nbd0p2 /mnt/vm-disk

# Inspect files
cat /mnt/vm-disk/etc/hostname
ls -la /mnt/vm-disk/home/tester/.config/

# Unmount and disconnect
umount /mnt/vm-disk
qemu-nbd --disconnect /dev/nbd0
```

#### 9.3 Copy files into VM without SSH

For files that need to be in the VM before SSH is available, use `qemu-nbd`:

```bash
modprobe nbd max_part=16
qemu-nbd --connect=/dev/nbd0 /tmp/arch-test.qcow2
mkdir -p /mnt/vm-disk
mount /dev/nbd0p2 /mnt/vm-disk

# Copy dotfiles directly
cp -r /path/to/dotfiles /mnt/vm-disk/tmp/dotfiles

umount /mnt/vm-disk
qemu-nbd --disconnect /dev/nbd0
```

#### 9.4 Idempotent dotfiles scripts

Every dotfiles script should be safe to run multiple times:

```bash
#!/usr/bin/env bash
# idempotent-config.sh

link_if_needed() {
  local src="$1"
  local dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  OK: $dest -> $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sf "$src" "$dest"
  echo "  SET: $dest -> $src"
}

link_if_needed "$HOME/dotfiles/niri/.config/niri/config.kdl" "$HOME/.config/niri/config.kdl"
link_if_needed "$HOME/dotfiles/waybar/.config/waybar/config" "$HOME/.config/waybar/config"
```

#### 9.5 Testing GUI apps (niri)

For testing that niri actually starts, use software rendering:

```bash
# In the VM:
pacman -S mesa-utils libglvnd

# Validate config syntax
niri validate --config ~/.config/niri/config.kdl

# For headless GL testing:
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
```

---

### 10. Noctalia Shell — Desktop Environment

[Noctalia](https://github.com/noctalia-dev/noctalia) is a Wayland desktop shell in Arch's
`extra` repo. It provides a full desktop experience (notifications, system tray, app
launcher, lock screen, settings panel) on top of a compositor — unlike niri, which is a
bare compositor requiring manual assembly of every component.

#### 10.1 Install Noctalia

```bash
pacman -S noctalia

# Optional dependencies for full functionality
pacman -S ddcutil power-profiles-daemon upower
```

#### 10.2 Noctalia vs niri

|  | niri | Noctalia |
|---|---|---|
| **Type** | Bare Wayland compositor | Full desktop shell |
| **Panel/bar** | Waybar (manual config) | Built-in panel |
| **App launcher** | fuzzel (manual) | Built-in launcher |
| **Notifications** | mako (manual) | Built-in notifications |
| **Lock screen** | swaylock (manual) | Built-in lock screen |
| **Settings** | None (config files only) | Built-in settings GUI |
| **Configuration** | `config.kdl` (text file) | GUI settings + config files |
| **Resource use** | Lower (fewer components) | Higher (more integrated) |
| **Customization** | Unlimited (it's just wlroots) | Structured (designed workflow) |

**Choose niri** if you want a tiling compositor you assemble piece by piece. **Choose
Noctalia** if you want a working desktop with minimal setup — closer to GNOME/KDE in
out-of-box experience, but Wayland-native and lighter.

#### 10.3 Autostart Noctalia on TTY1

```bash
# ~/.bash_profile
if [ "$(tty)" = "/dev/tty1" ]; then
    exec noctalia
fi
```

#### 10.4 Noctalia config

Noctalia stores its configuration under `~/.config/noctalia/`:

```toml
# ~/.config/noctalia/config.toml
[general]
theme = "dark"
startup_applications = [
    "waybar",
    "swaybg -i /usr/share/backgrounds/archlinux/simple.png",
]

[panel]
position = "top"
height = 32
show_clock = true
show_battery = true
show_network = true

[shortcuts]
terminal = "Mod+Return"
launcher = "Mod+D"
lock = "Mod+L"
quit = "Mod+Shift+Q"
```

#### 10.5 Dotfiles deployment for Noctalia

```bash
# In your dotfiles repo:
# dotfiles/noctalia/.config/noctalia/config.toml

# Deploy with stow
stow noctalia

# Verify
test -f ~/.config/noctalia/config.toml
```

---

### 11. Multi-Machine CLI Tooling — mosh + tmux + SSH

When managing multiple machines (laptop + desktop + home server + VM), the right CLI tools
make your life dramatically easier.

#### 11.1 mosh — SSH that survives network changes

```bash
pacman -S mosh

# Connect (same syntax as SSH)
mosh user@server.local

# Advantages over ssh:
# - Survives IP changes (WiFi -> Ethernet, VPN connect/disconnect)
# - Instant local echo — no latency on keystrokes
# - Automatic reconnect when you suspend/resume or change networks
# - Works behind NAT without port forwarding (uses UDP)
```

#### 11.2 tmux — persistent terminal sessions

```bash
pacman -S tmux

tmux new -s work          # start session
# Prefix (Ctrl+B) then D   — detach
tmux attach -t work       # reattach
tmux ls                   # list sessions

# Prefix + "  = horizontal split
# Prefix + %  = vertical split
# Prefix + C  = new window
# Prefix + 0-9 = switch window
```

**Multi-machine workflow:**

1. SSH/mosh into server
2. Start tmux session with all your work
3. Detach, disconnect
4. Later, reconnect and reattach — everything is exactly as you left it

#### 11.3 SSH config for multiple hosts

Save as `~/.ssh/config`:

```ssh
Host desktop
    HostName 192.168.1.10
    User joaov
    IdentityFile ~/.ssh/id_ed25519_desktop
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host laptop
    HostName 192.168.1.20
    User joaov
    IdentityFile ~/.ssh/id_ed25519

Host server
    HostName server.example.com
    User admin
    IdentityFile ~/.ssh/id_ed25519_server
    Port 2222
    Compression yes

Host arch-test-*
    User tester
    Port 2222
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

```bash
ssh desktop          # instead of ssh joaov@192.168.1.10
mosh server          # instant, survives network changes
ssh -t server tmux attach   # one-liner to reattach
```

#### 11.4 Syncing dotfiles across machines

```bash
# Option 1: chezmoi (recommended — handles per-machine differences)
chezmoi init --apply git@github.com:you/dotfiles.git

# Option 2: rsync from a central machine
rsync -avz --delete ~/.config/niri/ desktop:~/.config/niri/

# Option 3: git bare repo
git clone --bare git@github.com:you/dotfiles.git ~/.dotfiles.git
alias df='git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
df checkout -f
```

#### 11.5 clusterssh — run commands on multiple machines at once

```bash
pacman -S clusterssh
cssh desktop laptop server

# ~/.clusters:
# servers desktop laptop server
# vms arch-test-01 arch-test-02
```

> [!warning] clusterssh is not secure for untrusted machines
> It sends your keystrokes to every host. Only use it on machines you fully trust. For
> untrusted environments, use `ansible` or `parallel-ssh` instead.

---

## Gotchas

> [!warning] KVM permissions
> `/dev/kvm` is typically owned by root:kvm. Your user must be in the `kvm` group, or QEMU
> fails with "Permission denied". After adding yourself, **log out and back in** — group
> membership is evaluated at login time.

> [!danger] Snapshot revert destroys unsaved state
> `qemu-img snapshot -a` is destructive — any changes in the current disk state are lost.
> Never revert a snapshot on a VM with unsaved work.

> [!warning] Arch ISO version drift
> Pin your ISO to a specific date (e.g. `archlinux-2026.09.01-x86_64.iso`). The `latest`
> symlink changes monthly and WILL break your `expect` scripts. Update deliberately.

> [!warning] niri and Noctalia are Wayland-only — no X11 fallback
> Both are Wayland shells. If your dotfiles assume X11 (e.g. `.xinitrc`, `xrdb`,
> `xsetroot`), they will not work. Use `config.kdl` (niri) or `config.toml` (noctalia)
> exclusively.

> [!warning] Serial console timing
> `expect` scripts are timing-sensitive. Under heavy CI load, boot time can vary
> significantly. Use generous timeouts and retry loops, not `sleep 5 && send ...`.

> [!tip] qcow2 backing files for space efficiency
> Use a backing file chain so multiple test variants share a common base:
> ```bash
> qemu-img create -f qcow2 -b arch-test.qcow2 -F qcow2 arch-test-variant.qcow2
> ```
> Each variant only stores the delta — a 30 GB base with 2 GB deltas per variant.

> [!warning] mosh requires UDP access
> If a server sits behind a strict firewall that blocks UDP 60000-61000, mosh cannot
> connect. Fall back to `ssh` + `tmux` in those environments.

> [!tip] Expect debugging
> Add `exp_internal 1` at the top of any expect script to see exactly what it's matching
> against. When a script breaks after an ISO update, this shows you the new prompt.

---

## Verification

After running the full pipeline, you should see:

```
============================================
  Automated Dotfiles Test Pipeline
  Disk: /tmp/arch-test.qcow2
  Time: 2026-09-27T12:00:00-03:00
============================================

==> Step 1: Reverting to clean-install snapshot...

==> Step 2: Starting VM...
  VM PID: 12345

==> Step 3: Waiting for SSH on port 2222...
  SSH ready after 12 attempts

==> Step 4: Deploying dotfiles...

==> Step 5: Running test assertions...
  PASS: niri binary
  PASS: waybar binary
  PASS: foot binary
  PASS: fuzzel binary
  PASS: niri config exists
  PASS: waybar config exists
  PASS: niri config validates

  Results: 7 passed, 0 failed

==> Step 6: Shutting down VM...

============================================
  Test pipeline completed successfully
============================================
```

To verify the snapshot exists:

```bash
qemu-img snapshot -l /tmp/arch-test.qcow2
```

```
Snapshot list:
ID        TAG                 VM SIZE                DATE       VM CLOCK     ICOUNT
1         clean-install       2.3 GiB                2026-09-27 00:00:00.000 0
```

---

## Related

- [[arch-setup]] — host machine setup; the VM test environment validates changes before
  applying them here
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU) — KVM setup, QEMU flags, disk formats
- [Arch Linux installation guide](https://wiki.archlinux.org/title/Installation_guide) — manual
  install steps (what the expect script automates)
- [Scripted QEMU setup without libvirt — ArchWiki](https://wiki.archlinux.org/title/User:Nd43/Scripted_QEMU_setup_without_libvirt) — the pattern this guide follows
- [GNU Stow manual](https://www.gnu.org/software/stow/manual/) — symlink farm management
- [niri repository](https://github.com/YaLTeR/niri) — Wayland compositor, config format,
  `niri validate`
- [QEMU qemu-img documentation](https://www.qemu.org/docs/master/tools/qemu-img.html) —
  snapshot, backing file, and commit commands
- [QEMU iotests](https://www.qemu.org/docs/master/devel/testing.html) — how the QEMU
  project itself tests with bash scripts
