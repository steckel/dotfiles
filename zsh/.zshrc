# dotfiles:seeded
# The following lines were added by compinstall
zstyle :compinstall filename "${HOME}/.zshrc"

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install

HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd extendedglob nomatch notify
unsetopt beep
# End of lines configured by zsh-newuser-install

#####################################################################
# prompt
#####################################################################

# Inside tmux on the local host, omit user@host (already displayed in tmux status bar).
# Outside tmux (or when SSH'ed from a tmux pane into another machine where $TMUX is unset),
# include user@host on its own line so remote/non-tmux shells clearly identify themselves.
if [[ -n "$TMUX" ]]; then
  PS1='%1~ %(#.#.$) '
else
  PS1='%n@%M\n%1~ %(#.#.$) '
fi

#####################################################################
# vcs_info — git status on the right prompt
#####################################################################
#
# Renders ' (branch*+↑N↓N)' on RPS1 when inside a git repo:
#   *   unstaged changes (dirty working tree)
#   +   staged but uncommitted
#   ↑N  N commits ahead of upstream (not pushed)
#   ↓N  N commits behind upstream
#   ?   no upstream tracking branch configured
#
# vcs_info runs synchronously on each precmd; in very large repos this
# can add tens of ms per prompt. If that ever bites, switch to pure or
# starship for async git status.
#
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '%F{red}*%f'
zstyle ':vcs_info:git:*' stagedstr   '%F{yellow}+%f'
zstyle ':vcs_info:git:*' formats       '%b%u%c%m'
zstyle ':vcs_info:git:*' actionformats '%b|%a%u%c%m'

+vi-git-ahead-behind() {
  local ahead behind
  if git --no-optional-locks rev-parse @{upstream} &>/dev/null; then
    ahead=$(git --no-optional-locks rev-list --count @{upstream}..HEAD 2>/dev/null)
    behind=$(git --no-optional-locks rev-list --count HEAD..@{upstream} 2>/dev/null)
    (( ahead  )) && hook_com[misc]+="%F{green}↑${ahead}%f"
    (( behind )) && hook_com[misc]+="%F{magenta}↓${behind}%f"
  else
    hook_com[misc]+='%F{red}?%f'
  fi
}
zstyle ':vcs_info:git*+set-message:*' hooks git-ahead-behind

_vcs_info_no_locks() {
  GIT_OPTIONAL_LOCKS=0 vcs_info
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _vcs_info_no_locks
setopt prompt_subst

#####################################################################
# aliases
#####################################################################

alias gst='git status'
alias gco='git checkout'

#####################################################################
# vim mode & right prompt (RPS1) engine
#####################################################################
# Order (left-to-right on RPS1): [Vi Mode] -> [Git Status] -> [Extra]
# Supports two styles:
#   - "airline"  (1A: Solid colored background segments)
#   - "brackets" (2:  Standardized [...] foreground modules)
# Toggle anytime with `prompt-style` or set icon with `prompt-icon <icon>`

export PROMPT_STYLE="${PROMPT_STYLE:-airline}"
export PROMPT_VCS_ICON="${PROMPT_VCS_ICON:-🔀}"

_update_rprompt() {
  local style="${PROMPT_STYLE:-airline}"
  local icon="${PROMPT_VCS_ICON:-🔀}"
  local vim_seg vcs_seg extra_seg

  # 1. Vi Mode Segment (Leftmost on RPS1 — most dynamic)
  if [[ "$style" == "airline" ]]; then
    case "$KEYMAP" in
      vicmd) vim_seg="%K{214}%F{232}%B NORMAL %b%f%k" ;;
      *)     vim_seg="%K{24}%F{255} INSERT %f%k" ;;
    esac
  else
    case "$KEYMAP" in
      vicmd) vim_seg="%B%F{yellow}[NORMAL]%f%b" ;;
      *)     vim_seg="%F{blue}[INSERT]%f" ;;
    esac
  fi

  # 2. VCS / Git Segment (Middle on RPS1)
  if [[ -n "$vcs_info_msg_0_" ]]; then
    local vcs_prefix=""
    [[ -n "$icon" ]] && vcs_prefix="${icon} "
    if [[ "$style" == "airline" ]]; then
      vcs_seg="%K{237}%F{cyan} ${vcs_prefix}${vcs_info_msg_0_}%F{cyan} %f%k"
    else
      vcs_seg=" %F{cyan}[${vcs_prefix}${vcs_info_msg_0_}%F{cyan}]%f"
    fi
  else
    vcs_seg=""
  fi

  # 3. Extra / Variant Segment (Rightmost on RPS1 — least dynamic)
  RPS1="${vim_seg}${vcs_seg}"'${(e)RPS1_EXTRA}'
}

add-zsh-hook precmd _update_rprompt

# Toggle or set prompt style: `prompt-style` (toggles), `prompt-style airline`, `prompt-style brackets`
prompt-style() {
  if [[ "$1" == "airline" || "$1" == "1a" ]]; then
    export PROMPT_STYLE="airline"
  elif [[ "$1" == "brackets" || "$1" == "2" ]]; then
    export PROMPT_STYLE="brackets"
  else
    if [[ "${PROMPT_STYLE:-airline}" == "airline" ]]; then
      export PROMPT_STYLE="brackets"
    else
      export PROMPT_STYLE="airline"
    fi
  fi
  for hook in $precmd_functions; do
    "$hook"
  done
  _update_rprompt
  print -P "Prompt style set to %B${PROMPT_STYLE}%b: ${RPS1}"
}

# Set VCS branch icon: e.g. `prompt-icon 🌿` or `prompt-icon ⎇`
prompt-icon() {
  export PROMPT_VCS_ICON="$1"
  _update_rprompt
  print -P "Prompt VCS icon set to %B${PROMPT_VCS_ICON}%b: ${RPS1}"
}

bindkey -v

bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

function zle-line-init zle-keymap-select {
  _update_rprompt
  zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select
export KEYTIMEOUT=1
export PATH="$HOME/.local/bin:$PATH"

#####################################################################
# ssh-agent socket recovery (macOS)
#####################################################################
#
# Why this exists:
#
# macOS ships a launchd-managed ssh-agent. Its socket lives at a
# randomized path under /private/tmp/com.apple.launchd.XXXXXX/Listeners
# that is regenerated every login session. The path is published into
# the per-user GUI launchd domain (gui/$UID) as $SSH_AUTH_SOCK, and
# Terminal.app / iTerm2 inherit it when launched from the Dock.
#
# Two failure modes hit us:
#
#   1. A shell can end up with $SSH_AUTH_SOCK unset (e.g. spawned by
#      something not started via launchd, or via `sudo -i`), leaving
#      `step ssh login` and `ssh` with no agent to talk to.
#
#   2. tmux captures the env of whichever shell first started the
#      server. After a reboot the launchd socket path rotates, but
#      old tmux panes keep pointing at the dead path -- so one pane
#      works and a sibling pane silently doesn't.
#
# The fix has two halves:
#
#   (a) If $SSH_AUTH_SOCK is missing or dead, look it up out of the
#       gui/$UID launchd domain and adopt it. `launchctl getenv` does
#       not see this var on modern macOS; `launchctl print gui/$UID`
#       does, so we parse it out of there.
#
#   (b) Symlink the live socket to a stable path (~/.ssh/agent.sock)
#       and export *that* instead. Long-lived tmux panes then pin a
#       path that survives reboots -- the symlink target updates each
#       login, but the path tmux remembers stays valid.
#
# Pair this with `set -g update-environment "SSH_AUTH_SOCK ..."` in
# tmux.conf and `tmux kill-server` once, so the running tmux picks
# up the new var.
#
if [[ "$OSTYPE" == darwin* ]]; then
  # Ensure standard /usr/local/bin is in PATH for tools managed outside Homebrew
  if [[ ":$PATH:" != *":/usr/local/bin:"* && -d /usr/local/bin ]]; then
    export PATH="/usr/local/bin:$PATH"
  fi

  # (a) Recover SSH_AUTH_SOCK from launchd if it's empty or stale.
  if [[ -z "$SSH_AUTH_SOCK" || ! -S "$SSH_AUTH_SOCK" ]]; then
    sock=$(launchctl print gui/$UID 2>/dev/null \
      | awk -F' => ' '/SSH_AUTH_SOCK/ {print $2; exit}')
    [[ -S "$sock" ]] && export SSH_AUTH_SOCK="$sock"
    unset sock
  fi

  # (b) Pin a stable path so tmux panes survive socket rotation.
  if [[ -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]]; then
    ln -snf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
  fi
fi

# Variant-specific shell configuration
[[ -f ~/.zshrc.variant ]] && source ~/.zshrc.variant

# Solarized Dark for the Linux virtual console (before starting tmux).
# Linux OSC P palette controls: console_codes(4).
# https://ethanschoonover.com/solarized/
# Slots 0 and 7 use the dark background and normal foreground so ordinary
# console programs get readable defaults without needing their own theme.
# Slot 8 is a custom dim gray-blue, between the foreground and background.
if [[ "$OSTYPE" == linux* && "$TERM" == linux && -z "$TMUX" && -t 1 ]]; then
  () {
    local color
    for color in \
      0002b36 1dc322f 2859900 3b58900 \
      4268bd2 5d33682 62aa198 7839496 \
      8355157 9cb4b16 A586e75 B657b83 \
      C839496 D6c71c4 E93a1a1 Ffdf6e3; do
      printf '\033]P%s' "$color"
    done
  }
fi

# Machine-local overrides (not tracked in dotfiles).
# Put per-machine tool bootstrapping (bun, nvm, rbenv, pyenv, rustup, etc.) here.
# See zsh/.zshrc.local.example in the dotfiles repo for a starting point.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

