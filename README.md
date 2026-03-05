# ACS — Absolute Continuity System

**A session management protocol for multi-session AI-assisted software development.**

ACS solves the most common failure mode in AI-assisted development: documentation that claims work is complete when the codebase tells a different story. It does this by enforcing a simple rule — nothing is recorded as complete without a verified git commit hash.

---

## The Problem

AI coding assistants have no memory between sessions. Every session starts from whatever context you provide. When that context is wrong — claiming commits that never landed, tests that are now failing, services that have stopped — the assistant builds on a false picture. The error compounds session by session until the gap between documented progress and actual progress becomes the primary obstacle to getting anything done.

## The Solution

ACS ensures that project documentation **reflects verified reality**, not intention. It uses five interlocking mechanisms:

1. **Startup Verification** — a script checks actual git/test state against STATE.md before every session
2. **Atomic Task Units** — every task has a verification gate; "complete" means evidence, not assertion
3. **Live Checkpointing** — CHECKPOINT.md is updated after every task, not summarised at session end
4. **Credit Horizon Monitoring** — prevents starting tasks that cannot be finished before session end
5. **Structured Termination** — whether planned or abrupt, every session ends in a documented, recoverable state

ACS works with both **Claude.ai Chat** and **Claude Code CLI**. Claude Code automates the startup sequence; Chat requires a manual trigger. The documents, rules, and verification script are identical.

---

## Quickstart

### Option A — New project, no existing planning document

```bash
# 1. Clone ACS scripts into your project
git clone https://github.com/yourusername/acs.git .acs-setup
bash .acs-setup/setup.sh "My Project" "One-line description"
rm -rf .acs-setup
```

### Option B — New project with an existing BMAD / DevOps / spec document

```bash
# Requires: ANTHROPIC_API_KEY set in environment or .env file
git clone https://github.com/yourusername/acs.git .acs-setup
bash .acs-setup/setup.sh "My Project" "Description" --input BMAD.md
rm -rf .acs-setup
```

### Option C — Manual script-by-script

```bash
# Copy the three scripts into your project
cp scripts/verify_state.py scripts/acs_ingest.py scripts/init_acs.sh /your/project/

# Initialise
bash init_acs.sh "My Project" "Description"

# Optionally ingest planning document
python acs_ingest.py --input BMAD.md
```

After setup, confirm everything is working:

```bash
python .claude/scripts/verify_state.py
# Should print: ✅ SAFE TO PROCEED — all checks passed
```

---

## Repository Contents

```
acs/
├── README.md                   ← This file
├── setup.sh                    ← Single-command setup entry point
├── LICENSE
│
├── docs/
│   ├── ACS_PROTOCOL.md         ← Complete protocol documentation
│   └── CHANGELOG.md
│
├── scripts/
│   ├── verify_state.py         ← Session startup verification script
│   ├── init_acs.sh             ← Project initialisation script
│   └── acs_ingest.py           ← Planning document ingestion script
│
└── templates/
    ├── CLAUDE.md               ← Claude Code auto-trigger template
    ├── MUST_READ.md            ← Session startup brief template
    ├── STATE.md                ← Verified completions template
    ├── MEMORY.md               ← Persistent context template
    ├── CHECKPOINT.md           ← Live session state template
    └── PROTOCOL.md             ← Quick-reference card
```

---

## The Five Documents

| Document | Purpose | Updated |
|---|---|---|
| `CLAUDE.md` | Claude Code auto-trigger. Under 100 lines always. | When phase changes |
| `.claude/MUST_READ.md` | Session startup brief — tasks, state, blockers | End of every session |
| `.claude/STATE.md` | Verified completions. Every row needs a commit hash. | After every ATU |
| `.claude/MEMORY.md` | Architectural decisions, problems solved, context | When understanding changes |
| `.claude/CHECKPOINT.md` | Live session log — updated after every task | During every session |

---

## The One Rule

> **STATE.md receives the word `VERIFIED` only when there is a real git commit hash next to it.**

Every other mechanism exists to enforce this rule. When in doubt, write `PARTIAL`.

---

## Starting a Session

### Claude Code (automatic)
Claude Code reads `CLAUDE.md` automatically. The startup sequence runs without any user action. Confirm the five startup points in Claude Code's first response before proceeding.

### Claude.ai Chat (manual)
Paste this as your first message:

```
You are operating under the ACS protocol. Before doing anything else:

1. I am pasting .claude/MUST_READ.md:
[PASTE MUST_READ.md CONTENTS]

2. I am pasting .claude/STATE.md:
[PASTE STATE.md CONTENTS]

3. Confirm: last verified ATU, any CHECKPOINT.md recovery needed,
   today's planned tasks, and any blockers. Do not write code until confirmed.
```

Then run `verify_state.py` in your terminal and paste the result.

---

## Security

- **Never commit API keys.** `acs_ingest.py` reads `ANTHROPIC_API_KEY` from the environment or a `.env` file. The `.env` file is always in `.gitignore`.
- **`CLAUDE.md` is committed to git.** It must never contain credentials, tokens, or secrets. `verify_state.py` checks for common secret patterns and warns if found.
- **`.claude/last_verification.json`** is excluded from git — it is a runtime artefact.
- **`.claude/ingestion_result.json`** is excluded from git — it may contain project details you do not want public.

---

## Requirements

- Python 3.8+
- Git
- `anthropic` Python package (only required for `acs_ingest.py`)
- `python-docx` Python package (only required for `.docx` input to `acs_ingest.py`)

```bash
pip install anthropic python-docx
```

---

## Environments Supported

| Environment | Startup | Notes |
|---|---|---|
| Claude Code CLI | Automatic via `CLAUDE.md` | Recommended |
| Claude.ai Chat (browser/desktop) | Manual paste sequence | See Starting a Session above |

---

## Licence

MIT Licence — see `LICENSE`.

© 2026 James MacAskill. All rights reserved.
