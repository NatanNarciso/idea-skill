# Tutorial: from zero to `/idea`

This walks through setting up idea-skill on a real repo, end to end. It
assumes you already have [`gh`](https://cli.github.com/) installed and
logged in (`gh auth login`), `jq` installed, and
[Claude Code](https://claude.com/claude-code) set up.

## 1. Clone idea-skill

You only do this once — it's a toolbox you point `setup.sh` at, not
something you fork per project.

```bash
git clone https://github.com/NatanNarciso/idea-skill.git ~/tools/idea-skill
```

## 2. Grant the `project` scope

GitHub Projects (v2) requires a separate OAuth scope from the default `gh`
login. Check what you have:

```bash
gh auth status
```

Look for `project` in the "Token scopes" line. If it's missing:

```bash
gh auth refresh -h github.com -s project
```

This prints a one-time code and a URL
(`https://github.com/login/device`) — open it, paste the code, approve. It
blocks the terminal until you do; that's expected.

## 3. Run the setup script on a real repo

Pick a repo you actually work on. `cd` into it — `setup.sh` needs to run
from inside the target repo's working directory, because it reads the
GitHub remote from there and writes files into `.github/` relative to
`pwd`.

```bash
cd ~/code/my-project
bash ~/tools/idea-skill/setup/setup.sh --title "My Project"
```

`--title` is what shows up as the Project board's name on GitHub; if you
skip it, it defaults to the repo name.

What happens, in order:

1. Copies `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE.md`,
   `.github/labels.yml`, `.github/scripts/sync-labels.sh` into your repo.
2. Runs the label sync (creates or updates `type:*`, `priority:*`,
   `status:*`, `size:*`).
3. Creates a GitHub Project and links it to the repo.
4. Rewrites the default `Status` field's options into the 5-column model
   (`Backlog/Todo/In Progress/In Review/Done`) — see the README's "How it
   works" section for why this needs a GraphQL call instead of a plain
   `gh` flag.
5. Adds a `Due date` field (type `DATE`) to the board.
6. Writes `CONTRIBUTING.md` from the template, with the board URL and your
   default branch name filled in.
7. Commits everything locally — **does not push**.

At the end you'll see something like:

```
Done.

  Board:   https://github.com/users/you/projects/11
  Labels:  type:*, priority:P0-P3, status:blocked, status:needs-review, size:S/M/L
  Commit:  created locally (not pushed — review and push when ready)

Add this to your registry (see skills/idea/README for the default path):

  "My Project": {
    "aliases": ["my project"],
    "local_path": "/home/you/code/my-project",
    "github_owner": "you",
    "github_repo": "my-project",
    "default_branch": "main",
    "project_number": 11
  }
```

Review the commit (`git show`), then `git push` when you're happy with it.

## 4. Install the skill

Skills live at `~/.claude/skills/<name>/SKILL.md` for a personal skill that
works across every project (as opposed to `.claude/skills/` inside a
single repo, which only applies there).

```bash
mkdir -p ~/.claude/skills
cp -r ~/tools/idea-skill/skills/idea ~/.claude/skills/idea
```

Claude Code picks up new skills automatically at the start of a session —
no restart needed if you're already mid-session, it'll show up listed as
available shortly after.

## 5. Create your registry

The skill needs to know which repo/board a project name maps to. Create
`~/.claude/idea-projects.json`:

```json
{
  "My Project": {
    "aliases": ["my project"],
    "local_path": "/home/you/code/my-project",
    "github_owner": "you",
    "github_repo": "my-project",
    "default_branch": "main",
    "project_number": 11
  }
}
```

Paste in the snippet `setup.sh` printed in step 3. Repeat step 3 + this
step for every repo you want on the workflow — the JSON object just grows
one key per project.

## 6. Try it

Open a Claude Code session (any repo, doesn't have to be the one you just
set up) and type:

```
/idea My Project: the retry logic on failed webhooks needs backoff, priority high
```

Claude should: infer `type:bug` (or `feature`, depending on the wording),
`priority:P1` (from "priority high"), create the issue, add it to the
board, place it in `Backlog`, and reply with both links.

If it asks which project you meant, or says it can't find one, that's the
skill working as intended — it's built to ask rather than guess when the
registry doesn't clearly resolve.

## Troubleshooting

**`gh: project scope required`-style errors on `item-add`/`item-edit`** —
your token lost/never had the `project` scope. Re-run step 2.

**`setup.sh` says "Could not detect a GitHub repo here"** — you're not
inside a git repo with a GitHub `origin` remote. `cd` into the right
directory, or check `git remote -v`.

**The card doesn't show up on the board** — check that
`gh project item-edit ... --field "Status" --value "Backlog"` actually ran
(look at the skill's tool calls). A common cause is a typo'd project
number in the registry.

**Two projects share a name** (e.g. a `.Web`/`.Api` pair) — give them
separate registry keys and let both list the shared short name as an
alias; the skill is instructed to ask which one instead of picking one.

**I want a different set of columns** — edit the `singleSelectOptions`
array inside `setup/setup.sh` before running it on a new repo. For a board
that already exists, run the same `gh api graphql` mutation by hand with
your new list (see the README's "How it works" section for the full
snippet) — the `fieldId` you need comes from
`gh project field-list <number> --owner <owner> --format json`.
