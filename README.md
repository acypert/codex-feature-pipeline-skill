# Codex Feature Pipeline Skill

A subagent-only feature delivery workflow for Codex.

This repo packages:

- `codex-feature-pipeline`: the full delegated workflow skill.
- `ship`: a short alias skill for invoking the workflow as `$ship` or from the Skills slash menu.
- `prompts/ship.md`: an optional prompt shim for Codex installs that expose prompt files.
- `install.sh`: a local installer that copies the skills and prompt into `CODEX_HOME`.

## Install

```bash
git clone https://github.com/acypert/codex-feature-pipeline-skill.git
cd codex-feature-pipeline-skill
./install.sh
```

Then start a fresh Codex session so the skill list reloads.

By default the installer writes to `~/.codex`. To install somewhere else:

```bash
CODEX_HOME=/path/to/codex-home ./install.sh
```

## Usage

Invoke the short alias:

```text
$ship implement the requested feature
```

Or invoke the full skill directly:

```text
$codex-feature-pipeline implement the requested feature
```

Depending on the Codex client build, `Ship` may also appear in the slash command Skills group, and the prompt shim may be available through the prompts namespace.

## Workflow

The initiating Codex session is only the Leader/orchestrator. All substantive work is delegated to subagents:

1. Explore repo context.
2. Planner writes a plan.
3. Plan Critic reviews the plan.
4. Planner and Critic loop until the Critic approves or HITL is required.
5. Executor implements the approved plan.
6. Tester adds/runs focused verification.
7. Fixer handles failures or review findings.
8. Final Reviewer decides `SHIP`, `NEEDS WORK`, or `BLOCK`.

The workflow uses `.pipeline/` for ephemeral handoff files. The skill instructs the Leader to ignore it locally, reset it before a new run, and delete it after a `SHIP` verdict unless preservation is explicitly requested.

## Packaged Files

```text
skills/
  codex-feature-pipeline/
    SKILL.md
    agents/openai.yaml
  ship/
    SKILL.md
    agents/openai.yaml
prompts/
  ship.md
install.sh
```

## Validate

If your Codex install has the system skill validator:

```bash
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py ~/.codex/skills/codex-feature-pipeline
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py ~/.codex/skills/ship
```

