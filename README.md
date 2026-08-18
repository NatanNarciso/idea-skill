# idea-skill

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-d97757)](https://claude.com/claude-code)
[![Requires gh cli](https://img.shields.io/badge/requires-gh%20cli-181717?logo=github)](https://cli.github.com/)
[![GitHub Projects v2](https://img.shields.io/badge/board-GitHub%20Projects%20v2-2088ff)](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
[![Wiki](https://img.shields.io/badge/docs-wiki-8250df)](https://github.com/NatanNarciso/idea-skill/wiki)

**Say an idea, get a tagged GitHub issue on the right Kanban board — and
when a plan is ready to build, let it ride the same board all the way to
a merged PR.**

A pair of [Claude Code](https://claude.com/claude-code) Agent Skills + a
one-shot setup script that give every repo you own the same lightweight
project-management workflow: issue templates, standard labels, and a
GitHub Projects (v2) Kanban board with 5 columns and a due-date field —
wired together so a loose sentence becomes a fully tagged issue, and an
approved plan turns into issue → branch → PR → merge, with zero manual
clicking either way. No dashboard to babysit, no server, no API keys
beyond what `gh` already uses — it's `gh cli` calls with a natural-language
front end.

## Contents

- [Why this exists](#why-this-exists)
- [What you get, per repo](#what-you-get-per-repo)
- [Requirements](#requirements)
- [Quickstart](#quickstart)
- [How it works](#how-it-works)
- [Customizing](#customizing)
- [FAQ](#faq)
- [Wiki](https://github.com/NatanNarciso/idea-skill/wiki) — full docs, troubleshooting, config reference
- [License](#license)

```
you:  /idea billing-service: webhook retries aren't backing off, prod is noisy, priority high

Claude:
  - created NatanNarciso/billing-service#42 (type:bug, priority:P1)
  - added to the board, column: Backlog
  → https://github.com/NatanNarciso/billing-service/issues/42
  → https://github.com/users/NatanNarciso/projects/11
```

```
you:  [approves a plan Claude proposed in plan mode]

Claude:
  - created NatanNarciso/billing-service#43 (type:feature, priority:P2), board column: In Progress
  - branch feat/43-webhook-backoff created, implementing...
  ...
  - implementation ready — open the PR?
you:  yes
Claude:
  - opened PR #44 (Closes #43), board column: In Review — merge?
you:  yes
Claude:
  - merged, issue #43 closed, board column: Done
```

No dashboard, no browser tab, no "let me go open a new issue real quick."

## Why this exists

Backlog friction is the reason ideas die mid-thought: you're mid-conversation
with an AI pair programmer, a good idea comes up, and by the time you've
switched to GitHub, picked the right repo, filled the issue form, added
labels, and dragged the card to the right column, the idea — or the
momentum — is gone. `/idea` collapses that whole sequence into one sentence.

The same friction shows up on the other end of the cycle: a plan gets
approved and then someone still has to open the issue, cut the branch,
open the PR, link it, merge it, and close the issue by hand. `ship`
collapses that sequence too — it's the same board, the same labels, just
triggered by plan approval instead of a loose sentence.

## What you get, per repo

- `.github/ISSUE_TEMPLATE/` — bug report, feature request, chore
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/labels.yml` + a sync script — `type:*`, `priority:P0-P3`,
  `status:blocked`/`status:needs-review`, `size:S/M/L`
- `CONTRIBUTING.md` documenting the flow (issue → branch → PR → squash merge)
- A GitHub Projects board: **Backlog → Todo → In Progress → In Review → Done**,
  plus a **Due date** field and a **Priority** field (Urgente/Alta/Média/Baixa,
  mirroring the `priority:P0-P3` labels — group/sort the board by it to
  keep the Kanban actually ordered by urgency)
- The `/idea` command wired to that board — loose thought in, tagged
  Backlog card out, Priority field set
- The `ship` skill wired to the same board — approved plan **or an
  existing tracked issue** in, merged PR and closed issue out, moving the
  card across the board as it goes

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated
- `jq`
- A `project` scope on your `gh` token — if you don't have one yet:
  ```bash
  gh auth refresh -h github.com -s project
  ```
  (opens a device-code flow in your browser)
- [Claude Code](https://claude.com/claude-code), for the `/idea` command
  and the `ship` skill themselves (the setup script alone works without it)

## Quickstart

**1. Clone this repo once, anywhere:**

```bash
git clone https://github.com/NatanNarciso/idea-skill.git
```

**2. Set up each project you want on the workflow** (run from inside that
project's repo):

```bash
cd ~/code/billing-service
bash /path/to/idea-skill/setup/setup.sh --title "Billing Service"
```

This creates the templates, syncs the labels, creates and links the board,
rewrites the default "Status" field into the 5 columns above, adds the
`Due date` and `Priority` fields, and commits everything locally (it does
**not** push — review the diff and push when you're happy with it). At
the end it prints a ready-to-paste JSON snippet for the registry, plus a
reminder to group the board by `Priority` by hand (one GitHub UI setting
that isn't scriptable yet).

**3. Install the skills** (once, works across every repo):

```bash
mkdir -p ~/.claude/skills
cp -r /path/to/idea-skill/skills/idea ~/.claude/skills/idea
cp -r /path/to/idea-skill/skills/ship ~/.claude/skills/ship
```

`/idea` is invoked by name (or things like "file an issue for..."). `ship`
has no command — it fires on its own whenever you approve a plan (via
Claude Code's plan mode) in a registered project. Install just one of the
two if you only want one half of the workflow.

**4. Create your registry** at `~/.claude/idea-projects.json`, pasting in
the snippet `setup.sh` printed for each project:

```json
{
  "Billing Service": {
    "aliases": ["billing-service", "billing"],
    "local_path": "/home/you/code/billing-service",
    "github_owner": "your-github-username",
    "github_repo": "billing-service",
    "default_branch": "main",
    "project_number": 11
  }
}
```

**5. Use it**, from any Claude Code session:

```
/idea billing-service: webhook retries need backoff, priority high
```

And when you're ready to build something, just approve the plan Claude
proposes — `ship` picks it up from there and takes it to a merged PR,
asking for confirmation before it pushes, opens the PR, and merges.

See [`docs/TUTORIAL.md`](docs/TUTORIAL.md) for the full walkthrough with
screenshots-in-words and troubleshooting.

## How it works

Nothing here is magic — it's `gh cli` (and plain `git`) calls a human
would type, just sequenced and given a natural-language front end.

`/idea`:

1. `gh issue create` — with `--label type:X --label priority:PN`
2. `gh project item-add` — puts the issue on the board
3. `gh project item-edit --field Status --value Backlog` — places the card,
   without depending on any GitHub-side "auto-add" automation
4. `gh project item-edit --field "Due date" --date ...` — only if a date
   was mentioned

`ship` (triggered by an approved plan, not typed):

1. `gh issue create` + `gh project item-add` + `item-edit --value "In Progress"`
   — same as above, but skips straight past `Backlog`/`Todo` since work
   starts immediately
2. `git checkout -b <type>/<issue-number>-<slug>` off the default branch
3. implementation happens as normal commits on that branch
4. once you approve the result: `git push`, `gh pr create` with
   `Closes #<N>` in the body, `item-edit --value "In Review"`
5. once you approve the merge: `gh pr merge --squash --delete-branch`,
   `item-edit --value "Done"` — the issue closes itself via `Closes #<N>`

The one non-obvious piece: GitHub Projects' default **Status** field ships
hardcoded with `Todo / In Progress / Done`, and `gh cli` refuses to delete
it (`Only custom fields can be deleted`). You can still **overwrite its
options wholesale** via the GraphQL API — that's how `setup.sh` turns 3
columns into the 5 this workflow uses, without touching anything else in
the project:

```bash
gh api graphql -f query='
mutation($fieldId: ID!) {
  updateProjectV2Field(input: {
    fieldId: $fieldId
    singleSelectOptions: [
      {name: "Backlog", color: GRAY, description: ""},
      {name: "Todo", color: BLUE, description: ""},
      {name: "In Progress", color: YELLOW, description: ""},
      {name: "In Review", color: PURPLE, description: ""},
      {name: "Done", color: GREEN, description: ""}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}' -f fieldId="$STATUS_FIELD_ID"
```

Worth knowing even if you never use the rest of this repo.

## Customizing

- **Labels**: edit `setup/templates/labels.yml` before running `setup.sh`
  (or edit it per-repo afterward in `.github/labels.yml` and re-run
  `.github/scripts/sync-labels.sh`).
- **Priority/type keyword inference**: edit the rules directly in
  `skills/idea/SKILL.md` (`ship` reuses the same defaults) — it's plain
  instructions, not code.
- **Branch naming**: `ship` uses `<type>/<issue-number>-<slug>`, matching
  `CONTRIBUTING.md.tmpl`. Edit both `skills/ship/SKILL.md` and
  `setup/templates/CONTRIBUTING.md.tmpl` together if you change it.
- **Merge strategy**: `ship` always squash-merges and deletes the branch.
  Edit the `gh pr merge` line in `skills/ship/SKILL.md` if you prefer
  merge commits or rebase.
- **Board columns**: edit the `singleSelectOptions` list in `setup.sh`
  before running it (changing it after the board exists means re-running
  that one GraphQL call by hand with the new list).

## FAQ

**Does the board cost anything?** No — GitHub Projects is free on every
plan, public or private repos, no seat limit for personal use.

**What if I don't use Claude Code?** The `setup/setup.sh` script is
standalone and useful on its own — it just won't wire up `/idea` or
`ship`, since those are Claude Code skills specifically.

**Will `ship` ever push, open a PR, or merge without asking me first?**
No. Creating the issue and the local branch happens automatically on plan
approval, but pushing, opening the PR, and merging each require you to
explicitly say yes — those touch shared/public state, this is by design,
not a missing feature.

**What if I only want one of the two skills?** They're independent —
install just `skills/idea` or just `skills/ship` in step 3 of the
Quickstart. `ship` doesn't require `/idea` to have been used on an issue.

**Multiple repos with the same product name (e.g. a frontend/backend
pair)?** Give them distinct registry keys but let both share an alias
(e.g. `"structcore"` on both) — the skill is instructed to ask which one
you mean when a name matches more than one entry, instead of guessing.

**Can I use a different date field name / add more fields?** Yes — it's
just a GitHub Projects board underneath. Add fields with
`gh project field-create`, then reference them the same way `SKILL.md`
references `Due date`.

## Contributing

Bug reports, feature ideas, and PRs are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the branch/commit/PR conventions
this repo follows (it's the same workflow `idea-skill` automates). Fittingly,
this project's own issues live on its own `/idea`-managed board:
[project #10](https://github.com/users/NatanNarciso/projects/10).

If this saved you the "let me go open a new issue real quick" tax, a ⭐
on the repo helps other people find it.

## License

MIT — see [LICENSE](LICENSE).

---

Built by pairing with [Claude Code](https://claude.com/claude-code); the
workflow itself was designed and refined in a real, ongoing multi-repo
setup before being extracted here.
