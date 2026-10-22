# 50-prompt.zsh — the prompt
#
# The prompt is `pure` (https://github.com/sindresorhus/pure), loaded
# through zinit below. It replaces the two prompts that came before it:
#
#   * powerlevel10k — needed a generated ~/.p10k.zsh from an interactive
#     wizard, and cost a few milliseconds on every shell start.
#   * a hand-rolled prompt in this same file — fast, but it carried its
#     own git parser and its own colour handling.
#
# pure draws the branch, the staged/unstaged/untracked counts, the
# upstream ahead/behind markers, the last command's duration and its exit
# code, and it does the git lookups asynchronously through zsh-async, so
# a slow repository does not slow the prompt down.
#
# It needs a font with the right glyphs. JetBrains Mono Nerd Font is
# already installed and already selected in Alacritty, so there is
# nothing to do here.
#
# Loaded last on purpose: pure owns PROMPT, and anything that touched the
# prompt afterwards would fight it.

zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure
