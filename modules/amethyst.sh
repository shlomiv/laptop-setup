#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Amethyst..."

# swap-main = Cmd+Shift+Enter (carbonKeyCode 36 = Return, carbonModifiers 768 = Cmd+Shift)
defaults write com.amethyst.Amethyst "KeyboardShortcuts_swap-main" -string '{"carbonKeyCode":36,"carbonModifiers":768}'

# focus-main = Shift+Option+Enter (carbonModifiers 2560 = Shift+Option)
defaults write com.amethyst.Amethyst "KeyboardShortcuts_focus-main" -string '{"carbonKeyCode":36,"carbonModifiers":2560}'

ok "Amethyst: swap-main=Cmd+Shift+Enter, focus-main=Shift+Option+Enter"
