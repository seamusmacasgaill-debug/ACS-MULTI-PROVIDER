#!/bin/bash
# init_acs.sh — Absolute Continuity System (ACS) Project Initialiser
# Run ONCE at the start of a new project.
# Usage: bash init_acs.sh "Project Name" "One-line project description"

PROJECT_NAME="${1:-MyProject}"
PROJECT_DESC="${2:-AI-assisted development project}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Initialising ACS Protocol for: $PROJECT_NAME"
echo "======================================================="

# 1. Create directory structure
mkdir -p .claude/scripts
echo "✓ Created .claude/scripts/"

# 2. Create verify_state.py
# (Copy verify_state.py into the scripts directory)
if [ -f "verify_state.py" ]; then
    cp verify_state.py .claude/scripts/verify_state.py
    echo "✓ Copied verify_state.py to .claude/scripts/"
else
    echo "⚠ verify_state.py not found in current directory."
    echo "  Download it and place it at .claude/scripts/verify_state.py"
fi

# 3. Create MUST_READ.md
cat > .claude/MUST_READ.md << EOF
# MUST READ — SESSION STARTUP BRIEF
**Last updated**: $TIMESTAMP
**Updated by**: ACS Initialisation
**Emergency flag**: NONE

## ⚡ IMMEDIATE ACTIONS (do before anything else)
1. Run: \`python .claude/scripts/verify_state.py\`
2. If verification fails: resolve discrepancies before ANY new work
3. Read CHECKPOINT.md if Emergency flag is set above

---

## Project: $PROJECT_NAME
$PROJECT_DESC

## Current Phase
**Phase**: 1 — Initial Setup
**Current Focus**: Project initialisation and environment verification
**Blocking Issues**: NONE

## Last Verified Completion
**ATU**: ATU-000 — ACS Protocol Initialised
**Commit**: (run git log --oneline -1 after first commit)
**Timestamp**: $TIMESTAMP
**Verification**: Directory structure confirmed, verify_state.py executable

## THIS Session's Tasks
1. ATU-001: Environment setup and dependency installation — MEDIUM
2. ATU-002: Initial project structure — SMALL
3. (Add tasks here at the start of each session)

## Architecture Summary
- (Update this as architecture is established)

## Active Environment Details
- Python version: $(python3 --version 2>/dev/null || echo "not detected")
- Key services: (list services that should be running)
- Branch: $(git branch --show-current 2>/dev/null || echo "main")
- Key env vars needed: (list env var names, not values)

## Do NOT Do This Session
- Nothing excluded yet — project just started
EOF
echo "✓ Created .claude/MUST_READ.md"

# 4. Create STATE.md
cat > .claude/STATE.md << EOF
# PROJECT STATE — VERIFIED COMPLETIONS ONLY
**Rule**: Nothing is added here without a verified commit hash.
**Last verification run**: $TIMESTAMP
**Project**: $PROJECT_NAME

---

## LEGEND
- VERIFIED: Confirmed working with commit hash and test evidence
- IN_PROGRESS: Currently being built this session
- PARTIAL: Started but not complete (requires recovery)
- NOT_STARTED: On the roadmap but not yet begun
- BLOCKED: Cannot proceed — blocker documented in MUST_READ.md

---

## Infrastructure

| Component | Status | Commit | Verified Timestamp |
|-----------|--------|--------|--------------------|
| Git repository | VERIFIED | (initial) | $TIMESTAMP |
| ACS Protocol files | VERIFIED | (initial) | $TIMESTAMP |
| Python environment | NOT_STARTED | — | — |
| Docker/compose | NOT_STARTED | — | — |
| Database | NOT_STARTED | — | — |

---

## Data Pipelines

| Pipeline | Status | Commit | Test Status | Verified |
|----------|--------|--------|-------------|----------|
| (none yet) | — | — | — | — |

---

## Feature Engineering

| Feature | Status | Commit | Shape/Output Verified | Verified |
|---------|--------|--------|-----------------------|----------|
| (none yet) | — | — | — | — |

---

## Models

| Model | Status | Commit | Test Accuracy | Verified |
|-------|--------|--------|---------------|----------|
| (none yet) | — | — | — | — |

---

## Tests

| Test Suite | Pass | Fail | Last Run | Commit |
|------------|------|------|----------|--------|
| (no tests yet) | — | — | — | — |

---

## API / Services

| Endpoint / Service | Status | Commit | Health Check | Verified |
|--------------------|--------|--------|--------------|----------|
| (none yet) | — | — | — | — |

---

## Git State
- Current branch: $(git branch --show-current 2>/dev/null || echo "main")
- Last push confirmed: (not yet pushed)
- Remote sync status: NOT_CONFIGURED
EOF
echo "✓ Created .claude/STATE.md"

# 5. Create MEMORY.md
cat > .claude/MEMORY.md << EOF
# PROJECT MEMORY — PERSISTENT CONTEXT
**Project**: $PROJECT_NAME
**Initialised**: $TIMESTAMP

---

## Architectural Decisions

### $TIMESTAMP: ACS Protocol Adopted
**Decision**: Using the Absolute Continuity System (ACS) for all session management.
**Rationale**: Previous multi-session projects suffered from gaps between claimed and actual completion. ACS enforces verification gates before marking anything complete.
**Impact**: Every task requires a verify command + git log confirmation. Documentation is a side-effect of verified actions, not a substitute.

---

## Problems Encountered and Resolved
(None yet — add as they occur)

---

## External Dependencies Discovered

| Dependency | Version | Purpose | First encountered |
|------------|---------|---------|-------------------|
| (none yet) | — | — | — |

---

## Changed Understanding
(None yet — add when understanding of the codebase evolves)

---

## Performance Baselines

| Metric | Baseline | Target | Current Best | Date |
|--------|----------|--------|--------------|------|
| (none yet) | — | — | — | — |

---

## Contacts and External Accounts
(No credentials — reference only)

| Service | Account name / username | Notes |
|---------|------------------------|-------|
| (none yet) | — | — |
EOF
echo "✓ Created .claude/MEMORY.md"

# 6. Create PROTOCOL.md (quick reference)
cat > .claude/PROTOCOL.md << 'EOF'
# ACS PROTOCOL — QUICK REFERENCE
# Full protocol: PROJECT_PROTOCOL_MASTER.md

## Every Session Starts With:
1. Read .claude/MUST_READ.md
2. Read .claude/STATE.md
3. Read .claude/CHECKPOINT.md (if it exists)
4. Run: python .claude/scripts/verify_state.py
5. Resolve ALL discrepancies before writing any new code

## A Task (ATU) is DONE When ALL of these are true:
- [ ] Verify command was run and output matches expected
- [ ] git commit was run with a standard message
- [ ] git log --oneline -1 confirms the commit actually landed
- [ ] STATE.md updated with commit hash and timestamp
- [ ] CHECKPOINT.md updated to show task as COMPLETE

## Claude Must Never Say "Complete" Without:
Running the verify command AND showing its actual output
AND running git log --oneline -1 AND showing that output

## Credit Check — Before MEDIUM or LARGE Tasks, State:
"Task size: [SIZE]. Estimated time: [X min]. 
 Remaining session capacity: [assessment]. 
 Safe to start: YES/NO. Recommendation: [proceed/defer/decompose]"

## Session End Sequence (Planned):
1. Complete current ATU fully — no half-finished tasks
2. Update CHECKPOINT.md Status → COMPLETED
3. Update STATE.md with all new verified completions
4. Add session learnings to MEMORY.md
5. Write next session's MUST_READ.md
6. Run: git push && git status (must show clean working tree)
7. Say in chat: "SESSION TERMINATION COMPLETE. Next session: ATU-[X]"

## Emergency Session End (in priority order):
1. git add -A && git commit -m "WIP: EMERGENCY [describe state]" && git push
2. Append emergency block to CHECKPOINT.md
3. Add ⚠️ EMERGENCY flag to top of MUST_READ.md

## ATU Structure (copy this for each task):
ATU-[ID]: [Name]
- Intent:  What this changes
- Actions: Exact steps
- Verify:  Command that proves it worked (must run and show output)
- Commit:  git add [files] && git commit -m "[message]"
- Update:  STATE.md line(s) to update

## The Ten Golden Rules:
1. Verify before trusting — run verify_state.py first
2. Never claim complete — only show verification output  
3. Commit hash or it didn't happen — git log confirms
4. STATE.md = reality not intention
5. CHECKPOINT.md is live — update after every ATU
6. Check credit before large tasks — estimate first
7. 80% rule — stop starting, finish cleanly
8. Emergency commit — always better than undocumented state
9. Partial is documented — never leave undocumented partial state
10. Next session brief — written before this session ends
EOF
echo "✓ Created .claude/PROTOCOL.md"

# 7. Create .gitignore additions
if [ ! -f .gitignore ]; then
    touch .gitignore
fi

if ! grep -q "last_verification.json" .gitignore; then
    cat >> .gitignore << EOF

# ACS Protocol — generated files (not sensitive, but not needed in repo)
.claude/last_verification.json
EOF
    echo "✓ Updated .gitignore"
fi

# 8. Initial git commit (if in a git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    git add .claude/ .gitignore
    git commit -m "chore: initialise ACS Absolute Continuity System protocol

- .claude/MUST_READ.md: session startup brief
- .claude/STATE.md: verified completion tracking  
- .claude/MEMORY.md: persistent project context
- .claude/PROTOCOL.md: quick reference
- .claude/scripts/verify_state.py: startup verification script"
    echo "✓ Initial ACS commit made"
    echo ""
    echo "Commit hash: $(git log --oneline -1)"
else
    echo "⚠ Not in a git repository. Initialise git first:"
    echo "  git init && git add . && git commit -m 'initial commit'"
    echo "  Then update STATE.md with the initial commit hash."
fi

echo ""
echo "======================================================="
echo "ACS Protocol initialised for: $PROJECT_NAME"
echo ""
echo "NEXT STEPS:"
echo "1. Update .claude/MUST_READ.md with your first session's tasks"
echo "2. Run: python .claude/scripts/verify_state.py"
echo "   (Should show: SAFE TO PROCEED — all checks passed)"
echo "3. Start your first session following the startup protocol"
echo ""
echo "Full protocol documentation: PROJECT_PROTOCOL_MASTER.md"
echo "======================================================="
