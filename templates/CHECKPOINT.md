# SESSION CHECKPOINT
**Session Started**: [ISO timestamp]
**Last Updated**: [ISO timestamp — update this after every ATU]
**Session Goal**: [one line]
**Status**: IN_PROGRESS

---

## Credit Status
- Tasks planned this session: [N]
- Tasks completed: [N]
- Credit concern triggered: NO
- Session end trigger: [PLANNED / EMERGENCY / CREDIT_LIMIT]

---

## ATU Log

### ATU-[ID]: [Name] ✅ COMPLETE
- Started: [time] | Completed: [time]
- Verification output:
  ```
  [paste actual terminal output here]
  ```
- Commit: `[hash]` — confirmed via `git log --oneline -1`
- STATE.md updated: ✅

---

### ATU-[ID]: [Name] 🔄 IN PROGRESS
- Started: [time]
- Work done so far: [describe]
- Files modified: [list]
- NOT YET VERIFIED — NOT YET COMMITTED
- Rollback: `git checkout -- [files]`

---

## Emergency Recovery
*(Write this section BEFORE starting each ATU so it is ready if the session ends)*

If session ends right now:
- Last safe state: ATU-[ID] commit `[hash]`
- Incomplete work: [describe]
- To complete: [exact commands]
- To roll back: `git checkout -- [files]`
