#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Applying macOS defaults..."

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false

# Finder
defaults write com.apple.finder AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Input sources: Unicode Hex Input (primary) + Hebrew
defaults write com.apple.HIToolbox AppleEnabledInputSources -array \
    '<dict><key>Bundle ID</key><string>com.apple.CharacterPaletteIM</string><key>InputSourceKind</key><string>Non Keyboard Input Method</string></dict>' \
    '<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>-18432</integer><key>KeyboardLayout Name</key><string>Hebrew</string></dict>' \
    '<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>-1</integer><key>KeyboardLayout Name</key><string>Unicode Hex Input</string></dict>'
defaults write com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID -string "com.apple.keylayout.UnicodeHexInput"
defaults write com.apple.HIToolbox AppleSelectedInputSources -array \
    '<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>-1</integer><key>KeyboardLayout Name</key><string>Unicode Hex Input</string></dict>'

# Restart affected apps
killall Dock Finder 2>/dev/null || true

ok "macOS defaults applied"
