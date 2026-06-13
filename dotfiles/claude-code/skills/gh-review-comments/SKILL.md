---
description: Handle GitHub PR review comments — fetch threads, reply in-thread, and resolve, all via the GraphQL API. Use when the user says "handle review comments", "address Copilot review", "reply to PR comments", "resolve review threads", or wants to triage/respond to pull-request review feedback.
argument-hint: [PR number] (optional; inferred from current branch if omitted)
allowed-tools: Bash, Read, Edit, Write
---

# GitHub PR Review Comment Handler

The user invoked this command with: $ARGUMENTS

Goal: respond to every PR review thread **in its own thread** (not a single top-level
comment) and resolve the ones that are settled, using the GitHub GraphQL API. Leave
threads that need a human decision open.

## Why GraphQL (not `gh pr comment`)

- `gh pr comment` posts ONE top-level comment — it cannot reply inside a specific
  review thread, and cannot resolve threads. Reviewers lose the per-comment context.
- Review-thread reply + resolve are **only** available via GraphQL mutations
  (`addPullRequestReviewThreadReply`, `resolveReviewThread`). REST can reply to a
  comment but cannot resolve a thread.

## Step 0: Auth + repo

1. Resolve the repo: `gh repo view --json nameWithOwner -q .nameWithOwner` (or the user
   gave `OWNER/REPO`). Resolve PR number from `$ARGUMENTS`, else
   `gh pr view --json number -q .number` for the current branch.
2. **Account check.** Private org repos often need a specific account. If a `gh api`
   call returns `Could not resolve to a Repository`, the active `gh` account lacks
   access — run `gh auth status`, then `gh auth switch --user <account-with-access>`
   and retry. (Common trap: personal account active, but the repo is under a work org.)

## Step 1: Fetch all review threads with node IDs

```bash
gh api graphql -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
        nodes{
          id isResolved isOutdated
          comments(first:1){nodes{databaseId author{login} path line originalLine body}}
        }
      }
    }
  }
}' -F owner=OWNER -F repo=REPO -F pr=NUMBER
```

The thread `id` (`PRRT_…`) is what you reply to and resolve. The first comment gives
path/line/body for triage. `isOutdated: true` means the line moved/changed since the
comment — usually already addressed.

## Step 1.5: Thematic breakdown FIRST (before touching anything)

Before replying or fixing, present the user a **thematic summary** of all comments —
grouped by theme, not listed one-by-one. Example themes: "rendering/markup (br tags,
spacing)", "typos", "PII/over-disclosure", "ambiguous dates", "scope questions". For
each theme: how many comments, and your read on whether it's worth acting on.

This does two things: shows the reviewer's real concerns at a glance, and surfaces
duplicates (automated reviewers often file the same nit many times).

Then STOP and get the user's direction on which themes to act on. Do not proceed to
replies/fixes until the user has weighed in (unless they already told you the policy).

## Reasoning before action (core principle)

**A comment is an input, not an instruction.** Never fix something just because a
comment was left. Each one gets judged on merit:

- Is it actually correct? (Reviewers — especially bots — are often wrong, stale, or
  flag intentional choices.)
- Does the fix improve the artifact, or just churn it to silence a bot?
- Does it contradict an established decision or the document's own conventions?

State your reasoning per theme. If a comment is wrong or not worth acting on, say so
and resolve as wontfix with the reason — don't cargo-cult a "fix" to clear the count.
When unsure whether something is intentional, ask rather than assume.

## Step 2: Triage each thread

Sort threads into three buckets:

1. **Fixed** — the comment's issue is genuinely addressed by a commit. Reply citing the
   commit SHA + what changed, then resolve.
2. **Wontfix / intentional** — valid comment but a deliberate decision not to change
   (e.g. "internal draft, PII kept", "this style is intentional"). Reply with the
   reason, then resolve. **Get the user's explicit call before resolving these** if the
   decision isn't already established in the conversation.
3. **Needs human** — a question or scope decision directed at a person (e.g. "should
   this be X instead?"). Reply acknowledging, **leave OPEN**. Never resolve someone
   else's open question on their behalf.

Do NOT resolve a thread you haven't actually addressed. Resolving ≠ dismissing.

## Step 3: Reply in-thread, then resolve

For each thread, build a `threadId<TAB>action<TAB>message` table, then loop:

```bash
# reply inside the thread
gh api graphql -f query='
  mutation($tid:ID!,$body:String!){
    addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$tid,body:$body}){
      comment{id}
    }
  }' -f tid="$TID" -f body="$MSG"

# resolve (only for fixed / wontfix)
gh api graphql -f query='
  mutation($tid:ID!){ resolveReviewThread(input:{threadId:$tid}){ thread{isResolved} } }' \
  -f tid="$TID"
```

Reply message guidance: one or two sentences. Cite the commit SHA for fixes
(`Fixed in <sha> — <what changed>`). For wontfix, state the reason crisply. Reference
the asker by `@handle` on human-decision threads.

Tip: put the thread table in a temp TSV and loop with `while IFS=$'\t' read -r TID ACTION MSG`.
Echo success/failure per thread so a partial failure is visible.

## Step 4: Verify + watch for the re-review loop

Re-query thread state (Step 1, just `id isResolved` + first author):

```bash
gh api graphql -f query='...' --jq '.data.repository.pullRequest.reviewThreads.nodes
  | "resolved: \([.[]|select(.isResolved)]|length)  open: \([.[]|select(.isResolved|not)]|length)",
    (.[]|select(.isResolved|not)|"  OPEN: \(.id) \(.comments.nodes[0].author.login)")'
```

**Re-review loop:** automated reviewers (Copilot) re-review after each new push and
post NEW threads. Pushing fixes → new commit → new review → new threads. Expect the
open count to include freshly-spawned bot threads. Don't chase indefinitely:
- Surface the new threads to the user and ask whether to fix or resolve-as-wontfix.
- Replying to a thread can itself re-trigger a bot pass; if you only reply (no push),
  the loop is usually quiet.

## Rules

- **Thematic breakdown first.** Always open with a grouped summary + your read, then
  wait for direction. Never dive straight into per-comment fixes.
- **Reason, don't react.** A left comment is not a mandate to change code. Judge each
  on correctness and value; resolve wrong/low-value ones as wontfix with a reason.
- **One reply per thread, in-thread.** Never substitute a single top-level summary
  comment for per-thread replies (that was the wrong approach — fix it if found).
- **Never resolve a human's open question.** Reply, leave open, name them.
- **Never resolve wontfix without the user's decision** unless already established.
- **Cite commit SHAs** in fix replies so reviewers can verify.
- **Account-switch on `Could not resolve to a Repository`** before assuming failure.
- Stale bot nits (date formats, etc.) are the user's call — present them, don't
  silently fix or silently dismiss.
