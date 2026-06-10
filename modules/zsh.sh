#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up Zsh..."

link_file "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"

# Install oh-my-zsh if missing
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install zsh-autosuggestions if missing
plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$plugin_dir" ]]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
fi

ok "Zsh configured (plugins: git, fzf, z, zsh-autosuggestions)"
