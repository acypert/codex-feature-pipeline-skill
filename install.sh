#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_TYPE_INTERFACE_ORGANIZER="${INSTALL_TYPE_INTERFACE_ORGANIZER:-}"
if [[ -z "${SKILLS_HOME:-}" ]]; then
  if [[ -d "$HOME/.agents/skills" ]]; then
    SKILLS_HOME="$HOME/.agents/skills"
  else
    SKILLS_HOME="$CODEX_HOME/skills"
  fi
fi
PROMPTS_HOME="${PROMPTS_HOME:-$CODEX_HOME/prompts}"
TYPE_INTERFACE_ORGANIZER_REPO="${TYPE_INTERFACE_ORGANIZER_REPO:-https://github.com/acypert/type-interface-organizer-skill.git}"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --with-type-interface-organizer   Also install acypert/type-interface-organizer-skill
  --skip-type-interface-organizer   Do not prompt for or install the companion skill
  -h, --help                        Show this help

Environment:
  SKILLS_HOME                       Skill install root. Defaults to ~/.agents/skills when present, else $CODEX_HOME/skills
  PROMPTS_HOME                      Prompt install root. Defaults to $CODEX_HOME/prompts
  CODEX_HOME                        Codex home. Defaults to ~/.codex
  INSTALL_TYPE_INTERFACE_ORGANIZER  yes/no; non-flag way to control companion skill install
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-type-interface-organizer)
      INSTALL_TYPE_INTERFACE_ORGANIZER="yes"
      shift
      ;;
    --skip-type-interface-organizer)
      INSTALL_TYPE_INTERFACE_ORGANIZER="no"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

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

ask_install_type_interface_organizer() {
  if [[ -n "$INSTALL_TYPE_INTERFACE_ORGANIZER" ]]; then
    return
  fi

  if [[ -t 0 && -t 1 ]]; then
    local answer
    read -r -p "Install optional type-interface-organizer companion skill? [y/N] " answer
    case "$answer" in
      y|Y|yes|YES)
        INSTALL_TYPE_INTERFACE_ORGANIZER="yes"
        ;;
      *)
        INSTALL_TYPE_INTERFACE_ORGANIZER="no"
        ;;
    esac
  else
    INSTALL_TYPE_INTERFACE_ORGANIZER="no"
    echo "Skipping optional type-interface-organizer install in non-interactive mode."
    echo "Run ./install.sh --with-type-interface-organizer to install it."
  fi
}

install_type_interface_organizer() {
  local dest="$SKILLS_HOME/type-interface-organizer"

  if [[ "$INSTALL_TYPE_INTERFACE_ORGANIZER" != "yes" ]]; then
    echo "Optional type-interface-organizer skill not installed."
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "git was not found; cannot install optional type-interface-organizer skill."
    echo "Install it manually from $TYPE_INTERFACE_ORGANIZER_REPO"
    return
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  if ! git clone --depth 1 "$TYPE_INTERFACE_ORGANIZER_REPO" "$tmp/type-interface-organizer-skill" >/dev/null 2>&1; then
    echo "Could not clone optional type-interface-organizer skill from $TYPE_INTERFACE_ORGANIZER_REPO"
    echo "The feature pipeline still installs; Type Interface Organizer stage will be skipped until the companion skill is installed."
    return
  fi

  if ! bash "$tmp/type-interface-organizer-skill/install.sh" "$SKILLS_HOME"; then
    echo "Optional type-interface-organizer install failed."
    echo "The feature pipeline still installs; Type Interface Organizer stage will be skipped until the companion skill is installed."
    return
  fi

  if [[ -f "$dest/SKILL.md" ]]; then
    echo "Installed optional type-interface-organizer skill."
  fi
}

validate_optional_type_interface_organizer() {
  local validator_command=("$@")

  if [[ "$INSTALL_TYPE_INTERFACE_ORGANIZER" != "yes" ]]; then
    return
  fi

  if [[ ! -f "$SKILLS_HOME/type-interface-organizer/SKILL.md" ]]; then
    return
  fi

  if ! "${validator_command[@]}" "$SKILLS_HOME/type-interface-organizer"; then
    echo "Optional type-interface-organizer validation failed; feature pipeline install remains complete."
  fi
}

mkdir -p "$SKILLS_HOME" "$PROMPTS_HOME"

install_skill codex-feature-pipeline
install_skill ship
install_prompt
ask_install_type_interface_organizer
install_type_interface_organizer

VALIDATOR="$CODEX_HOME/skills/.system/skill-creator/scripts/quick_validate.py"
if [[ ! -f "$VALIDATOR" && -f "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" ]]; then
  VALIDATOR="$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py"
fi
if [[ -f "$VALIDATOR" ]]; then
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    python3 "$VALIDATOR" "$SKILLS_HOME/codex-feature-pipeline"
    python3 "$VALIDATOR" "$SKILLS_HOME/ship"
    validate_optional_type_interface_organizer python3 "$VALIDATOR"
  elif command -v uv >/dev/null 2>&1; then
    uv run --with pyyaml python "$VALIDATOR" "$SKILLS_HOME/codex-feature-pipeline"
    uv run --with pyyaml python "$VALIDATOR" "$SKILLS_HOME/ship"
    validate_optional_type_interface_organizer uv run --with pyyaml python "$VALIDATOR"
  else
    echo "Validator requires PyYAML; skipped validation because python3 lacks yaml and uv is unavailable."
  fi
else
  echo "Validator not found at $VALIDATOR; skipped validation."
fi

echo "Installed skills to $SKILLS_HOME"
echo "Installed prompt to $PROMPTS_HOME/ship.md"
echo "Done. Start a fresh Codex session before using \$ship or \$codex-feature-pipeline."
