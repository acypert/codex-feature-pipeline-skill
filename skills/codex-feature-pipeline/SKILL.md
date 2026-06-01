---
name: codex-feature-pipeline
description: Subagent-only feature delivery pipeline for Codex. Use when the user asks to ship, build, implement, or change a feature through a delegated workflow where the initiating session remains only the leader/orchestrator, with planner/critic review loops, HITL stop conditions, implementation, testing, fixing, and final review handled by subagents.
---

# Codex Feature Pipeline

Run a feature request through a delegated Codex pipeline. The initiating session is the Leader only; all substantive work is performed by subagents through explicit handoff files.

## Non-Negotiable Orchestration Rule

The initiating Codex session is the Leader.

The Leader may:
- inspect workflow state and lightweight repo facts needed for routing
- create, reset, or delete stale `.pipeline/` state and write orchestration metadata such as `.pipeline/run.md`
- spawn subagents, pass artifacts between them, and wait for completion
- verify required handoff files exist and read verdict fields
- decide whether to continue, loop, stop for HITL, or report status

The Leader must not:
- write or revise the implementation plan
- review or approve its own plan
- implement code
- write tests
- fix code or tests
- perform the final review
- hand-edit stage artifacts except orchestration metadata

If a stage cannot be delegated to a subagent, stop and report that the workflow cannot proceed under the subagent-only contract.

## Artifacts

Use `.pipeline/` for handoffs:

- `.pipeline/run.md`: Leader-owned run state, subagent ids, current stage, and stop reason
- `.pipeline/context.md`: Explore output
- `.pipeline/plan.md`: Planner output
- `.pipeline/plan-review.md`: Plan Critic output
- `.pipeline/hitl.md`: HITL question, options, and recommended default
- `.pipeline/changes.md`: Executor/Fixer change summary
- `.pipeline/test-results.md`: Test Engineer output
- `.pipeline/review.md`: Final Reviewer output

Each stage subagent owns its artifact. The Leader verifies presence and reads status, but does not patch stage artifacts.

## Pipeline Directory Hygiene

Treat `.pipeline/` as ephemeral local orchestration state. It must not be committed.

At the start of a new `/ship` workflow, before spawning any subagent:

1. If `.pipeline/` already exists, delete it completely so stale artifacts cannot affect the new run.
2. Recreate `.pipeline/` for the new run.
3. Ensure `.pipeline/` is ignored by Git. Prefer the repo's local exclude file, such as `.git/info/exclude`, to avoid changing the project diff solely for pipeline state. Use a committed `.gitignore` entry only if that is already the repo convention or the user explicitly wants the ignore rule committed.

Only preserve an existing `.pipeline/` directory when the user is explicitly resuming the same paused workflow after HITL or interruption.

After Final Reviewer returns `SHIP`, the Leader must read the final artifacts, report the verdict, then delete `.pipeline/` unless the user explicitly asks to preserve the artifacts for debugging or audit.

## Subagent Selection

Use the available subagent/delegation mechanism, such as `spawn_agent`, when exposed by the runtime.

Preferred stage mapping:

| Stage | Preferred role | Desired effort |
| --- | --- | --- |
| Explore | `explore` / `explorer` | `high`; upgrade to `xhigh` when repo discovery is broad, unfamiliar, architectural, high-risk, or cross-cutting |
| Planner | `planner` or custom planner prompt | `xhigh` |
| Plan Critic | `critic` or custom critic prompt | `xhigh` |
| Executor | `executor` / `worker` | `high` |
| Tester | `test-engineer` | `medium`; upgrade to `high` for cross-cutting, brittle, or failure-prone behavior |
| Fixer | `build-fixer` / `executor` | `high` |
| Final Reviewer | `code-reviewer` / `verifier` | `xhigh` |

If named runtime roles have fixed model or effort presets, use the closest available role and preserve the phase intent. When a gate needs stronger reasoning than a fixed named role provides and the runtime supports custom/default subagents with effort overrides, prefer a custom stage prompt at the desired effort.

Do not set all subagents to `xhigh` by default. Spend the highest reasoning budget on planning, critique, and approval gates.

## Leader Workflow

1. Restate the request, reset stale `.pipeline/` state for a new run, ensure `.pipeline/` is Git-ignored, and create `.pipeline/run.md`.
2. Spawn Explore subagent(s) to inspect relevant repo context. Require `.pipeline/context.md`.
3. Run the Planner/Critic loop until Critic approves or HITL is required.
4. Spawn Executor only after plan approval. Require `.pipeline/changes.md`.
5. Spawn Tester. Require `.pipeline/test-results.md`.
6. If tests fail, spawn Fixer, then return to Tester.
7. Spawn Final Reviewer. Require `.pipeline/review.md`.
8. If Final Reviewer returns `NEEDS WORK`, spawn Fixer or Executor with the review findings, then return to Tester and Final Reviewer.
9. If Final Reviewer returns `BLOCK`, stop and report the blocker.
10. If Final Reviewer returns `SHIP`, report the verdict, changed files, tests run, and remaining risks, then delete `.pipeline/` unless preservation was explicitly requested. Do not merge or deploy unless the user explicitly asks after the final verdict.

## Planner/Critic Loop

Repeat this loop:

1. Leader spawns Planner with the user request and `.pipeline/context.md`.
2. Planner writes `.pipeline/plan.md`.
3. Leader spawns Plan Critic with `.pipeline/plan.md`, `.pipeline/context.md`, and the original request.
4. Plan Critic writes `.pipeline/plan-review.md` with one verdict:
   - `APPROVED`: no additional plan changes required
   - `REVISE`: specific plan changes required
   - `HITL_REQUIRED`: user decision required before planning can continue

If verdict is `REVISE`, Leader spawns Planner again with the Critic feedback. The Leader never edits the plan directly.

If verdict is `HITL_REQUIRED`, Leader stops, asks the Critic or Planner to write `.pipeline/hitl.md` if it is missing, and shows the user the exact question. The Leader does not author the HITL content.

If the loop does not converge after 5 Planner/Critic iterations, treat that as `HITL_REQUIRED` and ask the user how to resolve the remaining disagreement.

## HITL Stop Conditions

Stop for human input when any of these occur:

- unresolved product, UX, API, security, data, or rollout choices
- conflicting requirements or unclear acceptance criteria
- Critic says user intent or business priority is needed
- production access, secrets, credentials, paid services, destructive actions, merge/deploy approval, or external account changes are required
- tests require unavailable services or unsafe side effects
- Planner/Critic, test/fix, or review/fix loops do not converge within their iteration limits

HITL output must include:

- the exact blocking question
- 2-3 concrete options when possible
- the recommended default and why
- what stage will resume after the user answers

## Stage Prompts

Use these instructions when spawning subagents.

### Explore

Inspect only the repo context needed for the requested change. Find existing patterns before proposing new ones. Write `.pipeline/context.md` with:

- relevant files and symbols
- existing patterns to follow
- likely test commands
- risks or unknowns the Planner must handle

Do not implement.

### Planner

Write `.pipeline/plan.md`. Do not implement. Include:

- requirements summary
- assumptions
- files to create or modify, with exact paths where known
- existing patterns to follow
- interface or behavior contracts
- edge cases and failure cases
- test strategy and acceptance criteria
- rollout or safety notes
- open questions only when they truly block planning

If Plan Critic supplied feedback, revise the plan to address it directly.

### Plan Critic

Review `.pipeline/plan.md` against the original request and `.pipeline/context.md`. Do not edit the plan. Write `.pipeline/plan-review.md` with:

- `VERDICT: APPROVED`, `REVISE`, or `HITL_REQUIRED`
- critical gaps only, not preference nitpicks
- exact changes required when revising
- the HITL question when user input is required

Approve only when no additional plan changes are required before implementation.

### Executor

Implement exactly the approved `.pipeline/plan.md`. Follow existing repo patterns. Do not broaden scope or refactor unrelated code. Write `.pipeline/changes.md` with:

- files changed
- behavior implemented
- deviations from plan, if any
- test focus areas for Tester

If the plan is impossible or unsafe, stop and write the blocker to `.pipeline/changes.md`.

### Tester

Read `.pipeline/plan.md`, `.pipeline/changes.md`, and the changed files. Add or update tests that prove the public behavior. Run focused verification. Write `.pipeline/test-results.md` with:

- tests added or changed
- commands run
- pass/fail status
- failures and likely cause
- test gaps that remain

Do not fix implementation code.

### Fixer

Read the approved plan, changes, and failures or review findings. Make only the minimal scoped fixes needed. Update `.pipeline/changes.md` with what changed and why. Do not change requirements or silently skip failing coverage.

### Final Reviewer

Read the original request, `.pipeline/context.md`, `.pipeline/plan.md`, `.pipeline/changes.md`, `.pipeline/test-results.md`, and the actual diff. Write `.pipeline/review.md` with:

- `VERDICT: SHIP`, `NEEDS WORK`, or `BLOCK`
- whether implementation matches the plan
- whether tests are meaningful
- correctness, security, performance, and maintainability concerns
- exact fixes required for `NEEDS WORK` or `BLOCK`

Green tests are not enough. Block if behavior is wrong, risky, or materially unverified.

## Loop Limits

- Planner/Critic: 5 iterations, then HITL
- Test/Fix: 3 iterations, then HITL unless the next fix is obvious and low risk
- Review/Fix: 3 iterations, then HITL

Prefer stopping with a precise HITL question over continuing an unbounded loop.
