.DEFAULT_GOAL := all
ROOT_DIR := $(CURDIR)
VARIANTS_DIR := $(ROOT_DIR)/variants
BREW := $(shell command -v brew 2>/dev/null || echo /opt/homebrew/bin/brew)

# ==============================================================================
# Modular Variant Discovery Engine
# ==============================================================================
# Variants are modular configurations located in $(VARIANTS_DIR)/<variant_name>
# (often maintained in environment-specific branches such as 'work' or 'corp').
#
# Each variant directory may provide:
#   1. detect.sh (or detect): An executable script that exits 0 if the host
#      environment matches the variant, and prints a human-readable description.
#   2. variant.mk: A Makefile fragment included by this root Makefile. It can
#      define:
#      - VARIANT_CUSTOM_TMUX := 1  (skips Homebrew tmux and invokes variant-tmux)
#      - variant-tmux: Target to configure and link tmux for the variant
#      - variant-setup:: Double-colon rule hooked into `make all`
#      - variant-down:: Double-colon rule hooked into teardown
#
# Override variant manually if desired:
#   make VARIANT=work
#   make VARIANT=none
# ==============================================================================
VARIANT ?= $(shell \
	if [ -d "$(VARIANTS_DIR)" ]; then \
		for dir in "$(VARIANTS_DIR)"/*; do \
			if [ -d "$$dir" ]; then \
				detector=""; \
				if [ -x "$$dir/detect.sh" ]; then \
					detector="$$dir/detect.sh"; \
				elif [ -x "$$dir/detect" ]; then \
					detector="$$dir/detect"; \
				fi; \
				if [ -n "$$detector" ] && "$$detector" >/dev/null 2>&1; then \
					basename "$$dir"; \
					exit 0; \
				fi; \
			fi; \
		done; \
	fi; \
	echo none; \
)

ifneq ($(VARIANT),none)
  VARIANT_DIR := $(VARIANTS_DIR)/$(VARIANT)
  VARIANT_DETECTOR := $(firstword $(wildcard $(VARIANT_DIR)/detect.sh $(VARIANT_DIR)/detect))
  ifneq ($(VARIANT_DETECTOR),)
    VARIANT_DESC ?= $(shell $(VARIANT_DETECTOR) 2>/dev/null)
  endif
  VARIANT_DESC ?= $(VARIANT)
  -include $(VARIANT_DIR)/variant.mk
endif

.PHONY: env-info
env-info:
ifneq ($(VARIANT),none)
	@echo "==> Detected variant: $(VARIANT_DESC)"
	@echo "==> Applying '$(VARIANT)' profile..."
	@echo ""
else
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		echo "==> Detected environment: Personal Mac"; \
	else \
		echo "==> Detected environment: Personal Linux"; \
	fi
	@echo "==> Applying standard profile (Homebrew & upstream tmux)..."
	@echo ""
endif

# Double-colon targets for modular variant hooks
.PHONY: variant-setup
variant-setup::
	@:

.PHONY: variant-down
variant-down::
	@:

.PHONY: brew
brew:
	@if ! command -v brew &>/dev/null && [ ! -f /opt/homebrew/bin/brew ]; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Homebrew already installed."; \
	fi

ifeq ($(VARIANT_CUSTOM_TMUX),1)

.PHONY: tmux
tmux: env-info variant-tmux

else

.PHONY: tmux
tmux: env-info brew
	@echo "Installing tmux via Homebrew..."
	@$(BREW) list tmux &>/dev/null || $(BREW) install tmux
	@echo "Symlinking tmux configuration files..."
	@ln -snf "$(ROOT_DIR)/tmux/tmux.conf" "$(HOME)/.tmux.conf"

endif

.PHONY: tmux-down
tmux-down: variant-down
	@echo "Unlinking tmux configuration files..."
	@rm -f "$(HOME)/.tmux.conf"

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

# macOS system defaults. Deliberately NOT part of `all`: it prompts for sudo,
# wipes the Dock, and restarts Finder, Dock, and SystemUIServer. Run it by
# hand on a new machine.
# Target is named `macos` rather than `mac-os` so it cannot collide with the
# `mac-os` script sitting in the repo root -- make would treat a same-named
# target as already up to date.
.PHONY: macos
macos:
	@echo "Applying macOS system defaults..."
	@"$(ROOT_DIR)/mac-os"

# iTerm2 color profiles are not tracked in this repo yet. The instructions
# below pointed at $(ROOT_DIR)/mac-os/ as if it were a directory of presets,
# but mac-os is the system-defaults script and no profiles are committed
# anywhere. Re-enable once there is something real to import.
#
# .PHONY: iterm
# iterm:
# 	@echo ""
# 	@echo "iTerm2 color profile must be configured manually:"
# 	@echo "  1. Open iTerm2 > Settings > Profiles > Colors"
# 	@echo "  2. Click 'Color Presets...' > Import"
# 	@echo "  3. Select a profile from <path to committed presets>"
# 	@echo ""

# Installs git hooks from an optional, untracked `hooks/` directory into
# `.git/hooks/`.
#
# `hooks/` is listed in .gitignore on purpose. Hook contents tend to encode
# environment-specific values (scanner paths, blocked domains, trusted remote
# patterns), and anything committed to this repository is published. Keeping
# the mechanism generic here and the contents local means a public branch
# cannot carry them.
#
# Note: `.git/hooks/` receives copies, not symlinks. A symlink into the
# worktree dangles whenever a branch without `hooks/` is checked out, which
# would silently disable the hooks on exactly the branches that are published.
# Re-run `make hooks` after editing a hook source.
.PHONY: hooks
hooks:
	@# A stale core.hooksPath makes git ignore .git/hooks/ entirely, silently
	@# disabling every hook installed below.
	@git config --unset core.hooksPath 2>/dev/null || true
	@if [ -d "$(ROOT_DIR)/hooks" ]; then \
		echo "Installing local git hooks into .git/hooks (untracked)..."; \
		for hook in pre-commit pre-push; do \
			if [ -f "$(ROOT_DIR)/hooks/$$hook" ]; then \
				install -m 0755 "$(ROOT_DIR)/hooks/$$hook" "$(ROOT_DIR)/.git/hooks/$$hook"; \
				echo "  installed $$hook"; \
			fi; \
		done; \
	else \
		echo "No local hooks/ directory found; skipping git hook installation."; \
	fi

.PHONY: all
all: env-info hooks tmux zsh variant-setup
