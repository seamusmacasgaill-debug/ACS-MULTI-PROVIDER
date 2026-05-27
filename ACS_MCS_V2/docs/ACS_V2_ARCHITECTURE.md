# ACS v2 — Hooks Layer Architecture

**Status:** Active from 2026-05-27  
**Extends:** ACS_PROTOCOL.md (v1 session management — still applies)

---

## Why v2 exists

ACS v1 solved the cross-session memory problem: state is verified before every session, commits are required for completion, checkpoints are live. That works.

v1 did not solve the **within-session forgetting problem.** In a long debugging thread, context compaction summarises away the specific contract rules that were established at session open. By the time you open a pipeline file deep in a thread, those rules are gone. The agent edits without them.

v2 adds one layer: **hooks that fire at the moment of tool use**, injecting contract rules into the conversation at the exact moment they are needed — regardless of where you are in the thread, regardless of what has been compacted.

---

## The Two-Layer Model

```
ACS v1 (session layer)          ACS v2 (tool-use layer)
─────────────────────           ───────────────────────
verify_state.py                 ~/.claude/settings.json
  ↓ runs at session open          ↓ fires at every Edit/Write
STATE.md                        ~/.claude/hooks/acs-contract-check.sh
CHECKPOINT.md                     ↓ reads
MUST_READ.md                    .acs/contract.json (per project)
MEMORY.md                         ↓ outputs
                                contract rules injected mid-conversation
```

Both layers are required. v1 ensures sessions start from verified state. v2 ensures the rules survive the session.

---

## How v2 works

### 1. Global hook (install once, works everywhere)

`~/.claude/settings.json` registers a `PreToolUse` hook for Edit and Write tool calls:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/acs-contract-check.sh"
          }
        ]
      }
    ]
  }
}
```

The hook fires before every file edit. For files that are NOT in a project's contract, it outputs nothing and exits silently. For pipeline files, it injects the contract rules.

### 2. Hook script (~/.claude/hooks/acs-contract-check.sh)

1. Parses the `file_path` from the tool call JSON on stdin
2. Walks up the directory tree looking for `.acs/contract.json`
3. If found, checks whether `file_path` matches any pattern in `pipeline_files`
4. If matched: outputs a formatted contract reminder including the hard rules and blast zone matrix
5. Always exits 0 — warns but never blocks

### 3. Per-project contract config (.acs/contract.json)

Lives in the project repo root. Committed to git. Defines:
- `pipeline_files`: filename patterns that trigger the contract check
- `rules`: the specific hard rules for this project
- `contract_doc`: path to the full contract document (relative to project root)
- `quality_gate`, `smoke_test`, `session_gate`: references to other project docs

```json
{
  "project": "MyProject",
  "contract_doc": "docs/PIPELINE-CONTRACT.md",
  "pipeline_files": ["critical-file.ts", "processor/route.ts"],
  "rules": [
    "Rule 1 — the hard rule that must be in working memory",
    "Rule 2"
  ],
  "quality_gate": "6-star"
}
```

---

## Installing ACS v2

### New machine / first-time setup (run once globally)

```bash
cd ~/GitHub/ACS/acs-repo
bash scripts/install_global.sh
```

This installs `~/.claude/hooks/acs-contract-check.sh` and creates `~/.claude/settings.json`.

### Adding ACS to a new project

```bash
cd /path/to/your-project
bash ~/GitHub/ACS/acs-repo/scripts/init_project.sh
```

Interactive setup. Creates `.acs/contract.json`. Commit it to the project.

### Adding ACS to an existing project (manual)

1. Create `.acs/contract.json` using `templates/contract.json` as a guide
2. Fill in `pipeline_files` (the critical files for your project)
3. Fill in `rules` (the hard rules that must be checked before editing them)
4. `git add .acs/contract.json && git commit`

---

## What goes in pipeline_files

A pipeline file is any file where an edit in isolation can break another file it has never imported. This happens when:

- File A produces output that File B post-processes (generator → post-processor)
- File A manages state that File C reads (state producer → state consumer)
- File A establishes a CSS/API contract that File D depends on (contract establisher → contract consumer)

In WebBuilder, the pipeline is: `wrapInDocument()` → `style-swap/update-colours` → `handleSaveEdits`. Editing any one layer can break the others.

In any project, ask: "if I change this file and get it wrong, which other file breaks silently?"

---

## What goes in rules

The three to five most important things that must be in working memory when touching that file. Not general coding guidelines — the specific invariants for THIS project that have historically caused bugs when violated.

Good rule: "Any CSS var replacement must be followed by restoring the .bg-white contrast-fix block"  
Bad rule: "Write clean code" (too generic, no actionable check)

Rules should be:
- Specific enough to be checklist items
- Short enough to be read in 10 seconds
- Written from past failures, not aspirational best practice

---

## Portability to new projects

For any new project with an interconnected pipeline:

1. Run `init_project.sh` — creates the config
2. Identify the pipeline files (ask: "which files can break other files silently?")
3. Write the rules (ask: "what are the invariants that caused the most bugs?")
4. Commit `.acs/contract.json`

The global hook (installed once) handles the rest automatically.

---

## Relationship to ACS v1

v2 does not replace v1. v1 session protocol still applies:
- `verify_state.py` still runs at session open
- `STATE.md` still requires commit hashes for VERIFIED items
- `CHECKPOINT.md` is still live during sessions
- `MUST_READ.md` still states the session brief

v2 adds: automatic contract enforcement mid-session, regardless of context state.

Together: v1 ensures you start from truth. v2 ensures you don't lose the rules while working.
