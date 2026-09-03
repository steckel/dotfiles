.DEFAULT_GOAL := all
ROOT_DIR := $(CURDIR)
BREW := $(shell command -v brew 2>/dev/null || echo /opt/homebrew/bin/brew)

.PHONY: brew
brew:
	@if ! command -v brew &>/dev/null && [ ! -f /opt/homebrew/bin/brew ]; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Homebrew already installed."; \
	fi

.PHONY: tmux
tmux: brew
	@echo "Installing tmux via Homebrew..."
	@$(BREW) list tmux &>/dev/null || $(BREW) install tmux
	@echo "Symlinking tmux configuration files..."
	@ln -snf "$(ROOT_DIR)/tmux/tmux.conf" "$(HOME)/.tmux.conf"

.PHONY: tmux-down
tmux-down:
	@echo "Unlinking tmux configuration files..."
	@rm $(HOME)/.tmux.conf

.PHONY: zsh
# Install order matters:
#   1. Guarantee ~/.zshrc.local exists, so step 2 always has a file to append
#      to and never has to decide whether to create or clobber one.
#   2. Migrate any pre-existing, non-dotfiles ~/.zshrc into ~/.zshrc.local
#      (appended, never overwritten) and keep a .bak copy. The tracked .zshrc
#      sources ~/.zshrc.local at the end, so migrated config stays live.
#   3. Only then replace ~/.zshrc with the symlink.
# The "# dotfiles:seeded" marker on line 1 of zsh/.zshrc makes step 2
# idempotent: once the symlink is in place, there is nothing left to migrate.
zsh:
	@if [ ! -f "$(HOME)/.zshrc.local" ]; then \
		echo "Seeding ~/.zshrc.local from zsh/.zshrc.local.example..."; \
		cp "$(ROOT_DIR)/zsh/.zshrc.local.example" "$(HOME)/.zshrc.local"; \
	fi
	@if [ -e "$(HOME)/.zshrc" ] && ! grep -q "# dotfiles:seeded" "$(HOME)/.zshrc" 2>/dev/null; then \
		backup="$(HOME)/.zshrc.bak"; \
		if [ -e "$$backup" ]; then backup="$(HOME)/.zshrc.bak.$$(date +%Y%m%d%H%M%S)"; fi; \
		echo "Backing up existing .zshrc to $$backup..."; \
		cp "$(HOME)/.zshrc" "$$backup"; \
		echo "Appending existing .zshrc to ~/.zshrc.local..."; \
		{ echo ""; \
		  echo "# --- Migrated from previous ~/.zshrc by dotfiles setup on $$(date +%Y-%m-%d) ---"; \
		  cat "$$backup"; } >> "$(HOME)/.zshrc.local"; \
	fi
	@echo "Symlinking zsh configuration files..."
	@ln -snf "$(ROOT_DIR)/zsh/.zshrc" "$(HOME)/.zshrc"

.PHONY: iterm
iterm:
	@echo ""
	@echo "iTerm2 color profile must be configured manually:"
	@echo "  1. Open iTerm2 > Settings > Profiles > Colors"
	@echo "  2. Click 'Color Presets...' > Import"
	@echo "  3. Select a profile from $(ROOT_DIR)/mac-os/"
	@echo ""

.PHONY: all
all: brew tmux zsh iterm
