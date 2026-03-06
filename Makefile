.DEFAULT_GOAL := all
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
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
	@ln -snf $(ROOT_DIR)/tmux/tmux.conf $(HOME)/.tmux.conf

.PHONY: tmux-down
tmux-down:
	@echo "Unlinking tmux configuration files..."
	@rm $(HOME)/.tmux.conf

.PHONY: zsh
zsh:
	@if ! grep -q "# dotfiles:seeded" $(HOME)/.zshrc 2>/dev/null; then \
		echo "Backing up existing .zshrc to ~/.zshrc.bak..."; \
		cp $(HOME)/.zshrc $(HOME)/.zshrc.bak; \
		echo "Seeding ~/.zshrc.local from existing .zshrc..."; \
		{ echo "# Migrated from previous .zshrc by dotfiles setup"; \
		  echo ""; \
		  cat $(HOME)/.zshrc; } > $(HOME)/.zshrc.local; \
	fi
	@echo "Symlinking zsh configuration files..."
	@ln -snf $(ROOT_DIR)/zsh/.zshrc $(HOME)/

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
