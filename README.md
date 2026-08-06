# idea-skill

**Say an idea, get a tagged GitHub issue on the right Kanban board.**

A [Claude Code](https://claude.com/claude-code) skill + a one-shot setup
script that gives every repo you own the same lightweight workflow: issue
templates, standard labels, and a GitHub Projects (v2) board with 5 columns
and a due-date field — wired together so a loose sentence becomes a fully
tagged issue, already placed on the board, with zero manual clicking.

```
you:  /idea billing-service: webhook retries aren't backing off, prod is noisy, priority high

Claude:
  - created NatanNarciso/billing-service#42 (type:bug, priority:P1)
  - added to the board, column: Backlog
  → https://github.com/NatanNarciso/billing-service/issues/42
  → https://github.com/users/NatanNarciso/projects/11
```

No dashboard, no browser tab, no "let me go open a new issue real quick."

## Why this exists

Backlog friction is the reason ideas die mid-thought: you're mid-conversation
with an AI pair programmer, a good idea comes up, and by the time you've
switched to GitHub, picked the right repo, filled the issue form, added
labels, and dragged the card to the right column, the idea — or the
momentum — is gone. This collapses that whole sequence into one sentence.

## What you get, per repo

- `.github/ISSUE_TEMPLATE/` — bug report, feature request, chore
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/labels.yml` + a sync script — `type:*`, `priority:P0-P3`,
  `status:blocked`/`status:needs-review`, `size:S/M/L`
- `CONTRIBUTING.md` documenting the flow (issue → branch → PR → squash merge)
- A GitHub Projects board: **Backlog → Todo → In Progress → In Review → Done**,
  plus a **Due date** field
- The `/idea` command wired to that board

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated
- `jq`
- A `project` scope on your `gh` token — if you don't have one yet:
  ```bash
  gh auth refresh -h github.com -s project
  ```
  (opens a device-code flow in your browser)
- [Claude Code](https://claude.com/claude-code), for the `/idea` command
  itself (the setup script alone works without it)

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
`Due date` field, and commits everything locally (it does **not** push —
review the diff and push when you're happy with it). At the end it prints
a ready-to-paste JSON snippet for the registry.

**3. Install the skill** (once, works across every repo):

```bash
mkdir -p ~/.claude/skills
cp -r /path/to/idea-skill/skills/idea ~/.claude/skills/idea
```

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

See [`docs/TUTORIAL.md`](docs/TUTORIAL.md) for the full walkthrough with
screenshots-in-words and troubleshooting.

## How it works

Nothing here is magic — it's `gh cli` calls a human would type, just
sequenced and given a natural-language front end:

1. `gh issue create` — with `--label type:X --label priority:PN`
2. `gh project item-add` — puts the issue on the board
3. `gh project item-edit --field Status --value Backlog` — places the card,
   without depending on any GitHub-side "auto-add" automation
4. `gh project item-edit --field "Due date" --date ...` — only if a date
   was mentioned

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
  `skills/idea/SKILL.md` — it's plain instructions, not code.
- **Board columns**: edit the `singleSelectOptions` list in `setup.sh`
  before running it (changing it after the board exists means re-running
  that one GraphQL call by hand with the new list).

## FAQ

**Does the board cost anything?** No — GitHub Projects is free on every
plan, public or private repos, no seat limit for personal use.

**What if I don't use Claude Code?** The `setup/setup.sh` script is
standalone and useful on its own — it just won't wire up the `/idea`
command, since that part is a Claude Code skill specifically.

**Multiple repos with the same product name (e.g. a frontend/backend
pair)?** Give them distinct registry keys but let both share an alias
(e.g. `"structcore"` on both) — the skill is instructed to ask which one
you mean when a name matches more than one entry, instead of guessing.

**Can I use a different date field name / add more fields?** Yes — it's
just a GitHub Projects board underneath. Add fields with
`gh project field-create`, then reference them the same way `SKILL.md`
references `Due date`.

## License

MIT — see [LICENSE](LICENSE).

---

Built by pairing with [Claude Code](https://claude.com/claude-code); the
workflow itself was designed and refined in a real, ongoing multi-repo
setup before being extracted here.
