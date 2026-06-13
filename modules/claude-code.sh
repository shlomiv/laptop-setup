#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Claude Code..."

mkdir -p ~/.claude/skills/reminders ~/.claude/skills/journal ~/.claude/skills/gh-review-comments

link_file "$REPO_DIR/dotfiles/claude-code/settings.json" "$HOME/.claude/settings.json"
link_file "$REPO_DIR/dotfiles/claude-code/settings.local.json" "$HOME/.claude/settings.local.json"
link_file "$REPO_DIR/dotfiles/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_file "$REPO_DIR/dotfiles/claude-code/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link_file "$REPO_DIR/dotfiles/claude-code/skills/reminders/SKILL.md" "$HOME/.claude/skills/reminders/SKILL.md"
link_file "$REPO_DIR/dotfiles/claude-code/skills/journal/SKILL.md" "$HOME/.claude/skills/journal/SKILL.md"
link_file "$REPO_DIR/dotfiles/claude-code/skills/gh-review-comments/SKILL.md" "$HOME/.claude/skills/gh-review-comments/SKILL.md"

chmod +x "$HOME/.claude/statusline-command.sh"

ok "Claude Code: settings, settings.local, CLAUDE.md, statusline, /reminders, /journal, /gh-review-comments linked"
