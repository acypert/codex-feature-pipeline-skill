#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

install_skill() {
  local name="$1"
  local src="$REPO_DIR/skills/$name"
  local dest="$CODEX_HOME/skills/$name"

  if [[ ! -d "$src" ]]; then
    echo "Missing skill source: $src" >&2
    exit 1
  fi

  if [[ -e "$dest" ]]; then
    local backup="$dest.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "Backed up existing $name skill to $backup"
  fi

  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
  echo "Installed skill: $name"
}

install_prompt() {
  local src="$REPO_DIR/prompts/ship.md"
  local dest="$CODEX_HOME/prompts/ship.md"

  if [[ ! -f "$src" ]]; then
    echo "Missing prompt source: $src" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" ]]; then
    local backup="$dest.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "Backed up existing ship prompt to $backup"
  fi

  cp "$src" "$dest"
  echo "Installed prompt shim: ship"
}

mkdir -p "$CODEX_HOME/skills" "$CODEX_HOME/prompts"

install_skill codex-feature-pipeline
install_skill ship
install_prompt

VALIDATOR="$CODEX_HOME/skills/.system/skill-creator/scripts/quick_validate.py"
if [[ -f "$VALIDATOR" ]]; then
  python3 "$VALIDATOR" "$CODEX_HOME/skills/codex-feature-pipeline"
  python3 "$VALIDATOR" "$CODEX_HOME/skills/ship"
else
  echo "Validator not found at $VALIDATOR; skipped validation."
fi

echo "Done. Start a fresh Codex session before using \$ship or \$codex-feature-pipeline."
