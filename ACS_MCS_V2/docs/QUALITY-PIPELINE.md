# QUALITY-PIPELINE.md
## AI Code Quality & Safety Gate for ACS

> Scope note: This pipeline is a **quality-control layer** that runs alongside ACS’s existing continuity layer.  
> ACS continuity (STATE.md, MEMORY.md, MUST_READ.md, verify_state.py) handles provider interruption, session recovery, checkpointing, and resumability.  
> This pipeline handles scope enforcement, deterministic validation, evidence validation, and hidden-bug review.  
> They are complementary and decoupled.

---

## 1. Gate architecture

The pipeline is a strict, sequential gate system. Each gate must pass before the next begins.

| Gate | Name                        | Responsibility                                                        | Artefact produced                   |
|------|-----------------------------|------------------------------------------------------------------------|-------------------------------------|
| 0    | Implementation              | Agent generates initial patch under a task contract                   | `patch.diff`, `changed_files.txt`   |
| 1    | Mechanical & Scope         | Scope check + deterministic tools + Janitor loop (≤ N iterations)     | `tool_output.json`, `janitor_iterations.log` |
| 2a   | Evidence & Acceptance (Validator) | Checks contract alignment, scope, CI/tools, evidence completeness | `validator_report.json`, `decision.json` |
| 2b   | Semantic & Hidden Bugs (Reviewer) | Runs hidden-bug checklist against diff + codebase                | `reviewer_report.md`                |
| 3    | Human Sign-off             | Developer reviews evidence bundle and merges or rejects               | MR/PR + production commit           |

**Key separation**

- **Validator (Gate 2a)**  
  Mechanical, structural, and evidence gate.  
  Answers: *Did the agent stay in scope? Is there enough proof to move to semantic review?*

- **Reviewer (Gate 2b)**  
  Semantic and behavioural gate.  
  Answers: *Does this behave correctly under real conditions, including edge cases and concurrency?*

---

## 2. Task contracts

All gates anchor to a machine-readable contract.

**Location**

```text
.acs/tasks/<task-id>.yml
```

**Schema (example)**

```yaml
task_id: "feat-user-pagination"
goal: "Add offset-based pagination to GET /users endpoint"

scope:
  allowed_files:
    - "backend/users/controller.ts"
    - "backend/users/repository.ts"
    - "backend/users/types.ts"
  forbidden_files:
    - "backend/auth/**"
    - "package.json"
    - "tsconfig.json"

acceptance_criteria:
  - id: "AC1"
    text: "GET /users accepts page and pageSize query params"
  - id: "AC2"
    text: "Returns { data: User[], total: number }"
  - id: "AC3"
    text: "Returns 400 for page < 1 or pageSize < 1"

risk_level: "medium"   # low | medium | high | critical

test_requirements:
  min_changed_line_coverage: 0.80
  required_new_tests:
    - "backend/users/__tests__/pagination.test.ts"
  required_commands:
    - "npm run lint"
    - "npm run typecheck"
    - "npm test -- pagination"
    - "npm run build"

escalation_policy:
  max_janitor_loops: 3
  escalate_on_new_failure_class: true
  escalate_on_scope_violation: true
  escalate_on_oscillation: true

continuity:
  resume_from_evidence: true
  checkpoint_after_each_gate: true
```

---

## 3. Evidence bundle layout

Each task has a structured evidence bundle.

**Location**

```text
.acs/evidence/<task-id>/
```

**Files**

- `task_contract.yml` — exact contract used for this run.
- `patch.diff` — patch the implementation agent produced.
- `changed_files.txt` — one path per line, used by the scope checker.
- `tool_output.json` — structured output of all deterministic tools run in Gate 1 (lint, type, tests, build).
- `janitor_iterations.log` — chronological log of janitor passes (inputs, summary, outcome).
- `validator_report.json` — Gate 2a decision and rationale.
- `reviewer_report.md` — Gate 2b hidden-bug findings.
- `decision.json` — final machine-readable gate decisions and escalation flags.
- `resume_state.json` — current gate, iteration count, and next step if interrupted.

`resume_state.json` is used by the continuity layer so that an interrupted pipeline (e.g. provider outage mid-janitor loop) can resume without starting again from scratch.

---

## 4. Gate sequence and integration points

### Gate 0 — Implementation

**Who**: Implementation agent  
**Input**: `.acs/tasks/<task-id>.yml`, repository code  
**Steps**

1. Read the task contract.
2. Plan the work and list intended changed files.
3. Apply changes only to `scope.allowed_files`.
4. Produce:
   - `patch.diff`
   - `changed_files.txt`
   - an implementation summary (for validator and reviewer).

**Output written to evidence**

- `patch.diff`
- `changed_files.txt`
- updated `task_contract.yml` copy (if needed).

---

### Gate 1 — Mechanical & Scope

**Who**: Scripts + Janitor agent  
**Input**: `patch.diff`, `changed_files.txt`, task contract

**Script**: `scripts/check_scope.py`

- Compares `changed_files.txt` with `scope.allowed_files` and `scope.forbidden_files`.
- Fails immediately on any violation.

**Script**: `scripts/run_quality_gate.sh`

Typical steps:

1. Run deterministic commands from `test_requirements.required_commands`.
2. Parse their output into `tool_output.json` (grouped by category: lint, type, build, tests).
3. If there are no failures:
   - Write `tool_output.json`.
   - Update `resume_state.json` to mark Gate 1 as complete.
4. If there are failures:
   - Invoke the Janitor agent with:
     - `tool_output.json`
     - `patch.diff`
     - `changed_files.txt`
     - task contract.
   - Janitor returns a minimal corrective patch and a summary.
   - Apply the patch.
   - Re-run the deterministic commands.
   - Append a new entry to `janitor_iterations.log`.
   - Increment the loop count in `resume_state.json`.

**Retry and escalation**

- A “loop” = one full cycle of:
  - run tools → call janitor → re-run tools.
- Maximum loops = `escalation_policy.max_janitor_loops`.
- Escalate immediately if:
  - scope violation is detected,
  - a new failure category appears after a janitor edit,
  - the same failure repeats twice without improvement,
  - failures oscillate between categories (fixing A reopens B).

On escalation, Gate 1 marks the task as `NEEDS HUMAN REVIEW` in `decision.json` and stops.

---

### Gate 2a — Validator (Evidence & Acceptance)

**Who**: Validator agent  
**Input**

- `task_contract.yml`
- `patch.diff`
- `changed_files.txt`
- `tool_output.json`
- `janitor_iterations.log`
- implementation summary

**Checks**

- Contract alignment:
  - Work matches `goal`.
  - No out-of-scope changes.
- Scope compliance:
  - All changed files in `allowed_files`.
- Acceptance criteria:
  - Each criterion mapped to evidence (tests, diffs, or reasoning).
- Test proof:
  - Required commands ran.
  - Changed-line coverage meets `min_changed_line_coverage` if available.
- Evidence completeness:
  - All required files present in the evidence directory.
- Replayability:
  - Another agent/human could reproduce the result from the artefacts.

**Decisions**

- `PASS`
- `PASS_WITH_CONDITIONS`
- `FAIL`
- `NEEDS_HUMAN_REVIEW`

**Output**

- `validator_report.json` (detailed)
- Update to `decision.json` (Gate 2a state)
- Update to `resume_state.json` (Gate 2a complete or escalated)

Validator does **not** do deep semantic review; it ensures there is enough structured proof to justify running Gate 2b.

---

### Gate 2b — Reviewer (Semantic & Hidden Bugs)

**Who**: Reviewer agent  
**Input**

- Same bundle as validator
- `validator_report.json` + Gate 2a decision

**Scope**

- Only runs if Gate 2a result is `PASS` or `PASS_WITH_CONDITIONS` (unless a human forces it).
- Checks semantic risks: correctness, edge cases, failure handling, data integrity, security, concurrency, performance, contracts, observability, test adequacy.

**Output**

- `reviewer_report.md` (structured by category)
- Updates `decision.json` (Gate 2b state)
- Update `resume_state.json` (Gate 2b complete or escalated)

---

### Gate 3 — Human Sign-off

**Who**: Human reviewer  
**Input**

- MR/PR with code changes
- Full evidence bundle for the relevant task-id
- `validator_report.json`
- `reviewer_report.md`
- `decision.json`

**Responsibilities**

- Review high-risk issues and unresolved “NOT PROVEN” items.
- Decide whether to merge or reject.
- Optionally add new invariants, tests, or checklist items for future runs.

**Output**

- Merge decision in VCS
- Any follow-up tasks or contract updates

---

## 5. Telemetry

All stage executions append a line to `.acs/pipeline.log`:

```text
2026-04-22T13:45:12Z feat-user-pagination GATE1 PASS loops=1 duration_ms=8423
2026-04-22T13:45:29Z feat-user-pagination GATE2A PASS duration_ms=1020
2026-04-22T13:45:36Z feat-user-pagination GATE2B PASS duration_ms=2110
```

Format (recommended):

```text
timestamp,task_id,gate,result,loops=<int>,duration_ms=<int>,notes=<optional>
```

This lets you see how often each gate catches issues and whether the pipeline is earning its keep.

---

## 6. Prompt artefacts

See `.acs/prompts/`:

- `implementer.md`
- `janitor.md`
- `validator.md`
- `reviewer.md`

Each prompt is designed to work against the artefacts and structure defined here.