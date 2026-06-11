# claude-at

Jump into a Claude Code session at a specific point in time.

## What it does

`claude-at` loads a Claude session transcript truncated to a specific line, so you can
review or continue from any past moment in a conversation.

## Components

| File | Purpose |
|------|---------|
| `~/bin/claude-at` | Main script — truncates session, overwrites bootstrap, runs `claude --continue` |
| `~/bin/claude-at-open` | Helper — opens iTerm2 window and runs `claude-at` (called by URL handler) |
| `~/Applications/ClaudeAt.app` | macOS URL scheme handler — registers `vclaude://` protocol |
| `src/main.swift` | Source for the app binary (rebuild with `swiftc src/main.swift -o ... -framework Cocoa`) |

## Usage

### From terminal
```bash
claude-at ~/.claude/projects/-Users-shlomi-work-SDA/3ceedb06-....jsonl:97
```

### From Logseq (clickable link)
```markdown
[session](vclaude://file/Users/shlomi/.claude/projects/-Users-shlomi-work-SDA/3ceedb06-....jsonl:97)
```

Clicking opens iTerm2 → runs `claude-at` → loads session truncated to line 97.

## URL format

```
vclaude://file/Users/shlomi/.claude/projects/<project-key>/<session-id>.jsonl:<LINE>
```

Same structure as `vscode://file/...` — just swap the scheme.

## How it works

1. First run auto-bootstraps: launches claude interactively to create an indexed session
2. Subsequent runs: overwrites that session's .jsonl with truncated content from the target
3. Runs `claude --continue` which picks up the overwritten content
4. On exit, restores the bootstrap session for next use

## Rebuild the app

```bash
swiftc src/main.swift -o ~/Applications/ClaudeAt.app/Contents/MacOS/ClaudeAt -framework Cocoa
lsregister -f ~/Applications/ClaudeAt.app
```
