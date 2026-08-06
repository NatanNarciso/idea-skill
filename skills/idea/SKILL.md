---
name: idea
description: Turns a loose, free-text idea into a GitHub issue with the right type/priority labels, added to the project's Kanban board in the Backlog column, with a due date set when one is mentioned. Use when the user says "/idea", "file an issue for...", "add this to the board for..." or similar.
---

# /idea — turn a loose idea into an issue on the board

Part of [idea-skill](https://github.com/NatanNarciso/idea-skill): a
lightweight dev workflow (issue templates, standard labels, a GitHub
Projects Kanban board per repo) plus this command, which lets you just
*say* an idea and have the issue + board card appear, fully tagged, no
commands to remember.

Everything below is pure `gh cli` (plus one GraphQL call) — no extra
infrastructure, no server, no API keys beyond what `gh` already uses.

## 1. Read the project registry

Default location: `~/.claude/idea-projects.json` (a JSON object, one key
per project — see the main repo's README for the exact format and how to
generate entries with `setup.sh`). If the user's own instructions
(`CLAUDE.md`, etc.) point at a different registry path, use that instead.
Always re-read the file — don't rely on a cached copy from an earlier
session, the registry grows over time.

## 2. Resolve the project

Users typically open the sentence with the project name and a colon, e.g.
`/idea billing-service: fix the retry logic on failed webhooks`. Match the
name/alias (case-insensitive) against the registry's keys and each entry's
`aliases`.

- If nothing matches, or the sentence doesn't make the target project
  clear, **ask** before creating anything — filing an issue in the wrong
  repo is worse than asking.
- If invoked from a session whose working directory matches a registry
  entry's `local_path` and the user didn't name a project, assume that one
  — but confirm in one line if there's any ambiguity.
- If a name matches more than one registry entry (e.g. a split
  frontend/backend pair sharing a product name), ask which one instead of
  guessing.

## 3. Extract: title, type, priority, due date

**Title**: a short, clean issue title (doesn't need to be a literal quote
of the user's sentence — tidy it up).

**Body**: include the user's original wording as context, plus any other
relevant detail they gave in the conversation.

**Type** (`type:bug` / `type:feature` / `type:chore`):
- "broken", "doesn't work", "crashes", "error", "bug" → `bug`
- "add", "build", "implement", "I want it to..." → `feature`
- "refactor", "bump dependency", "clean up", "reorganize" → `chore`
- No clear signal → default `feature`

**Priority** (`priority:P0` through `priority:P3`):
- "urgent", "critical", "blocking", "prod is down" → `P0`
- "important", "high priority", "asap" → `P1`
- "whenever", "low priority", "no rush" → `P3`
- No clear signal → default `P2`

**Due date** (the board's `Due date` field, format `YYYY-MM-DD`):
- Resolve relative dates ("Friday", "next week", "the 20th") against
  today's date, which is available in the session context.
- If no due date is mentioned, leave the field unset — don't invent one.

If type or priority are genuinely ambiguous on a short/vague sentence (not
just "the defaults above don't perfectly fit"), ask a quick clarifying
question before creating the issue. Otherwise, go with the defaults —
don't stall the flow with trivial questions.

## 4. Create the issue

```bash
gh issue create --repo <github_owner>/<github_repo> \
  --title "<title>" \
  --body "<body>" \
  --label "type:<type>" \
  --label "priority:<PN>"
```

Capture the returned URL (the last line of output).

## 5. Add it to the board

```bash
gh project item-add <project_number> --owner <github_owner> --url <issue_url>
```

## 6. Place it in the Backlog column

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "Backlog"
```

This is what actually makes the card show up on the board — it doesn't
rely on any GitHub-side automation being configured manually.

## 7. Set the due date, if there is one

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Due date" --date "YYYY-MM-DD"
```

Skip this step if no due date was mentioned/inferred.

## 8. Reply to the user

A short response: the issue link, the board link
(`https://github.com/users/<github_owner>/projects/<project_number>`), and
a one-line summary of what was set (project, type, priority, due date if
any). No need to narrate every technical step — just the outcome.

## Common issues

- **Project not found in the registry**: stop and tell the user — don't
  create a "loose" issue with no board card without flagging that the
  board couldn't be located.
- **`gh` missing the `project` scope**: if `gh project item-add`/`item-edit`
  fail on permissions, have the user run
  `gh auth refresh -h github.com -s project` (opens a device-code flow in
  the browser), then retry.
