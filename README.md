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
installs the Solarized Dark profile, selects **GoogleSansCode Nerd Font Mono**
at **10 points**, and makes the profile the default. Run it on the machine
running the terminal; existing windows may need to be reopened.

Run `make fonts` to install Google Sans Code through the
[official Nerd Fonts installer](https://github.com/ryanoasis/nerd-fonts/blob/adbd16ab7ca911eaca7ce3b0f2b7994207c7ecae/install.sh).
The wrapper pins the upstream installer revision and font release (`v3.5.1`);
upstream handles downloads, extraction, installation, and font-cache refresh.
It requires Bash, curl, tar with xz support, and standard Unix tools. Run it
as your normal user on Linux or macOS. Upstream uses the user font directory
and supports `FONT_DIR` and `XDG_DATA_HOME` overrides. Other terminal apps
need the font selected manually.

Font installation and profile configuration are separate explicit steps:

```sh
make fonts
make konsole
```

Neither target is part of default `make`. Rerunning `make fonts` delegates
updates to the pinned upstream installer; it can download the font again.

`make claude` symlinks `claude/settings.json`, `claude/statusline-command.sh`,
and `claude/set-busy.sh` into `~/.claude/`. It's not part of `make` — run it
by hand. `make claude-down` removes the symlinks.

## Tmux plugins

`make tmux` installs [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm)
into `~/.tmux/plugins/tpm` when missing. Git and network access are needed for
that first installation. `make tpm` installs only the manager; existing TPM
checkouts are left in place.

Add `set -g @plugin 'owner/plugin'` lines above the TPM initializer at the end
of `tmux/tmux.conf`, then reload with `tmux source-file ~/.tmux.conf`.
Press `Ctrl-a`, then **I** to install declared plugins, **U** to update them,
or **Alt-u** to remove undeclared plugins.

[tmux-complications](https://github.com/steckel/tmux-complications) owns the
status bar through TPM. It needs tmux 3.5+, Bash 3.2+, awk, and standard Unix
utilities; no build is required. The repository currently requires GitHub SSH
access, so authenticate before pressing **I**. `make tmux` links the bar
composition from `tmux/complications/config.toml`: hostname, windows, and clock
on one row. Rendering and interaction changes belong in the plugin repository.

For local plugin development, clone that repository alongside dotfiles as
`../complications`. Before installing it with TPM, link the checkout:

```sh
mkdir -p ~/.tmux/plugins
ln -s /absolute/path/to/complications ~/.tmux/plugins/tmux-complications
```

If TPM already installed it, move that checkout aside before creating the link.
Reload tmux after plugin edits. TPM's update command also updates linked Git
checkouts, so keep local development changes committed before using **U**.

## License

This project is licensed under the GNU General Public License
version 3 or later (GPL-3.0-or-later). See LICENSE for details.
