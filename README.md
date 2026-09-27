# steckel/dotfiles

Personal zsh and tmux configuration for macOS and Linux.

## Install

```sh
git clone https://github.com/steckel/dotfiles.git
cd dotfiles
make
```

`make` symlinks `~/.zshrc` and `~/.tmux.conf` into this repo. An existing
`~/.zshrc` is backed up and appended to `~/.zshrc.local`, which is sourced last
and is the place for machine-specific settings.

Individual targets: `make zsh`, `make tmux`, `make tmux-down`. On a new Mac,
`make macos` applies system defaults (prompts for sudo and restarts the Dock
and Finder, so it is not part of `make`). Where Konsole is used, `make konsole`
installs the Solarized Dark color scheme and makes it the default profile.

## License

This project is licensed under the GNU General Public License
version 3 or later (GPL-3.0-or-later). See LICENSE for details.
