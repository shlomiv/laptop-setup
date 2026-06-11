#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up claude-at..."

# Install scripts
link_file "$REPO_DIR/dotfiles/bin/claude-at" "$HOME/bin/claude-at"
link_file "$REPO_DIR/dotfiles/bin/claude-at-open" "$HOME/bin/claude-at-open"
chmod +x "$HOME/bin/claude-at" "$HOME/bin/claude-at-open"

# Install URL scheme handler app
APP_DIR="$HOME/Applications/ClaudeAt.app"
mkdir -p "$APP_DIR/Contents/MacOS"
link_file "$REPO_DIR/dotfiles/claude-at.app/Contents/Info.plist" "$APP_DIR/Contents/Info.plist"
link_file "$REPO_DIR/dotfiles/claude-at.app/Contents/MacOS/ClaudeAt" "$APP_DIR/Contents/MacOS/ClaudeAt"
chmod +x "$APP_DIR/Contents/MacOS/ClaudeAt"

# Register URL scheme with macOS
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" 2>/dev/null

ok "claude-at: scripts + vclaude:// URL scheme registered"
