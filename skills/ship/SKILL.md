---
name: ship
description: Takes work all the way to a merged PR and a closed issue — either a freshly approved plan (Claude Code plan mode) or an existing tracked issue the user is resuming — creating the GitHub issue if needed, cutting the branch, implementing, opening a linked PR, and merging it with confirmation, moving the card across the Kanban board (Backlog/Todo → In Progress → In Review → Done) with its Priority field set. Fires automatically whenever a feature/fix/chore plan is approved (ExitPlanMode) in a registered project, or whenever the user asks to start/resume work on an issue already tracked on a registered project's board — no command needed.
---

# ship — from approved plan (or existing issue) to merged PR

Part of [idea-skill](https://github.com/NatanNarciso/idea-skill): the
`/idea` skill turns a loose thought into a tagged issue sitting in
`Backlog`, waiting to be picked up later. This skill is the other half —
it covers work that's about to happen **right now**, whether that's a
brand-new plan or an issue that's already sitting on the board: branch →
implementation → PR → merge → issue closed, driven by the same registry,
labels, and board as `/idea`, with zero manual GitHub clicking.

Everything below is `gh cli` plus normal `git`, sequenced — no extra
infrastructure.

## When this fires

Automatically, without the user typing a command, whenever **either** of
these holds (this is what decides Path A vs. Path B below):

- **Path A — new work**: you presented a plan through plan mode and the
  user approved it (`ExitPlanMode` accepted), and it's real code work
  (feature, fix, chore) — not an exploratory answer or a
  discussion-only architecture decision.
- **Path B — resuming tracked work**: the user asks to start/continue/pick
  up work on an issue that's already on a registered project's board
  (they name an issue number or URL, or point at something sitting in
  `Backlog`/`Todo`) — even without going through plan mode first.

Both paths require the current working directory to match a `local_path`
(or the user to have named the project) in the registry — default
`~/.claude/idea-projects.json`, or wherever the user's own instructions
point instead.

If the project isn't in the registry, **don't** create an issue, branch,
or PR on your own — tell the user the project isn't registered and ask
whether to proceed with a plain implementation (no GitHub flow) or
register the project first (see the main README's Quickstart).

## 1. Resolve the project

Read the registry fresh every time (don't trust a cached copy from an
earlier session — it grows). Same resolution logic as `/idea`: match by
`local_path` against the cwd, by name/alias the user mentioned, or ask if
there's any ambiguity (e.g. a split frontend/backend pair sharing a
product name).

## 2. Which path applies

- If the work has no existing issue yet (a plan just got approved for
  something new) → **Path A**, go to step 3.
- If the work is already tracked — the user referenced an issue
  number/URL, or you're picking something off the board yourself → **Path
  B**, skip straight to step 4 (don't create a duplicate issue).

## 3. Path A — create the issue (as soon as the plan is approved, before implementing)

Title and body come from the approved plan itself (a short, clean title;
the body can be close to the plan verbatim, including the list of
changes).

Type and priority: same heuristic as `/idea` (`type:bug` / `type:feature`
/ `type:chore`; `priority:P0`–`P3`, default `feature` / `P2`). Only ask if
genuinely ambiguous.

```bash
gh issue create --repo <github_owner>/<github_repo> \
  --title "<title>" \
  --body "<plan body>" \
  --label "type:<type>" \
  --label "priority:<PN>"
```

Keep the issue number (`<N>`) and the returned URL, then continue to step
5 (add to the board).

## 4. Path B — resolve the existing issue

The issue already exists — find its project item instead of creating a
new one:

```bash
gh project item-list <project_number> --owner <github_owner> --format json \
  | jq -r --arg url "<issue_url>" '.items[] | select(.content.url == $url)'
```

If the user only gave an issue number, resolve the URL first with
`gh issue view <N> --repo <github_owner>/<github_repo> --json url -q .url`.
Keep the issue number, title, and URL — same as Path A — then continue to
step 5.

## 5. Add to the board and move to "In Progress"

**Path A** (item doesn't exist on the board yet):

```bash
gh project item-add <project_number> --owner <github_owner> --url <issue_url>
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "In Progress"
```

(Skips `Backlog`/`Todo` — the work starts immediately.)

**Path B** (item is already on the board, just not `In Progress` yet):

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "In Progress"
```

**Both paths** — also set the `Priority` field (P0→Urgente, P1→Alta,
P2→Média, P3→Baixa) if it isn't set yet:

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Priority" --value "<Urgente|Alta|Média|Baixa>"
```

Skip the Priority step silently if the board predates that field
(`gh project field-list` won't show it).

## 6. Cut the branch

Before switching branches, run `git status` — if there are uncommitted
changes from something else, flag it to the user instead of discarding or
mixing them in.

```bash
git fetch origin
git checkout <default_branch>
git pull
git checkout -b <type>/<N>-<slug>
```

`<type>` is `feat`/`fix`/`chore` (same mapping as the issue's `type:*`
label). `<slug>` is the issue title in kebab-case, kept short (~40 chars).
E.g. `feat/42-batch-sending` — this is the exact convention the
`CONTRIBUTING.md` template (`setup/templates/CONTRIBUTING.md.tmpl`) in
this repo already documents; keep the two in sync if you change one. The
branch stays local for now — no push yet.

Tell the user in one line that the issue and branch are ready, then start
implementing the plan on that branch, with normal incremental commits.

## 7. Implementation done — ask before opening the PR

When the implementation is finished, **stop and explicitly ask** whether
it's approved to become a PR (e.g. "Implementation's ready — want me to
open the PR?"). Don't skip this confirmation: pushing a branch and opening
a PR is a visible, shared-state action.

Once approved:

```bash
git push -u origin <type>/<N>-<slug>
gh pr create --repo <github_owner>/<github_repo> \
  --base <default_branch> --head <type>/<N>-<slug> \
  --title "<title>" \
  --body "<implementation summary>

Closes #<N>"
```

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "In Review"
```

## 8. Merge — ask for confirmation, then merge

Show the PR link and ask whether it's OK to merge. Once confirmed:

```bash
gh pr merge <pr_number_or_url> --squash --delete-branch
```

The `Closes #<N>` in the PR body closes the issue automatically on merge.
Since the board has no automation configured, move the card by hand too:

```bash
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "Done"
```

Reply with a short summary: merged PR link, issue closed, and that the
local branch can be deleted (`git branch -d <type>/<N>-<slug>` after
switching back to `<default_branch>` and pulling).

## Common issues

- **Project not in the registry**: don't guess owner/repo/project_number —
  stop and ask (same rule as `/idea`).
- **`gh` missing the `project` scope**: point the user at
  `gh auth refresh -h github.com -s project`.
- **Uncommitted changes when switching branches**: never discard them —
  flag it and ask (stash, commit separately, or let the user handle it).
- **PR merge blocked** (branch protection, pending checks): don't force
  it — tell the user what's blocking and wait.
- **User doesn't explicitly confirm the PR or the merge**: never skip
  either confirmation, even in a more autonomous mode — both touch shared
  state (a public push, a public PR, a merge into the default branch).
- **Path B, multiple issues at once**: if several existing issues are
  being picked up together (tightly coupled changes touching the same
  files), it's fine to move all their cards to "In Progress", use one
  branch/PR, and reference all of them (`Closes #1, Closes #2, ...`) — just
  say so to the user instead of silently picking one.
