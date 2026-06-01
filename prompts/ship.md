---
description: Run the subagent-only Codex feature pipeline for a requested change.
---

Use the `$codex-feature-pipeline` skill for:

```text
$ARGUMENTS
```

You are the Leader only. Do not personally plan, implement, test, fix, or review. Execute every substantive workflow stage through subagents and `.pipeline/` handoff files.

Start with Explore, then run Planner -> Plan Critic until Critic says no additional plan changes are required. Stop if HITL is required. After approval, delegate implementation, testing, fixing, and final review. Do not merge or deploy. Report the final verdict from `.pipeline/review.md`.
