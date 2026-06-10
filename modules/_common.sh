#!/bin/bash
# Shared helpers for all modules

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { printf '\033[34m[INFO]\033[0m %s\n' "$1"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }
err() { printf '\033[31m[ERR]\033[0m %s\n' "$1" >&2; }

# Create symlink idempotently. Args: source (in repo), target (system path)
link_file() {
    local src="$1" dst="$2"

    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            ok "Already linked: $dst"
            return 0
        else
            warn "Repointing symlink: $dst (was $current)"
            ln -sfn "$src" "$dst"
        fi
    elif [[ -e "$dst" ]]; then
        warn "Backing up existing: $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
        ln -sfn "$src" "$dst"
    else
        mkdir -p "$(dirname "$dst")"
        ln -sfn "$src" "$dst"
    fi
    ok "Linked: $dst → $src"
}

# Remove symlink if it points into our repo
unlink_file() {
    local dst="$1"
    if [[ -L "$dst" ]]; then
        local target
        target="$(readlink "$dst")"
        if [[ "$target" == "$REPO_DIR"* ]]; then
            rm "$dst"
            if [[ -e "${dst}.bak" ]]; then
                mv "${dst}.bak" "$dst"
                info "Restored backup: $dst"
            else
                info "Removed: $dst"
            fi
        fi
    fi
}
