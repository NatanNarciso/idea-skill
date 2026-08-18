#!/usr/bin/env bash
# One-time backfill for boards created before the "Priority" field existed
# (see setup.sh). Idempotent — safe to re-run.
#
#   1. Creates the "Priority" single-select field if it's missing.
#   2. For every item already on the board, reads its issue's
#      `priority:PN` label and sets the Priority field to match
#      (P0=Urgente, P1=Alta, P2=Média, P3=Baixa). Items without a
#      priority:* label, or that already have Priority set, are skipped.
#
# Usage:
#   bash setup/migrate-priority-field.sh --project <number> --owner <owner>
set -euo pipefail

PROJECT_NUMBER="" OWNER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_NUMBER="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$PROJECT_NUMBER" ] || [ -z "$OWNER" ]; then
  echo "Usage: bash setup/migrate-priority-field.sh --project <number> --owner <owner>" >&2
  exit 1
fi

for bin in gh jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing dependency: $bin" >&2
    exit 1
  fi
done

echo "==> Project $PROJECT_NUMBER (owner: $OWNER)"

HAS_PRIORITY="$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json \
  | jq -r '.fields[] | select(.name=="Priority") | .name')"

if [ -z "$HAS_PRIORITY" ]; then
  echo "-- Creating the 'Priority' field"
  gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" --name "Priority" \
    --data-type SINGLE_SELECT --single-select-options "Urgente,Alta,Média,Baixa" >/dev/null
else
  echo "-- 'Priority' field already exists, skipping creation"
fi

echo "-- Backfilling Priority from priority:* labels"
gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json \
  | jq -r '.items[] | select(.content.url != null) | "\(.content.url)\t\(.priority // "")"' \
  | while IFS=$'\t' read -r ITEM_URL CURRENT_PRIORITY; do
      if [ -n "$CURRENT_PRIORITY" ]; then
        echo "skip (already set): $ITEM_URL"
        continue
      fi

      LABEL="$(gh issue view "$ITEM_URL" --json labels \
        -q '.labels[] | select(.name | startswith("priority:")) | .name' 2>/dev/null | head -1)"

      case "$LABEL" in
        "priority:P0") VALUE="Urgente" ;;
        "priority:P1") VALUE="Alta" ;;
        "priority:P2") VALUE="Média" ;;
        "priority:P3") VALUE="Baixa" ;;
        *) echo "skip (no priority:* label): $ITEM_URL"; continue ;;
      esac

      gh project item-edit "$PROJECT_NUMBER" --owner "$OWNER" \
        --url "$ITEM_URL" --field "Priority" --value "$VALUE" >/dev/null
      echo "set $VALUE: $ITEM_URL"
    done

echo "Done."
