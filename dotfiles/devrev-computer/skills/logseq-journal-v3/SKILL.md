---
name: logseq-journal-v3
description: >
  Write a flat daily journal page in Logseq. Gathers activity from all sources (Claude Code,
  DMs, Granola meetings, Slack, DevRev objects) and writes timestamped entries grouped by
  project to the journal day page. Does NOT route to entity pages — that's the indexer's job.
trigger: >
  Activate when the user asks to journal, log, record, or note something to Logseq.
  Trigger phrases include: journal this, log this, note this, add to journal, write to logseq,
  record this in logseq, update my journal, log my day, journal my day, journal entry,
  logseq entry, capture this, journal v3.
  Also activate when the user says "journal" as a standalone command or asks to summarize
  what was accomplished and write it to the journal.
  Do NOT activate for: reading/searching logseq, indexing (use logseq-graph-index-v3).
---

# Logseq Journal v3 — Daily Page Writer

Write a flat, chronological daily journal page. This skill gathers data and writes to the journal day page only. Entity page routing, link enrichment, and claims are handled by `logseq-graph-index-v3` as a separate pass.

## Connection

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w)
LOGSEQ_API_URL="http://localhost:12315"
```

All API calls:
```bash
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "...", "args": [...]}'
```

## Pre-flight: API health check (MANDATORY)

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w 2>/dev/null)
HEALTH=$(curl -s --max-time 3 -X POST "http://localhost:12315/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.App.getCurrentGraph", "args": []}')

if echo "$HEALTH" | grep -q "journal"; then
  echo "ok"
else
  echo "Logseq API unreachable. Open Logseq with the journal graph."
  exit 1
fi
```

Run ONCE at start. If it fails, STOP and tell the user.

## Journal Page Format

Page name: `"Jun 11th, 2026"` (ordinal suffix: 1st, 2nd, 3rd, 4th-20th, 21st, 22nd, 23rd, 24th-30th, 31st).

### Structure

```markdown
## [[project-or-context]] #category-tag
  HH:MM — Brief outcome description ⚡ [DM](url)
    Supporting detail line
  HH:MM — Another outcome [📄](vscode://...) [🦀](vclaude://...)
    Detail
## [[another-project]] #tag
  HH:MM — Entry ⚡
```

### Rules

1. **Group by the user's INTENT, not by tool/topic** — each `## [[page]] #tag` heading represents the high-level activity/context the user was in.
   - **ONE section per project.** Never create two headings for the same `[[page]]`. Merge into existing.
   - **Lump aggressively.** If you're setting up a laptop and you configure iTerm2, Zsh, Karabiner, Vivaldi — that's ALL under `[[laptop-setup]]`. The individual tools get `[[wikilinks]]` inline, but NOT their own sections. The user's intent was "set up my laptop" — not "do 8 independent tool configurations."
   - **Create a new section only when the user's context genuinely shifts.** Laptop setup → MongoDB deployment is a context shift. iTerm2 → Karabiner is NOT (it's still laptop setup).
   - **Use inline wikilinks** for sub-topics: `13:01 — Fixed [[iTerm2]] Option key navigation 📄🦀`. This gives the indexer backlinks without fragmenting the journal.
   - **Fewer sections = better.** A typical day should have 3-6 sections, not 10-15. Think: what were the 3-5 major contexts/projects today?

2. **Timestamp every entry** — `HH:MM` in 24h format (user's local timezone — see Timezone Conversion section).
   - Entries MUST be sorted chronologically ascending within each section.
   - Sections sorted by their earliest timestamp (page reads as a timeline top to bottom).

3. **Outcome-first** — lead with what was accomplished, not what was attempted.

4. **Wikilinks** — use `[[PageName]]` for tools, concepts, projects that are or could be pages.

5. **Tags** — use `#tag` for queryable categories:
   - `#tooling` — dev tools, CLI, MCP servers
   - `#config` — system/app configuration
   - `#product` — product/feature work
   - `#feature` — new feature built
   - `#bugfix` — bug fixed
   - `#devops` — deployment, packaging, CI
   - `#habits` — routines, reminders
   - `#meeting` — meetings

6. **Supporting details** — indent under the timestamp line. Keep terse.

7. **Attribution markers** (source signal, no `#Computer` tag needed):
   - `⚡` at end of entry line — from DMs, Slack, meetings, DevRev objects
   - `[📄](vscode://...) [🦀](vclaude://...)` at end — from Claude Code sessions
   - `#manual-entry` — human-authored, no source fingerprint

   **Invariant:** every entry the skill *generates* carries a source fingerprint and one of the automated markers above. The skill NEVER writes a sourceless activity entry. Therefore, at end of run, EVERY activity block on the page must be *either* fingerprinted/marked (automated) *or* `#manual-entry` (human-authored). A block that is neither is NOT a manual entry — it is a skill error (a write that lost its marker). Surface it; never silently treat it as manual.

   **How `#manual-entry` gets applied — by timing, not by absence of a marker:**
   - The tag is applied in a FIRST PASS (step 3), before any new entries are written: any entry already on the page at the start of the run predates this run, so it is human-authored by definition — tag it `#manual-entry`.
   - Do NOT infer "manual" later from "this entry has no fingerprint." That would mask the skill's own marker bugs. Classification is by *when the entry appeared* (pre-existing → manual), verified by an end-of-run audit (step 13a).
   - The human never adds this tag themselves; the skill always does.

8. **DM link** — append `[DM](https://app.devrev.ai/devrev/computer/dm?chatId=don%3Acore%3Advrv-us-1%3Adevo%2F0%3Adm%2F<SUFFIX>)` for DM-sourced entries.

9. **Chronological order is mandatory.** Use `moveBlock` to reorder if needed.

10. **Issue linking** — handled by `logseq-graph-index-v3` Phase 4, NOT by this skill. Do NOT append issue links or `#no-issue` during journaling. Just write the activity entries.

### Customer page convention

When work relates to a customer/account, use `[[Customer/<Name>]]` as the section heading.

### Existing page references

Use wikilinks to existing pages when relevant:
- `[[Customer/MongoDB]]`, `[[Customer/PwC]]` — customer work
- `[[SDA]]`, `[[sda-solution]]` — internal product
- `[[Claude Code]]`, `[[claude-code]]` — agent/skill work
- `[[Logseq]]`, `[[mcp-logseq]]` — knowledge graph
- `[[iTerm2]]`, `[[tmux]]`, `[[Zsh]]`, `[[FZF]]` — terminal tools
- `[[Karabiner-Elements]]`, `[[Amethyst]]` — system tools
- `[[laptop-setup]]` — infra/dotfiles
- `[[DevRev]]` — DevRev platform/product

## Incremental Mode (Multi-Run Support)

This skill supports running multiple times per day. On subsequent runs, it gathers ONLY new activity since the last run — saving tokens and avoiding duplicates.

### Journal page markers

The journal day page carries two timestamps in its first block (as Logseq page properties):

```
last_journaled:: 2026-06-12T20:10:00-05:00
last_indexed:: 2026-06-12T20:10:00-05:00
```

| Marker | Meaning | Set by |
|---|---|---|
| `last_journaled` | Timestamp of latest activity entry written. Source data freshness boundary. | This skill (journal) |
| `last_indexed` | Timestamp of latest entry moved to entity pages. | Indexer skill |

**The timestamp is the latest ACTIVITY timestamp captured** — not the time the skill ran.

### Reading markers (Step 0 of workflow)

```python
import re
from datetime import datetime

def read_markers(page_tree):
    """Extract last_journaled and last_indexed from page properties."""
    if not page_tree or not isinstance(page_tree, list):
        return None, None
    
    first_block = page_tree[0]
    content = first_block.get('content', '')
    
    lj_match = re.search(r'last_journaled:: (.+)', content)
    li_match = re.search(r'last_indexed:: (.+)', content)
    
    last_journaled = datetime.fromisoformat(lj_match.group(1)) if lj_match else None
    last_indexed = datetime.fromisoformat(li_match.group(1)) if li_match else None
    
    return last_journaled, last_indexed
```

### Source fingerprints

Every entry has a unique source identifier embedded in its links. These are the dedup keys.

| Source | Fingerprint fragment (unique substring) | Where in entry |
|---|---|---|
| Claude Code | `<session-uuid>.jsonl:<line>` | `[📄](vscode://file/.../<uuid>.jsonl:<LINE>)` |
| Slack | `archives/<CHANNEL_ID>/p<TIMESTAMP>` | `[Slack](https://devrev.slack.com/archives/...)` |
| Granola | `document_id=<UUID>` | `[notes](granola://...document_id=<UUID>...)` |
| DMs | `chatId=<DON_SUFFIX>` | `[DM](https://app.devrev.ai/...chatId=...)` |
| DevRev objects | DON ID (e.g., `issue/304209`) | `[ISS-xxx](url)` or DON |
| Manual | None | Tagged `#manual-entry`, always new |

### Datalog fingerprint dedup

**"Which of my gathered items already exist somewhere in the graph?"**

```python
def check_fingerprints_exist(fingerprints, token):
    """Batch Datalog query: which fingerprints are already in the graph?
    Returns the SET of fingerprints that already exist."""
    if not fingerprints:
        return set()
    
    # Build Datalog query with needle list
    query = '[:find ?needle :in $ [?needle ...] :where [?b :block/content ?c] [(clojure.string/includes? ?c ?needle)]]'
    
    payload = json.dumps({
        "method": "logseq.DB.datascriptQuery",
        "args": [query, fingerprints]
    })
    result = subprocess.run(
        ['curl', '-s', '-X', 'POST', 'http://localhost:12315/api',
         '-H', f'Authorization: Bearer {token}',
         '-H', 'Content-Type: application/json',
         '-d', payload],
        capture_output=True, text=True)
    
    try:
        data = json.loads(result.stdout)
        # Result is [[needle1], [needle2], ...] — flatten
        return set(item[0] for item in data if item)
    except:
        return set()

def extract_fingerprint(content):
    """Extract the unique source fingerprint from an entry's content."""
    # Claude Code: session file + line
    m = re.search(r'vscode://file/.+?/([0-9a-f-]+\.jsonl:\d+)', content)
    if m: return m.group(1)
    
    # Slack permalink
    m = re.search(r'archives/[A-Z0-9]+/p\d+', content)
    if m: return m.group(0)
    
    # Granola meeting UUID
    m = re.search(r'document_id=([0-9a-f-]{36})', content)
    if m: return f"document_id={m.group(1)}"
    
    # DM chat ID
    m = re.search(r'chatId=([^&)]+)', content)
    if m: return f"chatId={m.group(1)}"
    
    # DevRev issue
    m = re.search(r'(issue|works)/[A-Z]+-\d+', content)
    if m: return m.group(0)
    
    return None  # No fingerprint — manual entry
```

### Three-way decision

After fingerprint dedup, each gathered item is classified:

| Case | Condition | Action |
|---|---|---|
| **1. Net new** | Fingerprint not in graph, not on journal page already | Add as new entry |
| **2. Discard** | Fingerprint already exists in graph or on journal page | Skip |
| **3. Sub-block** | Fingerprint is new, BUT topically related to an existing entry (same people + subject + within ~30 min) | Add as sub-block of that entry |

For case 3 detection, use targeted Datalog to fetch today's entries on the relevant entity page:

```clojure
[:find (pull ?b [:block/uuid :block/content])
 :where
 [?b :block/page ?p]
 [?p :block/name "<page-name-lowercase>"]
 [?b :block/parent ?parent]
 [?parent :block/content ?pc]
 [(clojure.string/includes? ?pc "Jun 12th, 2026")]]
```

### Updating markers after writing

After writing all entries to the journal page, update `last_journaled::`:

```python
def update_last_journaled(page_name, timestamp_str, token):
    """Set or update last_journaled:: on the journal page's first block."""
    tree = api("logseq.Editor.getPageBlocksTree", [page_name])
    if not tree:
        return
    
    first_block = tree[0]
    content = first_block.get('content', '')
    uuid = first_block.get('uuid', '')
    
    if 'last_journaled::' in content:
        # Update existing
        content = re.sub(r'last_journaled:: .+', f'last_journaled:: {timestamp_str}', content)
    else:
        # Add to properties block (or create properties block)
        if content.strip() == '':
            content = f'last_journaled:: {timestamp_str}'
        else:
            content = f'last_journaled:: {timestamp_str}\n{content}'
    
    api("logseq.Editor.updateBlock", [uuid, content])
```

---

## Data Sources

**⚠️ CRITICAL: Query ALL sources below for EVERY run. Do NOT skip any source based on day-of-week (weekend/weekday), holidays, or assumptions about when the user works. The user works every day. If a source returns empty results, that's fine — but you MUST query it. Never write "(none - Sunday)" or "(none - weekend)" — those are fabricated excuses for not querying.**

**⚠️ DELTA MODE: If `last_journaled` exists, apply delta filtering to each source. If `last_journaled` is None (first run), gather the full day.**

| Source | Full-day query | Delta query (when `last_journaled` exists) |
|---|---|---|
| Claude Code | Scanner with `today = '<TARGET_DATE>'` | Add filter: `if local_dt > last_journaled` after timestamp parse |
| Slack | `from:<@ID> on:YYYY-MM-DD` | `from:<@ID> after:YYYY-MM-DDTHH:MM` |
| Granola | `ListMeetings(custom_start=today)` → `GetMeetings` all | Same `ListMeetings` → Datalog UUID check → `GetMeetings` only new |
| DMs | `start_date=today, end_date=today` | Same query, filter results by `modified_date > last_journaled` |
| DevRev SQL | `modified_date >= today` | `modified_date > TIMESTAMPTZ '<last_journaled>'` |

### 1. Claude Code sessions

```bash
python3 -c "
import json, os
from datetime import datetime
from pathlib import Path

today = '<TARGET_DATE>'  # YYYY-MM-DD from date determination step above
sessions_dir = Path.home() / '.claude' / 'projects'

print(f'SCANNER: searching for date={today}')
files_scanned = 0
results = {}
for jsonl in sessions_dir.rglob('*.jsonl'):
    if 'subagents' in str(jsonl):
        continue
    files_scanned += 1
    project = jsonl.parent.name.replace('-Users-shlomi-', '~/').replace('-', '/')
    with open(jsonl) as f:
        all_lines = f.readlines()
    total_lines = len(all_lines)
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
        # DELTA MODE: skip entries before last_journaled timestamp
        # (uncomment and set LAST_JOURNALED when in delta mode)
        # if LAST_JOURNALED and local_dt <= LAST_JOURNALED:
        #     continue
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
            # Find the LAST assistant line before the next user message
            # (the conclusion, not the first acknowledgment)
            assistant_ln = lineno
            for offset in range(1, 200):
                idx = lineno - 1 + offset
                if idx >= len(all_lines):
                    break
                try:
                    ad = json.loads(all_lines[idx])
                    if ad.get('type') == 'user':
                        break  # hit next user message, stop
                    if ad.get('type') == 'assistant':
                        assistant_ln = lineno + offset  # keep updating to get the LAST one
                except:
                    continue
            results.setdefault(project, []).append((time_str, content, str(jsonl), lineno, assistant_ln, total_lines))

print(f'SCANNER: scanned {files_scanned} files, found {sum(len(v) for v in results.values())} entries across {len(results)} projects')
if not results:
    print(f'SCANNER: NO ENTRIES FOUND for {today}. Do NOT fabricate entries.')
else:
    for proj in sorted(results):
        print(f'=== {proj} ===')
        # Group entries by session file for clarity
        by_file = {}
        for t, c, f, ln, aln, total in results[proj]:
            by_file.setdefault(f, []).append((t, c, ln, aln, total))
        for f in sorted(by_file):
            total = by_file[f][0][4]
            print(f'  SESSION: {f} ({total} lines)')
            for t, c, ln, aln, _ in by_file[f]:
                print(f'    {t} | L{ln} | A{aln} | {c}')
        print()
"
```

**Summarization rules:**
- Group by project, identify outcomes, use FIRST timestamp of each logical task.
- Merge related messages into single outcome bullets.
- Never fabricate timestamps.
- **If the scanner says "NO ENTRIES FOUND", write ZERO Claude Code entries.** Do not invent entries from filenames, directory listings, or your imagination.
- **Never fabricate line numbers.** The scanner outputs `HH:MM | L<N> | A<N> | text` — use THOSE line numbers verbatim for the `[📄]` and `[🦀]` links. The scanner also shows `(N lines)` per session file — your line numbers must be ≤ that number.
- **Never fabricate content.** The outcome description MUST be derived from the actual user message text output by the scanner. If the scanner says "set up my iterm2 to darkmnodeq", the entry is about iTerm2 dark mode — NOT about FZF or anything else you hallucinated.
- **Read assistant tool calls for outcome clarity.** When a user message is an instruction to write/save/document something (e.g., "keep this as an MD file", "save this as a spec"), the outcome description MUST reflect WHAT was written — not just that something was saved. Look at the assistant's response lines (between the user line and the next user line) for `Write` or `Edit` tool_use blocks. The file path and the first line of content tell you what was actually produced. Example: if the assistant wrote `docs/specs/2026-06-12-cancel-propagation-to-external-system.md`, the outcome is "Documented cancel-propagation spec for MANA duplicate-request bug" — NOT "Saved roadmap alternatives to MD file". When the scanner output shows a vague user message like "lets do A now, but keep this as an MD file", you MUST read a few lines ahead in the session to find the tool_use/Write call and use THAT for the outcome description.
- **Cross-check:** `[📄]` line ≤ total lines in file. `[🦀]` line > `[📄]` line. Both ≤ total lines. If any of these fail, you made an error.
- **No scanner output = no entries.** If the script produced no output for a project/session, that session had no activity on the target date. Period.

**Project name mapping:**

| Session path (from scanner) | Logseq project | Tag |
|---|---|---|
| `~/work/SDA/MongoDB` | `[[Customer/MongoDB]]` | `#product` |
| `~/work/SDA/sda/solution` | `[[sda-solution]]` | `#product` |
| `~/work/SDA` | Infer from content (see below) | varies |
| `~/personal/laptop-setup` | `[[laptop-setup]]` | `#infra` |
| `~/work/vulcan` | `[[vulcan]]` | `#product` |
| `~/work/devrev/cli` | `[[devrev-cli]]` | `#tooling` |
| `/Users/shlomi` (root project) | Infer from content (see below) | varies |
| `/private/tmp/claude/at` | Same as the session it's replaying | varies |
| `~//aws` | `[[laptop-setup]]` | `#infra` |
| `~/work` (root) | Infer from content | varies |

**When project path is ambiguous** (e.g., `/Users/shlomi` or `~/work/SDA`), infer the Logseq project from the message CONTENT:
- iTerm2, terminal, dark mode → `[[iTerm2]]` `#config`
- Karabiner, keyboard, profiles → `[[Karabiner-Elements]]` `#config`
- FZF, fzf, fuzzy finder → `[[Zsh]]` `#config`
- Vivaldi, browser, search engines → `[[Vivaldi]]` `#config`
- zsh, zshrc, powerlevel10k → `[[Zsh]]` `#config`
- Amethyst, tiling, window → `[[Amethyst]]` `#config`
- brew, install, setup → `[[laptop-setup]]` `#infra`
- Multiple topics in one session file → split into separate entries by topic, each under the correct project heading

**Splitting multi-topic sessions:** A single session file may contain work on 3 different tools. Group consecutive messages about the same topic into one journal entry. When the topic changes (e.g., from iTerm2 to Karabiner), that's a new entry under a different project section. Use the FIRST timestamp of each topic cluster.

**Claude Code entry format:**
```
HH:MM — Outcome description [📄](vscode://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<USER_LINE>) [🦀](vclaude://file/Users/shlomi/.claude/projects/<DIR>/<UUID>.jsonl:<ASSISTANT_LINE>?name=Descriptive+5-10+word+summary+of+what+happened)
```

**`?name=` parameter:** Must be **5-10 words** that describe what was accomplished in that segment. This shows as the iTerm2 window title when vclaude opens, so make it meaningful at a glance. Use `+` for spaces.

Good examples:
- `?name=Built+vclaude+protocol+handler+for+macOS+URL+scheme`
- `?name=Fixed+session+bootstrap+and+history+file+interference`
- `?name=Restyled+Mana+sequence+diagram+to+match+SDA+format`
- `?name=Attempted+org-mode+migration+then+reverted+to+markdown`

Bad examples (too short):
- `?name=Fix+bug` ❌
- `?name=New+script` ❌
- `?name=Working` ❌

Line numbers: `[📄]` points to the user message line. `[🦀]` points to the LAST assistant response before the next user message (the conclusion/result, not the first acknowledgment). This way vclaude opens at the point where the work was completed.

**MANDATORY: Every Claude Code entry gets BOTH `[📄]` AND `[🦀]`.** This applies to parent entries AND sub-blocks equally. A sub-block is still a distinct user↔assistant exchange — it has its own user line and its own assistant response. Never write a Claude Code entry with only `[📄]` and no `[🦀]`. If the scanner gave you `HH:MM | L<N> | A<N>`, the entry MUST have both links using those exact line numbers.

### 2. DM conversations

Use RecallChats with `start_date`/`end_date` for the target date. For each DM, call FetchObjectContext to get exact message timestamps from `discussions_on_the_object`. Convert UTC to local (see Timezone Conversion section).

### 3. Granola meetings

**Workspace ID:** Read from `/memories/user/granola-config.md`. Use it for `granola://` deep links.

1. `ListMeetings(time_range="custom", custom_start="<TARGET_DATE>", custom_end="<TARGET_DATE>")`
2. `GetMeetings(meeting_ids=["<UUID>"])` for full details.

**Meeting entry format:**
```
HH:MM — [[Meeting]]: "Title" with [participants] #meeting ⚡ [notes](granola://open-document?document_id=<UUID>&workspace_id=<WORKSPACE_ID>)
  Key topics:
  - Topic summary
  Action items (Shlomi only):
  - Action item
```

Only journal meetings that actually happened (have a summary). Focus on Shlomi's contributions and commitments.

### 4. Slack messages

**⚠️ Slack user ID:** Read from `/memories/user/slack-identity.md`. Open that file and use the ID stored there.

**DO NOT use the bot/app ID** from the Slack tool description (the `Current logged in user's user_id` shown in the tool schema is a bot account, NOT Shlomi's personal account). Always read the ID from the memory file.

```
SlackSearchPublicAndPrivate(query="from:<@SLACK_USER_ID> on:YYYY-MM-DD", include_context=true, limit=20)
SlackSearchPublicAndPrivate(query="to:<@SLACK_USER_ID> on:YYYY-MM-DD", include_context=true, limit=20)
```

**Cross-source merging:** Slack messages often relate to meetings, Claude Code sessions, or DMs. During the correlation step (step 5 in Workflow), merge related Slack messages as sub-blocks under the primary entry from another source. Only create standalone Slack entries for genuinely independent interactions that don't relate to any other source.

**Slack link format:** Use the permalink URL returned by Slack search results directly. Each search result includes a `Permalink` field — use that URL as-is.

Example: `https://devrev.slack.com/archives/C09N3MPJ7GF/p1780978084405479`

Do NOT construct `slack://` deep links manually. Just use the permalink.

**Slack entry format:**
```
HH:MM — Brief summary ⚡ [Slack](https://devrev.slack.com/archives/CHANNEL_ID/pTIMESTAMP)
  Channel: #channel-name. Context.
```

### 5. DevRev objects (issues/tickets/conversations)

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

For each object, call FetchObjectContext to get comment threads. Summarize what was said/decided.

## TODO Extraction

Actively look for open action items across all sources:

- Claude Code: "TODO", "lets do this tomorrow", unfinished work
- Meetings: Action items **assigned to Shlomi only** (skip items with other names in parentheses)
- DMs: Commitments ("I'll look into it", "will follow up")
- Issues: Shlomi's commitments in comments

**TODO format:**
```
## TODOs
  TODO Description ([[relevant-page]]) ⚡
  SCHEDULED: <YYYY-MM-DD DAY>
    Because [narrative phrase](((activity-block-uuid))) — brief context.
```

**Grounding rule (MANDATORY):** Every TODO MUST contain a `[narrative phrase](((uuid)))` block reference pointing to the specific activity entry that spawned it. This is what makes the TODO traceable — you can click through to see exactly where the commitment was made or the need emerged.

- The `(((uuid)))` references the activity block on the journal page (before indexer moves it). Since `moveBlock` preserves UUIDs, the reference will still work after indexing routes the activity to its entity page.
- The narrative phrase should read naturally: `Because [prereqs need testing on a fresh org](((uuid)))` or `Because [Amar promised tonight/tomorrow](((uuid)))`.
- If the TODO comes from a Slack message or DM, reference the journal entry that captured it (not the Slack message itself — there's no block for that).

**Rules:**
- Only Shlomi's items. Helping != owning.
- If work was already done today, it's a journal entry, not a TODO.
- Every TODO needs: SCHEDULED date, grounded block reference.
- `#no-issue` if no matching DevRev issue found; issue link in sub-block if found.
- Due date heuristics: "by end of week" = Friday, "tomorrow" = next business day, "soon" = 3 business days.

**Cross-reference against same-day activity (MANDATORY):**

Before writing ANY TODO derived from meeting notes or DMs, check if a later activity entry (by timestamp) on the SAME day already fulfills it. This is the #1 source of false TODOs.

Procedure:
1. For each candidate TODO from meetings/DMs, extract the core action (e.g., "document duplicate-request bug in MD file").
2. Scan ALL activity entries gathered from ALL sources (Claude Code, Slack, etc.) for the same day.
3. If an activity entry's outcome description matches the TODO's intent (same topic + same action verb like "wrote", "documented", "created", "deployed", "sent"), the work is DONE — do NOT write a TODO.
4. When in doubt (activity is vaguely related but not clearly completing the TODO), write the TODO but add a note: "Possibly already done — see HH:MM entry."

Example:
- Meeting at 12:00 says: "Next: Shlomi to document bug in MD"
- Activity at 12:01 says: "Documented duplicate-request bug spec in MongoDB repo [📄](...)"
- Result: Do NOT create a TODO. The 12:01 entry IS the completion.

Additionally, check if the TODO's origin and a later Claude Code entry share the SAME session file. If a meeting action item was discussed at 12:00 and the scanner shows activity in the same `.jsonl` at 12:01+ with a Write tool call — that's strong evidence the work was done immediately.

**CRITICAL: API newline convention.** TODOs with SCHEDULED must use Python-internal pattern for real newlines:
```bash
python3 -c "
import json, subprocess, os
token = os.popen('security find-generic-password -s \"devrev-pat\" -a \"logseq-kg\" -w').read().strip()
content = 'TODO Action item ([[Page]])\nSCHEDULED: <2026-06-10 Tue>'
payload = json.dumps({'method': 'logseq.Editor.insertBlock', 'args': ['PARENT_UUID', content, {'sibling': False}]})
result = subprocess.run(
    ['curl', '-s', '-X', 'POST', 'http://localhost:12315/api',
     '-H', f'Authorization: Bearer {token}',
     '-H', 'Content-Type: application/json',
     '-d', payload],
    capture_output=True, text=True)
print(result.stdout)
"
```

## Workflow

1. **Pre-flight health check** — STOP if fails.
2. **Get the ACTUAL date** — MANDATORY, see below. Run `date` before anything else.
3. **Read journal page + extract markers.**
   - Read `getPageBlocksTree` for the journal day page.
   - Extract `last_journaled::` and `last_indexed::` from the first block (see `read_markers()` above).
   - Collect any existing entries on the journal page (not yet indexed). Extract their fingerprints into a `journal_fingerprints` set.
   - **FIRST PASS — manual-entry tagging (MANDATORY, do this BEFORE gathering or writing anything new):** every leaf activity/content block already on the page at the start of this run predates the run, so it is human-authored by definition. Append ` #manual-entry` to each such block via `updateBlock` (skip if already tagged). This classifies manual entries by TIMING (they pre-exist this run), not by absence of a marker — so it is immune to the skill's own marker bugs. Exclude page-property blocks (e.g. the `last_journaled::` block) and pure section headings (`## ...`); tag only leaf activity/content blocks. When editing a block whose content contains a LOGBOOK/CLOCK drawer or other control characters, append the tag to the first line only and preserve the rest of the content verbatim.
   - **If `last_journaled` is None:** First run of the day. Proceed with full gather.
   - **If `last_journaled` exists:** Delta mode. Filter all sources to only return data AFTER that timestamp.
4. **Gather data from sources (with delta filtering).**
   - Query EVERY source — no exceptions, no skipping based on day-of-week.
   - **Delta mode filters:**
     - Claude Code scanner: `if local_dt > last_journaled` in Python filter
     - Slack: `from:<@ID> after:YYYY-MM-DDTHH:MM` (where HH:MM comes from `last_journaled`)
     - Granola: `ListMeetings(custom_start=today)` → compare UUIDs against Datalog results → only `GetMeetings` on new UUIDs
     - DMs: filter by `modified_date > last_journaled`
     - DevRev objects: `modified_date > last_journaled` in SQL WHERE clause
   - **First run (no marker):** Gather the full day as normal.
5. **Fingerprint dedup — classify gathered items.**
   - Extract fingerprint from each gathered item using `extract_fingerprint()`.
   - Run `check_fingerprints_exist()` — one Datalog batch query for all fingerprints.
   - Python set subtraction:
     - `existing_in_graph` = fingerprints returned by Datalog (already captured on entity pages)
     - `on_journal_already` = `journal_fingerprints` from step 3
     - `truly_new` = gathered items whose fingerprint is in neither set
     - `already_captured` = everything else → discard silently
   - **If nothing is truly new:** Tell user "Nothing new since last run." STOP.
6. **Three-way decision for truly new items.**
   - For each item in `truly_new`, check if it's topically related to an existing entry (case 3):
     - Use targeted Datalog to fetch today's entries on the target entity page.
     - Signals: same people, same subject, within ~30 min, same conversation thread.
     - If related → mark as sub-block (`item.merge_target = existing_entry_uuid`).
     - If not → standalone new entry.
7. **Brief status** — one line: `Gathered: X new entries (Y discarded as already captured). Delta since HH:MM.`
8. **Correlate across sources** — merge related new activity into single entries (existing lumping logic).
9. **🚦 USER GATE — Show proposed groupings and WAIT for approval.**
   - Present the lumped plan as a concise outline: section headings, entry summaries (one line each), and sub-blocks (indented). Include timestamps and source indicators (⚡, 📄🦀, Slack, etc.) so the user can see what feeds into what.
   - For case 3 items, clearly indicate: "(adds to existing HH:MM entry on [[Page]])"
   - Ask: "Does this look right? Want to change groupings, add context, or adjust anything before I write it?"
   - **STOP HERE.** Do NOT proceed to step 10 until the user responds.
   - If the user says "looks good" / "go" / "yes" / approves → proceed as-is.
   - If the user requests changes → apply, show revised, ask again.
   - If the user adds narrative context → incorporate.
10. **Write entries to journal day page** — grouped by project, sorted chronologically.
    - For case 3 items (sub-blocks of existing entity page entries), include `amend:: <target-block-uuid>` in the entry content. The indexer will use this to merge instead of creating a new entry.
11. **Extract TODOs** — write to `## TODOs` section at end of journal page (see UUID verification below).
12. **Update `last_journaled::`** — set to the timestamp of the LATEST activity entry written (not the current clock time).
13. **Verify block references (MANDATORY)** — after writing TODOs, run UUID verification.
13a. **Attribution audit (MANDATORY)** — re-read the page tree and confirm EVERY leaf activity/content block is either fingerprinted/marked (`⚡`, `[📄]`, `[🦀]`, or a source fingerprint) OR tagged `#manual-entry`. Any block that is neither is a skill error — a write that lost its marker, NOT a manual entry. Do not auto-tag it as manual. Surface each such block to the user (uuid + first line) and ask how to handle it. See Attribution audit below.
14. **Confirm** — brief summary: how many entries written, which project sections, any TODOs, and the attribution-audit result (clean, or N blocks flagged). 2-3 lines max.

### UUID verification (step 10)

After writing all TODOs with `(((uuid)))` block references, verify every referenced UUID actually resolves to a block on the page. This prevents broken/unlinked references.

**Procedure:**

1. Re-read the full page tree with `getPageBlocksTree`.
2. Walk all blocks, collecting every UUID that exists on the page into a set.
3. Find all `(((uuid)))` patterns in block content (these are the references).
4. For each reference, check if the referenced UUID exists in the set.

```python
import json, re

# After reading page tree into `data`:
existing_uuids = set()
ref_blocks = []  # (block_uuid, referenced_uuid, content_snippet)

def walk(blocks):
    for b in blocks:
        uuid = b.get('uuid', '')
        content = b.get('content', '')
        if uuid:
            existing_uuids.add(uuid)
        refs = re.findall(r'\(\(\(([0-9a-f-]{36})\)\)\)', content)
        for ref in refs:
            ref_blocks.append((uuid, ref, content[:100]))
        for c in b.get('children', []):
            walk([c])

walk(data)

broken = [(bu, ru, c) for bu, ru, c in ref_blocks if ru not in existing_uuids]
if broken:
    print(f'BROKEN: {len(broken)} references')
    for bu, ru, c in broken:
        print(f'  Block {bu}: refs {ru} | {c}')
else:
    print('ALL REFERENCES VALID')
```

**If broken references are found:**

1. Use the narrative phrase text in the `[...]` part of the broken reference as a search hint — e.g., if the link text says "got past params bug", search for a block on the page whose content contains that text.
2. Get its actual UUID from the page tree.
3. Update the broken block with `logseq.Editor.updateBlock` using the correct UUID.
4. Re-run verification to confirm all references now resolve.

**Root cause prevention:** NEVER use a UUID in a `(((uuid)))` reference unless you have confirmed it exists by:
- Reading it from the return value of `insertBlock` or `appendBlockInPage` (the API returns the created block with its UUID), OR
- Looking it up in the `getPageBlocksTree` result after all entries are written.

Do NOT guess, remember from earlier in the conversation, or construct UUIDs. The correct workflow for TODO grounding:
1. Write ALL activity entries first (steps 8).
2. Re-read page tree to get the actual UUIDs of all written blocks.
3. THEN write TODO grounding sub-blocks using UUIDs from that fresh read.

**FORMAT VALIDATION (MANDATORY before writing any grounding sub-block):**
The ONLY valid grounding format is: `Because [narrative phrase](((36-char-uuid)))`
- ✅ CORRECT: `Because [Chris demanded a business case](((6a2ceb57-6155-4b00-b529-b385e835eb21)))`
- ❌ WRONG: `Because [Chris demanded a business case]([[Christopher Kiffe]] called it a failure)`
- ❌ WRONG: `Because [works.create issue](works.create only accepts team ID)`
- ❌ WRONG: `Because [phrase](any text that is not a (((uuid))))`

Before calling `insertBlock` with a grounding sub-block, validate that the content matches `r'\[.+\]\(\(\([0-9a-f-]{36}\)\)\)'`. If it doesn't, STOP — you have a bug. Go back and get the real UUID from the page tree.

### Attribution audit (step 13a)

After all writing is done, verify the invariant: every leaf activity/content block on the page is *either* automated (has a fingerprint / `⚡` / `[📄]` / `[🦀]`) *or* human-authored (`#manual-entry`). A block that is NEITHER is a skill error — an automated write whose marker was dropped or malformed. It must NOT be silently treated as manual.

**Procedure:**

1. Re-read the page tree with `getPageBlocksTree`.
2. Walk leaf activity/content blocks. Skip page-property blocks (`last_journaled::` etc.) and pure section headings (`## ...`).
3. For each block, classify:
   - `automated` if `extract_fingerprint(content)` is non-None OR content contains `⚡`, `[📄]`, or `[🦀]`.
   - `manual` if content contains `#manual-entry`.
   - else → `UNATTRIBUTED` (error).

```python
import re
unattributed = []
def walk(blocks):
    for b in blocks:
        c = b.get('content','')
        first = c.split(chr(10))[0]
        is_heading = first.strip().startswith('##')
        is_prop = '::' in first and not first.strip().startswith('-')
        is_leaf_activity = not is_heading and not is_prop and first.strip() != ''
        if is_leaf_activity:
            automated = (extract_fingerprint(c) is not None) or any(m in c for m in ['⚡','[📄]','[🦀]'])
            manual = '#manual-entry' in c
            if not automated and not manual:
                unattributed.append((b.get('uuid',''), first[:90]))
        for ch in b.get('children', []):
            walk([ch])
walk(data)
if unattributed:
    print(f'UNATTRIBUTED: {len(unattributed)} blocks — likely skill errors (lost markers)')
    for u, f in unattributed:
        print(f'  {u} | {f}')
else:
    print('ATTRIBUTION CLEAN')
```

**If any block is UNATTRIBUTED:** do NOT auto-tag it `#manual-entry`. Surface it to the user — show the uuid and first line, explain it is an automated entry that lost its marker (or an entry added mid-run), and ask whether to fix the marker or tag it manual. The first-pass tagging in step 3 guarantees genuine human entries were already tagged before any writing began, so a leftover unattributed block is, by elimination, a marker bug — except for a human entry added DURING the run, which is fine to surface for review rather than fail on.

### Correlation and lumping (BEFORE writing)

After gathering all data, **correlate and lump before writing anything.** One real-world activity = one journal entry with sub-blocks, regardless of how many sources or sessions it spans.

**Principle:** Lump by INTENT — not by tool, not by project path, not by source. Ask: "what was Shlomi trying to accomplish?" That's the entry. Everything that served that goal is a sub-block.

**Intent > tool.** Multiple tools/sessions serving the same goal = one entry. Examples:
- Setting up a dev environment → iTerm2 + Zsh + FZF + Vivaldi are sub-blocks of ONE entry
- Shipping a feature → design meeting + code sessions + deploy + Slack announcement = ONE entry
- Investigating a bug → logs check + code read + fix + test = ONE entry

**Different intents in the same path ≠ same entry.** If the same project folder has unrelated tasks (e.g., a utility install, a PR link feature, and a plugin setup), those are separate intents. Don't lump just because they share a directory.

**How to lump:**

1. **Build a timeline.** Lay out all gathered data points chronologically (from all sources mixed together).
2. **Identify intents.** For each data point, ask: "what goal was this serving?" Look at the user's messages — they reveal intent:
   - "set up my iterm2 to dark mode" + "fix Option key" + "iterm2 crashes" → intent: get iTerm2 working
   - "can you install FZF" + "devrev-cli install" + "powerlevel10k" → intent: get shell tooling working
   - If both intents are part of a LARGER intent, lump under the parent goal
   - "prereqs rebuild" + "code review" + "deploy to sda-dev-shlomi" → intent: ship MongoDB prereqs
   - "ffmpeg install" → intent: quick utility install (standalone)
   - "Asked Amar for Markpad" → intent: get annotation tool (standalone)
3. **Nest intents when they share a parent goal:**
   - If the day has a clear theme (setup day, delivery day, debug day), many items share that parent intent
   - Standup + code + deploy + follow-up about the same feature = one intent
   - BUT: a Slack message about a completely different topic during focused work is its own intent — don't absorb it
4. **Structure as parent + sub-blocks:**
   ```
   HH:MM — Intent-level outcome summary [primary source links]
     HH:MM — First step/detail [📄](...) [🦀](...)
     HH:MM — Second step from another source ⚡ [Slack](permalink)
     HH:MM — Third step/resolution [📄](...) [🦀](...)
   ```
   - **Parent block:** First timestamp of the cluster. Describes the INTENT/GOAL achieved. Links from the primary source.
   - **Sub-blocks:** Each step/interaction, timestamped, with its own source links. Chronological order.
   - All links preserved. Nothing lost. Reads as one coherent narrative.

5. **Intent signals to look for:**
   - The user's actual words ("set up", "fix", "install", "build", "deploy", "investigate")
   - Time of day context (morning = setup, afternoon = project work)
   - Day context (setup day = config work shares an intent, delivery day = build/deploy work shares an intent)
   - Conversation flow (DM asking for something → Claude session doing it → Slack confirming = one intent)

**What NOT to merge:**
- Genuinely independent activities that happen to share a timeframe
- Different topics even if same tool (iTerm2 dark mode vs. iTerm2 crash investigation could be separate if they feel like distinct efforts — use judgment)
- A quick one-off interaction that's unrelated to the surrounding work

**Example — raw data points (9 items):**
```
- Claude Code 09:30: Updated API endpoint in service
- Claude Code 09:45: Added error handling
- Claude Code 10:15: Wrote tests for new endpoint
- Meeting 10:30: Sprint standup
- Slack 10:45: "deployed to staging" in #team channel
- Claude Code 11:00: Fixed failing test
- Claude Code 11:30: Deployed to production
- Slack 14:00: Answered question in #support about unrelated bug
- DM 14:30: Amar asked about Q3 planning doc
```

**Intent analysis:**
- Items 1-3, 6-7: ONE intent → "ship the API endpoint" (code + test + deploy)
- Item 4: part of the same day but standalone — sprint standup covers multiple topics
- Item 5: relates to intent 1 — the deploy announcement
- Item 8: standalone — different topic entirely
- Item 9: standalone — different topic

**After lumping → entries to write:**
```
## [[sda-solution]] #product
  09:30 — Shipped new API endpoint: code, tests, staging, production [📄](...) [🦀](...)
    09:30 — Updated API endpoint in service [📄](...) [🦀](...)
    09:45 — Added error handling [📄](...) [🦀](...)
    10:15 — Wrote tests [📄](...) [🦀](...)
    10:45 — Deployed to staging ⚡ [Slack](permalink)
    11:00 — Fixed failing test [📄](...) [🦀](...)
    11:30 — Deployed to production [📄](...) [🦀](...)

## [[DevRev]] #product
  10:30 — Sprint standup #meeting ⚡ [notes](granola://...)

## [[DevRev]] #product
  14:00 — Answered support question about auth bug ⚡ [Slack](permalink)

## [[DevRev]] #product
  14:30 — Q3 planning doc discussion with Amar ⚡ [DM](url)
```

9 raw data points → 4 entries. The 7-item coding flow is ONE intent. The standup, support question, and planning chat are each independent intents.

### Date determination (MANDATORY FIRST STEP — BEFORE ANYTHING ELSE)

**Step 1: Run `date` to get the current year and today's date.**

```bash
date '+%Y-%m-%d %A %Z'
```

**Step 2: Determine target date.**

- If ARGUMENTS include `date=YYYY-MM-DD` → check: does the year match the system year from step 1? 
  - If YES → use the argument as-is.
  - If NO → **the outer agent probably guessed the wrong year.** Replace the year with the system year. Example: argument says `2025-06-08` but system says 2026 → target is `2026-06-08`.
  - Exception: only keep a non-matching year if the user's ORIGINAL message explicitly typed that year (e.g., "journal June 8, 2025"). Since you can't see the original message, default to using the system year.
- If ARGUMENTS include `day=Wednesday` → use that for the page name. Do not argue.
- If user gave month+day without year (e.g., "June 8", "Jun 8th") → **append the year from step 1**.
- If user said "today" or gave no date → use today from step 1.
- If user said "yesterday" → `date -v-1d '+%Y-%m-%d %A'`

**The system year from `date` wins over any argument year that doesn't match, because the outer agent is known to guess the wrong year.**

### Timezone conversion (CRITICAL for non-Claude sources)

Claude Code `.jsonl` files embed UTC offsets in timestamps — `dt.astimezone()` handles them correctly.

**Granola, Slack, DevRev DMs, and DevRev issues return UTC timestamps.** These MUST be converted to the user's local timezone before extracting the `HH:MM` for journal entries. The local timezone is the system timezone (what `date +%Z` returns).

```python
from datetime import datetime

def utc_to_local(utc_string):
    """Convert a UTC timestamp string to local time.
    Handles: '2026-06-10T19:22:27Z', '2026-06-10 19:22:27 UTC', epoch floats.
    """
    if isinstance(utc_string, (int, float)):
        # Epoch seconds (Slack message_ts)
        dt = datetime.fromtimestamp(float(utc_string))
        return dt
    # ISO format
    dt = datetime.fromisoformat(utc_string.replace('Z', '+00:00'))
    return dt.astimezone()  # converts to system local timezone
```

**Source-specific gotchas:**

| Source | Timestamp format | Conversion |
|---|---|---|
| Claude Code `.jsonl` | ISO 8601 with offset | `dt.astimezone()` — already has offset |
| Slack `message_ts` | Unix epoch float (e.g., `1781140947.608879`) | `datetime.fromtimestamp(float(ts))` — auto-local |
| Slack `Time:` field | `2026-06-10 20:22:27 CDT` | Already local — parse directly |
| Granola meeting `date` | `Jun 10, 2026 5:53 PM CDT` | Already local — parse directly |
| DevRev DMs (FetchObjectContext) | `[2026-06-10T19:22:27Z]` | UTC → `astimezone()` to local |
| DevRev SQL `modified_date` | `TIMESTAMPTZ` in UTC | UTC → `astimezone()` to local |

**Key rule:** If a timestamp ends in `Z` or has no offset, treat as UTC and convert. If it already says CDT/CST/EDT/etc, it's already local — use as-is. If it's a Unix epoch, `datetime.fromtimestamp()` gives local time directly.

## Operations

### Writing to journal day page

Use `appendBlockInPage` for top-level headings, `insertBlock` for children:

```bash
# Top-level section heading
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.appendBlockInPage", "args": ["Jun 11th, 2026", "## [[Customer/MongoDB]] #product"]}'

# Entry under a section (need parent UUID from above)
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.insertBlock", "args": ["<parent-uuid>", "15:33 — Rebuilt prereqs workflow [📄](...) [🦀](...)", {"sibling": false}]}'
```

### Reading the current page state

```bash
curl -s -X POST "$LOGSEQ_API_URL/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"method": "logseq.Editor.getPageBlocksTree", "args": ["Jun 11th, 2026"]}'
```

## Important Notes

- **Write to journal day page ONLY.** Entity page routing is the indexer's job.
- Never overwrite existing entries. Always append.
- Always read the page first to avoid duplicates.
- Timestamp accuracy is critical — use source timestamps, convert UTC to local timezone (see Timezone Conversion section).
- Keep entries concise — this is a log, not prose.
- Focus on outcomes not process.
- After completion, tell the user to run `logseq-graph-index-v3` for entity routing and claims.
