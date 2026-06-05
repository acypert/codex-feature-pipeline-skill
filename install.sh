#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
if [[ -z "${SKILLS_HOME:-}" ]]; then
  if [[ -d "$HOME/.agents/skills" ]]; then
    SKILLS_HOME="$HOME/.agents/skills"
  else
    SKILLS_HOME="$CODEX_HOME/skills"
  fi
fi
PROMPTS_HOME="${PROMPTS_HOME:-$CODEX_HOME/prompts}"

install_skill() {
  local name="$1"
  local src="$REPO_DIR/skills/$name"
  local dest="$SKILLS_HOME/$name"

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
  local dest="$PROMPTS_HOME/ship.md"

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

mkdir -p "$SKILLS_HOME" "$PROMPTS_HOME"

install_skill codex-feature-pipeline
install_skill ship
install_prompt

VALIDATOR="$CODEX_HOME/skills/.system/skill-creator/scripts/quick_validate.py"
if [[ ! -f "$VALIDATOR" && -f "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" ]]; then
  VALIDATOR="$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py"
fi
if [[ -f "$VALIDATOR" ]]; then
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    python3 "$VALIDATOR" "$SKILLS_HOME/codex-feature-pipeline"
    python3 "$VALIDATOR" "$SKILLS_HOME/ship"
  elif command -v uv >/dev/null 2>&1; then
    uv run --with pyyaml python "$VALIDATOR" "$SKILLS_HOME/codex-feature-pipeline"
    uv run --with pyyaml python "$VALIDATOR" "$SKILLS_HOME/ship"
  else
    echo "Validator requires PyYAML; skipped validation because python3 lacks yaml and uv is unavailable."
  fi
else
  echo "Validator not found at $VALIDATOR; skipped validation."
fi

echo "Installed skills to $SKILLS_HOME"
echo "Installed prompt to $PROMPTS_HOME/ship.md"
echo "Done. Start a fresh Codex session before using \$ship or \$codex-feature-pipeline."
