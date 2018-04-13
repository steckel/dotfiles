.DEFAULT_GOAL := all
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: tmux
tmux:
	@echo "symlinking tmux configuration files...."
	ln -snf $(ROOT_DIR)/tmux/tmux.conf $(HOME)/.tmux.conf

tmux-down:
	@echo "unlinking tmux configuration files...."
	@rm $(HOME)/.tmux.conf

.PHONY: zsh
zsh:
	@echo "symlinking zsh configuration files...."
	@ln -snf $(ROOT_DIR)/zsh/.zshrc $(HOME)/

.PHONY: all
all: tmux zsh
