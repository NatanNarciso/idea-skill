---
name: ship
description: Takes an approved plan (Claude Code plan mode) all the way to a merged PR and a closed issue — creates the GitHub issue, cuts the branch, implements, opens a linked PR, and merges it with confirmation, moving the card across the Kanban board (Backlog → In Progress → In Review → Done). Fires automatically whenever a feature/fix/chore plan is approved (ExitPlanMode) in a registered project — no command needed.
---

# ship — from approved plan to merged PR

Part of [idea-skill](https://github.com/NatanNarciso/idea-skill): the
`/idea` skill turns a loose thought into a tagged issue sitting in
`Backlog`, waiting to be picked up later. This skill is the other half —
it covers plans that are about to be worked on **right now**: issue →
branch → implementation → PR → merge → issue closed, driven by the same
registry, labels, and board as `/idea`, with zero manual GitHub clicking.

Everything below is `gh cli` plus normal `git`, sequenced — no extra
infrastructure.

## When this fires

Automatically, without the user typing anything, when **all** of these
hold:

- You presented a plan through plan mode and the user approved it
  (`ExitPlanMode` accepted).
- The plan is real code work (feature, fix, chore) in a project — not an
  exploratory answer, not an architecture decision meant purely for
  discussion.
- The current working directory matches a `local_path` (or the user named
  the project) in the registry — default `~/.claude/idea-projects.json`,
  or wherever the user's own instructions point instead.

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

## 2. Create the issue (as soon as the plan is approved, before implementing)

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

Keep the issue number (`<N>`) and the returned URL.

## 3. Add to the board and move straight to "In Progress"

```bash
gh project item-add <project_number> --owner <github_owner> --url <issue_url>
gh project item-edit <project_number> --owner <github_owner> \
  --url <issue_url> --field "Status" --value "In Progress"
```

(Skips `Backlog`/`Todo` — the work starts immediately.)

## 4. Cut the branch

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

## 5. Implementation done — ask before opening the PR

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

## 6. Merge — ask for confirmation, then merge

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
