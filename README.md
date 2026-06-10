# laptop-setup

Idempotent macOS workstation configuration with symlink-managed dotfiles.

## Usage

```bash
# Full setup
./setup.sh

# Single module
./modules/karabiner.sh

# Reverse all symlinks
./unlink.sh
```

## Design

- **Symlinks** — config files live in this repo, symlinked to system paths. Edits anywhere are immediately git-tracked.
- **Idempotent** — safe to re-run. Checks state before acting, skips if already configured, backs up existing files to `.bak`.
- **Modular** — each tool is independent. Run one module or all.

## Modules

| Module | What it does |
|--------|-------------|
| `zsh` | Symlinks `.zshrc`, installs oh-my-zsh + plugins (fzf, z, zsh-autosuggestions) |
| `karabiner` | Symlinks karabiner.json (word nav, caps→ctrl, vivaldi profiles, tab↔option, brightness→illumination) |
| `amethyst` | Window manager keybindings via `defaults write` |
| `iterm2` | Hex key mappings (word nav, line nav) + global Shift+Enter→newline |
| `vivaldi` | Documents profile setup (switching handled by Karabiner) |
| `macos-defaults` | Dock, Finder, keyboard repeat, trackpad, input sources |
| `claude-code` | Symlinks settings.json, statusline, `/reminders` and `/journal` skills |
| `logseq` | MCP wrapper, link-redirect server, LaunchAgent |
| `devrev-pat` | Keychain-based token manager for CLI tools |

## Structure

```
├── setup.sh              # Orchestrates all modules
├── unlink.sh             # Removes all symlinks, restores backups
├── modules/
│   ├── _common.sh        # Shared: link_file, unlink_file, info/ok/warn/err
│   └── *.sh              # One per tool
└── dotfiles/
    ├── bin/devrev-pat
    ├── claude-code/      # settings, statusline, skills
    ├── karabiner/        # karabiner.json
    ├── logseq/           # mcp wrapper, link server, LaunchAgent plist
    └── zsh/zshrc
```

## Requirements

- macOS (tested on Apple Silicon, Sequoia)
- Homebrew (for app installs)
- The tools themselves (Karabiner, Amethyst, iTerm2, Logseq, etc.)

## Notes

- No secrets in this repo — tokens live in macOS Keychain, referenced by label only
- `devrev-pat` is a generic keychain token manager (add/get/rotate/remove)
- Logseq link server bridges `http://localhost:12316` → `logseq://` for clickable links in web UIs
