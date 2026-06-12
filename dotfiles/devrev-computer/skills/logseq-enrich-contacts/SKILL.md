---
name: logseq-enrich-contacts
description: >
  Enrich customer people pages in the Logseq knowledge graph with role, expertise, and
  "reach for" context. Pulls from DevRev contact data + graph activity history to write
  short, actionable identity descriptions that show on hover.
trigger: >
  Activate when the user asks to enrich contacts, update people descriptions, refresh contact
  context, or fill in person page details. Trigger phrases include: enrich contacts, update
  contacts, who are these people, fill in people pages, refresh contact info, enrich people,
  update identities, contact enrichment.
  Also activated automatically by logseq-graph-index-v3 during Phase 2 when new person pages
  are materialized.
  Do NOT activate for: creating new person pages (that's the indexer), looking up a single
  contact (just answer directly).
---

# Logseq Enrich Contacts

Enrich `Customer/*/People/*` pages with actionable identity descriptions. The `identity::` property shows on hover in Logseq — it should answer: "Who is this? What's their role? Why would I reach them?"

## Connection

```bash
LOGSEQ_TOKEN=$(security find-generic-password -s "devrev-pat" -a "logseq-kg" -w)
LOGSEQ_API_URL="http://localhost:12315"
```

## When to run

1. **Standalone** — user asks to enrich contacts for a specific customer or all customers.
2. **From indexer** — called during Phase 2 when new person pages are created or when existing person pages gain new activity context.
3. **Periodic refresh** — when the user asks to update stale contact descriptions.

## Target pages

Query all person pages under `Customer/*/People/*`:

```
[:find (pull ?p [:block/name :block/uuid])
 :where
 [?p :block/name ?n]
 [(clojure.string/includes? ?n "/people/")]
 [?p :block/journal? false]]
```

If the user specifies a customer (e.g., "enrich contacts MongoDB"), filter to only that customer's people pages.

## Enrichment process

For each target person page:

### 1. Read current state

```python
tree = call_api("logseq.Editor.getPageBlocksTree", [page_name])
first_block = tree[0]
current_content = first_block['content']
current_uuid = first_block['uuid']
```

### 2. Determine if enrichment is needed

**Always enrich when:**
- `identity::` is missing or empty
- `identity::` contains only generic text: "Engineering contact at", "Contact at", "TBD"
- New activity exists on the person's page since the last enrichment (new entries under `## Activity`)
- The user explicitly asked to refresh

**Enrichment is additive, not replacement.** If the existing identity is already rich but new information emerged (new meetings, new activity blocks mentioning this person, new role info from DevRev), UPDATE it to incorporate the new context. Don't throw away good existing descriptions — merge new info in.

**Signal that existing identity needs update:**
- New activity entries reference this person in a new capacity (e.g., they were in a security discussion but identity only mentions "engineering")
- DevRev contact data has fields (job_title, department, description) that aren't reflected in the current identity
- Graph activity shows them doing things their identity doesn't mention

### 3. Gather context from multiple sources

#### Source A: DevRev contact data

Search for the person in DevRev:
```
HybridSearch(query="<Full Name> <Customer>", namespace="rev_user")
```

Then `FetchObjectContext` on the matched ID. Extract:
- `tnt__job_title` — their actual title
- `tnt__department` — their team/dept
- `tnt__job_level` — seniority (Director, Manager, Senior IC, etc.)
- `description` — LinkedIn-style bio (if present)
- `tnt__city`, `tnt__state` — location (include if relevant for in-person meetings)
- `tnt__linkedin_profile` — save for reference

#### Source B: Graph activity context

Search for blocks mentioning this person across the graph:
```
[:find (pull ?b [:block/content :block/page])
 :where
 [?b :block/content ?c]
 [(clojure.string/includes? ?c "<person_keyword>")]]
```

From activity blocks, infer:
- What topics/projects they appear in
- What role they play in those interactions (decision maker? implementer? reviewer? blocker?)
- What they've committed to or been asked about

#### Source C: Meeting context

If the person appears in meeting `participants::` properties, check what those meetings were about. This reveals their involvement pattern.

### 4. Compose the identity

**Format:**
```
identity:: <Title> at <Company> [(<Location>)]. <Expertise/focus in 1 sentence>. Reach for: <3-5 specific reasons you'd contact them>.
```

**Rules:**
- Keep it under 200 characters ideally, 300 max.
- Lead with title if known, otherwise role description.
- "Reach for:" is the most valuable part — be specific and actionable.
- Use context from activity to make "Reach for" real, not generic.
- Include location only if relevant (e.g., for in-person meeting planning).
- If insufficient context exists for confident "Reach for:", write what you know and add "TBD" for unknown aspects. Don't fabricate expertise.

**Good examples:**
```
identity:: Staff AI Product Manager at MongoDB (SF). Ex-Tesla automation lead. Reach for: AI use cases, product requirements, exec demo feedback.
identity:: Security team lead at MongoDB. Controls admin access and security waivers. Reach for: access approvals, security policy exceptions, environment permissions.
identity:: Senior IT Support Specialist at MongoDB. MacOS/Windows admin, mentors team. Reach for: laptop provisioning, device access, IT support escalations.
```

**Bad examples:**
```
identity:: Engineering contact at MongoDB    # Too generic — says nothing useful
identity:: Person who works at MongoDB       # Useless
identity:: Jonathan is a great guy           # Not actionable
```

### 5. Write the update

```python
# Preserve all other properties (alias::, team::, works_on::, etc.)
# Only update/add the identity:: line
lines = current_content.split('\n')
new_lines = []
identity_written = False
for line in lines:
    if line.startswith('identity::'):
        new_lines.append(f'identity:: {new_identity}')
        identity_written = True
    else:
        new_lines.append(line)
if not identity_written:
    # Insert after type:: line
    for i, line in enumerate(new_lines):
        if line.startswith('type::'):
            new_lines.insert(i + 1, f'identity:: {new_identity}')
            break

new_content = '\n'.join(new_lines)
call_api("logseq.Editor.updateBlock", [current_uuid, new_content])
```

**CRITICAL: Preserve all existing properties.** Read the full first-block content, update only the `identity::` line, and write back the complete block. Never clobber `alias::`, `team::`, `works_on::`, or other properties.

## Batch execution

When running across all contacts for a customer:

1. Collect all target pages.
2. For each, read current state (batch reads are cheap).
3. Group DevRev lookups — if multiple people share an account, one HybridSearch for the account's contacts can seed multiple pages.
4. Write updates with 150ms delays between mutations.

## Integration with logseq-graph-index-v3

When called from the indexer's Phase 2:

- Receives a list of person page names that were just created or have new activity.
- Runs enrichment only on those pages (not the full customer roster).
- Returns quickly — don't block the indexer with slow lookups for pages that already have good identities.

**Indexer integration point:** After Phase 2 materializes person pages, check each new/updated person page. If `identity::` is generic or missing, run enrichment. If `identity::` is already rich and no new activity context exists, skip.

## Standalone invocation

When the user says "enrich contacts MongoDB":

1. Find all `Customer/MongoDB/People/*` pages.
2. Read each page's current `identity::`.
3. For pages needing enrichment (generic, stale, or new info available), run the full process.
4. Report: "Enriched X contacts, skipped Y (already rich)."

When the user says "enrich contacts" (no customer specified):

1. Find ALL `Customer/*/People/*` pages.
2. Same process, grouped by customer for efficient DevRev lookups.

## Output

After enrichment, report concisely:

```
Enriched 8 contacts for MongoDB:
  Christopher Kiffe — Engineering Manager, technical buy-in
  Dex — Mana integration lead, API decisions
  Gavin Linkens — Sr IT Support, device provisioning
  ...
Skipped 2 (already rich, no new context):
  Chris — security approvals (unchanged)
  Maxime Levintoff — AI PM (unchanged)
```
