#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Claude Code..."

mkdir -p ~/.claude/skills/reminders

link_file "$REPO_DIR/dotfiles/claude-code/settings.json" "$HOME/.claude/settings.json"
link_file "$REPO_DIR/dotfiles/claude-code/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link_file "$REPO_DIR/dotfiles/claude-code/skills/reminders/SKILL.md" "$HOME/.claude/skills/reminders/SKILL.md"

chmod +x "$HOME/.claude/statusline-command.sh"

ok "Claude Code: settings, statusline, /reminders skill linked"
