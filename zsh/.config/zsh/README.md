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
  02-cache.zsh         cached initialisers (fzf, zoxide, atuin, mise)
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

## Tool versions

`mise` manages the tool versions. It is the only version manager on this
machine — the old asdf setup is gone.

Which tools exist and which version each one is pinned to lives in
`mise/.config/mise/config.toml`, stowed to `~/.config/mise/config.toml`:

```toml
[tools]
jd = "latest"
node = "latest"
npm = "latest"
```

`05-mise.zsh` evaluates `mise activate zsh`, which puts the shims at the
front of `PATH` and re-resolves the versions when the working directory
changes.

Everything else — `fzf`, `zoxide`, `atuin`, `bat`, `eza`, `delta`, `git` —
is a pacman package and is deliberately absent from that list.

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

### fzf

`40-plugins.zsh` sets the environment fzf reads:

| variable | value |
| --- | --- |
| `FZF_DEFAULT_OPTS` | half the screen, reversed layout, rounded border, inline info |
| `FZF_CTRL_T_COMMAND` | `fd`, so the file picker skips what `.gitignore` skips |
| `FZF_CTRL_T_OPTS` | previews the file with `bat` |
| `FZF_ALT_C_COMMAND` | `fd` on directories only |
| `FZF_ALT_C_OPTS` | previews the directory as a tree |

`FZF_DEFAULT_OPTS` reaches the completion menu too, because fzf-tab is
told to use it. fzf-tab sets the height itself, so the menu is sized to
the number of matches and not to the screen.

### man

`MANPAGER` points at `bat`, which keeps the bold and the underline that
`man | less` throws away. `PAGER` is `less -R`, which keeps the colours
and leaves the other escape sequences alone.

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

`50-prompt.zsh` turns on the parts pure keeps off by default: the stash
count, the number of dirty files instead of a single dot, the node
version, and a dim `/` between the parts of the path.

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

`git_br` completes branch names with Tab.

## Performance

A shell start costs **350 ms to 400 ms** on this machine, depending on
what else is running; zsh itself, with no configuration at all, costs
5 ms of that.

| what | cost |
| --- | --- |
| zinit and the four plugins | ~155 ms |
| `mise activate` | ~33 ms |
| the rest of the config | ~150 ms |

Measure it yourself with `time zsh -i -c exit`, and watch where the
time goes with `zinit times`.

zinit is the biggest part of it, and it is the price of the plugin
manager: sourcing `fast-syntax-highlighting` on its own takes 35 ms, and
zinit spends another 90 ms of bookkeeping around it.

`mise activate` is the second biggest, and it cannot be cached: the
script it writes bakes the PATH of the shell that asked for it, so a
cached copy would freeze that PATH for every shell that came after.

The four initialisers that *can* be cached are: the shell integrations of
fzf, zoxide and atuin, and mise's completion script. They are written to
`~/.cache/zsh/init` and sourced from there. The cached copy is thrown
away when the binary that produced it is newer than the copy, so a
package upgrade regenerates it. To rebuild them by hand:

```sh
rm -rf ~/.cache/zsh/init
```

The completion cache is rebuilt once a day and loaded straight from
memory otherwise. Everything else is lazy: no plugin is loaded that you
do not use, and each block in `40-plugins.zsh` skips itself when its
package is missing.

## Troubleshooting

**Startup is slow or errors.** Comment out files in `~/.config/zsh/` one
at a time to find the culprit; each section is independent. `zinit times`
shows where the time went.

**A key does nothing after an upgrade.** The cached initialiser in
`~/.cache/zsh/init` may be from the old version of the program. Remove
the directory and open a new shell.

**Tab shows a plain list instead of fzf.** `fzf-tab` did not load. Check
it with `zinit loaded` and reinstall it with `zinit delete Aloxaf/fzf-tab`
followed by `zinit light Aloxaf/fzf-tab`.

**No ghost suggestions.** `zsh-autosuggestions` did not load. Check it
with `zinit loaded`.

**`?` does nothing.** Atuin's AI binding. It is disabled in
`20-history.zsh`; if you re-enabled it, that is what took the key.

**Undo a change.** Everything is plain zsh script; read it and edit.
