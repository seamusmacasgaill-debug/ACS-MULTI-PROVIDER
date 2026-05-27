# ACS — Technical Manual

**Absolute Continuity System v2**  
**Audience:** Developers maintaining, extending, or debugging ACS  
**Last updated:** 2026-05-27

---

## System architecture

```
Machine-global (installed once):
  ~/.claude/settings.json              Claude Code settings — registers the PreToolUse hook
  ~/.claude/hooks/acs-contract-check.sh  Hook entry point — runs before every Edit/Write

Per-project (committed to each repo):
  .acs/contract.json                   Declares pipeline files and rules for this project
  CLAUDE.md                            Always-loaded rules (survives context compaction)
  .claude/MUST_READ.md                 Session brief
  .claude/STATE.md                     Verified completion record
  .claude/CHECKPOINT.md                Live session progress
  .claude/MEMORY.md                    Architectural decisions
  .claude/scripts/verify_state.py      State verification script

ACS repo (source of truth for tooling):
  ~/GitHub/ACS/acs-repo/
    hooks/acs-contract-check.sh        Canonical hook script (copied to ~/.claude/hooks/)
    scripts/install_global.sh          Machine-level install
    scripts/init_project.sh            Per-project init (creates .acs/contract.json)
    scripts/init_acs.sh                Per-project session docs init
    scripts/verify_state.py            State verification
    templates/contract.json            Template for .acs/contract.json
    docs/ACS_V2_ARCHITECTURE.md        Architecture reference
    docs/user-manual.md                End-user documentation
    docs/technical-manual.md           This file
```

---

## Claude Code hooks API

Claude Code fires hooks at specific events in the tool-use lifecycle. Hooks are shell commands configured in `settings.json`. The global settings file (`~/.claude/settings.json`) applies to all projects; a project-level `.claude/settings.json` applies only to that project.

### settings.json format

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/script.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook types:**
- `PreToolUse` — fires before a tool call executes
- `PostToolUse` — fires after a tool call completes
- `Notification` — fires on agent notifications
- `Stop` — fires when the agent stops

**matcher** — regex matched against tool name. Common values:
- `"Edit"` — file edits only
- `"Write"` — file writes only
- `"Edit|Write"` — both (used by ACS)
- `"Bash"` — shell commands
- `".*"` — all tools

**Exit codes:**
- `0` — allow the tool call; stdout appears in conversation
- `2` — block the tool call; stdout is the error message shown to the agent

ACS uses exit code `0` (warn, never block).

### Hook stdin format

The hook receives the tool call as JSON on stdin:

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/absolute/path/to/file.ts",
    "old_string": "...",
    "new_string": "..."
  }
}
```

For the `Write` tool:
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/absolute/path/to/file.ts",
    "content": "..."
  }
}
```

The hook script must handle both structures since `file_path` is at different nesting levels depending on the source format (the wrapper `tool_input` key may or may not be present).

---

## Hook script internals

**File:** `hooks/acs-contract-check.sh`

### Step-by-step logic

**1. Parse file_path from stdin**

```bash
RAW=$(cat)
FILE_PATH=$(echo "$RAW" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'file_path' in data:
        print(data['file_path'])
    elif 'tool_input' in data and 'file_path' in data['tool_input']:
        print(data['tool_input']['file_path'])
except:
    pass
" 2>/dev/null || echo "")
```

Uses Python 3 for JSON parsing (reliable) rather than `jq` (may not be installed) or `grep`/`sed` (fragile on complex JSON). Falls back silently if parsing fails.

**2. Walk up directory tree for .acs/contract.json**

```bash
DIR="$(dirname "$FILE_PATH")"
CONTRACT_JSON=""
while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/.acs/contract.json" ]]; then
        CONTRACT_JSON="$DIR/.acs/contract.json"
        PROJECT_ROOT="$DIR"
        break
    fi
    DIR="$(dirname "$DIR")"
done
```

Walks up from the file's directory, stops at the filesystem root. Finds the nearest `.acs/contract.json`. This allows monorepos — a subproject can have its own contract.

**3. Pattern matching**

```bash
MATCHED=$(python3 -c "
import json, sys
with open('$CONTRACT_JSON') as f:
    cfg = json.load(f)
patterns = cfg.get('pipeline_files', [])
filepath = '$FILE_PATH'
for p in patterns:
    if p in filepath:
        print(p)
        break
" 2>/dev/null || echo "")
```

Substring match: `pattern in filepath`. First match wins. Case-sensitive.

**4. Output**

If matched, outputs a formatted box with:
- Project name, file path, matched pattern
- All rules from `rules[]`
- The standard same-class sweep reminder
- The blast zone matrix section from the contract doc (if it exists and is readable)

If not matched or no contract found: outputs nothing, exits 0 silently.

### Error handling

All Python calls use `2>/dev/null` and `|| echo ""` fallbacks. If JSON parsing fails, the script exits silently rather than producing noisy errors. A malformed `contract.json` results in silent exit. This is intentional — contract failures should never interrupt the agent's work.

---

## contract.json schema

```json
{
  "project": "string — display name for the hook output header",
  "contract_doc": "string — path to full contract document, relative to project root",
  "pipeline_files": [
    "string — substring pattern matched against absolute file path"
  ],
  "rules": [
    "string — hard rule injected into conversation before pipeline file edits"
  ],
  "quality_gate": "string — informational, e.g. '6-star'",
  "smoke_test": "string — path to smoke test document, relative to project root",
  "session_gate": "string — path to session gate document, relative to project root"
}
```

All fields except `project` and `pipeline_files` are optional. A minimal valid config:

```json
{
  "project": "MyProject",
  "pipeline_files": ["critical-file.ts"],
  "rules": ["Rule 1"]
}
```

### Pattern matching semantics

Patterns are substring matches against the absolute file path. Examples:

| Pattern | Matches | Does not match |
|---------|---------|---------------|
| `"component-assembler.ts"` | `.../assemblers/component-assembler.ts` | `.../old-assembler.ts` |
| `"style-swap/route.ts"` | `.../ai/style-swap/route.ts` | `.../update-colours/route.ts` |
| `"custom-generate/page.tsx"` | `.../app/custom-generate/page.tsx` | `.../custom-generate-old/page.tsx` |
| `"page.tsx"` | ANY file named page.tsx anywhere | (nothing — too broad) |

Use path fragments (`dir/file.ts`) rather than bare filenames where possible.

---

## CLAUDE.md integration

`CLAUDE.md` at the project root is loaded by Claude Code at every session start. Rules in this file are in the model's context throughout the session. This is distinct from the hook mechanism:

| | CLAUDE.md | Hook |
|--|-----------|------|
| When fires | Session start (once) | Before each Edit/Write to pipeline file |
| Survives compaction? | Yes — re-injected from file | Yes — runs as shell command, not from context |
| Can be forgotten mid-session? | Yes — context grows, early content fades | No — fires at tool-use time regardless |
| Best for | Rules that apply throughout the session | Rules specific to a file edit |

For maximum enforcement: put the 5 most critical rules in both CLAUDE.md AND contract.json.

---

## Claude Code memory system integration

Claude Code maintains a file-based memory system at `~/.claude/projects/<project-path>/memory/`. Memory files are loaded at session start and indexed in `MEMORY.md`.

ACS v2 adds a feedback memory entry for the pipeline contract:

```
~/.claude/projects/.../memory/feedback_pipeline_contract.md
```

This entry is referenced in `MEMORY.md` and appears in every session's context. It reinforces the hook by stating the rule at session start.

**Memory file format:**

```markdown
---
name: feedback-pipeline-contract
description: Before editing any pipeline file, read PIPELINE-CONTRACT.md
metadata:
  type: feedback
---

Body text with **Why:** and **How to apply:** lines...
```

Memory types: `user`, `feedback`, `project`, `reference`. Pipeline contract rules belong in `feedback`.

---

## verify_state.py internals

**File:** `scripts/verify_state.py`

Reads every entry in `STATE.md` marked as `VERIFIED`. For each, extracts the commit hash and runs:

```python
result = subprocess.run(
    ['git', 'log', '--oneline', '--all', '--grep', hash_prefix],
    capture_output=True, text=True
)
```

If the hash is not in git history: reports as `CLAIMED_NOT_COMMITTED` with the recovery command.

Exit codes:
- `0` — all VERIFIED items confirmed in git history
- `1` — one or more discrepancies found (lists each with type and recovery command)

The script never modifies STATE.md. It only reads and reports.

---

## Installing ACS on a new machine

```bash
# 1. Clone the ACS repo
git clone git@github.com:seamusmacasgaill-debug/CLAUDE-ABSOLUTE-CONTINUITY-SYSTEM-ACS-.git ~/GitHub/ACS/acs-repo

# 2. Run global install (installs hook script + settings.json)
bash ~/GitHub/ACS/acs-repo/scripts/install_global.sh

# 3. For each project: clone the project, then
cd /path/to/project
# If .acs/contract.json already exists in the repo, hook is already active.
# If not, run:
bash ~/GitHub/ACS/acs-repo/scripts/init_project.sh
```

---

## Extending ACS

### Adding a new contract category

To add a new class of enforcement (e.g. "database schema contract", "API contract"):

1. Add the relevant files to `pipeline_files` in the project's `.acs/contract.json`
2. Write a contract document (e.g. `DB-CONTRACT.md`) in the project's docs
3. Set `contract_doc` to point to it
4. The hook will read and output the blast zone matrix section from that document

The hook looks for a `## Blast zone matrix` section in the contract doc and outputs it. Structure any new contract doc with this section to get it injected automatically.

### Adding a hook for a new event type

To add a `PostToolUse` hook (e.g. log every file changed):

```json
{
  "hooks": {
    "PreToolUse": [ ... existing ... ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/acs-post-edit-log.sh"
          }
        ]
      }
    ]
  }
}
```

Write `~/.claude/hooks/acs-post-edit-log.sh` following the same pattern: read JSON from stdin, extract relevant fields, output or exit silently.

### Adding project-specific hook scripts

For project-specific hooks (rather than global), create `.claude/settings.json` in the project root (not `~/.claude/`). Project settings override global settings for that project.

---

## Troubleshooting

### Hook fires but no output appears in conversation

Possible causes:
- `contract.json` has a typo in a pipeline_files pattern
- `contract.json` is not at the project root (hook walks up from file path, must find it)
- The file being edited is in a path that doesn't contain any of the patterns

Debug: run the hook manually:
```bash
echo '{"file_path": "/path/to/the/file"}' | bash ~/.claude/hooks/acs-contract-check.sh
```

If no output, add `set -x` to the top of the script to trace execution.

### Hook fails with Python error

The hook requires `python3` on PATH. Verify:
```bash
python3 --version  # must be 3.6+
```

If not available, install Python 3 or modify the hook to use `node` or `jq` for JSON parsing.

### Hook fires for wrong files

Pattern is too broad. Use `grep` to test:
```bash
echo "/path/to/your/project/src/components/page.tsx" | grep -c "page.tsx"
# If 1, the pattern matches. Narrow it: "custom-generate/page.tsx"
```

### settings.json not taking effect

Claude Code reads settings at startup. Restart the Claude Code session after modifying `settings.json`.

Check which settings.json is active:
- Global: `~/.claude/settings.json`
- Project: `.claude/settings.json` in project root
- Local: `~/.claude/settings.local.json` (user-only, not shared)

Local settings (`settings.local.json`) can override global hooks. Check for conflicts.

### verify_state.py shows a hash as missing

```
CLAIMED_NOT_COMMITTED: abc1234 not found in git history
Recovery: git log --all --oneline | grep abc1234
```

The commit exists in a different repo, was amended (changing the hash), or was never actually committed. Check with:
```bash
git log --all --oneline | grep <hash>
git log --remotes --oneline | grep <hash>
```

If genuinely missing: mark the STATE.md entry as `IN_PROGRESS` and redo the task.

---

## Known limitations

**1. Hook does not fire for Bash tool edits**  
If a file is modified via `Bash` (e.g. `sed -i`), the hook does not fire. Only `Edit` and `Write` tools trigger it. Mitigation: CLAUDE.md rules cover the session as a whole; Bash-based file modification is unusual for pipeline files.

**2. Pattern matching is case-sensitive on Linux**  
`"Page.tsx"` does not match `"page.tsx"`. Use lowercase patterns matching actual filenames.

**3. Contract doc extraction looks for specific heading**  
The blast zone matrix section is only extracted if the heading is exactly `## Blast zone matrix`. Variation in heading case or format (`### Blast Zone Matrix`) will not extract.

**4. ACS v2 hook requires Python 3 on PATH**  
Environments without Python 3 will fail silently (hook exits 0 without output). This is acceptable — the CLAUDE.md and memory layers still enforce the rules.
