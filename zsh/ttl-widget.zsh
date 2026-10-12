#!/usr/bin/env zsh
#####################################################################
# ttl-widget — countdowns for the prompt and tmux
#####################################################################
#
# Renders a color-coded "time left" segment for short-lived credentials
# (SSH certificates, Kerberos tickets, cloud tokens, ...):
#
#   green  🪪 14h 2m    healthy
#   yellow 🪪 42m       expiring within the provider's warn window
#   red    🪪 expired   missing or expired
#
# and for upcoming events such as a scheduled reboot, which stay hidden
# until they are close:
#
#   (hidden)            nothing scheduled, or further away than show_within
#   yellow 🔄 5h 10m    within show_within
#   red    🔄 42m       within the warn window (or "now" once due)
#
# Usage:
#   source ttl-widget.zsh        from .zshrc: prompt segment (outside tmux)
#   ttl-widget tmux              from tmux status-right: #[...] segments
#   ttl-widget refresh [name]    re-probe now (all widgets, or one)
#
# Design: prompt and tmux renders only read a tiny per-user cache file
# (`<expires_epoch> <last_check_epoch> <ok|expired>`), so rendering never
# forks. Probes run asynchronously and disowned, guarded by a 30s lock:
#   - expired:       re-probe every 30s
#   - within warn:   re-probe every 2m
#   - healthy:       re-probe every 10m
#
# Adding a widget:
#   A provider is a function that prints the credential's expiry as epoch
#   seconds and returns 0, or returns non-zero if the credential is missing.
#   Register it with:
#
#     ttl_widget_register <name> <icon> <probe_fn> [warn_secs=3600]
#
#   An event provider works the same way but returns non-zero when nothing
#   is scheduled; register it with:
#
#     ttl_widget_register_event <name> <icon> <probe_fn> \
#       [warn_secs=3600] [show_within_secs=28800]
#
#   Registering an existing name again replaces its icon, probe and windows,
#   so a variant can swap in a better probe for a built-in widget.
#
#   Put extra providers in ~/.config/ttl-widget/*.zsh; they are sourced by
#   both the prompt and the tmux renderer. See the `step` example below.

zmodload zsh/datetime

typeset -ga _TTL_WIDGETS
typeset -gA _TTL_ICON _TTL_PROBE _TTL_WARN _TTL_SHOW
typeset -g ttl_prompt_info=""

# _TTL_SHOW[name] is empty for credentials and holds show_within for events.
ttl_widget_register() {
  local name=$1 icon=$2 probe=$3 warn=${4:-3600}
  (( ${+functions[$probe]} )) || return 1
  (( ${_TTL_WIDGETS[(Ie)$name]} )) || _TTL_WIDGETS+=("$name")
  _TTL_ICON[$name]=$icon
  _TTL_PROBE[$name]=$probe
  _TTL_WARN[$name]=$warn
  _TTL_SHOW[$name]=""
}

ttl_widget_register_event() {
  ttl_widget_register "$1" "$2" "$3" "${4:-3600}" || return 1
  _TTL_SHOW[$1]=${5:-28800}
}

#--------------------------------------------------------------------
# Cache & probing (side effects live here)
#--------------------------------------------------------------------

_ttl_cache_path() { REPLY="${TMPDIR:-/tmp}/ttl_${1}_${UID}"; }

_ttl_refresh_sync() {
  local name=$1 now=$EPOCHSECONDS expires
  _ttl_cache_path "$name"
  local cache=$REPLY tmp="$REPLY.tmp.$$"
  if expires=$("${_TTL_PROBE[$name]}" 2>/dev/null) \
      && [[ $expires == <-> ]] && (( expires > now )); then
    print -r -- "$expires $now ok" >| "$tmp"
  else
    print -r -- "0 $now expired" >| "$tmp"
  fi
  mv -f "$tmp" "$cache"
}

_ttl_refresh_async() {
  local name=$1 lock_time
  _ttl_cache_path "$name"
  local lock="$REPLY.lock"
  if [[ -r $lock ]] && read -r lock_time < "$lock" \
      && [[ $lock_time == <-> ]] && (( EPOCHSECONDS - lock_time < 30 )); then
    return 0
  fi
  print -r -- "$EPOCHSECONDS" >| "$lock"
  ( _ttl_refresh_sync "$name"; rm -f "$lock" ) </dev/null &>/dev/null &!
}

#--------------------------------------------------------------------
# State & rendering (pure apart from scheduling a background refresh)
#--------------------------------------------------------------------

# 3725 -> "1h 2m"
_ttl_format() {
  local ttl=$1
  local d=$(( ttl / 86400 )) h=$(( ttl % 86400 / 3600 )) m=$(( ttl % 3600 / 60 ))
  if   (( d > 0 )); then REPLY="${d}d ${h}h"
  elif (( h > 0 )); then REPLY="${h}h ${m}m"
  elif (( m > 0 )); then REPLY="${m}m"
  else                   REPLY="<1m"
  fi
}

# Sets reply=(<state> <time_str>) and returns 0, or returns 1 when the widget
# should not be shown (still unknown, or an event that is absent or far off).
# Credential states: ok, warn, expired. Event states: soon, imminent.
_ttl_state() {
  local name=$1 now=$EPOCHSECONDS expires=0 last=0 st=unknown
  _ttl_cache_path "$name"
  if [[ ! -r $REPLY ]]; then
    _ttl_refresh_async "$name"
    return 1
  fi
  read -r expires last st < "$REPLY"

  local ttl=$(( expires - now )) warn=${_TTL_WARN[$name]}
  local show=${_TTL_SHOW[$name]}
  if [[ -n $show ]]; then
    _ttl_event_state "$name" "$now" "$last" "$st" "$ttl" "$warn" "$show"
    return
  fi
  if [[ $st != ok ]] || (( ttl <= 0 )); then
    (( now - last > 30 )) && _ttl_refresh_async "$name"
    reply=(expired expired)
    return 0
  fi

  local interval=$(( ttl <= warn ? 120 : 600 ))
  (( now - last > interval )) && _ttl_refresh_async "$name"
  _ttl_format "$ttl"
  if (( ttl <= warn )); then reply=(warn "$REPLY"); else reply=(ok "$REPLY"); fi
}

_ttl_event_state() {
  local name=$1 now=$2 last=$3 st=$4 ttl=$5 warn=$6 show=$7
  # Nothing scheduled, or not yet close enough to show: check hourly.
  if [[ $st != ok ]] || (( ttl > show )); then
    (( now - last > 3600 )) && _ttl_refresh_async "$name"
    return 1
  fi
  local interval=$(( ttl <= warn ? 120 : 600 ))
  (( now - last > interval )) && _ttl_refresh_async "$name"
  if (( ttl <= 0 )); then
    reply=(imminent now)
  else
    _ttl_format "$ttl"
    if (( ttl <= warn )); then reply=(imminent "$REPLY"); else reply=(soon "$REPLY"); fi
  fi
}

# $1 = tmux | airline | brackets. Sets REPLY to all widget segments.
_ttl_render() {
  local fmt=$1 out="" name st t i
  for name in $_TTL_WIDGETS; do
    _ttl_state "$name" || continue
    st=$reply[1] t=$reply[2] i=${_TTL_ICON[$name]}
    case $fmt:$st in
      tmux:expired)         out+="#[fg=red,bold]$i EXPIRED#[default]  " ;;
      tmux:imminent)        out+="#[fg=red,bold]$i $t#[default]  " ;;
      tmux:(warn|soon))     out+="#[fg=yellow]$i $t#[default]  " ;;
      tmux:ok)              out+="#[fg=green]$i $t#[default]  " ;;
      airline:expired)      out+="%K{160}%F{255}%B $i expired %b%f%k" ;;
      airline:imminent)     out+="%K{160}%F{255}%B $i $t %b%f%k" ;;
      airline:(warn|soon))  out+="%K{208}%F{232}%B $i $t %b%f%k" ;;
      airline:ok)           out+="%K{22}%F{255} $i $t %f%k" ;;
      brackets:expired)     out+=" %B%F{red}[$i expired]%f%b" ;;
      brackets:imminent)    out+=" %B%F{red}[$i $t]%f%b" ;;
      brackets:(warn|soon)) out+=" %F{yellow}[$i $t]%f" ;;
      brackets:ok)          out+=" %F{green}[$i $t]%f" ;;
    esac
  done
  REPLY=$out
}

ttl-widget-refresh() {
  local name
  for name in ${@:-$_TTL_WIDGETS}; do
    (( ${+_TTL_PROBE[$name]} )) && _ttl_refresh_sync "$name"
  done
  [[ -n $TMUX ]] && tmux refresh-client -S 2>/dev/null
  return 0
}

#####################################################################
# Example provider: smallstep SSH certificate (`step ssh login`)
#####################################################################
# Reads certificates loaded in ssh-agent -- the ones ssh actually uses --
# and reports the latest expiry. Narrow the match to a key comment (step
# uses the login identity, e.g. you@example.com) with:
#   TTL_STEP_SSH_MATCH='*you@example.com*'

_ttl_probe_step_ssh() {
  local line to epoch best=0
  for line in ${(f)"$(ssh-add -L 2>/dev/null)"}; do
    [[ $line == *-cert-v01@openssh.com\ * ]] || continue
    [[ $line == ${~TTL_STEP_SSH_MATCH:-*} ]] || continue
    # "        Valid: from 2026-09-28T10:00:00 to 2026-09-29T02:00:00"
    to=${(M)${(f)"$(print -r -- "$line" | ssh-keygen -L -f - 2>/dev/null)"}:#*Valid:*}
    to=${to##* to }
    [[ $to == forever ]] && { best=4102444800; break; }  # 2100-01-01
    strftime -r -s epoch '%Y-%m-%dT%H:%M:%S' "$to" 2>/dev/null || continue
    (( epoch > best )) && best=$epoch
  done
  (( best > 0 )) && print -r -- "$best"
}

if (( ${+commands[step]} && ${+commands[ssh-add]} )); then
  ttl_widget_register step 🪪 _ttl_probe_step_ssh 3600
fi

#####################################################################
# Event provider: systemd scheduled shutdown/reboot (`shutdown -r +N`)
#####################################################################
# systemd-logind records a pending shutdown in /run/systemd/shutdown/scheduled
# as USEC=<microseconds since the epoch>. Shown once it is within 8 hours.

_ttl_probe_systemd_shutdown() {
  local line
  [[ -r /run/systemd/shutdown/scheduled ]] || return 1
  while IFS= read -r line; do
    if [[ $line == USEC=<-> ]]; then
      print -r -- $(( ${line#USEC=} / 1000000 ))
      return 0
    fi
  done < /run/systemd/shutdown/scheduled
  return 1
}

if [[ -d /run/systemd/system ]]; then
  ttl_widget_register_event reboot 🔄 _ttl_probe_systemd_shutdown 3600 28800
fi

#####################################################################
# Local / variant providers
#####################################################################
() {
  local f
  for f in ${XDG_CONFIG_HOME:-$HOME/.config}/ttl-widget/*.zsh(N); do
    source "$f"
  done
}

#####################################################################
# Entry points
#####################################################################

if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  # Executed as a script (tmux status-right, or manual refresh).
  case $1 in
    tmux)    _ttl_render tmux; print -rn -- "$REPLY" ;;
    refresh) shift; ttl-widget-refresh "$@" ;;
    *)       print -u2 "usage: ttl-widget {tmux|refresh [name...]}"; exit 2 ;;
  esac
  return 0 2>/dev/null || exit 0
fi

# Sourced from .zshrc.
(( ${#_TTL_WIDGETS} )) || return 0

# Refresh the moment the credential is renewed.
if (( ${+_TTL_PROBE[step]} )); then
  step() {
    command step "$@"
    local ret=$?
    (( ret == 0 )) && [[ $1 == ssh && $2 == (login|renew) ]] && ttl-widget-refresh step
    return $ret
  }
fi

# Inside tmux the status bar shows the widgets (tmux.conf runs
# `ttl-widget tmux`), so only add the prompt segment outside tmux.
if [[ -z $TMUX ]]; then
  _ttl_precmd() {
    _ttl_render "${PROMPT_STYLE:-airline}"
    ttl_prompt_info=$REPLY
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _ttl_precmd
  RPS1_EXTRA+='${ttl_prompt_info}'
fi
