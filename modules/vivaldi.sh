#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Vivaldi..."

# Vivaldi keybindings are managed via Karabiner (Ctrl+1/2 for profile switching).
# The Karabiner rule handles: Ctrl+1 → Cmd+Shift+P, Tab, Enter (profile 1)
#                             Ctrl+2 → Cmd+Shift+P, Tab×4, Enter (profile 2)
# See dotfiles/karabiner/karabiner.json for the full rule.

# Vivaldi preferences live at:
VIVALDI_PREFS="$HOME/Library/Application Support/Vivaldi/Default/Preferences"

if [[ -f "$VIVALDI_PREFS" ]]; then
    ok "Vivaldi installed. Profile switching via Karabiner Ctrl+1/2."
else
    warn "Vivaldi not found. Install it, then profile switching works via Karabiner."
fi

info "Vivaldi profiles must be set up manually:"
info "  1. Open Vivaldi → File → Open Profile Manager"
info "  2. Create profiles as needed"
info "  3. Ctrl+1/2 switching handled by Karabiner rule"
