# Codex Feature Pipeline Skill

A subagent-only feature delivery workflow for Codex with an external `codex exec` review gate.

This repo packages:

- `codex-feature-pipeline`: the full delegated workflow skill.
- `ship`: a short alias skill for invoking the workflow as `$ship` or from the Skills slash menu.
- `prompts/ship.md`: an optional prompt shim for Codex installs that expose prompt files.
- `install.sh`: a local installer that copies the skills and prompt into the active local skill roots.

## Install

```bash
git clone https://github.com/acypert/codex-feature-pipeline-skill.git
cd codex-feature-pipeline-skill
./install.sh
```

Then start a fresh Codex session so the skill list reloads.

By default the installer writes skills to `~/.agents/skills` when that directory exists, falling back to `~/.codex/skills`. The prompt shim still installs to `~/.codex/prompts`.

To install somewhere else:

```bash
SKILLS_HOME=/path/to/skills PROMPTS_HOME=/path/to/prompts ./install.sh
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
9. After `SHIP`, a separate generic `codex exec` session reviews the uncommitted changes with `model_reasoning_effort="xhigh"` and saves `.pipeline/external-review.md`.
10. If that external review requests changes, the Leader delegates accepted fixes to a subagent, then reruns Tester, Final Reviewer, and the external review gate.

The workflow uses `.pipeline/` for ephemeral handoff files. The skill instructs the Leader to ignore it locally, reset it before a new run, and delete it after the external review gate returns `PASS` unless preservation is explicitly requested.

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
