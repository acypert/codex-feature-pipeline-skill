---
name: ship
description: Shortcut alias for the Codex feature pipeline. Use when the user invokes /ship, asks to ship a feature, or wants the subagent-only workflow with explore, planner, plan critic, executor, tester, fixer, and reviewer phases.
---

# Ship

This is a short alias for the full Codex feature pipeline skill.

When this skill is triggered, read and follow:

`$CODEX_HOME/skills/codex-feature-pipeline/SKILL.md`

If `CODEX_HOME` is not set, use:

`~/.codex/skills/codex-feature-pipeline/SKILL.md`

Preserve the full subagent-only contract from that skill. The initiating session is only the leader/orchestrator. All substantive workflow stages must be delegated to subagents through the pipeline handoff files.
