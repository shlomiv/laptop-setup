#!/bin/bash
source "$(dirname "$0")/modules/_common.sh"

echo "Removing symlinks..."

unlink_file "$HOME/.config/karabiner/karabiner.json"
unlink_file "$HOME/.zshrc"
unlink_file "$HOME/.claude/settings.json"
unlink_file "$HOME/.claude/statusline-command.sh"
unlink_file "$HOME/.claude/skills/reminders/SKILL.md"

echo "Done. Backups restored where available."
