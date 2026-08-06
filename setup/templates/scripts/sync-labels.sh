#!/usr/bin/env bash
# Applies the labels defined in ../labels.yml to the current repo via gh cli.
# Run from the repo root:
#   bash .github/scripts/sync-labels.sh
set -euo pipefail

LABELS_FILE="$(dirname "$0")/../labels.yml"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh cli not found. Install: https://cli.github.com/" >&2
  exit 1
fi

name="" color="" desc=""
apply() {
  [ -z "$name" ] && return
  if gh label edit "$name" --color "$color" --description "$desc" >/dev/null 2>&1; then
    echo "updated: $name"
  else
    gh label create "$name" --color "$color" --description "$desc"
    echo "created: $name"
  fi
}

while IFS= read -r line; do
  case "$line" in
    "- name:"*)
      apply
      name=$(echo "$line" | sed -E 's/- name: *"?([^"]*)"?/\1/')
      color=""; desc=""
      ;;
    "  color:"*)
      color=$(echo "$line" | sed -E 's/ *color: *"?([^"]*)"?/\1/')
      ;;
    "  description:"*)
      desc=$(echo "$line" | sed -E 's/ *description: *"?([^"]*)"?/\1/')
      ;;
  esac
done < "$LABELS_FILE"
apply

echo "Labels synced."
