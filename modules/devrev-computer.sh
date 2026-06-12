#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up DevRev Computer skills..."

COMPUTER_SKILLS_DIR="$HOME/.devrev/computer/don_identity_dvrv-us-1_devo_0_devu-45/agent/skills"

mkdir -p "$COMPUTER_SKILLS_DIR/logseq-journal-v3" \
         "$COMPUTER_SKILLS_DIR/logseq-graph-index-v3" \
         "$COMPUTER_SKILLS_DIR/check-logseq-todo"

link_file "$REPO_DIR/dotfiles/devrev-computer/skills/logseq-journal-v3/SKILL.md" "$COMPUTER_SKILLS_DIR/logseq-journal-v3/SKILL.md"
link_file "$REPO_DIR/dotfiles/devrev-computer/skills/logseq-graph-index-v3/SKILL.md" "$COMPUTER_SKILLS_DIR/logseq-graph-index-v3/SKILL.md"
link_file "$REPO_DIR/dotfiles/devrev-computer/skills/check-logseq-todo/SKILL.md" "$COMPUTER_SKILLS_DIR/check-logseq-todo/SKILL.md"

ok "DevRev Computer: logseq-journal-v3, logseq-graph-index-v3, check-logseq-todo linked"
