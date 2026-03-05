# ACS PROTOCOL — QUICK REFERENCE
# Full documentation: docs/ACS_PROTOCOL.md

## Every Session Starts With
1. Read `.claude/MUST_READ.md`
2. Read `.claude/STATE.md`
3. Read `.claude/CHECKPOINT.md` (if it exists)
4. Run: `python .claude/scripts/verify_state.py`
5. Resolve ALL discrepancies before writing any code

## An ATU is DONE When ALL of these are true
- [ ] Verify command run — output matches expected
- [ ] `git commit` run with descriptive message
- [ ] `git log --oneline -1` confirms commit landed (hash shown)
- [ ] `STATE.md` updated with that hash
- [ ] `CHECKPOINT.md` updated — task marked COMPLETE

## Never Say "Complete" Without
Running the verify command AND showing its actual output
AND `git log --oneline -1` AND showing that output.

## Credit Check — Before MEDIUM or LARGE Tasks
State: task size / estimated time / remaining capacity / safe to start YES|NO

## Session End — Planned
1. Complete current ATU fully
2. CHECKPOINT.md → Status: COMPLETED
3. STATE.md updated with all new verified completions
4. MEMORY.md updated with session learnings
5. MUST_READ.md written for the next session
6. `git push && git status` → clean working tree confirmed
7. Say: "SESSION TERMINATION COMPLETE. Next session: ATU-[X]"

## Session End — Emergency (priority order)
1. `git add -A && git commit -m "WIP: EMERGENCY [state]" && git push`
2. Append emergency block to CHECKPOINT.md
3. Add ⚠️ flag to top of MUST_READ.md

## The Ten Golden Rules
 1. Verify before trusting — verify_state.py first, every session
 2. Never claim complete — show verification output
 3. Commit hash or it did not happen
 4. STATE.md = reality, not intention
 5. CHECKPOINT.md is live — update after every ATU
 6. Credit check before medium/large tasks — gate, not estimate
 7. 80% rule — stop starting, finish cleanly
 8. Emergency commit beats undocumented state
 9. Partial is documented — always a recovery path
10. MUST_READ.md written before this session ends
