---
description: Run the subagent-only Codex feature pipeline for a requested change.
---

Use the `$codex-feature-pipeline` skill for:

```text
$ARGUMENTS
```

You are the Leader/orchestrator. Do not personally plan, implement, test, fix, or perform final review. Execute substantive workflow stages through subagents and `.pipeline/` handoff files.

Start with Explore, then run Planner -> Plan Critic until Critic says no additional plan changes are required. Stop if HITL is required. After approval, delegate implementation, testing, fixing, and final review.

After Final Reviewer returns `SHIP`, run the External Codex Review Gate through a separate generic `codex exec --sandbox read-only -c 'model_reasoning_effort="xhigh"' --output-last-message .pipeline/external-review.md` session. Do not pass a custom prompt to `codex exec review --uncommitted`; some CLI builds reject that combination. The external review must inspect the uncommitted changes, invoke/read relevant skills based on the work accomplished, and write `.pipeline/external-review.md`. Its primary goal is independent architectural and code-health review, not another task-completion check; it should look for boundary, abstraction, coupling, ownership, state-flow, security, maintainability, and testability concerns even when the feature appears complete. If generic `codex exec` is unavailable, fallback to `codex exec review --uncommitted -c 'model_reasoning_effort="xhigh"' --output-last-message .pipeline/external-review.md` without a custom prompt. If the review requests changes and you agree they are plausible and in scope, delegate fixes to Fixer or Executor, then rerun Tester, Final Reviewer, and the external review gate. Only report final success after the external review returns `PASS`.

Do not merge or deploy. Report the final verdict from `.pipeline/review.md` and `.pipeline/external-review.md`.
