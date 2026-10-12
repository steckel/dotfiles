# ~/.zshenv — sourced by every zsh, including non-interactive ones such as
# `ssh host cmd`. Keep it to environment variables; interactive setup belongs
# in ~/.zshrc.

# Terminate orphaned mosh-server sessions after 8 hours without client
# packets. mosh-server is started by a non-interactive SSH command before any
# interactive shell runs, so this has to be set here rather than in ~/.zshrc.
export MOSH_SERVER_NETWORK_TMOUT=28800

# Variant-specific and machine-local environment (not tracked here).
[[ -f ~/.zshenv.variant ]] && source ~/.zshenv.variant
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
