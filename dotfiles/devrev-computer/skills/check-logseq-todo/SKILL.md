---
name: check-logseq-todo
description: >
  MANDATORY skill for ANY question about the user's personal todos, tasks, action items, or what's due.
  This is the ONLY way to get accurate todo information - never answer from memory or prior conversations.
  Activate when the user asks about their todos, upcoming tasks, overdue items, what's due,
  what's on their plate, pending actions, scheduled items, or anything related to their task list.
  Also activate for: "show my todos", "pending todos", "what needs to happen", "my action items",
  "tasks this week", "anything overdue", "what's coming up", "do I have anything due".
  This skill MUST execute bash commands against the Logseq API - never skip execution.
  DISAMBIGUATION: If the user says "next steps" or "action items" in the context of a specific deal/opportunity,
  use nextstepforopportunity instead. But if it's personal todos, "my tasks", "what's due", or general — use THIS skill.
trigger_phrases:
  - check my todos
  - logseq todos
  - what's due
  - overdue tasks
  - upcoming tasks
  - what do I need to do
  - what's on my plate
  - scheduled tasks
  - check logseq
  - open todos
  - pending todos
  - show my todos
  - my action items
  - tasks this week
  - what needs to happen
  - anything overdue
  - what's coming up
  - do I have anything due
  - todo
  - todos
---

# Check Logseq TODOs

Query Logseq's Datascript database for open tasks that are scheduled soon or overdue.

⚠️ **YOU MUST EXECUTE THE BASH COMMANDS BELOW.** Never answer from memory, prior conversations, or cached results. The source of truth is always a live query against Logseq's API. If the API is unreachable, tell the user — don't fall back to stale data.

## Execution

1. Determine the date window: today and 3 days ahead (configurable if user specifies).
2. Retrieve the Logseq API token from Keychain.
3. Run TWO native Datalog queries against `logseq.DB.datascriptQuery`:
   - **Scheduled items** (`:block/scheduled`) up to the end of the window.
   - **Deadline items** (`:block/deadline`) up to the end of the window.
4. Merge and deduplicate results.
5. Categorize into **overdue** (before today) and **upcoming** (today through end of window).
6. Present a clean summary grouped by date.

## Datalog queries

### Scheduled items (open, within window)

```clojure
[:find (pull ?b [:block/uuid :block/marker :block/content :block/scheduled :block/deadline])
 :in $ ?end-date
 :where
 [?b :block/marker ?m]
 [(contains? #{"TODO" "DOING" "NOW" "LATER" "WAITING"} ?m)]
 [?b :block/scheduled ?d]
 [(<= ?d ?end-date)]]
```

### Deadline items (open, within window)

```clojure
[:find (pull ?b [:block/uuid :block/marker :block/content :block/scheduled :block/deadline])
 :in $ ?end-date
 :where
 [?b :block/marker ?m]
 [(contains? #{"TODO" "DOING" "NOW" "LATER" "WAITING"} ?m)]
 [?b :block/deadline ?d]
 [(<= ?d ?end-date)]]
```

### Child blocks (context for each todo)

After fetching todos, run a second query to get child block content for context:

```clojure
[:find (pull ?child [:block/content])
 :in $ ?end-date
 :where
 [?b :block/marker ?m]
 [(contains? #{"TODO" "DOING" "NOW" "LATER" "WAITING"} ?m)]
 [?b :block/scheduled ?d]
 [(<= ?d ?end-date)]
 [?child :block/parent ?b]]
```

Use the first child block's content as the contextual summary for each todo.

## API details

- **Endpoint**: `http://localhost:12315/api`
- **Method**: POST with JSON body `{"method": "logseq.DB.datascriptQuery", "args": [<query>, <end-date>]}`
- **Token**: `security find-generic-password -s "devrev-pat" -a "logseq-kg" -w`
- **Date format**: Integer YYYYMMDD (e.g., 20260613)

## Reference bash implementation

Use this as the execution template. Adjust END_DATE based on today + 3 days:

```bash
TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w 2>/dev/null) && \
END_DATE=YYYYMMDD && \
TODAY=YYYYMMDD && \
curl -s -X POST http://localhost:12315/api -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{
  \"method\": \"logseq.DB.datascriptQuery\",
  \"args\": [
    \"[:find (pull ?b [:block/uuid :block/marker :block/content :block/scheduled :block/deadline]) :in \$ ?end-date :where [?b :block/marker ?m] [(contains? #{\\\"TODO\\\" \\\"DOING\\\" \\\"NOW\\\" \\\"LATER\\\" \\\"WAITING\\\"} ?m)] [?b :block/scheduled ?d] [(<= ?d ?end-date)]]\",
    $END_DATE
  ]
}" > /tmp/logseq_todos.json && \
curl -s -X POST http://localhost:12315/api -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{
  \"method\": \"logseq.DB.datascriptQuery\",
  \"args\": [
    \"[:find ?puuid (pull ?child [:block/content]) :in \$ ?end-date :where [?b :block/marker ?m] [(contains? #{\\\"TODO\\\" \\\"DOING\\\" \\\"NOW\\\" \\\"LATER\\\" \\\"WAITING\\\"} ?m)] [?b :block/scheduled ?d] [(<= ?d ?end-date)] [?b :block/uuid ?puuid] [?child :block/parent ?b]]\",
    $END_DATE
  ]
}" > /tmp/logseq_children.json && \
curl -s -X POST http://localhost:12315/api -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{
  \"method\": \"logseq.DB.datascriptQuery\",
  \"args\": [
    \"[:find (pull ?b [:block/uuid :block/marker :block/content :block/scheduled :block/deadline]) :in \$ ?end-date :where [?b :block/marker ?m] [(contains? #{\\\"TODO\\\" \\\"DOING\\\" \\\"NOW\\\" \\\"LATER\\\" \\\"WAITING\\\"} ?m)] [?b :block/deadline ?d] [(<= ?d ?end-date)]]\",
    $END_DATE
  ]
}" > /tmp/logseq_deadlines.json
```

Then process with Python to:
1. Merge scheduled + deadline items, dedupe by uuid
2. Build children map (uuid → content list) from logseq_children.json
3. Categorize by date relative to TODAY
4. Format per the example output above

## Deep links

Each item MUST include a clickable deep link to jump into Logseq.

The chat UI only renders http/https links as clickable. A local redirect server on port 12316 bridges to `logseq://` URIs.

- **Base URL**: `http://localhost:12316`
- **Format**: `http://localhost:12316/graph/shlomi-kg?block-id=<uuid>`
- The path mirrors the `logseq://` scheme exactly, so switching to native deep links later is a base-URL swap.

Render the task content itself as the link text (not "open" or "open in Logseq"):
`[Task description here](http://localhost:12316/graph/shlomi-kg?block-id=<uuid>)`

The task description should be the first line of content, stripped of the marker prefix, `[[...]]` wrappers, and any trailing metadata (SCHEDULED lines, ⚡ markers, etc.).

### Page links

Any `[[Page/Name]]` reference in the content should be rendered as a clickable page link:
`[Page/Name](http://localhost:12316/graph/shlomi-kg?page=<url-encoded-page-name>)`

Strip the `[[` and `]]` — just use the page name as link text.

### Journal page links

The source journal page should also be a clickable link:
`[Jun 10th, 2026](http://localhost:12316/graph/shlomi-kg?page=Jun%2010th%2C%202026)`

### External links

Preserve any embedded links from the block content (Granola notes, Slack threads, etc.) as-is — they render clickable too if they use https://.

### Ensuring the server is running

Before rendering links, check if port 12316 is listening:
```bash
curl -s -o /dev/null -w "%{http_code}" "http://localhost:12316/graph/shlomi-kg?block-id=test" 2>/dev/null
```
If it returns nothing or errors, start it:
```bash
python3 /Users/shlomi/bin/logseq-link-server &>/dev/null &
```

## Presentation

- Group by: **Overdue**, **Today**, **Tomorrow**, **Later this week**.
- Each item as a bullet: `**MARKER** [task description](block-link) — **Due: Thu Jun 12 (in 2 days)**`
- The date label must include "Due:" prefix and a relative "(in N days)" or "(today)" or "(yesterday)" or "(N days overdue)" suffix.
- Sub-bullet with **context from child blocks** — this is the real value. Show the first child block's content as a brief summary of what the todo is about, why it matters, or what's needed.
- Strip `[[...]]` wrappers from the task title — show page names as plain text or links.
- Strip `⚡`, `SCHEDULED:` lines, and Granola links from the title (keep Slack/http links if useful).
- Flag overdue items with ⚠️.
- If no items found, say so clearly.
- End with a total count and a brief one-liner about what's next.

### What NOT to show
- Journal page name (it's just the date, already shown).
- Customer/project page links in a sub-bullet (already visible in the title).
- Redundant metadata. Keep it tight.

### External links — ALWAYS retain
Any https:// links from the parent block content (Slack threads, DevRev issues, etc.) MUST appear in the sub-bullet, even when child block context is shown. Append them after the child context with a ` · ` separator. These links are the user's breadcrumbs back to the source — never drop them.

## Example output (FOLLOW THIS EXACTLY)

```
## Overdue

- ⚠️ **TODO** [Some overdue task](http://localhost:12316/graph/shlomi-kg?block-id=abc123) — **Due: Mon Jun 9 (1 day overdue)**
  - Context from child block here. · [Slack thread](https://devrev.slack.com/archives/...)

## Today (Jun 10)

- **TODO** [Something due today](http://localhost:12316/graph/shlomi-kg?block-id=def456) — **Due: today**
  - Child block context explaining what this is about.

## Tomorrow (Jun 11)

Nothing scheduled.

## Jun 12-13

- **TODO** [PwC debrief sync - Thursday 10AM Austin](http://localhost:12316/graph/shlomi-kg?block-id=6a2907ae-cfe4-4325-849a-5b40724f99cd) — **Due: Thu Jun 12 (in 2 days)**
  - Same group as today's sync. Discuss findings from RFP process mapping session.

- **TODO** [Request >100 node workflow limit for SDA](http://localhost:12316/graph/shlomi-kg?block-id=6a290872-faa2-40b0-980d-00ffcd244103) — **Due: Fri Jun 13 (in 3 days)**
  - Current SDA workflow at 97 nodes, platform limit blocks abstraction. · [Slack thread](https://devrev.slack.com/archives/C042ZCY8Z8B/p1780962134163979)

---
3 open items through Jun 13. Next up is the PwC debrief Thursday morning.
```

CRITICAL RULES:
1. You MUST run the bash commands to query Logseq. Do NOT answer from memory or prior conversations.
2. The task title MUST be a markdown link: `[title](http://localhost:12316/graph/shlomi-kg?block-id=<uuid>)`
3. Strip `[[...]]` from titles — show as plain text (e.g., "Customer/PwC" not "[[Customer/PwC]]")
4. Strip marker prefix (TODO/LATER/etc.), ⚡, SCHEDULED lines, #no-issue from the link text
5. Always include `http://localhost:12316` links — NEVER use `logseq://` directly (it won't render clickable)
6. External https:// links from block content MUST be preserved in the sub-bullet

## Notes

- The user's timezone is America/Chicago. Calculate "today" accordingly.
- Default lookahead is 3 days. User can request a wider window (e.g., "this week", "next 7 days").
- Items may have both scheduled and deadline dates - show the most relevant one.
- Always get the graph name via `logseq.App.getCurrentGraph` if unsure, but default to `shlomi-kg`.
