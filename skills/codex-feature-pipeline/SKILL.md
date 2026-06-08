---
name: codex-feature-pipeline
description: Subagent-only feature delivery pipeline for Codex. Use when the user asks to ship, build, implement, or change a feature through a leader-orchestrated workflow with planner/critic review loops, HITL stop conditions, subagent implementation/testing/fixing/type-interface cleanup/final review, and an external codex exec review gate.
---

# Codex Feature Pipeline

Run a feature request through a delegated Codex pipeline. The initiating session is the Leader only; all substantive work is performed by subagents through explicit handoff files. After Final Reviewer returns `SHIP`, the Leader runs an independent external Codex review gate and delegates any accepted fixes back to subagents.

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
- `.pipeline/type-interface-report.md`: Type Interface Organizer markdown report and verdict
- `.pipeline/type-interface-summary.json`: Type Interface Organizer JSON summary, when produced
- `.pipeline/review.md`: Final Reviewer output
- `.pipeline/external-review.md`: independent `codex exec` review output after Final Reviewer returns `SHIP`

Each stage subagent owns its artifact. The Leader verifies presence and reads status, but does not patch stage artifacts.

## Pipeline Directory Hygiene

Treat `.pipeline/` as ephemeral local orchestration state. It must not be committed.

At the start of a new `/ship` workflow, before spawning any subagent:

1. If `.pipeline/` already exists, delete it completely so stale artifacts cannot affect the new run.
2. Recreate `.pipeline/` for the new run.
3. Ensure `.pipeline/` is ignored by Git. Prefer the repo's local exclude file, such as `.git/info/exclude`, to avoid changing the project diff solely for pipeline state. Use a committed `.gitignore` entry only if that is already the repo convention or the user explicitly wants the ignore rule committed.

Only preserve an existing `.pipeline/` directory when the user is explicitly resuming the same paused workflow after HITL or interruption.

After the External Codex Review Gate returns `PASS`, the Leader must read the final artifacts, report the verdict, then delete `.pipeline/` unless the user explicitly asks to preserve the artifacts for debugging or audit.

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
| Type Interface Organizer | custom prompt with `$type-interface-organizer` | `high`; upgrade to `xhigh` for monorepos, public API types, broad TS ownership, or large duplicate graphs |
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
7. If TypeScript applies and `$type-interface-organizer` is installed/discoverable, spawn Type Interface Organizer with `$type-interface-organizer`. Require `.pipeline/type-interface-report.md`. TypeScript applies when the repo has `tsconfig.json` or the diff includes TS/TSX files. If TypeScript applies but the skill is unavailable, skip this optional stage and record the skip in `.pipeline/run.md`.
8. If Type Interface Organizer applies conservative edits, return to Tester before proceeding.
9. If Type Interface Organizer returns `BLOCK`, stop and report the blocker.
10. Spawn Final Reviewer. Require `.pipeline/review.md`.
11. If Final Reviewer returns `NEEDS WORK`, spawn Fixer or Executor with the review findings, then return to Tester, Type Interface Organizer when applicable, and Final Reviewer.
12. If Final Reviewer returns `BLOCK`, stop and report the blocker.
13. If Final Reviewer returns `SHIP`, run the External Codex Review Gate before reporting final success.
14. If External Codex Review returns `CHANGES_REQUESTED`, triage the findings. For findings the Leader agrees are plausible and in scope, spawn Fixer or Executor with `.pipeline/external-review.md`, then return to Tester, Type Interface Organizer when applicable, Final Reviewer, and the External Codex Review Gate. If the Leader disagrees with a material finding, spawn another external review or stop for HITL; do not silently ignore material concerns.
15. If External Codex Review returns `BLOCK`, stop and report the blocker.
16. If External Codex Review returns `PASS`, report the verdict, changed files, tests run, type/interface summary when applicable, external review summary, and remaining risks, then delete `.pipeline/` unless preservation was explicitly requested. Do not merge or deploy unless the user explicitly asks after the final verdict.

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
- Planner/Critic, test/fix, type-interface/test, review/fix, or external-review/fix loops do not converge within their iteration limits

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

### Type Interface Organizer

Run this stage only when both conditions are true:

- the repository has `tsconfig.json` or the changed files include TypeScript/TSX
- `$type-interface-organizer` is installed/discoverable in the active Codex skill roots

If the repository is not TypeScript and no TS/TSX files changed, skip the stage and note the skip in `.pipeline/run.md`.

If the TypeScript condition is true but the companion skill is unavailable, skip the stage and write `Type Interface Organizer: skipped; $type-interface-organizer unavailable` to `.pipeline/run.md`. Do not block the feature pipeline solely because this optional companion skill is missing.

Spawn a subagent with `$type-interface-organizer` injected. The subagent must read the active `$type-interface-organizer` skill body before doing the work. Prefer `~/.agents/skills/type-interface-organizer/SKILL.md`, then `$CODEX_HOME/skills/type-interface-organizer/SKILL.md`, then `~/.codex/skills/type-interface-organizer/SKILL.md`.

The stage goal is conservative type/interface analysis and dedup after tests pass but before Final Reviewer approval. This placement ensures type/interface cleanup is included in the final semantic review and the external architectural review.

The Type Interface Organizer subagent must:

- confirm the repository root and locate `tsconfig.json`
- run report mode before edits
- write the markdown report to `.pipeline/type-interface-report.md`
- write JSON summary to `.pipeline/type-interface-summary.json` when analyzer support is available
- apply only analyzer-marked conservative edits allowed by `$type-interface-organizer`
- treat the pipeline as an explicit request for conservative type/interface cleanup edits
- update `.pipeline/changes.md` when edits are applied
- leave non-conservative proposals as report-only findings
- run typecheck and focused tests after edits when commands are discoverable

The report must include one verdict:

- `VERDICT: SKIPPED`: not a TypeScript repo or no TS/TSX surface
- `VERDICT: REPORT_ONLY`: report produced, no conservative edits applied
- `VERDICT: CHANGES_APPLIED`: conservative edits applied and verification attempted
- `VERDICT: BLOCK`: analyzer, dependency, typecheck baseline, or ownership issue prevents safe completion

If the verdict is `CHANGES_APPLIED`, the Leader must rerun Tester before Final Reviewer.

If the verdict is `BLOCK`, the Leader stops for HITL unless the blocker is a missing optional analyzer dependency that can be installed safely in the skill directory without changing the target repo.

### Fixer

Read the approved plan, changes, and failures or review findings. Make only the minimal scoped fixes needed. Update `.pipeline/changes.md` with what changed and why. Do not change requirements or silently skip failing coverage.

### Final Reviewer

Read the original request, `.pipeline/context.md`, `.pipeline/plan.md`, `.pipeline/changes.md`, `.pipeline/test-results.md`, `.pipeline/type-interface-report.md` when present, and the actual diff. Write `.pipeline/review.md` with:

- `VERDICT: SHIP`, `NEEDS WORK`, or `BLOCK`
- whether implementation matches the plan
- whether tests are meaningful
- whether type/interface cleanup was skipped, report-only, safely applied, or blocked when TypeScript is present
- correctness, security, performance, and maintainability concerns
- exact fixes required for `NEEDS WORK` or `BLOCK`

Green tests are not enough. Block if behavior is wrong, risky, or materially unverified.

## External Codex Review Gate

After Final Reviewer returns `SHIP`, the Leader must run a separate Codex CLI session against the uncommitted changes. This is not a subagent and not the Leader's own review. Its primary purpose is independent architectural and code-health review, not another task-completion check.

The external reviewer should be anchored on the diff and repository architecture, not on the plan's local success criteria. It should ask whether the change worsens boundaries, abstractions, coupling, ownership, state flow, security posture, testability, or long-term maintainability even when the requested feature appears complete.

Run from the repository root and write the final external review output to `.pipeline/external-review.md`.

Use generic `codex exec`, not `codex exec review --uncommitted` with a custom prompt. Some Codex CLI builds reject custom prompts on the `review --uncommitted` subcommand or require the long output flag when that subcommand is present. The generic exec path keeps custom review instructions and skill selection reliable:

```bash
codex exec --sandbox read-only -c 'model_reasoning_effort="xhigh"' --output-last-message .pipeline/external-review.md "Perform a read-only independent architectural and code-health review of the uncommitted changes in this repository. This is not a task-completion review; assume the feature may already satisfy its plan, and focus on whether the diff introduces architectural problems, code smells, incorrect abstractions, unnecessary coupling, unclear ownership boundaries, brittle state flow, security posture regressions, maintainability risks, missing or weak tests, or other issues that should block shipping. First inspect the working tree with git status --short, git diff --stat, git diff --no-ext-diff, git diff --cached --no-ext-diff, and git ls-files --others --exclude-standard as needed. Infer which domain skills apply based on the work accomplished. Explicitly invoke or read relevant skills before reviewing, such as agent-patterns for agent/orchestration changes, codex-security skills for security-sensitive changes, frontend/build-web skills for frontend changes, or other matching local skills. Do not modify files, run destructive commands, commit, merge, or deploy. Output markdown with:
VERDICT: PASS, CHANGES_REQUESTED, or BLOCK
SKILLS_USED:
ARCHITECTURAL_REVIEW:
FINDINGS:
QUESTION_OR_BLOCKER:"
```

If generic `codex exec` is unavailable, fallback to the native review subcommand without a custom prompt and with the long output flag:

```bash
codex exec review --uncommitted -c 'model_reasoning_effort="xhigh"' --output-last-message .pipeline/external-review.md
```

When using the fallback, the external review may not report `SKILLS_USED`. Treat the saved review as the independent artifact anyway, and require a clear `PASS`, `CHANGES_REQUESTED`, or `BLOCK` interpretation before proceeding.

The external review verdict means:

- `PASS`: no requested changes from the independent review
- `CHANGES_REQUESTED`: one or more actionable concerns should be considered before final reporting
- `BLOCK`: review could not complete or found an issue that requires user input

The Leader may triage whether external findings are plausible, in scope, and consistent with the approved plan.

When the Leader agrees with a `CHANGES_REQUESTED` finding, the Leader must spawn Fixer or Executor with the external review findings. The fixing subagent updates `.pipeline/changes.md` with the accepted findings, rejected findings and rationale, files changed, and tests or review stages that must be rerun. After delegated fixes, the Leader must rerun Tester, Final Reviewer, and the External Codex Review Gate.

When the Leader disagrees with a material external finding, the Leader must either spawn another external `codex exec` review with the disputed finding called out or stop for HITL. Only bypass a finding without another review when it is clearly out of scope, factually wrong from artifact evidence, or already covered by an explicit user decision; record that rationale in `.pipeline/run.md`.

## Loop Limits

- Planner/Critic: 5 iterations, then HITL
- Test/Fix: 3 iterations, then HITL unless the next fix is obvious and low risk
- Type Interface/Test: 2 iterations, then HITL
- Review/Fix: 3 iterations, then HITL
- External Review/Fix: 2 iterations, then HITL

Prefer stopping with a precise HITL question over continuing an unbounded loop.
