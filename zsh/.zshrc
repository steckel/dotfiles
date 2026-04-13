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

# Machine-local overrides (not tracked in dotfiles).
# Put per-machine tool bootstrapping (bun, nvm, rbenv, pyenv, etc.) here.
# See zsh/.zshrc.local.example in the dotfiles repo for a starting point.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
