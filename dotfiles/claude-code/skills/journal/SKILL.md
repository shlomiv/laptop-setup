---
description: Write today's daily journal via Logseq — scans ALL Claude sessions for the day
allowed-tools: Bash, Read, mcp__mcp-logseq__update_page, mcp__mcp-logseq__get_page_content, mcp__mcp-logseq__list_pages, mcp__mcp-logseq__create_page
---

# Daily Journal

The user invoked this command with: $ARGUMENTS

## Instructions

The journal lives in Logseq. Journal pages are named by date (e.g. "Jun 9th, 2026").

### Behavior — No arguments (write/update today's journal)

1. **Determine today's date** in local timezone: `date +"%Y-%m-%d"` for filtering, and format as Logseq title (e.g. "Jun 9th, 2026"). Fix ordinal suffix (1st, 2nd, 3rd, 11th, 12th, 13th, 21st, 22nd, 23rd, 31st).

2. **Scan ALL session files** across all projects:
   ```bash
   find ~/.claude/projects -name "*.jsonl" -not -path "*/subagents/*"
   ```

3. **For each session file**, extract user messages whose UTC timestamp falls on today's local date. Convert UTC to local using the system timezone. Use this pattern:
   ```bash
   python3 -c "
   import json, os
   from datetime import datetime, timezone
   from pathlib import Path
   
   today = '$(date +%Y-%m-%d)'
   sessions_dir = Path.home() / '.claude' / 'projects'
   
   results = {}
   for jsonl in sessions_dir.rglob('*.jsonl'):
       if 'subagents' in str(jsonl):
           continue
       project = jsonl.parent.name.replace('-Users-shlomi-', '~/').replace('-', '/')
       with open(jsonl) as f:
           for lineno, line in enumerate(f, 1):
               try:
                   d = json.loads(line)
               except:
                   continue
               if d.get('type') != 'user':
                   continue
               ts = d.get('timestamp')
               if not ts:
                   continue
               dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
               local_dt = dt.astimezone()
               if local_dt.strftime('%Y-%m-%d') != today:
                   continue
               # Extract content
               msg = d.get('message', {})
               content_raw = msg.get('content', '')
               content = ''
               if isinstance(content_raw, list):
                   for c in content_raw:
                       if isinstance(c, dict) and c.get('type') == 'text':
                           t = c.get('text', '')
                           if t and not t.strip().startswith('<'):
                               content = t.strip()[:120]
                               break
               elif isinstance(content_raw, str):
                   if not content_raw.strip().startswith('<'):
                       content = content_raw.strip()[:120]
               if content:
                   time_str = local_dt.strftime('%H:%M')
                   results.setdefault(project, []).append((time_str, content, str(jsonl), lineno))
   
   for proj in sorted(results):
       print(f'=== {proj} ===')
       # Print session file paths (deduplicated)
       files = set(r[2] for r in results[proj])
       for f in sorted(files):
           print(f'  SESSION: {f}')
       for t, c, f, ln in results[proj]:
           print(f'{t} | L{ln} | {c}')
       print()
   "
   ```

4. **Summarize** the raw messages into concise outcome bullets. Rules:
   - Each bullet has the real timestamp (HH:MM) from when the user initiated that task
   - Only log outcomes — not failed attempts, not back-and-forth, not system messages
   - Use `[[wikilinks]]` for tools, projects, concepts worth linking
   - Group by project using a heading with the project tag
   - Put `#claude-session` on the `## [[project]] #tag` heading (top-level block only)
   - Link to the session file on each entry: `[session](vclaude://file/<SESSION_PATH>:<LINE>?name=First+few+words)` — name param = first 3-5 words of outcome, URL-encoded

5. **Write to Logseq** using `mcp__mcp-logseq__update_page` with mode `replace` (so re-running doesn't duplicate):

   Format:
   ```
   ## [[project-name]] #tag #claude-session
     HH:MM — outcome description with [[wikilinks]] ⚡ [session](vclaude://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<LINE>?name=Short+outcome)
       Supporting detail
     HH:MM — another outcome ⚡ [session](vclaude://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<LINE>?name=Short+outcome)

   ## [[other-project]] #tag #claude-session
     HH:MM — outcome ⚡ [session](vclaude://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<LINE>?name=Short+outcome)
   ```

### Structure conventions

- **Group by project/context** — each `## [[project]] #tag` heading groups related work.
- **Timestamp every entry** — `HH:MM` in 24h format, from the session file (NOT current time).
- **Outcome-first** — lead with what was accomplished, not what was attempted.
- **Wikilinks** — use `[[PageName]]` for tools, concepts, projects that are or could be pages.
- **Chronological order** — entries sorted ascending by timestamp within each section.
- **Supporting details** — indent under the timestamp line. Keep terse.
- **Tags**: `#tooling` `#config` `#product` `#feature` `#bugfix` `#devops` `#habits` `#claude-code` `#infra` `#meeting`
  - Don't use `#product` for customer work — the `[[Customer/<Name>]]` heading is sufficient.
- **`#claude-session`** goes on the top-level `##` heading only (NOT on individual entries). The `[session](vclaude://file/...:<LINE>)` link goes on each entry line.

### Project name mapping

| Session path | Logseq project | Default tag |
|---|---|---|
| `~/work/SDA` | `[[SDA]]` | `#tooling` or `#config` |
| `~/work/SDA/sda/solution` | `[[sda-solution]]` | (none needed) |
| `~/work/SDA/MongoDB` | `[[Customer/MongoDB]]` | (none — `Customer/` prefix is implicit) |
| `~/work/vulcan` | `[[vulcan]]` | `#product` |
| `~/work/devrev/cli` | `[[devrev-cli]]` | `#tooling` |
| `~/personal/laptop-setup` | `[[laptop-setup]]` | `#infra` |
| `/Users/shlomi` (home) | context-dependent | varies |

### Customer page convention

When the work relates to a customer/account, use `[[Customer/<Name>]]` as the section heading. This:
- Creates a dedicated page per customer in Logseq (backlinks aggregate all activity)
- Makes the `#customer` tag implicit — don't add it separately
- Don't add `#product` either — the `Customer/` prefix is the signal
- Use the customer's proper name (MongoDB, PwC, Akira, etc.)

### Existing page references

Use wikilinks to existing pages when relevant:
- `[[Customer/MongoDB]]`, `[[Customer/PwC]]` — customer work
- `[[SDA]]`, `[[sda-solution]]` — internal product work
- `[[Claude Code]]`, `[[claude-code]]` — agent/skill work
- `[[Logseq]]`, `[[mcp-logseq]]` — knowledge graph
- `[[iTerm2]]`, `[[tmux]]`, `[[Zsh]]`, `[[FZF]]` — terminal tools
- `[[Karabiner-Elements]]`, `[[Amethyst]]` — system tools
- `[[laptop-setup]]` — infra/dotfiles
- `[[Reminders]]` — macOS reminders
- `[[devrev-cli]]`, `[[gh]]` — CLI tools

### Arguments

- No arguments: scan all sessions for today, summarize, write to Logseq
- `list`: use `mcp__mcp-logseq__list_pages` with `include_journals: true` to show recent journal pages
- `read [date]`: use `mcp__mcp-logseq__get_page_content` to show a specific day's journal
- `yesterday`: scan for yesterday's date instead of today

### Fallback

If Logseq MCP is unavailable (tools not loaded), fall back to writing `~/personal/journal/YYYY-MM-DD.md` directly and committing to git.

### Important

- NEVER fabricate timestamps. Every timestamp comes from the jsonl file.
- Use system timezone (whatever `date +%Z` reports) for converting UTC → local.
- Multiple sessions in the same project on the same day merge into one project section.
- The scan output is raw material — you must summarize it into outcomes, not dump it verbatim.
- Don't journal system prompts, skill invocations (lines starting with `##`), or `[Request interrupted]` messages.
- Each `##` heading MUST have `#claude-session` tag. Each entry line MUST have `[session](vclaude://file/...:<LINE>)` link to the source `.jsonl` file.
