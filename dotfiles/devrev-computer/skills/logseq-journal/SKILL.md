---
name: logseq-journal
description: >
  Journal the user's day into Logseq. Appends timestamped, structured entries to the daily journal page
  following Shlomi's established conventions. All entries are attributed to Computer.
trigger: >
  Activate when the user asks to journal, log, record, or note something to Logseq.
  Trigger phrases include: journal this, log this, note this, add to journal, write to logseq,
  record this in logseq, update my journal, log my day, what did I do today (when asking to record),
  add to today's log, journal entry, logseq entry, capture this.
  Also activate when the user says "journal" as a standalone command or asks you to summarize
  what was accomplished and write it to the journal.
  Do NOT activate for: reading/searching logseq (use direct API calls), general note-taking
  unrelated to the daily journal.
---

# Logseq Journal Skill

You journal Shlomi's day into his Logseq knowledge graph. Every entry you write is **attributed to Computer** so it's clear what was human-authored vs agent-authored.

## Connection

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w)
LOGSEQ_API_URL="http://localhost:12315"
```

All calls use:
```bash
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "...", "args": [...]}'
```

## Journal Structure & Conventions

Journal pages are named by date: `"Jun 9th, 2026"` (use the ordinal suffix: 1st, 2nd, 3rd, 4th-20th, 21st, 22nd, 23rd, 24th-30th, 31st).

### Page layout

```markdown
## [[project-or-context]] #category-tag #Computer
  HH:MM — Brief outcome from DM conversation ⚡ [DM](https://app.devrev.ai/devrev/computer/dm?chatId=don%3Acore%3Advrv-us-1%3Adevo%2F0%3Adm%2F<DM_SUFFIX>)
    Supporting detail line 1
## [[project-or-context]] #category-tag #claude-session
  HH:MM — Brief outcome from Claude Code [📄](vscode://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<USER_LINE>) [🦀](vclaude://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<ASSISTANT_LINE>?name=Brief+outcome)
    Supporting detail line 2
```

**Link format (markdown):** `[label](url)` — NOT org-mode `[[url][label]]`.

### Rules

1. **Group by project/context** — each `## [[project]] #tag #Computer` heading groups related work. Always add `#Computer` to every top-level heading you create so it's queryable as Computer-authored. Don't over-fragment: if multiple tools were configured in a single "laptop setup" session, group them under `## [[laptop-setup]]` rather than creating a section per tool.
   - **ONE section per project/page.** Never create two top-level headings for the same `[[page]]`. Before creating a new `##` heading, check if one already exists for that page on today's journal. If it does, append entries to it — even if the existing section has a different tag (e.g., `#config` vs `#tooling`). Merge into the existing section.
   - **Convergence rule:** If work spans both "product" and "team" for the same page (e.g., [[DevRev]] blog work + All Hands), use a single `## [[DevRev]] #Computer` section — don't split by sub-category. The entries themselves provide the context. Use additional tags on entries (not headings) if you need finer categorization.
   - **Project over tool.** Attribute entries to the *project* they serve, not the tool used. Building a Logseq skill? That's `[[Logseq]]`, not `[[claude-code]]`. Restyling a MongoDB diagram in Claude Code? That's `[[sda-solution]]` or `[[Customer/MongoDB]]`. Only use `[[claude-code]]` when the work is genuinely about agent/skill infrastructure with no specific project context.
2. **Timestamp every entry** — `HH:MM` in 24h format (America/Chicago timezone).
   - **Sort by time within each section.** Entries MUST be in chronological ascending order. When appending new entries to an existing section, insert them in the correct position — not just at the end. After all entries are written, verify the order. If out of order, use `moveBlock` to reorder.
   - **Sort sections by earliest timestamp.** Top-level `##` sections should appear in the order of their earliest entry. If a section's first entry is at 00:17, it goes before a section whose first entry is at 09:25. This makes the page read as a timeline of the day from top to bottom.
3. **Outcome-first** — lead with what was accomplished, not what was attempted.
4. **Wikilinks** — use `[[PageName]]` for tools, concepts, projects that are or could be pages.
5. **Tags** — use `#tag` for queryable categories. Common tags from Shlomi's graph:
   - `#tooling` — dev tools, CLI, MCP servers
   - `#config` — system/app configuration
   - `#product` — product/feature work
   - `#feature` — new feature built
   - `#bugfix` — bug fixed
   - `#devops` — deployment, packaging, CI
   - `#habits` — routines, reminders
   - `#claude-code` — skills, agent work
6. **Supporting details** — indent under the timestamp line. Keep terse. Code snippets, key decisions, gotchas.
6b. **Issue linking on entries** — After writing all entries, search DevRev (under DevRev Labs / PROD-56) for issues that match each work cluster. If a matching issue is found, append `[DISPLAY-ID](https://app.devrev.ai/devrev/works/DISPLAY-ID)` for ISS/TKT prefixes, or `[DISPLAY-ID](https://app.devrev.ai/devrev/issue/DISPLAY-ID)` for custom prefixes like FDE to the entry line (before the ⚡). If no issue matches, add `#no-issue` to the entry line instead. At the end, list all `#no-issue` entries and offer to create issues for them.
7. **DM link** — append `[DM](https://app.devrev.ai/devrev/computer/dm?chatId=don%3Acore%3Advrv-us-1%3Adevo%2F0%3Adm%2F<SUFFIX>)` at the end of each timestamp line, linking back to the source conversation. The suffix is the short ID from the DM's DON (e.g., `don:core:dvrv-us-1:devo/0:dm/15thudfCI` → suffix is `15thudfCI`). The DON components are URL-encoded: `:` → `%3A`, `/` → `%2F`.
8. **Chronological order** — entries within a section MUST be sorted by timestamp ascending. When appending, insert in the correct position or reorder after writing.
9. **Computer attribution** — markers depend on source:
   - `#Computer` on every `##` section heading you create (top-level tag, queryable in Logseq).
   - `⚡` at the end of entry lines from **DMs, Slack, meetings, or DevRev objects** (non-Claude-Code sources).
   - `[📄] [🦀]` at the end of entry lines from **Claude Code sessions** — these icons replace ⚡ (no need for both).
   Example:
   ```
   ## [[DevRev]] #product #Computer
     14:30 — Summarized pipeline status for weekly review ⚡
       3 deals flagged at risk, drafted update for Amar
     18:11 — Restyled Mana diagram #no-issue [📄](vscode://...) [🦀](vclaude://...?name=Restyled+Mana+diagram)
   ```

### Existing page references

Use wikilinks to existing pages when relevant:
- `[[Customer/MongoDB]]`, `[[Customer/PwC]]` — customer work (use `Customer/<name>` namespace for all customers/accounts)
- `[[SDA]]`, `[[sda-solution]]` — internal product work
- `[[Claude Code]]`, `[[claude-code]]` — agent/skill work
- `[[Logseq]]`, `[[mcp-logseq]]` — knowledge graph
- `[[iTerm2]]`, `[[tmux]]`, `[[Zsh]]`, `[[FZF]]` — terminal tools
- `[[Karabiner-Elements]]`, `[[Amethyst]]` — system tools
- `[[laptop-setup]]` — infra/dotfiles
- `[[Reminders]]` — macOS reminders
- `[[devrev-cli]]`, `[[gh]]` — CLI tools

### Customer page convention

When the work relates to a customer/account, use `[[Customer/<Name>]]` as the section heading. This:
- Creates a dedicated page per customer in Logseq (backlinks aggregate all activity)
- Makes the `#customer` tag implicit — don't add it separately
- Don't add `#product` either — the `Customer/` prefix is the signal
- Use the customer's proper name (MongoDB, PwC, Akira, etc.)

## Operations

### Read today's journal (before writing, to avoid duplicates)

```bash
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.getPageBlocksTree", "args": ["<page_name>"]}'
```

### Append to today's journal

```bash
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.appendBlockInPage", "args": ["<page_name>", "<content>"]}'
```

For nested content, use `insertBlock` with the parent block's UUID:
```bash
# Get parent UUID from appendBlockInPage response or getPageBlocksTree
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.insertBlock", "args": ["<parent-uuid>", "<content>", {"sibling": false}]}'
```

### Create a new section heading

If the project section doesn't exist yet on today's page, append a new `## [[project]] #tag` block, then nest entries under it.

## Workflow

1. **Determine the target date** — default is today, but the user can request any past date ("journal yesterday", "journal June 5th"). Format as journal page name (e.g., "Jun 9th, 2026").
2. **Read the current journal page** to understand what's already there (avoid duplicates).
3. **Gather data from all sources:**
   a. **Claude Code sessions** — scan `~/.claude/projects/` for all `.jsonl` files (excluding `subagents/`). Extract user messages with timestamps falling on the target date (convert UTC → America/Chicago). See "Claude Code Session Scanner" section below.
   b. **DM conversations** — use RecallChats with `start_date`/`end_date` for the target date. For each DM found, call FetchObjectContext to get exact message timestamps from `discussions_on_the_object`.
   c. **Issues/tickets/conversations touched** — query `devrev.issue`, `devrev.ticket`, and `devrev.conversation` where `modified_by_id = 'don:identity:dvrv-us-1:devo/0:devu/45'` AND `modified_date` is within the target date. For each found, call FetchObjectContext to get the full comment thread and summarize what was discussed.
   d. **Granola meetings** — use `ListMeetings` with the target date (time_range "custom", custom_start/custom_end as ISO dates). For each meeting found, call `GetMeetings` with the meeting ID to get the full summary, participants, and action items. See "Granola Meetings" section below.
   e. **Slack messages** — search for messages Shlomi sent or received on the target date. See "Slack Messages" section below.
   f. **Current session context** — if the user says "journal this", use the current conversation.
4. **Determine what to log:**
   - If the user says "journal this" or describes what happened → log exactly that.
   - If the user says "journal my day" or "journal [date]" → log everything found in step 3.
   - If the user provides specific items → log those items.
5. **Find or create the right section** — match the project/context to an existing `##` heading, or create a new one.
6. **Verify dates before writing.** For each item, confirm it belongs on the target date. Meetings from Granola have a `date` field — use that, not the list query range. If an item belongs on a different date, write it to THAT date's journal page instead. **Never discard information.** If you discover a misplaced item (wrong date), move it to the correct page — don't just delete it.
7. **Append entries** — with proper timestamps, wikilinks, tags, `⚡` marker, and `[DM](url)` link. **Sort chronologically** within each section.
8. **Confirm** what was written (show the entry text).

## Claude Code Session Scanner

Scan all Claude Code sessions to find what Shlomi did in the terminal/IDE on the target date. This captures work not done through DevRev Computer DMs.

### How to scan

```bash
python3 -c "
import json, os
from datetime import datetime
from pathlib import Path

today = '<TARGET_DATE>'  # e.g. '2026-06-09'
sessions_dir = Path.home() / '.claude' / 'projects'

results = {}
for jsonl in sessions_dir.rglob('*.jsonl'):
    if 'subagents' in str(jsonl):
        continue
    project = jsonl.parent.name.replace('-Users-shlomi-', '~/').replace('-', '/')
    with open(jsonl) as f:
        all_lines = f.readlines()
    for lineno, line in enumerate(all_lines, 1):
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
            # Find the assistant response line (search forward up to 10 lines)
            assistant_ln = lineno  # fallback to same line
            for offset in range(1, 10):
                idx = lineno - 1 + offset
                if idx >= len(all_lines):
                    break
                try:
                    ad = json.loads(all_lines[idx])
                    if ad.get('type') == 'assistant':
                        assistant_ln = lineno + offset
                        break
                except:
                    continue
            results.setdefault(project, []).append((time_str, content, str(jsonl), lineno, assistant_ln))

for proj in sorted(results):
    print(f'=== {proj} ===')
    # Print session file paths (deduplicated)
    files = set(r[2] for r in results[proj])
    for f in sorted(files):
        print(f'  SESSION: {f}')
    for t, c, f, ln, aln in results[proj]:
        print(f'{t} | L{ln} | A{aln} | {c}')
    print()
"
```

### How to summarize the raw output

The scan produces raw user prompts — these are NOT the journal entries. You must:
1. **Group by project** — each project path maps to a `## [[project]] #tag` section.
2. **Identify outcomes** — look for patterns like "built X", "fixed Y", "set up Z", "deployed W". Ignore failed attempts, interruptions, repeated messages, and system prompts.
3. **Use the FIRST timestamp** of each logical task as the entry time (when the user initiated it).
4. **Merge related messages** into single outcome bullets — e.g., 5 messages about "fixing karabiner brightness" = one entry.

### Project name mapping

| Session path | Logseq project | Tag |
|---|---|---|
| `~/work/SDA` | `[[SDA]]` | `#tooling` or `#config` |
| `~/work/SDA/sda/solution` | `[[sda-solution]]` | `#product` |
| `~/work/SDA/MongoDB` | `[[MongoDB]]` | `#product` |
| `~/work/vulcan` | `[[vulcan]]` | `#product` |
| `~/work/devrev/cli` | `[[devrev-cli]]` | `#tooling` |
| `~/personal/laptop-setup` | `[[laptop-setup]]` | `#infra` |
| `/Users/shlomi` (home) | context-dependent | varies |

### Important

- NEVER fabricate timestamps. Every timestamp comes from the `.jsonl` file.
- Multiple sessions in the same project merge into one section.
- Don't journal system prompts, skill invocations (lines starting with `##`), or `[Request interrupted]` messages.
- Claude Code entries get `#claude-session` on the **top-level heading** (same pattern as `#Computer` for DM-sourced sections). Individual entries get two icon links:
  - `[📄]` — uses `vscode://file/...:<USER_LINE>` (opens the raw transcript at the user's message)
  - `[🦀]` — uses `vclaude://file/...:<ASSISTANT_LINE>?name=Short+description` (opens live in Claude Code at the assistant's response, with the description as window title)
  The scanner captures both line numbers: `lineno` = user message, `assistant_ln` = Claude's response (found by scanning forward for the next `type: "assistant"` line).
  ```markdown
  ## [[project]] #tag #claude-session
    HH:MM — Built X for Y #feature [📄](vscode://file/Users/shlomi/.claude/projects/<PROJECT_DIR>/<SESSION_UUID>.jsonl:<USER_LINE>) [🦀](vclaude://file/Users/shlomi/.claude/projects/<PROJECT_DIR>/<SESSION_UUID>.jsonl:<ASSISTANT_LINE>?name=Built+X+for+Y)
  ```

## Granola Meetings

Granola records meeting notes with AI-generated summaries. These are a rich source for the journal.

### How to fetch

1. **List meetings for the target date:**
   ```
   ListMeetings(time_range="custom", custom_start="<TARGET_DATE>", custom_end="<TARGET_DATE>")
   ```
   Returns meeting IDs, titles, and times.

2. **Get details for each meeting:**
   ```
   GetMeetings(meeting_ids=["<UUID>"])
   ```
   Returns full summary, participants, and action items.

3. Optionally use `GetMeetingTranscript(meeting_id="<UUID>")` if you need exact quotes.

### How to journal meetings

Each meeting gets its own entry under the appropriate project section. Use the meeting's scheduled time as the timestamp.

```
HH:MM — [[Meeting]]: "Meeting Title" with [participants] ⚡
  Key topics discussed:
  - Topic 1 summary
  - Topic 2 summary
  My action items:
  - Action item assigned to Shlomi
```

### Rules for meeting entries

- **Only journal meetings that actually happened** (have a summary). Upcoming/empty ones are skipped.
- **Focus on Shlomi's contributions and action items** — summarize the whole meeting briefly, but highlight what Shlomi said, committed to, or was assigned.
- **Tag with `#meeting`** on the entry line.
- **Link to Granola** — append `[notes](granola://open-document?document_id=<MEETING_UUID>&workspace_id=c3f47c48-2a4a-426a-a9e7-0825a0b7f482)` at the end of the entry line (after ⚡). This deep-links directly into the Granola desktop app. The workspace_id is always `c3f47c48-2a4a-426a-a9e7-0825a0b7f482` (DevRev-Sales). Do NOT use `granola://meeting/`, `granola://note/`, `https://granola.ai/meetings/`, or `https://notes.granola.ai/t/` — all of these are broken.
- **Top-level heading** does NOT get a special meeting tag — meetings go under the relevant project section (e.g., `[[MongoDB]]` for a MongoDB standup). If no project matches, create a `## [[meetings]] #meeting #Computer` section.

### Example

```
## [[Customer/MongoDB]] #Computer
  14:00 — [[Meeting]]: "MongoDB/DevRev Daily Standup" #meeting ⚡ [notes](granola://open-document?document_id=695be894-...&workspace_id=c3f47c48-2a4a-426a-a9e7-0825a0b7f482)
    Prereqs feature built and tested, deployed to org, final testing underway
    Action: Finalize prereqs testing and share update
    Also discussed: Mana sync plugin, Zendesk IT sync, NY trip planning
```

## Data Sources for Object Activity

When journaling a full day, query ALL of these to find objects Shlomi touched:

### Step 1: SQL to find objects

```sql
-- Issues modified by Shlomi on target date
SELECT id, display_id, title, stage.name AS stage_name, priority, modified_date
FROM devrev.issue
WHERE modified_by_id = 'don:identity:dvrv-us-1:devo/0:devu/45'
  AND modified_date >= TIMESTAMPTZ '<TARGET_DATE>T00:00:00+00:00'
  AND modified_date <  TIMESTAMPTZ '<NEXT_DATE>T00:00:00+00:00'
LIMIT 100;

-- Tickets modified by Shlomi on target date
SELECT id, display_id, title, stage.name AS stage_name, severity, modified_date, account_id
FROM devrev.ticket
WHERE modified_by_id = 'don:identity:dvrv-us-1:devo/0:devu/45'
  AND modified_date >= TIMESTAMPTZ '<TARGET_DATE>T00:00:00+00:00'
  AND modified_date <  TIMESTAMPTZ '<NEXT_DATE>T00:00:00+00:00'
LIMIT 100;

-- Conversations modified by Shlomi on target date
SELECT id, display_id, title, state, stage.name AS stage_name, modified_date, account_id, priority
FROM devrev.conversation
WHERE modified_by_id = 'don:identity:dvrv-us-1:devo/0:devu/45'
  AND modified_date >= TIMESTAMPTZ '<TARGET_DATE>T00:00:00+00:00'
  AND modified_date <  TIMESTAMPTZ '<NEXT_DATE>T00:00:00+00:00'
LIMIT 100;
```

### Step 2: Enrich with FetchObjectContext

For EACH object found in Step 1, call `FetchObjectContext` with its DON ID. This returns `discussions_on_the_object` — the full comment thread with `[ISO_TIMESTAMP] Author: message` per line.

**Filter** to comments by Shlomi (devu/45) on the target date. Then summarize:
- What was the context (what issue/ticket is this about)?
- What did Shlomi say/decide?
- What was the outcome?

### Step 3: Journal with rich context

```
HH:MM — Commented on ISS-12345: "Issue title" — [summary of what was said/decided] ⚡
  Context: [brief description of the thread/situation]
  Action: [what was resolved or next step]
```

This produces much richer entries than just "Updated ISS-12345" — it captures the substance of the interaction.

## TODO Extraction

When compiling the journal for a day, actively look for **open action items** across all sources. These are commitments or tasks that were mentioned but not yet completed.

### What counts as a TODO

- **Claude Code sessions**: "can you fix X later", "we need to do Y", "TODO", "lets do this tomorrow", unfinished work interrupted by user
- **Meetings (Granola)**: Action items **explicitly assigned to Shlomi** in the "Next Steps" section, or anything he said "I will..." to. IMPORTANT: If the action item has another person's name in parentheses (e.g., "(Thomas)", "(Chris)"), it belongs to THEM, not Shlomi — skip it entirely regardless of whether Shlomi is involved in the broader project.
- **DM conversations**: Commitments made ("I'll look into it", "let me check", "will follow up")
- **Issue/ticket comments**: Anything Shlomi replied with a commitment ("I'll investigate", "will fix", "looking into this")

**What does NOT count as a TODO:**
- Action items owned by other people, even if Shlomi is on the same team/project
- Work that Shlomi is helping with but not driving (e.g., reviewing Thomas's code, giving input on Amar's follow-up)
- Items already completed during the same day (these are journal entries, not TODOs)

### How to journal TODOs

Add a `## TODOs #Computer` section at the end of the journal page. Each TODO has:
1. **`TODO` marker** — Logseq's native task keyword (queryable via `{{query (todo TODO)}}`)
2. **Description with wikilinks** — what needs to be done, linking to the relevant customer/project page
3. **Source link** — `[DM](https://app.devrev.ai/...)`, `[📄](vscode://file/...:<LINE>) [🦀](vclaude://file/...:<LINE>?name=Short+desc)`, or `[thread](https://devrev.slack.com/...)`. For meeting-sourced TODOs, no link is needed — the meeting title in the parent journal entry is the reference. The `?name=` param should be the first 3-5 words of the outcome, URL-encoded (spaces as `+`).
4. **`SCHEDULED: <YYYY-MM-DD DAY>`** — MUST be on the same block as the TODO (append with `\n`). This is how Logseq recognizes scheduled tasks for the agenda view. Do NOT put it as a separate child block.
5. **Context sub-block** — a child block with expanded context: why this matters, who's involved, what's blocking, relevant background.

**IMPORTANT**: When writing TODOs via the API, the SCHEDULED line must be part of the same block content (joined by `\n`), NOT inserted as a separate child block. Example API call:
```
content = "TODO Finalize prereqs testing ([[Customer/MongoDB]]) ⚡\nSCHEDULED: <2026-06-10 Tue>"
```

**When marking a TODO as DONE**: Change `TODO` to `DONE` and append a `CLOSED: [YYYY-MM-DD DAY]` line (same block, joined by `\n`). Example:
```
content = "DONE Finalize prereqs testing ([[Customer/MongoDB]]) ⚡\nSCHEDULED: <2026-06-10 Tue>\nCLOSED: [2026-06-10 Wed]"
```
This ensures Logseq tracks the completion date in queries and the agenda.

Rendered example:
```
## TODOs #Computer
  TODO Finalize prereqs testing and share update ([[Customer/MongoDB]]) ⚡
  SCHEDULED: <2026-06-10 Tue>
    Prereqs feature built and deployed over weekend. Needed before Mana sync can populate correctly. Final testing underway.
  TODO Share blog post on LLM agent access rights ([[Customer/PwC]]) ⚡
  SCHEDULED: <2026-06-13 Fri>
    Blog covers agent access rights, Obama example. Relevant to PwC zero-tolerance audit discussion. Share with Amar/Murali once live.
```

### Linking TODOs to DevRev issues

After extracting TODOs, **search for a matching DevRev issue** for each one using HybridSearch in the `issue` namespace. **Only look for issues under the "DevRev Labs" part (PROD-56).** For each TODO:

1. **Search** with a natural language query describing the action item. Filter results to those under PROD-56 (DevRev Labs).
2. **If a matching issue exists**: add a link to it in the TODO's context sub-block as `[DISPLAY-ID](https://app.devrev.ai/devrev/works/DISPLAY-ID)` for ISS/TKT prefixes, or `[DISPLAY-ID](https://app.devrev.ai/devrev/issue/DISPLAY-ID)` for custom prefixes like FDE. This makes the TODO clickable from Logseq directly into DevRev.
3. **If no matching issue exists**: note this to the user and **offer to create one** under DevRev Labs (PROD-56). List the TODOs that have no issue and ask the user if they'd like issues created for them. Do NOT auto-create without confirmation.
4. **When creating issues**: always use `applies_to_part: "PROD-56"` and `owned_by: ["don:identity:dvrv-us-1:devo/0:devu/45"]` (Shlomi).

Example with linked issue:
```
TODO Publish "Powerless by Design" blog post ([[Customer/PwC]]) ⚡
SCHEDULED: <2026-06-13 Fri>
  Tracked: [ISS-317157](https://app.devrev.ai/devrev/works/ISS-317157) (use /works/ for ISS/TKT prefixes) — in development, owned by Sourav.
  Blog covers agent access rights. Share with Amar/Murali once live.
```

Example without issue (offer to create):
```
TODO Finalize prereqs testing ([[Customer/MongoDB]]) #no-issue ⚡
SCHEDULED: <2026-06-10 Tue>
  Prereqs feature deployed over weekend. Needed before Mana sync can populate correctly.
```

Note: `#no-issue` goes on the TODO line itself (before ⚡), NOT as a child block. Same pattern as work entries.

### Rules for TODOs

- Only extract items assigned to or committed by **Shlomi** — not other people's action items.
- **Ownership is critical.** Meeting "Next Steps" sections often list actions for multiple people. Read carefully WHO each action is assigned to. If it says "(Thomas)", "(Chris)", "(Amar)", or any name other than Shlomi, it is NOT Shlomi's TODO. Only create TODOs for items where:
  - Shlomi is explicitly named as the owner, OR
  - Shlomi said "I will..." / "let me..." / committed verbally, OR
  - The item has no named owner but is clearly Shlomi's responsibility given context.
- **Helping ≠ owning.** If Shlomi is helping someone else with their task (e.g., pair-programming, providing input, reviewing), that does NOT make it Shlomi's TODO. The work is captured in journal entries, not as an action item.
- **If the work was already done today, it's a journal entry, not a TODO.** If a meeting discusses an action item and Shlomi completed it in a Claude Code session or Slack conversation later the same day, do NOT create a TODO — it's already journaled as completed work.
- Skip items that were clearly completed within the same session/conversation.
- If an item already exists as a TODO on a previous journal day (check recent pages), don't duplicate — but DO note it's still open if relevant.
- Cross-reference: if a TODO from a meeting matches work done in a Claude Code session the same day, it's DONE — don't list it.
- **Every TODO MUST have**: a source link, a SCHEDULED date, and a context sub-block. No naked TODOs.
- **Every TODO MUST be searched** against DevRev issues. Link if found, flag if not.
- **Due date heuristics**: "by end of week" = Friday, "tomorrow" = next business day, "this week" = Wednesday, "soon" / no deadline mentioned = 3 business days out, meeting follow-up with a specific date = that date.

## Slack Messages

Search Slack for messages Shlomi sent or was directly asked about on the target date. This captures requests made to/from him, decisions communicated, and threads he participated in.

### How to fetch

Shlomi's Slack user ID is `U01SZ9YF96D`.

1. **Messages Shlomi sent** on the target date:
   ```
   SlackSearchPublicAndPrivate(query="from:<@U0A8RUR1S00> on:YYYY-MM-DD", include_context=true, limit=20)
   ```

2. **Messages mentioning/directed at Shlomi** on the target date:
   ```
   SlackSearchPublicAndPrivate(query="to:<@U0A8RUR1S00> on:YYYY-MM-DD", include_context=true, limit=20)
   ```

3. **DMs with Shlomi** (for direct asks):
   ```
   SlackSearchPublicAndPrivate(query="in:<@U0A8RUR1S00> on:YYYY-MM-DD", include_context=true, limit=20)
   ```

### What to journal from Slack

- **Requests Shlomi made** — things he asked others to do (shows delegation/coordination)
- **Requests directed at Shlomi** — things others asked him for (shows what he's being pulled into)
- **Decisions communicated** — announcements, status updates, approvals he posted
- **Substantive thread participation** — technical discussions, reviews, problem-solving

### What to skip

- Bot notifications, automated messages
- Simple reactions, emoji-only messages
- Casual chat, greetings, "thanks" messages
- Messages already captured via other sources (e.g., a Slack thread about a meeting that's already journaled from Granola)

### How to journal Slack entries

Each entry goes under the relevant project section (match by channel/topic). Use the message timestamp.

```
HH:MM — [Slack]: Brief summary of what was communicated/requested #no-issue ⚡
  Channel: #channel-name. Context: what was discussed/decided.
```

If a Slack message links to a specific thread, use the **full permalink** from the search results at the end of the entry line. For thread replies, this MUST include `?thread_ts=...&cid=...` params — without these, Slack opens the channel but not the specific reply.

Format: `[thread](https://devrev.slack.com/archives/CHANNEL_ID/pTIMESTAMP?thread_ts=PARENT_TS&cid=CHANNEL_ID)`

For top-level (non-threaded) messages, just: `[thread](https://devrev.slack.com/archives/CHANNEL_ID/pTIMESTAMP)`

The permalink field from Slack search results already contains the correct full URL — use it verbatim.

### Rules for Slack entries

- **Only journal substantive interactions** — skip noise.
- **Merge related messages** — if 5 messages in one thread = one topic, that's one entry.
- **Attribute correctly** — note whether Shlomi asked or was asked.
- **Deduplicate** — if a Slack conversation led to a meeting or DM that's already journaled, skip the Slack entry as a standalone item.
- **Enrich other entries** — Slack often adds color/context to work captured from other sources. If a Slack thread relates to an existing journal entry (e.g., a meeting follow-up, a deployment discussion, a code review), don't create a separate entry — instead add the Slack context as a sub-block under the existing entry. Example: if Granola captured a MongoDB standup, and Slack has a follow-up thread where Chris asked for the timeline, add that as context under the meeting entry rather than a new standalone entry.

## Important Notes

- Never overwrite existing entries. Always append.
- Always read the page first to avoid duplicates and to find the right section.
- **Timestamp accuracy is critical.** When journaling past conversations, fetch the DM object via FetchObjectContext — the `discussions_on_the_object` field contains `[ISO_TIMESTAMP]` on each message. Convert UTC to America/Chicago (CDT = UTC-5, CST = UTC-6) for the journal timestamp. Only use "now" for entries happening in the current moment.
- **Chronological order is mandatory.** Entries within each section must be sorted ascending by timestamp. Use `moveBlock` to reorder if needed after inserting.
- **Always include DM links.** Every entry sourced from a DM conversation gets `[DM](https://app.devrev.ai/devrev/computer/dm?chatId=don%3Acore%3Advrv-us-1%3Adevo%2F0%3Adm%2F<SUFFIX>)` appended. The suffix is the short ID after the last `/` in the DM's DON.
- Keep entries concise — this is a log, not prose.
- When summarizing conversation work, focus on **outcomes** not process.
