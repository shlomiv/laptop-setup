#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up devrev-pat..."

link_file "$REPO_DIR/dotfiles/bin/devrev-pat" "$HOME/bin/devrev-pat"
chmod +x "$HOME/bin/devrev-pat"

ok "devrev-pat installed (use 'devrev-pat add <name>' to store tokens)"
