# Migrating from the Claude-Only ACS Repo

If you have been using
[CLAUDE-ABSOLUTE-CONTINUITY-SYSTEM-ACS-](https://github.com/seamusmacasgaill-debug/CLAUDE-ABSOLUTE-CONTINUITY-SYSTEM-ACS-)
and want to move to the multi-provider version, this is a ten-minute process.

Your `STATE.md`, `MEMORY.md`, and `MUST_READ.md` content is fully portable —
no reformatting or content changes needed.

---

## What Changes

| Old (Claude-only) | New (Multi-provider) |
|-------------------|---------------------|
| `.claude/` directory | `.acs/` directory |
| `CLAUDE.md` trigger file | `AGENT.md` trigger file |
| `acs_ingest.py` (Anthropic only) | `acs_ingest.py` (4 providers) |
| `ANTHROPIC_API_KEY` required | Any provider key, or none (Ollama) |

The ACS document content (`STATE.md`, `MEMORY.md`, `MUST_READ.md`,
`PROTOCOL.md`, `CHECKPOINT.md`) is identical in structure — only the directory
name changes.

---

## Migration Steps

### Step 1 — Rename the directory

```bash
cd your-project
mv .claude .acs
```

### Step 2 — Rename the trigger file

```bash
mv CLAUDE.md AGENT.md
```

### Step 3 — Update internal path references

The ACS documents reference `.claude/` in a few places. Update them:

```bash
# Update all .claude/ references to .acs/ in one pass
grep -rl '\.claude/' .acs/ AGENT.md | xargs sed -i 's|\.claude/|.acs/|g'
```

Verify nothing was missed:
```bash
grep -r '\.claude' .acs/ AGENT.md 2>/dev/null && echo "References remain" || echo "Clean"
```

### Step 4 — Replace acs_ingest.py

```bash
# Copy the new multi-provider version
cp path/to/ACS-MULTI-PROVIDER/scripts/acs_ingest.py .acs/scripts/acs_ingest.py
```

Or download it directly:
```bash
curl -o .acs/scripts/acs_ingest.py \
  https://raw.githubusercontent.com/seamusmacasgaill-debug/ACS-MULTI-PROVIDER/main/scripts/acs_ingest.py
```

### Step 5 — Update .env.example (optional)

If you want to support multiple providers in this project going forward, replace
your `.env.example` with the multi-provider version:

```bash
curl -o .env.example \
  https://raw.githubusercontent.com/seamusmacasgaill-debug/ACS-MULTI-PROVIDER/main/.env.example
```

### Step 6 — Verify syntax

```bash
python -m py_compile .acs/scripts/acs_ingest.py && echo "OK"
python -m py_compile .acs/scripts/verify_state.py && echo "OK"
```

### Step 7 — Run verification

```bash
python .acs/scripts/verify_state.py
```

### Step 8 — Commit the migration

```bash
git add .acs/ AGENT.md .env.example
git rm -r .claude/ CLAUDE.md 2>/dev/null || true
git commit -m "chore: migrate ACS from .claude/ to .acs/ (multi-provider support)"
git push
```

---

## If You Use Claude Code

Claude Code reads `CLAUDE.md` automatically. After renaming to `AGENT.md`,
add one line to your new `AGENT.md` so Claude Code still picks it up, or keep
`CLAUDE.md` as a one-line redirect:

```bash
# Option A: Keep CLAUDE.md as a pointer (zero friction)
echo "# See AGENT.md for ACS protocol" > CLAUDE.md
cat AGENT.md >> CLAUDE.md

# Option B: Symlink
ln -s AGENT.md CLAUDE.md
```

---

## Keeping Both Repos in Sync

If you want `ANTHROPIC_API_KEY` to still work after migration (it will — Anthropic
is still the default provider), no changes to your `.env` are needed. The new
`acs_ingest.py` reads `ANTHROPIC_API_KEY` exactly as before.

The only breaking change is the directory path. Any script or alias that
hardcodes `.claude/` needs updating.

---

## Rollback

If anything goes wrong, the migration is fully reversible:

```bash
mv .acs .claude
mv AGENT.md CLAUDE.md
grep -rl '\.acs/' .claude/ CLAUDE.md | xargs sed -i 's|\.acs/|.claude/|g'
git checkout -- scripts/acs_ingest.py   # restore original if needed
```
