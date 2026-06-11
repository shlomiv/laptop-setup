#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up DevRev Computer skills..."

COMPUTER_SKILLS_DIR="$HOME/.devrev/computer/don_identity_dvrv-us-1_devo_0_devu-45/agent/skills"

mkdir -p "$COMPUTER_SKILLS_DIR/logseq-journal" "$COMPUTER_SKILLS_DIR/check-logseq-todo"

link_file "$REPO_DIR/dotfiles/devrev-computer/skills/logseq-journal/SKILL.md" "$COMPUTER_SKILLS_DIR/logseq-journal/SKILL.md"
link_file "$REPO_DIR/dotfiles/devrev-computer/skills/check-logseq-todo/SKILL.md" "$COMPUTER_SKILLS_DIR/check-logseq-todo/SKILL.md"

ok "DevRev Computer: logseq-journal + check-logseq-todo skills linked"
