# The shell

Everything zsh-related is the `zsh/` package. It installs three paths:

| Target | Source |
| --- | --- |
| `~/.zshenv` | `zsh/.zshenv` |
| `~/.zshrc` | `zsh/.zshrc` |
| `~/.config/zsh` | `zsh/.config/zsh` |

The package carries its own README with the full reference:
[`zsh/.config/zsh/README.md`](../zsh/.config/zsh/README.md). This page
covers what matters at the repository level.

## The layout

```
~/.config/zsh/
  .zshrc               entry point, sources the numbered files in order
  00-paths.zsh         PATH helpers (append_path / prepend_path)
  02-cache.zsh         cached initialisers (fzf, zoxide, atuin)
  05-mise.zsh          mise activation
  10-options.zsh       setopt, keymap
  20-history.zsh       HISTFILE, history options, atuin
  30-completion.zsh    compinit + zstyle
  35-zinit.zsh         zinit bootstrap + the zsh plugins
  40-plugins.zsh       fzf, fzf-tab styles, zoxide
  45-environment.zsh   environment variables
  50-prompt.zsh        the prompt (pure)
  60-keys.zsh          keybindings
  70-aliases.zsh       aliases and small functions
  80-git.zsh           git helpers (fuzzy log, branch, reflog)
```

The `NN-` prefixes are the load order, and the order matters:

- options before history, because `SHARE_HISTORY` and friends interact;
- completion before the plugins, because fzf-tab and zoxide both hook into it;
- the prompt after everything else, because `pure` owns `PROMPT`.

A new file is named so it sorts where it is wanted — `45-my-stuff.zsh`
runs after the plugins.

## Why `~/.zshenv` exists

zsh resolves the location of `.zshenv` / `.zshrc` / `.zlogin` once, at
startup, from the environment it already has. Setting `ZDOTDIR` inside
`~/.zshrc` is too late — by then zsh has already decided to read
`~/.zshrc`. So the pointer lives in `~/.zshenv`, and zsh reads
`~/.config/zsh/.zshrc` directly.

`~/.zshenv` runs for non-interactive shells too, so it contains nothing but
variable assignments. `~/.zshrc` stays as a fallback for the case where
`ZDOTDIR` is unset.

## Two managers, one job each

zinit manages the zsh **plugins**. mise manages the **tool versions**.
Neither of them installs the programs: `fzf`, `zoxide`, `atuin`, `bat`,
`eza` and `delta` are all distribution packages. See
[packages.md](packages.md).

## The startup cost

`02-cache.zsh` exists because four programs — fzf, zoxide, atuin and
mise — each write a small shell script when asked to set themselves up.
Asking costs a process spawn each, around 55 ms of the startup on this
machine, and the script they produce only changes when the program
itself changes.

So the script is generated once, written to the cache directory and
sourced from there afterwards. The cached copy is discarded when the
binary that produced it is newer than the copy, so a package upgrade
regenerates it.

`mise activate` is deliberately not cached. The script it writes bakes in
the `PATH` of the shell that asked for it, and a cached copy would freeze
that `PATH` for every shell that came after it.

Nothing in that file is a dependency. When the binary is missing, the
block that asked for it does nothing at all.

## The prompt

`pure`, loaded through zinit. It shows the path, the branch with the
staged/unstaged/untracked counts and the upstream ahead/behind markers,
the duration of the last command and its exit code. The git lookups run
asynchronously through `zsh-async`, so a large repository does not slow
the prompt down.

`50-prompt.zsh` turns on the parts pure keeps off by default: the stash
count, the number of dirty files instead of a single dot, the node
version, and a dim `/` between the parts of the path.

It needs a font with the right glyphs. JetBrains Mono Nerd Font is the
one selected in Alacritty.

## History

zsh stores its history at `~/.local/share/zsh/history`. `SHARE_HISTORY` is
on, so every terminal shares one live history.

A command starting with a space is not recorded. That is deliberate:

```sh
 sudo systemctl restart nginx
```

Atuin adds a synced history on top and takes over Ctrl-R. Its up-arrow
and AI bindings are disabled on purpose — the up-arrow belongs to zsh's
prefix search, and the AI binding would swallow the `?` key.

## Portability

Nothing in the shell config names a distribution, a user or a home
directory. `ZDOTDIR`, the XDG directories and every plugin path are
derived from `$HOME` at runtime, so the same files work under a different
user name, on a different distribution, and in a container.

The one exception is `45-environment.zsh`, which exports
`GITHUB_USERNAME` — a personal value, not a machine-specific one. Machine
specific values belong in the file the user edits, not in the tracked
config.

## Editing

Edit the file in the repository. The symlink points at the working tree,
so the change is live the moment the file is saved. Re-running
`scripts/stow/stow.sh zsh` is only needed when a **new** file appears
that was not there when the link was made.

```sh
# what the package would link
./scripts/stow/stow.sh --dry-run zsh
```
