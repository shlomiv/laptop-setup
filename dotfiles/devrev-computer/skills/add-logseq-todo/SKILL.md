---
name: add-logseq-todo
description: >
  Add one or more TODOs to Shlomi's Logseq graph, following his conventions (marker, [[page]]
  tagging, optional SCHEDULED date, grounding context). Routes each todo to the right entity
  page's ## TODOs section, or to the daily journal page when no entity fits.
  Activate when Shlomi asks to add / create / capture / jot / remind-me-of a todo, task, or
  action item IN LOGSEQ — e.g. "add a todo in logseq", "make me a logseq todo", "capture this
  as a task", "remind me to X (in logseq)", "put this on my logseq list", "note this as a todo".
  Do NOT activate for: reading/listing existing todos (use check-logseq-todo), opportunity
  next-steps (use nextstepforopportunity), or DevRev issue/ticket creation.
---

# Add Logseq TODO

Write well-formed TODO blocks into Shlomi's Logseq graph that match his existing conventions, so they show up correctly in `check-logseq-todo` and get reconciled by `logseq-graph-index-v3`.

⚠️ **YOU MUST EXECUTE THE API CALLS BELOW.** Never claim a todo was added without a successful `insertBlock` response carrying a real block UUID. If the API is unreachable, tell Shlomi — don't pretend.

## Connection

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w)
LOGSEQ_API_URL="http://localhost:12315"
```

All calls: `POST $LOGSEQ_API_URL/api` with header `Authorization: Bearer $LOGSEQ_TOKEN` and JSON body `{"method": "...", "args": [...]}`.

## Pre-flight (MANDATORY)

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w 2>/dev/null)
HEALTH=$(curl -s --max-time 3 -X POST "http://localhost:12315/api" \
  -H "Authorization: Bearer $LOGSEQ_TOKEN" -H "Content-Type: application/json" \
  -d '{"method": "logseq.App.getCurrentGraph", "args": []}')
echo "$HEALTH" | grep -q "journal" && echo ok || { echo "Logseq API unreachable. Open Logseq with the journal graph."; exit 1; }
```

## TODO format (match Shlomi's conventions exactly)

A todo block is:

```
TODO <action phrase> ([[<entity page>]]) [optional inline links]
SCHEDULED: <YYYY-MM-DD Day>
```

Rules:
- **Marker:** `TODO` (default). Use `LATER` only if Shlomi says "later / someday / deferred"; `NOW`/`DOING` only if he says he's actively on it.
- **Action phrase:** imperative, specific, outcome-oriented. Lead with the verb (Follow up, Check, Draft, Share, Fix, Ask...).
- **Entity tag `([[Page]]`):** tag the primary entity the todo belongs to — a person `[[Full Name]]`, customer `[[Customer/X]]`, product `[[sda-solution]]`, tool `[[Logseq]]`, or `[[DevRev]]`. Use the SAME page the todo will be filed under. Wikilink people and entities mentioned in the phrase too.
- **DevRev issue IDs:** render as links — `[FDE-20](https://app.devrev.ai/devrev/issue/FDE-20)` (alias IDs use `/issue/`, `ISS-`/`TKT-` use `/works/`).
- **SCHEDULED:** add only if a date is given or clearly implied. Date heuristics (user timezone America/Chicago): "today" = today, "tomorrow" = next day, "by end of week" = Friday, "next week" = next Monday, "soon" = 3 business days. Day abbrev must match the date (Mon/Tue/...). If no date and none implied, omit `SCHEDULED:` — leave it undated.
- **Grounding sub-block (optional but preferred):** add a child block giving the WHY/context: `Because <context>` or `<context>`. If it stems from a specific Logseq block, use `Because [phrase](((<verified-uuid>)))`. NEVER fabricate a `(((uuid)))` — only use one read from an API response.

## Placement — where the todo lands

1. **Explicit page:** if Shlomi names a page ("add to my MongoDB todos"), use that page's `## TODOs` section.
2. **Inferred entity:** if the todo clearly belongs to an entity (a person, customer, product, tool), file it on that entity page's `## TODOs` section. Use the `([[Page]])` tag that matches.
3. **Fallback — daily journal:** if no entity fits (a loose personal task), append to a `## TODOs` section on TODAY's journal page (`"Jun 15th, 2026"` ordinal format). Create the `## TODOs` heading on the journal page if absent. The indexer will route it later.

**Always read the target page first** (`getPageBlocksTree`) to find the existing `## TODOs` section UUID and avoid creating a duplicate heading. If the entity page exists but has no `## TODOs` section, append one. If the entity page doesn't exist, prefer the journal fallback (don't mint new entity pages from here — that's the indexer's job).

## Writing the block (real newlines required)

`SCHEDULED:` makes the block multi-line. The `\n` in a bash variable does NOT survive JSON encoding — use the Python-internal pattern:

```bash
python3 - <<'PYEOF'
import json, subprocess, os
token = os.popen('security find-generic-password -s "devrev-pat" -a "logseq-kg" -w').read().strip()
def api(method, args):
    payload = json.dumps({'method': method, 'args': args})
    r = subprocess.run(['curl','-s','-X','POST','http://localhost:12315/api',
        '-H', f'Authorization: Bearer {token}', '-H','Content-Type: application/json','-d',payload],
        capture_output=True, text=True)
    return json.loads(r.stdout) if r.stdout.strip() else None

TODOS_SECTION_UUID = "<from getPageBlocksTree>"
content = 'TODO Draft Q3 plan ([[DevRev]])\nSCHEDULED: <2026-06-19 Fri>'
res = api('logseq.Editor.insertBlock', [TODOS_SECTION_UUID, content, {'sibling': False}])
todo_uuid = res.get('uuid','') if res else ''
print('todo:', todo_uuid)
# optional grounding child
if todo_uuid:
    api('logseq.Editor.insertBlock', [todo_uuid, 'Because committed to it in the planning sync.', {'sibling': False}])
PYEOF
```

`insertBlock` returns the created block (with its `uuid`); a `null`/empty response means the write failed — surface that, don't report success.

## Idempotency

Before inserting, scan the target `## TODOs` section for an existing open `TODO` with the same intent (same action verb + same noun phrase / same `[[page]]`). If a near-duplicate exists, don't add a second — tell Shlomi it's already there (with its block link) and ask if he wants to update it instead.

## Surfacing to the user (MANDATORY)

After writing, confirm with a clickable link through the local redirect server — never a bare `logseq://` URI or raw UUID:

`[<todo action phrase>](http://localhost:12316/graph/shlomi-kg?block-id=<uuid>)`

Check the redirect server is up first; start it if not:
```bash
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:12316/graph/shlomi-kg?block-id=test" 2>/dev/null)
[ "$STATUS" = "000" -o -z "$STATUS" ] && (python3 /Users/shlomi/bin/logseq-link-server &>/dev/null &)
```

Report concisely: what was added, where (which page), the scheduled date (or "undated"), as a clickable link. For multiple todos, list each.

## Notes
- User timezone: America/Chicago. Compute "today"/relative dates accordingly.
- One block per todo. For several todos, insert each separately (≥100ms apart to avoid dropped writes).
- Don't set `closed::` or mark `DONE` here — this skill only CREATES open todos. Reconciliation/closing is the indexer's and check-logseq-todo's domain.
- Journal page name format: `"Jun 15th, 2026"` (capitalized month, ordinal day: 1st/2nd/3rd/4th..31st).
