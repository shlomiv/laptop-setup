#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Logseq..."

# Check if Logseq is installed
if [[ ! -d "/Applications/Logseq.app" ]]; then
    info "Installing Logseq..."
    brew install --cask logseq
fi

# MCP wrapper script
link_file "$REPO_DIR/dotfiles/logseq/mcp-logseq-wrapper" "$HOME/bin/mcp-logseq-wrapper"
chmod +x "$HOME/bin/mcp-logseq-wrapper"

# Ensure token exists in Keychain
if ! security find-generic-password -s "devrev-pat" -a "logseq-kg" -w >/dev/null 2>&1; then
    warn "No Logseq API token in Keychain."
    info "1. Open Logseq → Settings → Features → Enable HTTP APIs server → Start → Generate token"
    info "2. Run: devrev-pat add logseq-kg"
else
    ok "Logseq API token found in Keychain"
fi

# Add MCP server to Claude Code (user scope)
if grep -q "mcp-logseq" "$HOME/.claude.json" 2>/dev/null; then
    ok "mcp-logseq already configured in Claude Code"
else
    claude mcp add mcp-logseq --scope user -- "$HOME/bin/mcp-logseq-wrapper" 2>/dev/null
    ok "Added mcp-logseq to Claude Code (user scope)"
fi

# Link server: bridges http://localhost:12316 → logseq:// for DevRev Computer clickable links
link_file "$REPO_DIR/dotfiles/logseq/logseq-link-server" "$HOME/bin/logseq-link-server"
chmod +x "$HOME/bin/logseq-link-server"

# LaunchAgent for link server (survives reboots)
mkdir -p "$HOME/Library/LaunchAgents"
link_file "$REPO_DIR/dotfiles/logseq/com.shlomi.logseq-link-server.plist" "$HOME/Library/LaunchAgents/com.shlomi.logseq-link-server.plist"
if ! launchctl list | grep -q "com.shlomi.logseq-link-server"; then
    launchctl load "$HOME/Library/LaunchAgents/com.shlomi.logseq-link-server.plist" 2>/dev/null
    ok "logseq-link-server LaunchAgent loaded"
else
    ok "logseq-link-server already running"
fi

ok "Logseq: app, MCP wrapper, link server, LaunchAgent configured"
