---
name: ship
description: Shortcut alias for the Codex feature pipeline. Use when the user invokes /ship, asks to ship a feature, or wants the subagent-only workflow with explore, planner, plan critic, executor, tester, fixer, final reviewer, and external codex review phases.
---

# Ship

This is a short alias for the full Codex feature pipeline skill.

When this skill is triggered, read and follow:

`~/.agents/skills/codex-feature-pipeline/SKILL.md`

If that file does not exist, use the first available fallback:

`$CODEX_HOME/skills/codex-feature-pipeline/SKILL.md`

`~/.codex/skills/codex-feature-pipeline/SKILL.md`

Preserve the full subagent-only contract from that skill. The initiating session is the leader/orchestrator. All substantive workflow stages must be delegated to subagents through the pipeline handoff files.
