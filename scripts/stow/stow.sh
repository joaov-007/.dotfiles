#!/usr/bin/env bash
set -Eeuo pipefail

# Stow the packages of this repository into a target directory, honouring the
# blacklist in .stow-local-ignore (NixOS config, repo tooling, /etc files,
# leftovers of the old zsh layout).
#
# Stow reads .stow-local-ignore only at the root of the package it stows, so
# per-package runs need this helper to pass the same list to every stow call.

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
IGNORE_FILE="$REPO_ROOT/.stow-local-ignore"

TARGET="$HOME"
DRY_RUN=false
VERBOSE=false
UNSTOW=false
ADOPT=false
GLOBAL_IGNORE=false
PACKAGES=()

show_help() {
	cat <<EOF
Usage: $0 [OPTIONS] PACKAGE [PACKAGE...]

Stow the given packages of the dotfiles repository into TARGET. Blacklisted
paths are never linked, neither as a package nor from inside a package.

Options:
-t, --target DIR   Target directory (default: $HOME)
-n, --dry-run      Show what would be done, change nothing
-v, --verbose      Verbose stow output
-u, --unstow       Remove the links instead of creating them
-a, --adopt       Adopt existing files that would conflict
-g, --global-ignore  Link ~/.stow-global-ignore to the blacklist and exit
-h, --help         Show this help

Examples:
$0 neovim
$0 --dry-run zsh espanso
$0 --target ~/.config neovim
$0 --unstow espanso
$0 --global-ignore
EOF
}

log() {
	printf '%s\n' "$*"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-t | --target)
		TARGET="${2:?--target requires a directory}"
		shift 2
		;;
	-n | --dry-run)
		DRY_RUN=true
		shift
		;;
	-v | --verbose)
		VERBOSE=true
		shift
		;;
	-u | --unstow)
		UNSTOW=true
		shift
		;;
	-a | --adopt)
		ADOPT=true
		shift
		;;
	-g | --global-ignore)
		GLOBAL_IGNORE=true
		shift
		;;
	-h | --help)
		show_help
		exit 0
		;;
	-*)
		printf 'Unknown option: %s\n' "$1" >&2
		show_help >&2
		exit 1
		;;
	*)
		PACKAGES+=("$1")
		shift
		;;
	esac
done

command -v stow >/dev/null 2>&1 || {
	printf 'stow is not installed\n' >&2
	exit 1
}

[[ -f "$IGNORE_FILE" ]] || {
	printf 'missing ignore file: %s\n' "$IGNORE_FILE" >&2
	exit 1
}

if [[ "$GLOBAL_IGNORE" == true ]]; then
	# stow consults ~/.stow-global-ignore for every package that has no
	# local ignore file, so plain "stow" calls honour the blacklist too
	ln -sfn "$IGNORE_FILE" "$HOME/.stow-global-ignore"
	log "linked $HOME/.stow-global-ignore -> $IGNORE_FILE"
	exit 0
fi

# Same parsing rules as stow: "#" starts a comment when it is at the
# beginning of the line or preceded by a space, "\#" is a literal "#".
segments=()
ignores=()
while IFS= read -r line || [[ -n "$line" ]]; do
	if [[ "$line" =~ ^[[:space:]]*# || "$line" =~ [[:space:]]# ]]; then
		line="${line%%[[:space:]]#*}"
	fi
	line="${line//\\#/#}"
	line="${line#"${line%%[![:space:]]*}"}"
	line="${line%"${line##*[![:space:]]}"}"
	[[ -n "$line" ]] || continue
	# qr{...} is the delimiter stow uses for --ignore, unbalanced braces
	# would break it
	if [[ "$line" == *'{'* || "$line" == *'}'* ]]; then
		log "skip pattern with braces: $line"
		continue
	fi
	ignores+=("$line")
	# patterns without "/" match a path segment, they can name a package
	if [[ "$line" != */* ]]; then
		segments+=("$line")
	else
		# "^/foo" is anchored to the package root; stow matches --ignore
		# against the path relative to the package, so the "/" goes away
		# and the "^" keeps the anchor
		ignores[-1]="${line/\//}"
	fi
done <"$IGNORE_FILE"

is_blacklisted() {
	local name="$1" pattern
	for pattern in "${segments[@]}"; do
		if [[ "$name" =~ ^($pattern)$ ]]; then
			return 0
		fi
	done
	return 1
}

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
	printf 'no package given, nothing to stow\n' >&2
	printf 'available packages: ' >&2
	for dir in "$REPO_ROOT"/*/; do
		name="$(basename "$dir")"
		if ! is_blacklisted "$name"; then
			printf '%s ' "$name" >&2
		fi
	done
	printf '\n' >&2
	exit 1
fi

stow_args=(--target="$TARGET" --dir="$REPO_ROOT")
for pattern in "${ignores[@]}"; do
	stow_args+=("--ignore=$pattern")
done
if [[ "$DRY_RUN" == true ]]; then
	stow_args+=(--no)
fi
if [[ "$VERBOSE" == true ]]; then
	stow_args+=(--verbose)
fi
if [[ "$UNSTOW" == true ]]; then
	stow_args+=(--unstow)
fi
if [[ "$ADOPT" == true ]]; then
	stow_args+=(--adopt)
fi

for package in "${PACKAGES[@]}"; do
	[[ -d "$REPO_ROOT/$package" ]] || {
		printf 'no such package: %s\n' "$package" >&2
		exit 1
	}
	if is_blacklisted "$package"; then
		printf 'refusing to stow blacklisted package: %s\n' "$package" >&2
		exit 1
	fi
	log "stow $package -> $TARGET"
	stow "${stow_args[@]}" "$package"
done
