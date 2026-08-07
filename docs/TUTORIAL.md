# Tutorial: from zero to `/idea` and `ship`

This walks through setting up idea-skill on a real repo, end to end,
covering both skills: `/idea` (loose thought → tagged issue in Backlog)
and `ship` (approved plan → merged PR, issue closed). It assumes you
already have [`gh`](https://cli.github.com/) installed and logged in
(`gh auth login`), `jq` installed, and
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

## 4. Install the skills

Skills live at `~/.claude/skills/<name>/SKILL.md` for a personal skill that
works across every project (as opposed to `.claude/skills/` inside a
single repo, which only applies there).

```bash
mkdir -p ~/.claude/skills
cp -r ~/tools/idea-skill/skills/idea ~/.claude/skills/idea
cp -r ~/tools/idea-skill/skills/ship ~/.claude/skills/ship
```

Claude Code picks up new skills automatically at the start of a session —
no restart needed if you're already mid-session, it'll show up listed as
available shortly after. Install just one of the two directories if you
only want half the workflow — `/idea` is invoked by name, `ship` fires on
its own when you approve a plan.

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

## 6. Try `/idea`

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

## 7. Try `ship`

Open a Claude Code session inside the project's `local_path` and ask for
something small enough to plan in one shot, e.g. "add a `/health` endpoint
that returns 200". Let Claude enter plan mode and present a plan, then
approve it.

You should see, without typing any command:

1. An issue created (type/priority inferred the same way as `/idea`), the
   board card placed straight in `In Progress`.
2. A local branch `feat/<N>-<slug>` created off the default branch.
3. The implementation happening as normal commits.
4. Once done, Claude stops and asks whether to open the PR — say yes.
5. The PR opens (`Closes #<N>`), the board card moves to `In Review`,
   Claude asks whether to merge — say yes.
6. The PR merges (squash, branch deleted), the issue closes itself, the
   board card moves to `Done`.

If your project isn't in the registry, `ship` should say so and ask
whether to proceed without the GitHub flow, instead of guessing or
silently skipping steps.

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

**`ship` didn't fire after I approved a plan** — check that plan mode was
actually used (`ExitPlanMode`) and that the cwd matches a registry
`local_path`. `ship` is instructed to skip silently (not create a
half-broken issue/branch) if the project doesn't resolve, so also check
whether Claude asked a clarifying question you missed instead.

**`gh pr merge` fails with a branch-protection error** — required checks
haven't passed yet, or the branch needs an approving review. That's your
repo's rules working as intended; wait for checks/review, then ask Claude
to retry the merge.

**I want a different set of columns** — edit the `singleSelectOptions`
array inside `setup/setup.sh` before running it on a new repo. For a board
that already exists, run the same `gh api graphql` mutation by hand with
your new list (see the README's "How it works" section for the full
snippet) — the `fieldId` you need comes from
`gh project field-list <number> --owner <owner> --format json`.
