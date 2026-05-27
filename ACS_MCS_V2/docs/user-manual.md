# ACS — User Manual

**Absolute Continuity System v2**  
**Audience:** Developers using ACS on any AI-assisted project  
**Last updated:** 2026-05-27

---

## What ACS does for you

ACS solves two problems that kill productivity in AI-assisted development:

**Problem 1 — Cross-session drift:** An AI assistant has no memory between sessions. Without structure, it starts each session from whatever documentation claims — which may not match the actual codebase. Work gets repeated, bugs get re-introduced, fixes overwrite fixes.

**Problem 2 — Within-session forgetting:** In a long debugging thread, context compaction summarises away the specific rules that were established at session open. By the time you edit a critical file deep in the thread, the agent has forgotten the contracts it was supposed to enforce.

ACS v1 solves Problem 1 (session management). ACS v2 adds a solution to Problem 2 (hook-based contract enforcement).

---

## Daily use — what you actually do

### At the start of every session

```bash
python .claude/scripts/verify_state.py
```

Read the output. If it shows discrepancies, fix them before proceeding. If it shows clean, continue.

Read `.claude/MUST_READ.md` — this is the current session brief.

That is all. The hook system runs automatically from that point.

### During a session

When you (or the agent) edits a **pipeline file** — any file listed in `.acs/contract.json` — the hook fires automatically and outputs the contract rules for that file into the conversation. You do not trigger this manually.

Example of what you see when the hook fires:

```
╔══════════════════════════════════════════════════════════════╗
║  ACS CONTRACT CHECK — WebBuilder
╠══════════════════════════════════════════════════════════════╣
║  File: src/app/api/ai/style-swap/route.ts
║  Matched pattern: style-swap/route.ts
╠══════════════════════════════════════════════════════════════╣
║  HARD RULES FOR THIS FILE:
  1. CSS var replacement MUST be followed by restoring the
     .bg-white contrast-fix block with WCAG-safe dark values
  2. ...
```

The agent reads this and applies the rules before writing the edit.

### At the end of every session

Update `.claude/CHECKPOINT.md` — record what was completed, what was not, and what the next session needs to know.

Update `.claude/STATE.md` — mark completed items as VERIFIED with their commit hashes.

Update `.claude/MUST_READ.md` — write the brief for the next session.

---

## Setting up ACS on a new project

### Step 1 — Global install (one time only, per machine)

```bash
cd ~/GitHub/ACS/acs-repo
bash scripts/install_global.sh
```

This installs the hook script to `~/.claude/hooks/` and creates `~/.claude/settings.json`. You only do this once. It applies to all projects from that point.

### Step 2 — Initialise ACS documents in the project

```bash
cd /path/to/your-project
bash ~/GitHub/ACS/acs-repo/scripts/init_acs.sh "Project Name" "One-line description"
```

This creates the five ACS documents inside `.claude/`:

| File | Purpose |
|------|---------|
| `MUST_READ.md` | Session brief — read at session open |
| `STATE.md` | Verified completion record — commit hashes required |
| `CHECKPOINT.md` | Live session progress — updated during session |
| `MEMORY.md` | Architectural decisions and patterns |
| `PROTOCOL.md` | Quick-reference rules |

### Step 3 — Add contract enforcement for pipeline files

```bash
bash ~/GitHub/ACS/acs-repo/scripts/init_project.sh
```

Interactive setup. Creates `.acs/contract.json` in the project root. Commit this file to the project repo — it's small and project-specific.

```bash
git add .acs/contract.json && git commit -m "Add ACS contract config"
```

From this point, any edit to a pipeline file triggers the contract check automatically.

---

## Starter contracts — day 0 setup

ACS ships five pre-built starter contracts for common project types. Run `init_project.sh` and select one:

| Starter | Good for |
|---------|---------|
| `nextjs-web-app` | Next.js apps with auth, email, billing, database |
| `stripe-integration` | Any project with Stripe checkout or subscriptions |
| `html-css-pipeline` | HTML/CSS generation with a generator stage + post-processors |
| `database-schema` | Prisma or Drizzle schema + migration files |
| `auth-email` | Magic link or token-based authentication flows |

Starters give you 4–5 rules that are universally true for that project type — derived from bugs that have caused production incidents across many projects. You do not need to have experienced the failures yourself to benefit from the rules.

**After loading a starter:** edit `pipeline_files` to match your actual file paths. The patterns in the starter are generic fragments (`src/lib/auth`, `webhooks/stripe`) — confirm they substring-match your real files before committing.

---

## Growing the contract — the incident → rule loop

The starter gets you to day 0. The contract becomes genuinely valuable when it grows from your own incidents.

**The two-event threshold:**

- **First occurrence** of a bug class on a pipeline file → log it in your session doc under "Pipeline Contract Candidates." Do not add a rule yet — it may be a one-off.
- **Second occurrence** of the same class → add a rule to `.acs/contract.json` now. A second hit is evidence of a structural gap, not bad luck.

At the closing trigger of every session: review the Pipeline Contract Candidates table. If any class has appeared before, that is your second event — add the rule.

**Writing a rule from an incident:**

A good rule comes from answering: *"What would I have needed to know, at the moment of editing the file, to prevent this bug?"* Not the fix — the check that would have caught it before the edit was written.

Good: `"After any CSS var replacement pass, verify the .bg-white contrast block was not overwritten — check rendered output on a dark palette"`  
Bad: `"Be careful with CSS"` — not actionable; not checkable

The rule should be completable as a checkbox item at the moment of editing.

---

## Contract hygiene — ranking and pruning

A contract with 20 rules is ignored. A contract with 8 rules is read. Keep it short.

**When to prune:** when the list approaches 10–12 rules, review before adding a new one.

**Ranking — what stays:**

| Factor | Keeps a rule | Removes a rule |
|--------|-------------|----------------|
| Frequency | Bug class occurred 3+ times | Bug class occurred once and was architectural |
| Blast radius | Failure silently breaks another file | Failure is visible immediately (type error, 500) |
| Detectability gap | No automated test catches this | CI/type checker now covers this class |
| Recency | In-scope active code area | Area not touched in 30+ sessions AND unchanged |

**The pruning test:** for each rule, ask: *"If we removed this rule and a new agent edited the file tomorrow — would they make the same mistake?"* If yes, the rule stays. If the answer is no (because a test now catches it, or the code was refactored away), remove it.

Rules that have been silent for 30+ sessions AND whose bug class is now covered by type checking or CI can be moved to a `_retired_rules` comment block in `contract.json` — preserved for reference but not injected into the hook output.

---

## Writing a good contract.json

The most important part of setup. A poorly written contract provides no protection.

**`pipeline_files`** — filename patterns, not full paths. The hook does a substring match. Use the most specific part of the filename that uniquely identifies the file.

```json
"pipeline_files": [
    "component-assembler.ts",      ✓ specific enough
    "style-swap/route.ts",         ✓ path fragment is specific
    "page.tsx"                     ✗ too generic — matches every page.tsx
]
```

**`rules`** — the 3–5 things that must be in working memory when editing these files. Not general coding guidelines. Specific invariants that have caused bugs when violated.

```json
"rules": [
    "CSS var replacement in Pass 1 MUST be followed by restoring the .bg-white block",
    "Text on primaryLight background MUST use heroTextColor(), not var(--color-text)"
]
```

Good rules:
- Short enough to read in 10 seconds
- Specific enough to be a checklist item
- Written from past failures, not aspirational

Bad rules:
- "Write clean code" — not actionable
- "Test everything" — too vague
- Rules about code style or formatting — wrong layer

**What makes a file a pipeline file?**

Ask: if I change this file and get it wrong, which other file breaks silently, without an import error or type error telling me?

If the answer is "another file I'm not touching," that file is a pipeline file.

---

## What to do when the contract check fires

Read the rules. Before writing your edit, confirm in your response that you have considered each rule. If the edit potentially affects a rule, state explicitly how you are satisfying it.

For example, if you are editing `style-swap/route.ts` and Rule 1 says "CSS var replacement must restore the .bg-white block," your response should include: "Pass 4 (the .bg-white restoration) is preserved/updated to account for this change."

Do not acknowledge the rule and then ignore it. The purpose of the check is to produce that explicit acknowledgment.

---

## The same-class sweep

Every time a pipeline bug is fixed, before marking it COMPLETE:

1. **Does the same class of bug exist in the other post-processor?**  
   If you fixed `style-swap`, check `update-colours`. They often have similar code.

2. **Does the fix apply to all inputs, not just the one that was broken?**  
   For colour bugs: does it work for both dark palettes (Bold, Luxury) and light palettes?

3. **Is the fix in every entry point?**  
   Two different routes may call similar logic independently. Fixing one doesn't fix the other.

4. **Does the test exercise the specific failure mode?**  
   A generic "test style swap" does not catch dark palette bugs. Test Bold and Luxury specifically.

Record the sweep in the commit message: "Same-class sweep: checked update-colours — same gap found and fixed."

---

## ACS documents — what they are

| Document | When updated | What it contains |
|----------|-------------|-----------------|
| `MUST_READ.md` | End of every session | What the next session needs to do; current blockers; relevant context |
| `STATE.md` | When a task completes | VERIFIED items with commit hashes; IN_PROGRESS items with partial state |
| `CHECKPOINT.md` | During session after every ATU | Live record of what happened; updated before moving to the next task |
| `MEMORY.md` | When architectural decisions are made | Decisions that affect future sessions; patterns to follow; things to avoid |
| `PROTOCOL.md` | Rarely | Quick-reference rules; do not edit frequently |

**The critical rule:** A task is not VERIFIED until `git log --oneline` shows the commit hash in actual git history. "I committed it" is not verification. The hash is.

---

## Adding ACS to a project mid-flight (retrofit)

ACS v2 works best from the start but can be added to an existing project. The contract enforcement (hooks layer) has no dependency on the session management layer — you can add `.acs/contract.json` to any project and get hook enforcement immediately.

For session management retrofit:
1. Create `.claude/` directory in the project
2. Copy the templates from `~/GitHub/ACS/acs-repo/templates/`
3. Fill in `STATE.md` with the real current state of the project (honest assessment)
4. Fill in `MUST_READ.md` with what the next session actually needs to do
5. Do not backfill — start clean from today's real state

For contract enforcement retrofit:
1. Run `init_project.sh` — creates `.acs/contract.json`
2. Identify the pipeline files (the files where a wrong edit silently breaks something else)
3. Write the rules from the bugs you already know about
4. Commit and you're done

---

## FAQ

**Q: The hook fires but the agent ignores the rules anyway.**  
A: The hook injects the rules as a tool result that appears in the conversation. The agent should treat it as instruction. If it is consistently ignored, add the same rules to the project `CLAUDE.md` file — that file loads at session start and is given higher weight.

**Q: The hook fires for a file it shouldn't.**  
A: The pattern in `pipeline_files` is too broad. Change `"page.tsx"` to `"custom-generate/page.tsx"` — be more specific.

**Q: The hook fires but shows no rules — just the header.**  
A: The `contract_doc` path in `contract.json` is wrong or the file doesn't exist. Fix the path.

**Q: I get a hook error in the output.**  
A: The hook script is at `~/.claude/hooks/acs-contract-check.sh`. Check it's executable: `chmod +x ~/.claude/hooks/acs-contract-check.sh`. Check Python 3 is available: `python3 --version`.

**Q: How do I update the rules when new bugs are found?**  
A: Edit `.acs/contract.json` directly, commit it, and push. The hook reads the file on every invocation so the new rules take effect immediately.

**Q: Does ACS slow down editing?**  
A: The hook adds less than 100ms per Edit/Write call on pipeline files. It is silent (zero output) on non-pipeline files, so there is no overhead for the vast majority of edits.
