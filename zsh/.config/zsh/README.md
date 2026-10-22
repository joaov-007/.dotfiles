# zsh config

Modern, fast, fish-like. zinit for plugins, `pure` for the prompt, and
the binaries (fzf, zoxide, atuin, bat, eza, delta) from pacman.

## Layout

```
~/.zshenv              ZDOTDIR + XDG paths        (loaded for every zsh)
~/.zshrc               fallback, see below
~/.config/zsh/
  .zshrc               entry point, sources the numbered files in order
  00-paths.zsh         PATH helpers (append_path / prepend_path)
  05-mise.zsh          mise activation
  10-options.zsh       setopt
  20-history.zsh       HISTFILE, history options, atuin
  30-completion.zsh    compinit + zstyle
  35-zinit.zsh         zinit bootstrap + the zsh plugins
  40-plugins.zsh       fzf, fzf-tab styles, zoxide
  45-enviroment.zsh    environment variables
  50-prompt.zsh        the prompt (pure)
  60-keys.zsh          keybindings
  70-aliases.zsh       aliases and small functions
  80-git.zsh           git helpers (fuzzy log, branch, reflog)
```

The `NN-` prefixes define load order, which matters:

- options before history (they interact),
- completion before the plugins (fzf-tab and zoxide both hook into it),
- syntax highlighting before autosuggestions (it needs the ZLE hooks that
  get set up first),
- the prompt after everything else (`pure` owns `PROMPT`).

To add a file of your own, name it so it sorts where you want it —
`45-my-stuff.zsh` runs after the plugins.

## Deployment

The repo is deployed with GNU Stow. Everything zsh-related lives in the
`zsh/` package, so one command installs all of it:

```sh
cd ~/.dotfiles
stow -t ~ zsh
```

That creates three symlinks:

| target | source |
| --- | --- |
| `~/.zshenv` | `zsh/.zshenv` |
| `~/.zshrc` | `zsh/.zshrc` |
| `~/.config/zsh` | `zsh/.config/zsh` |

To update a change, edit the file in the repo and re-run `stow -t ~ zsh`
(or nothing at all — the symlinks point straight at the repo).

To uninstall: `stow -D -t ~ zsh`.

### Why `~/.zshenv`

zsh resolves the location of `.zshenv` / `.zshrc` / `.zlogin` once, at
startup, from the environment it already has. Setting `ZDOTDIR` inside
`~/.zshrc` is too late — by then zsh has already decided to read
`~/.zshrc`. So the pointer lives in `~/.zshenv`, and zsh reads
`~/.config/zsh/.zshrc` directly.

`~/.zshenv` runs for non-interactive shells too, so it contains nothing
but variable assignments. `~/.zshrc` remains only as a fallback in case
`ZDOTDIR` is ever unset.

## Plugins

zinit manages the zsh plugins. It is **not** used as a package manager:
every program is a pacman package.

| plugin | what it does |
| --- | --- |
| `fast-syntax-highlighting` | colours the command line as you type |
| `zsh-autosuggestions` | fish-style ghost text from your history |
| `fzf-tab` | the Tab key opens an fzf menu |
| `pure` | the prompt |

zinit itself is cloned to `~/.local/share/zinit/zinit.git` on first run.
Update it with `zinit self-update`.

The system tools are used as they are:

| tool | what it does |
| --- | --- |
| `fzf` | Ctrl-R history, Ctrl-T files, Alt-C directory jump |
| `zoxide` | `z` jumps to frecent directories, `zi` picks one |
| `atuin` | history synced across machines, fuzzy Ctrl-R |
| `bat` / `delta` / `eza` | previews in the fzf menu |

## Keybindings

| Key | Action |
| --- | --- |
| `Tab` | fzf completion menu, `←`/`→` to move, `Enter` to pick |
| `Shift-Tab` | previous completion group |
| `Ctrl-R` | fuzzy history search (atuin, synced across machines) |
| `Ctrl-T` | fuzzy file search (fzf) |
| `Alt-C` | jump to a directory (fzf) |
| `↑` / `↓` | search history by what you've typed so far |
| `→` | accept the whole ghost suggestion (at end of line) |
| `Ctrl+→` / `Ctrl+←` | accept / give back one word of it |
| `Ctrl-X Ctrl-E` | open the current line in `$EDITOR` |
| `Alt-.` | insert the last argument of the previous command |
| `Alt-Delete` | delete the word under the cursor |

## The prompt

`pure` (https://github.com/sindresorhus/pure), loaded through zinit. It
shows the path, the branch with the staged/unstaged/untracked counts and
the upstream ahead/behind markers, the duration of the last command and
its exit code. The git lookups run asynchronously through `zsh-async`, so
a large repository does not slow the prompt down.

It needs a font with the right glyphs — JetBrains Mono Nerd Font is
already installed and already selected in Alacritty.

## History

Stored at `~/.local/share/zsh/history`. `SHARE_HISTORY` is on, so every
terminal shares one live history.

A command starting with a space is not recorded. Use that deliberately:
` sudo systemctl restart nginx`.

Atuin adds a synced history on top and takes over Ctrl-R. Its up-arrow
and AI bindings are disabled on purpose — the up-arrow belongs to zsh's
prefix search, and the AI binding would swallow the `?` key.

## Git

The git config in `~/.config/git/config` keeps the history linear: pulls
rebase instead of merging, pushes send only the current branch, and a
rebase stashes your work instead of refusing to start. Conflicts use
`zdiff3`, and `rerere` remembers how a conflict was resolved.

The shell side reads that history:

| command | what it does |
| --- | --- |
| `git_lg` (`glg`) | browse the commits of the branch, with a preview |
| `git_br` (`gbr`) | fuzzy branch switcher |
| `git_ref` (`gref`) | browse the reflog, the way back to a lost commit |
| `git_root` (`groot`) | jump to the top of the repository |

## Performance

The completion cache is rebuilt once a day and loaded straight from
memory otherwise, so `compinit` costs about a millisecond on a warm
shell. Everything else is lazy: no plugin is loaded that you do not use,
and each block in `40-plugins.zsh` skips itself when its package is
missing.

## Troubleshooting

**Startup is slow or errors.** Comment out files in `~/.config/zsh/` one
at a time to find the culprit; each section is independent.

**Tab shows a plain list instead of fzf.** `fzf-tab` did not load. Check
it with `zinit loaded` and reinstall it with `zinit delete Aloxaf/fzf-tab`
followed by `zinit light Aloxaf/fzf-tab`.

**No ghost suggestions.** `zsh-autosuggestions` did not load. Check it
with `zinit loaded`.

**`?` does nothing.** Atuin's AI binding. It is disabled in
`20-history.zsh`; if you re-enabled it, that is what took the key.

**Undo a change.** Everything is plain zsh script; read it and edit.
