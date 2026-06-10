#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Karabiner-Elements..."

mkdir -p ~/.config/karabiner
link_file "$REPO_DIR/dotfiles/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
