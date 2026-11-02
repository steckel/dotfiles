#!/usr/bin/env bash
# Delegate font downloads, extraction and font-cache refresh to Nerd Fonts.
set -euo pipefail
installer_revision=adbd16ab7ca911eaca7ce3b0f2b7994207c7ecae
release=v3.5.1
case $(uname -s) in
    Darwin|Linux) ;;
    *) echo 'Supported platforms: Linux and macOS' >&2; exit 1 ;;
esac
command -v curl >/dev/null || { echo 'Install curl before running make fonts' >&2; exit 1; }
staging=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-font.XXXXXX")
trap 'rm -rf "$staging"' EXIT
curl --fail --location --retry 2 \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/$installer_revision/install.sh" \
    --output "$staging/install.sh"
bash "$staging/install.sh" install --release "$release" GoogleSansCode
