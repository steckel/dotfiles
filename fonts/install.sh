#!/usr/bin/env bash
# Install the pinned Nerd Font into the current user's font directory.
set -euo pipefail
version=3.5.1
checksum=45d26b54728e01a665de4a1899ec146c79ea0752f6a0b09e1335e49187d04652
archive=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --archive) [ "$#" -ge 2 ] || { echo '--archive requires a ZIP path' >&2; exit 2; }; archive=$2; shift 2 ;;
        -h|--help) echo 'Usage: bash fonts/install.sh [--archive FILE]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
case $(uname -s) in
    Darwin) font_base="$HOME/Library/Fonts" ;;
    Linux) font_base="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
    *) echo 'Supported platforms: Linux and macOS' >&2; exit 1 ;;
esac
dest="$font_base/DejaVuSansMonoNerdFont"
marker="$dest/.release-sha256"
if [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$checksum" ] || [ ! -f "$dest/DejaVuSansMNerdFontMono-Regular.ttf" ]; then
    command -v unzip >/dev/null || { echo 'Install unzip to extract the font archive' >&2; exit 1; }
    staging=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-font.XXXXXX")
    trap 'rm -rf "$staging"' EXIT
    if [ -z "$archive" ]; then
        archive="$staging/font.zip"
        curl --fail --location --retry 2 "https://github.com/ryanoasis/nerd-fonts/releases/download/v$version/DejaVuSansMono.zip" --output "$archive"
    fi
    if command -v sha256sum >/dev/null; then
        actual=$(sha256sum < "$archive"); actual=${actual%% *}
    elif command -v shasum >/dev/null; then
        actual=$(shasum -a 256 < "$archive"); actual=${actual%% *}
    else
        echo 'A SHA-256 tool (sha256sum or shasum) is required' >&2; exit 1
    fi
    [ "$actual" = "$checksum" ] || { echo 'Font archive checksum mismatch; no fonts installed' >&2; exit 1; }
    mkdir -p "$staging/fonts"
    unzip -q -j "$archive" '*.ttf' -d "$staging/fonts"
    [ -f "$staging/fonts/DejaVuSansMNerdFontMono-Regular.ttf" ] || { echo 'Expected font not found in archive' >&2; exit 1; }
    mkdir -p "$dest"
    cp "$staging/fonts/"*.ttf "$dest/"
    printf '%s\n' "$checksum" > "$marker"
fi
if command -v fc-cache >/dev/null; then fc-cache -f "$dest"; fi
printf 'DejaVuSansM Nerd Font Mono v%s installed in %s\n' "$version" "$dest"
