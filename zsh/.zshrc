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
bindkey -e
# End of lines configured by zsh-newuser-install

#####################################################################
# prompt
#####################################################################

autoload -Uz promptinit
promptinit
prompt redhat

#####################################################################
# aliases
#####################################################################

alias gst='git status'
alias gco='git checkout'

#####################################################################
# vim mode
#####################################################################

bindkey -v

bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward

function zle-line-init zle-keymap-select {
  VIM_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]%  %{$reset_color%}"
  RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/} $EPS1"
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

# Machine-local overrides (not tracked in dotfiles).
# Put per-machine tool bootstrapping (bun, nvm, rbenv, pyenv, etc.) here.
# See zsh/.zshrc.local.example in the dotfiles repo for a starting point.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# rustup (installed via Homebrew, keg-only)
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
