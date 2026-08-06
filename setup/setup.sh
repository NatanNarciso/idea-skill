#!/usr/bin/env bash
# Sets up the full idea-skill workflow on the current repo:
#   - issue/PR templates + CONTRIBUTING.md
#   - standard labels (type/priority/status/size)
#   - a GitHub Projects (v2) board with 5 columns (Backlog/Todo/In
#     Progress/In Review/Done) and a "Due date" date field
#
# Usage: run from inside the target repo (must have a GitHub remote).
#   bash /path/to/idea-skill/setup/setup.sh [--title "Project Name"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

TITLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

for bin in gh git jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing dependency: $bin" >&2
    exit 1
  fi
done

REPO_NWO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [ -z "$REPO_NWO" ]; then
  echo "Could not detect a GitHub repo here. Run this from inside the" >&2
  echo "target repo's working directory (with an 'origin' remote on GitHub)." >&2
  exit 1
fi
OWNER="${REPO_NWO%%/*}"
REPO="${REPO_NWO##*/}"
BRANCH="$(git branch --show-current)"
[ -z "$TITLE" ] && TITLE="$REPO"

SCOPES="$(gh auth status 2>&1 || true)"
if ! echo "$SCOPES" | grep -q "'project'"; then
  echo "Your gh token is missing the 'project' scope (needed to create/edit" >&2
  echo "the Kanban board). Run this first, then re-run setup.sh:" >&2
  echo "" >&2
  echo "  gh auth refresh -h github.com -s project" >&2
  exit 1
fi

echo "==> Setting up $REPO_NWO (branch: $BRANCH)"

echo "-- Copying issue/PR templates and labels config"
mkdir -p .github/ISSUE_TEMPLATE .github/scripts
cp "$TEMPLATE_DIR/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
cp "$TEMPLATE_DIR/ISSUE_TEMPLATE/config.yml" .github/ISSUE_TEMPLATE/
cp "$TEMPLATE_DIR/PULL_REQUEST_TEMPLATE.md" .github/
cp "$TEMPLATE_DIR/labels.yml" .github/
cp "$TEMPLATE_DIR/scripts/sync-labels.sh" .github/scripts/

echo "-- Syncing labels"
bash .github/scripts/sync-labels.sh

echo "-- Creating the project board"
PROJECT_JSON="$(gh project create --owner "$OWNER" --title "$TITLE" --format json)"
PROJECT_NUMBER="$(echo "$PROJECT_JSON" | jq -r '.number')"
BOARD_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
gh project link "$PROJECT_NUMBER" --owner "$OWNER" --repo "$REPO_NWO" >/dev/null

echo "-- Rewriting Status column options"
# The default "Status" field ships with Todo/In Progress/Done and can't be
# deleted via gh cli (only custom fields can be) — but its options CAN be
# overwritten wholesale via the GraphQL API. That's the trick that gets us
# from 3 columns to the 5 this workflow uses.
STATUS_FIELD_ID="$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json \
  | jq -r '.fields[] | select(.name=="Status") | .id')"
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
}' -f fieldId="$STATUS_FIELD_ID" >/dev/null

echo "-- Adding the 'Due date' field"
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" --name "Due date" --data-type DATE >/dev/null

echo "-- Writing CONTRIBUTING.md"
sed -e "s#__BOARD_URL__#$BOARD_URL#g" \
    -e "s#__DEFAULT_BRANCH__#$BRANCH#g" \
    -e "s#__PROJECT_NAME__#$TITLE#g" \
    "$TEMPLATE_DIR/CONTRIBUTING.md.tmpl" > CONTRIBUTING.md

git add .github CONTRIBUTING.md
git commit -m "chore: add issue/PR templates, labels and contributing guide" >/dev/null || true

REGISTRY_ENTRY=$(cat <<EOF
  "$TITLE": {
    "aliases": ["$(echo "$TITLE" | tr '[:upper:]' '[:lower:]')"],
    "local_path": "$(pwd)",
    "github_owner": "$OWNER",
    "github_repo": "$REPO",
    "default_branch": "$BRANCH",
    "project_number": $PROJECT_NUMBER
  }
EOF
)

cat <<EOF

Done.

  Board:   $BOARD_URL
  Labels:  type:*, priority:P0-P3, status:blocked, status:needs-review, size:S/M/L
  Commit:  created locally (not pushed — review and push when ready)

Add this to your registry (see skills/idea/README for the default path):

$REGISTRY_ENTRY
EOF
