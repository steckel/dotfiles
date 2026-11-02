# steckel/dotfiles

Personal zsh, tmux, and Claude Code configuration for macOS and Linux.

## Install

```sh
git clone https://github.com/steckel/dotfiles.git
cd dotfiles
make
```

`make` symlinks `~/.zshrc` and `~/.tmux.conf` into this repo. An existing
`~/.zshrc` is backed up and appended to `~/.zshrc.local`, which is sourced last
and is the place for machine-specific settings.
Use `make zsh ZSH_MIGRATE_LOCAL=0` to skip appending the previous `.zshrc`
to `.zshrc.local`. A backup is still saved, and existing local settings are
preserved. The default remains to migrate the previous configuration.

Run `make login-shell` explicitly to select zsh as your account's login shell.
It requires zsh to be installed and listed in `/etc/shells`; `chsh` may ask
for your password. Existing zsh login shells are left alone, including
`/bin/zsh` versus `/usr/bin/zsh`. This target is separate from `make` and
`make zsh`. Log out and back in for the change to apply; `exec zsh` switches
the current terminal immediately.

Individual targets: `make zsh`, `make tmux`, `make tmux-down`. On a new Mac,
`make macos` applies system defaults (prompts for sudo and restarts the Dock
and Finder, so it is not part of `make`). Where Konsole is used, `make konsole`
installs the Solarized Dark color scheme and makes it the default profile.

`make claude` symlinks `claude/settings.json`, `claude/statusline-command.sh`,
and `claude/set-busy.sh` into `~/.claude/`. It's not part of `make` — run it
by hand. `make claude-down` removes the symlinks.

## License

This project is licensed under the GNU General Public License
version 3 or later (GPL-3.0-or-later). See LICENSE for details.
