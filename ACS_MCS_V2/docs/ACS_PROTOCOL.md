# ACS — ABSOLUTE CONTINUITY SYSTEM
## Complete Protocol Documentation

**Version**: 1.1  
**© 2026 James MacAskill. All rights reserved.**  
**Licence**: MIT

---

## CONTENTS

1. [Introduction](#1-introduction)
2. [Executive Summary](#2-executive-summary)
3. [Setting Up ACS on a New Project](#3-setting-up-acs-on-a-new-project)
   - 3a. With an Existing Planning Document (Automated)
   - 3b. Without a Planning Document (Manual)
4. [Starting a Session](#4-starting-a-session)
   - 4a. Claude Code CLI
   - 4b. Claude.ai Chat
5. [The Atomic Task Unit (ATU)](#5-the-atomic-task-unit-atu)
6. [Session Termination](#6-session-termination)
   - 6a. Planned Termination
   - 6b. Emergency Termination
7. [One Protocol, Two Environments](#7-one-protocol-two-environments)
8. [New Projects Only — Do Not Retrofit](#8-new-projects-only--do-not-retrofit)
9. [Document Reference](#9-document-reference)
10. [Script Reference](#10-script-reference)
11. [Conclusion: Things to Remember](#11-conclusion-things-to-remember)

---

## 1. INTRODUCTION

Anyone who has worked on a software project across multiple AI-assisted sessions
will recognise the moment. A new session opens, the handover notes are read, and
something feels wrong. A feature marked complete does not behave as described. A
file that was supposedly committed is not in the repository. Tests that were
passing are now failing, and nothing — not the documentation, not the previous
session's summary, not the memory file — can explain why.

This is not a failure of intelligence. It is a failure of architecture.

AI assistants have no memory between sessions. They read whatever documents are
provided and treat them as ground truth. If those documents say a step is
complete, the assistant proceeds as though it is complete — even if the filesystem
tells a different story. The assistant is not lying. It is reasoning correctly
from incorrect premises. The documents claimed something was done. The documents
were wrong.

The Absolute Continuity System (ACS) solves this by changing what the assistant
is asked to trust. Under ACS, no step is recorded as complete because an assistant
wrote that it was complete. A step is recorded as complete because a verification
command was run, its output matched the expected result, a git commit was made,
and `git log` confirmed the commit actually landed. Documentation becomes a
side-effect of verified actions rather than a substitute for them.

ACS is not bureaucracy for its own sake. Every document has a specific function
that cannot be served by any other. Every rule exists because its absence produced
a specific, observed failure. The system is as lean as the problem allows.

---

## 2. EXECUTIVE SUMMARY

### What ACS Is

A session management protocol ensuring that project documentation reflects
verified reality — at all times, across all sessions, regardless of how or when
any individual session ends.

### The Three Core Rules

**Rule 1 — Nothing is VERIFIED without a commit hash.**
`STATE.md` uses `VERIFIED` exclusively for items where `git log --oneline -1` was
run and the resulting hash is recorded. Everything else is `IN_PROGRESS` or
`PARTIAL`. The document cannot misrepresent reality because the hash either exists
in git history or it does not.

**Rule 2 — `verify_state.py` runs first, every session, no exceptions.**
The script cross-checks every hash in `STATE.md` against actual git history. It
catches the "claimed committed, never actually committed" failure mode and reports
the exact discrepancy type with the exact recovery command required.

**Rule 3 — `CHECKPOINT.md` is live, not a terminal summary.**
Updated after every Atomic Task Unit during a session. If a session collapses
after three of seven planned tasks, `CHECKPOINT.md` already contains confirmed
records of the first three and a documented recovery path for the fourth —
written before the fourth task started, not after the collapse.

### The Five Mechanisms

| # | Mechanism | What it prevents |
|---|---|---|
| 1 | Mandatory Startup Verification | Building on a false picture of project state |
| 2 | Atomic Task Units with Verification Gates | Calling something complete without evidence |
| 3 | Continuous Checkpoint Writing | Losing in-progress state when a session ends abruptly |
| 4 | Credit Horizon Monitoring | Starting tasks that cannot be finished before session end |
| 5 | Structured Session Termination | Leaving undocumented partial state between sessions |

### The Five Documents

| Document | One-line purpose | Location |
|---|---|---|
| `CLAUDE.md` | Claude Code auto-trigger. Under 100 lines always. | Project root |
| `MUST_READ.md` | Session startup brief — tasks, last state, blockers | `.claude/` |
| `STATE.md` | Verified completions. Every row needs a commit hash. | `.claude/` |
| `MEMORY.md` | Architectural decisions, problems solved, context | `.claude/` |
| `CHECKPOINT.md` | Live session log. Updated after every ATU. | `.claude/` |

### The One Rule

> **`STATE.md` receives the word `VERIFIED` only when there is a real git commit hash next to it.**

When in doubt, write `PARTIAL`. An honest `PARTIAL` is worth infinitely more than
a false `VERIFIED` that corrupts the next session's starting assumptions.

---

## 3. SETTING UP ACS ON A NEW PROJECT

ACS is always initialised before any project code is written. Run `setup.sh`
as the first command in a new project repository.

### Prerequisites

- Python 3.8 or later
- Git installed and a repository initialised (or `setup.sh` will initialise one)
- For automated ingestion only: `pip install anthropic python-docx`

---

### 3a. With an Existing Planning Document (Automated)

If a BMAD doc, DevOps plan, product spec, milestone document, or any structured
planning file exists, the entire ACS document set can be populated automatically.

**What automated ingestion produces:**

- `STATE.md` — every milestone from the planning document listed as `NOT_STARTED`,
  grouped by phase and category, ready to become the project's audit trail
- `MUST_READ.md` — first session brief derived from the plan, with tasks,
  description, and phase populated from the document content
- `MEMORY.md` — architectural decisions and external dependencies extracted
  from the document and pre-recorded
- `CLAUDE.md` — generated with the correct project name, phase, and tech stack

**Setup command:**

```bash
bash setup.sh "Project Name" "Description" --input BMAD.md
```

Multiple documents are supported and will be merged before analysis:

```bash
bash setup.sh "Project Name" "Description" --input BMAD.md devops.md architecture.md
```

Word documents are supported:

```bash
bash setup.sh "Project Name" "Description" --input project_spec.docx
```

**After ingestion, review the generated files:**

`STATE.md` — Confirm all milestones are captured. Add any rows missing from the
document. Adjust task sizes (SMALL / MEDIUM / LARGE) if the inference was
incorrect.

`MUST_READ.md` — Confirm the first session tasks are in the right order. Add any
blockers known at this point.

`MEMORY.md` — Confirm the architectural decisions are accurate. Add anything the
planning document implied but did not state explicitly.

**Re-running ingestion after a plan update:**

If the planning document is revised after the project has started, use
`--dry-run` and `--json-only` to review what has changed before overwriting:

```bash
python .claude/scripts/acs_ingest.py --input updated_plan.md --json-only
```

Then manually add new milestones to `STATE.md` as `NOT_STARTED`. Do **not** run
ingestion with `--force` on an in-progress project — it will reset all rows and
overwrite `VERIFIED` entries.

---

### 3b. Without a Planning Document (Manual)

```bash
bash setup.sh "Project Name" "Description"
```

This creates the directory structure and document templates. After running:

1. Open `.claude/STATE.md` and add a row for every planned milestone, set to
   `NOT_STARTED`. This is the project audit trail — populate it before writing
   any code.

2. Open `.claude/MUST_READ.md` and complete the first session tasks, tech stack,
   and environment details.

3. Run the verification script to confirm the baseline is clean:

```bash
python .claude/scripts/verify_state.py
# Expected: ✅ SAFE TO PROCEED — all checks passed
```

4. Commit all ACS files:

```bash
git add .claude/ CLAUDE.md .gitignore .env.example
git commit -m "chore: initialise ACS protocol"
```

---

### File Structure After Setup

```
project-root/
├── CLAUDE.md                        ← Claude Code auto-trigger (under 100 lines)
├── .env.example                     ← Environment variable template (committed)
├── .env                             ← Actual env vars (.gitignored, never committed)
├── .gitignore                       ← Includes ACS runtime files and secrets
│
└── .claude/
    ├── MUST_READ.md                 ← Session startup brief
    ├── STATE.md                     ← Verified completions ground truth
    ├── MEMORY.md                    ← Architectural decisions and context
    ├── CHECKPOINT.md                ← Live session state (created at first session)
    ├── PROTOCOL.md                  ← Quick-reference card
    └── scripts/
        ├── verify_state.py          ← Startup verification script
        └── acs_ingest.py            ← Planning document ingestion script
```

---

## 4. STARTING A SESSION

The startup sequence is the most critical part of the protocol. No code is written
before the startup sequence is confirmed complete.

---

### 4a. Claude Code CLI — Automatic Startup

Claude Code reads `CLAUDE.md` from the project root automatically at session
start. Provided `CLAUDE.md` contains the ACS startup instructions (as generated
by `setup.sh`), the sequence runs without user action.

**What happens automatically:**

1. `CLAUDE.md` is read — startup instructions loaded
2. `verify_state.py` is run — actual project state checked
3. `MUST_READ.md` is read — session brief loaded
4. `CHECKPOINT.md` is read (if present) — any prior emergency state detected

**What the user must confirm before proceeding:**

Claude Code's first response should contain all five of these. If any are missing,
ask for them explicitly before starting work:

```
✓ verify_state.py result: exit 0 (clean) or exit 1 (discrepancies listed)
✓ Current git HEAD: output of git log --oneline -1
✓ Last verified ATU: from STATE.md
✓ CHECKPOINT.md status: clean / recovery needed (describe)
✓ Today's planned tasks: from MUST_READ.md
```

**If `verify_state.py` returns exit 1:**

Do not proceed. Resolve the discrepancy first. Discrepancy types:

| Type | Meaning | Action |
|---|---|---|
| A | Commit hash in STATE.md does not exist in git | Commit the missing work now, or correct STATE.md |
| B | Tests failing | Fix tests before any new work |
| C | Service not running | Restart service or flag as blocker |
| D | CHECKPOINT.md shows mid-task termination | Complete or roll back the incomplete ATU first |
| E | Required ACS file missing | Recreate from template |

---

### 4b. Claude.ai Chat — Manual Startup

There is no automatic file reading in Claude.ai Chat. The user provides context
explicitly. Follow this sequence without skipping steps.

**Step 1 — Open a new conversation.**
Start fresh. Do not continue from a previous conversation — prior context is
unreliable and may mislead.

**Step 2 — Run `verify_state.py` in your terminal.**

```bash
python .claude/scripts/verify_state.py
```

If it returns `exit 1`: resolve the discrepancy before starting the session.
If it returns `exit 0`: note this result to include in your opening message.

**Step 3 — Paste this as your first message:**

```
You are operating under the ACS (Absolute Continuity System) protocol.
Before doing anything else, complete the startup sequence:

1. MUST_READ.md contents:
[PASTE .claude/MUST_READ.md HERE]

2. STATE.md contents:
[PASTE .claude/STATE.md HERE]

3. verify_state.py result: [PASTE RESULT — exit 0 or discrepancies]

4. CHECKPOINT.md (if it exists):
[PASTE .claude/CHECKPOINT.md HERE, or write "No CHECKPOINT.md present"]

Confirm the following before we start:
- Last verified ATU from STATE.md
- CHECKPOINT.md status (clean / recovery needed)
- Today's planned tasks from MUST_READ.md
- Any blockers

Do not write any code until these are confirmed.
```

**Step 4 — Wait for confirmation, then begin.**

At session end, paste the updated `CHECKPOINT.md`, `STATE.md`, and `MUST_READ.md`
back and ask the assistant to verify they are accurate before closing.

---

### Session Startup Comparison

| Action | Claude Code | Claude.ai Chat |
|---|---|---|
| Read `CLAUDE.md` | Automatic | Not applicable |
| Run `verify_state.py` | Automatic | User runs in terminal; pastes result |
| Read `MUST_READ.md` | Automatic | User pastes contents |
| Read `CHECKPOINT.md` | Automatic | User pastes if present |
| Confirm five startup points | Should appear in first response | Must be requested |

---

## 5. THE ATOMIC TASK UNIT (ATU)

Every piece of work is defined as an Atomic Task Unit before it begins. An ATU is
the smallest unit of work that results in a verifiably changed project state.

### ATU Structure

```
ATU-[ID]: [Name]

Intent:   What this changes (one sentence)
Actions:  The exact steps — commands, files to create/edit
Verify:   The command that proves it worked, and its expected output
Commit:   git add [files] && git commit -m "[message]"
Update:   Which rows of STATE.md to change to VERIFIED
```

### ATU Example

```
ATU-003: Implement 60-lag price feature extraction

Intent:   feature_engineering/price_features.py returns a (60,) shaped
          vector of log returns for a given asset and date

Actions:  Create feature_engineering/price_features.py
          Create tests/test_price_features.py

Verify:   pytest tests/test_price_features.py -v
          → all 5 tests pass
          python -c "from feature_engineering.price_features import extract;
                     v = extract('BTC', '2024-01-01');
                     assert v.shape == (60,)"
          → no assertion error

Commit:   git add feature_engineering/price_features.py
                  tests/test_price_features.py
          git commit -m "feat: 60-lag price feature extraction, tests passing"

Update:   STATE.md → Features → price_lags_60:
          VERIFIED [commit hash] [timestamp]
```

### The Verification Gate

A task is complete **when and only when** all five are true:

- [ ] The verify command was run and output matches expected
- [ ] `git commit` was run with a descriptive message
- [ ] `git log --oneline -1` confirms the commit actually landed (hash shown)
- [ ] `STATE.md` updated with that exact hash
- [ ] `CHECKPOINT.md` updated to show this ATU as COMPLETE

The phrase "complete" is never used without showing this evidence.

### Task Size Classification

| Size | Duration | Examples |
|---|---|---|
| MICRO | < 5 min | Single function, run a command, one config change |
| SMALL | 5–15 min | One module, one test file, one configuration |
| MEDIUM | 15–45 min | Feature with tests, infrastructure component |
| LARGE | 45+ min | Multiple interconnected components |

**Credit Horizon Rule:** Before starting any MEDIUM or LARGE task, state:

```
Task size: [SIZE]
Estimated completion: [time]
Session capacity remaining: [assessment]
Safe to start: YES / NO
```

If NO: decompose into smaller ATUs, or defer to the next session. Never start
a LARGE task if there is doubt about finishing it before session end.

**The 80% Rule:** When approximately 80% of session capacity is used, stop
starting new tasks. Finish and verify the current ATU, then execute the
termination protocol. Three fully verified tasks outperform five partial ones
in every subsequent session.

---

## 6. SESSION TERMINATION

### 6a. Planned Termination

Execute this sequence when the task list is complete or the 80% threshold is
reached:

```
1. Complete the current ATU fully — no half-finished tasks
2. Run verify command and confirm output
3. Run git commit and confirm with git log --oneline -1
4. Update STATE.md with the new commit hash
5. Update CHECKPOINT.md → Status: COMPLETED
   - List all ATUs completed this session with commit hashes
   - List any tasks deferred with reason
6. Update MEMORY.md with any architectural decisions from this session
7. Write MUST_READ.md for the next session
8. Run: git push origin [branch]
9. Run: git status → must show "nothing to commit, working tree clean"
10. Confirm in chat: "SESSION TERMINATION COMPLETE. Next session: ATU-[X]"
```

### 6b. Emergency Termination

When a session is ending abruptly — context window near-exhausted, user must
leave urgently, unexpected crash. Execute in priority order:

```
PRIORITY 1 — Commit current state (30 seconds)
  git add -A
  git commit -m "WIP: SESSION-EMERGENCY — [describe current state]"
  git push origin [branch]

PRIORITY 2 — Document the emergency in CHECKPOINT.md (60 seconds)
  Append:
  ## EMERGENCY TERMINATION [timestamp]
  Current ATU: [ID and name]
  State: [FUNCTIONAL / BROKEN / PARTIAL]
  Files modified: [list from git diff --name-only]
  Recovery:
    If FUNCTIONAL: continue from ATU-[ID] next session
    If BROKEN: git checkout [last-safe-hash] to roll back
    If PARTIAL: [specific instructions]
  Last safe commit: [hash]

PRIORITY 3 — Flag MUST_READ.md (30 seconds)
  Add to top: "⚠️ EMERGENCY TERMINATION — read CHECKPOINT.md before anything else"

PRIORITY 4 — Update STATE.md if time permits
  Change any IN_PROGRESS items to PARTIAL (not VERIFIED)
```

---

## 7. ONE PROTOCOL, TWO ENVIRONMENTS

There is one protocol. There are two environments that run it.

```
PROJECT_PROTOCOL_MASTER.md / docs/ACS_PROTOCOL.md
        │
        │  defines the rules, documents, and scripts
        │
        ├── Claude.ai Chat ──────► User pastes MUST_READ.md and STATE.md
        │                          User runs verify_state.py in terminal
        │                          User pastes result and CHECKPOINT.md
        │                          User confirms five startup points
        │
        └── Claude Code CLI ─────► CLAUDE.md triggers automatic startup
                                   verify_state.py runs automatically
                                   MUST_READ.md and CHECKPOINT.md read automatically
                                   First response confirms startup state
```

The documents, scripts, ATU structure, and termination protocol are identical.
Claude Code automates what the user must manually trigger in Chat.

**`CLAUDE.md` must stay under 100 lines.** It is read at the start of every
Claude Code session. Every line added consumes context window capacity on every
session, including lines no longer relevant. Current state belongs in
`MUST_READ.md`. Decisions belong in `MEMORY.md`. `CLAUDE.md` contains startup
instructions and a brief project summary — nothing else.

---

## 8. NEW PROJECTS ONLY — DO NOT RETROFIT

ACS is initialised before any project code is written. It is not retrofitted onto
existing projects with undocumented history.

Retrofitting creates a `STATE.md` that cannot be fully trusted — the exact problem
ACS exists to solve.

### For Existing Projects Being Resumed

If an existing project is being brought under ACS for the first time, treat the
first session as a one-time archaeological survey:

1. Run `git log --oneline` to establish what is actually committed
2. Compare git history against existing documentation
3. Write a new `STATE.md` based only on what can be verified in git
4. Mark anything that cannot be verified as `NOT_STARTED`
5. Run `setup.sh` to create the directory structure, then replace the templates
   with the verified content from step 3

A verified `NOT_STARTED` is a reliable foundation. A claimed `VERIFIED` without
evidence is not.

### For New Phases of a Multi-Phase Project

Continue in the same repository if the codebase is shared:

- Add new rows to `STATE.md` for the new phase's milestones, set to `NOT_STARTED`
- Update `MUST_READ.md` to reflect the phase transition
- Add a phase transition entry to `MEMORY.md`
- Do not create a new repository unless the new phase is a genuinely separate
  codebase

---

## 9. DOCUMENT REFERENCE

### MUST_READ.md

```markdown
# MUST READ — SESSION STARTUP BRIEF
**Last updated**: [ISO timestamp]
**Emergency flag**: NONE | ⚠️ EMERGENCY TERMINATION — read CHECKPOINT.md first

## ⚡ IMMEDIATE ACTIONS
1. Run: python .claude/scripts/verify_state.py
2. Resolve discrepancies before any new work
3. Read CHECKPOINT.md if Emergency flag is set

## Project: [Name]
[One paragraph description]

## Current Phase
**Phase**: [N — Name]
**Focus**: [current milestone]
**Blockers**: NONE | [describe]

## Last Verified Completion
**ATU**: [ID and name]
**Commit**: [hash]
**Timestamp**: [ISO]

## This Session's Tasks
1. ATU-[ID]: [name] — [SMALL/MEDIUM/LARGE]
2. ATU-[ID]: [name] — [SMALL/MEDIUM/LARGE]

## Architecture Summary
- [3-5 bullets — update when architecture changes]

## Do NOT Do This Session
- [Anything explicitly out of scope]
```

---

### STATE.md

```markdown
# PROJECT STATE — VERIFIED COMPLETIONS ONLY
**Rule**: Nothing is added here without a verified commit hash.

## LEGEND
VERIFIED = confirmed with commit hash | IN_PROGRESS = this session
PARTIAL = started, recovery path in CHECKPOINT.md | NOT_STARTED = not begun
BLOCKED = blocker in MUST_READ.md

## [Phase Name]

### [Category]
| ID | Milestone | Size | Status | Commit | Verified |
|----|-----------|------|--------|--------|----------|
| M-001 | [name] | MEDIUM | NOT_STARTED | — | — |

## Git State
- Branch: [name]
- Last push confirmed: [hash] at [timestamp]
- Remote sync: IN SYNC | BEHIND | AHEAD
```

---

### CHECKPOINT.md

```markdown
# SESSION CHECKPOINT
**Session Started**: [ISO]
**Last Updated**: [ISO]  ← update this after every ATU
**Status**: IN_PROGRESS | COMPLETED | EMERGENCY_TERMINATED

## Credit Status
- Tasks planned: [N] | Completed: [N] | Session end trigger: [reason]

## ATU Log

### ATU-[ID]: [Name] ✅ COMPLETE
- Verify output: [paste actual terminal output]
- Commit: [hash] — confirmed via git log --oneline -1
- STATE.md updated: ✅

### ATU-[ID]: [Name] 🔄 IN PROGRESS
- Work done: [describe]
- Files modified: [list]
- NOT YET COMMITTED
- Rollback: git checkout -- [files]

## Emergency Recovery (write this BEFORE starting each ATU)
If session ends right now:
- Last safe state: ATU-[ID] commit [hash]
- Incomplete: [describe]
- Recovery commands: [exact steps]
```

---

### MEMORY.md

```markdown
# PROJECT MEMORY — PERSISTENT CONTEXT

## Architectural Decisions
### [ISO]: [Decision Name]
**Decision**: [what]
**Rationale**: [why]
**Alternatives rejected**: [what and why]

## Problems Encountered and Resolved
### [ISO]: [Problem Name]
**Problem / Root cause / Solution / Prevention**

## External Dependencies
| Dependency | Version | Purpose | First encountered |

## Changed Understanding
### [ISO]: [What changed]
We thought [X]. We now know [Y] because [evidence].

## Performance Baselines
| Metric | Baseline | Target | Current Best | Date |
```

---

## 10. SCRIPT REFERENCE

### `verify_state.py`

Runs at session start. Checks actual project state against `STATE.md` claims.

```bash
python .claude/scripts/verify_state.py
```

**Checks performed:**
- All ACS files present
- Every commit hash in `STATE.md` exists in git history (Type A)
- No uncommitted changes from a previous session (Type D)
- Remote sync status
- Test suite passing (Type B)
- `CHECKPOINT.md` status — detects mid-task terminations (Type D)
- `CLAUDE.md` present and contains no secrets (Type E)

**Returns:** `exit 0` (safe to proceed) or `exit 1` (discrepancies found)  
**Writes:** `.claude/last_verification.json` (gitignored)

---

### `acs_ingest.py`

Reads planning documents and auto-populates ACS documents.

```bash
# Single document
python .claude/scripts/acs_ingest.py --input BMAD.md

# Multiple documents merged
python .claude/scripts/acs_ingest.py --input BMAD.md devops.md

# Word document
python .claude/scripts/acs_ingest.py --input spec.docx

# Dry run — see what would be generated
python .claude/scripts/acs_ingest.py --input plan.md --dry-run

# Extract JSON only — useful for reviewing before writing
python .claude/scripts/acs_ingest.py --input plan.md --json-only

# Force overwrite of existing files
python .claude/scripts/acs_ingest.py --input plan.md --force
```

**Supported formats:** `.md`, `.txt`, `.docx`  
**Requires:** `ANTHROPIC_API_KEY` in environment or `.env` file  
**Writes:** `STATE.md`, `MUST_READ.md`, `MEMORY.md`, `CLAUDE.md`, `PROTOCOL.md`,
`.claude/ingestion_result.json` (gitignored)

---

### `setup.sh`

Single-command project setup. Combines initialisation and optional ingestion.

```bash
# Basic setup
bash setup.sh "Project Name" "Description"

# With planning document
bash setup.sh "Project Name" "Description" --input BMAD.md

# Dry run
bash setup.sh "Project Name" "Description" --dry-run

# Force overwrite (existing project being reset)
bash setup.sh "Project Name" "Description" --force
```

**Performs:** git init (if needed), directory structure, script installation,
`.gitignore` configuration, `.env.example` creation, optional ingestion,
verification run, initial commit.

---

## 11. CONCLUSION: THINGS TO REMEMBER

### The One Rule

`STATE.md` receives the word `VERIFIED` only when there is a real git commit hash
next to it. Every other mechanism exists to enforce this rule. When in doubt,
write `PARTIAL`.

---

### The Four Failure Modes (in order of likelihood)

**1. `MUST_READ.md` not updated at session end.**
The next session reads a brief describing the previous session's starting point,
not its ending point. Treat writing `MUST_READ.md` as mandatory as `git push`.

**2. `CHECKPOINT.md` written as a summary rather than updated live.**
Once this drift begins, the emergency recovery value disappears. Update
`CHECKPOINT.md` after every ATU, during the session, not at the end.

**3. Credit horizon check skipped.**
A task seems quick. The check is skipped. The session ends mid-task. The next
session opens to an undocumented partial state. The pre-task credit check is a
gate, not an estimate. If in doubt, do not start the task.

**4. Context window exhaustion unrecognised.**
The assistant starts asking questions it already answered, or contradicts earlier
decisions. When these symptoms appear, execute the termination protocol
immediately. A fresh session outperforms a degraded long session every time.

---

### The Discipline That Matters Most

ACS can be circumvented at any point. Nothing technically prevents writing
`VERIFIED` without a commit hash. The system works because its users understand
why each rule exists — not as process for its own sake, but as the minimum
necessary response to specific failure modes they have experienced.

ACS is not asking for more work. It is asking for work already intended to be done
to be done in the right order and with evidence rather than assertion.

---

### The Ten Golden Rules

```
 1. Verify before trusting — run verify_state.py first, every session
 2. Never claim complete — show verification output, not intention
 3. Commit hash or it did not happen — git log confirms every time
 4. STATE.md = reality, not intention
 5. CHECKPOINT.md is live — update after every ATU, not at session end
 6. Check credit before medium or large tasks — gate, not estimate
 7. 80% rule — stop starting, finish current work cleanly
 8. Emergency commit — always better than undocumented partial state
 9. Partial is documented — never leave partial work without a recovery path
10. MUST_READ.md is written before this session ends, not by the next one
```

---

### For Every New Project

Run `setup.sh` before writing any code. Populate `STATE.md` with all planned
milestones as `NOT_STARTED` before the first ATU. Let the progression from
`NOT_STARTED` through `PARTIAL` to `VERIFIED` become the verified audit trail
of the project.

The person who will most benefit from a well-written `MUST_READ.md` is the
person starting the next session — often the same person, days or weeks later,
who has forgotten what they were doing and why. Write it for that person.

---

*ACS v1.1 — One protocol. One script. One source of truth.*  
*© 2026 James MacAskill. MIT Licence.*
