# ACS — Absolute Continuity System (Multi-Provider)

> **Session memory and verification protocol for any stateless AI agent.**
> Works with Anthropic Claude, OpenAI GPT, Google Gemini, or local Ollama models.

Every AI coding session starts from zero. ACS fixes that by giving your agent a
structured, verified record of exactly what was built, what was confirmed working,
and what to do next — before it writes a single line of code.

---

## Supported Providers

| Provider  | API Key Required | Free Tier | Best For |
|-----------|-----------------|-----------|----------|
| Anthropic | Yes | No | Highest quality extraction (default) |
| OpenAI | Yes | No | GPT-4o alternative |
| Gemini | Yes | Yes | Cost-sensitive projects |
| Ollama | No | Yes (local) | Offline / private / no API cost |

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/seamusmacasgaill-debug/ACS-MULTI-PROVIDER.git
cd ACS-MULTI-PROVIDER
```

### 2. Install dependencies

```bash
# Base requirement (always needed)
pip install python-docx

# Install your chosen provider's package
pip install anthropic          # Anthropic Claude
pip install openai             # OpenAI GPT
pip install google-generativeai  # Google Gemini
pip install ollama             # Local Ollama
```

### 3. Set your API key

```bash
# Copy the template and fill in your key
cp .env.example .env
# Edit .env and add your key — see docs/PROVIDERS.md for where to get each key
```

### 4. Run setup

```bash
# Auto-detects provider from your .env
bash setup.sh "My Project" "A short description"

# With a planning document (recommended)
bash setup.sh "My Project" "Description" --input plan.md

# Explicit provider
bash setup.sh "My Project" "Description" --input plan.md --provider openai
bash setup.sh "My Project" "Description" --input plan.md --provider ollama
```

That's it. ACS creates a `.acs/` directory in your project with all session
documents pre-populated from your planning doc.

---

## What Gets Created

```
your-project/
├── AGENT.md                        ← AI trigger file (read this every session)
└── .acs/
    ├── MUST_READ.md                ← What to do this session
    ├── STATE.md                    ← Verified completion tracker
    ├── MEMORY.md                   ← Architectural decisions + context
    ├── PROTOCOL.md                 ← Quick reference rules
    ├── CHECKPOINT.md               ← Live session progress (created per session)
    └── scripts/
        ├── verify_state.py         ← Startup verification script
        └── acs_ingest.py           ← Planning document ingestion
```

### What each file does

**`AGENT.md`** — The file your AI reads first, every session. Contains the mandatory
startup checklist: run verification, confirm git HEAD, confirm last verified task,
read session brief. No code is written until all five confirmations are given.

**`STATE.md`** — The single source of truth. Every completed task requires a real
git commit hash before it can be marked `VERIFIED`. Template rows mean nothing.

**`MUST_READ.md`** — Written at the end of each session for the next session.
Contains current phase, blocking issues, and the ordered task list.

**`MEMORY.md`** — Persistent architectural decisions, resolved problems, and
changed understanding. Survives across all sessions.

**`CHECKPOINT.md`** — Created live during a session. Records ATU-by-ATU progress
so an interrupted session can be recovered cleanly.

---

## Using acs_ingest.py Directly

If you already have a project set up and want to re-ingest a planning document:

```bash
# Auto-detect provider from env vars
python .acs/scripts/acs_ingest.py --input plan.md

# Explicit provider + model
python .acs/scripts/acs_ingest.py --input plan.md --provider openai --model gpt-4o
python .acs/scripts/acs_ingest.py --input plan.md --provider gemini --model gemini-1.5-pro
python .acs/scripts/acs_ingest.py --input plan.md --provider ollama --model llama3

# Multiple input files
python .acs/scripts/acs_ingest.py --input spec.md devops.md architecture.docx

# Dry run (see what would be written without writing anything)
python .acs/scripts/acs_ingest.py --input plan.md --dry-run

# Force overwrite existing ACS files
python .acs/scripts/acs_ingest.py --input plan.md --force

# Output extracted JSON only (useful for debugging)
python .acs/scripts/acs_ingest.py --input plan.md --json-only
```

Full flag reference: `python .acs/scripts/acs_ingest.py --help`

---

## Provider Auto-Detection

When you run with `--provider auto` (the default), ACS checks for API keys in
this order:

1. `ANTHROPIC_API_KEY` → uses Anthropic
2. `OPENAI_API_KEY` → uses OpenAI
3. `GEMINI_API_KEY` → uses Gemini
4. No key found → falls back to Ollama (local, no key needed)

Set your key in `.env` or export it in your shell and ACS handles the rest.

---

## CI/CD

This repo includes a GitHub Actions workflow with three jobs:

| Job | What it checks |
|-----|---------------|
| `verify-scripts` | Python syntax of `verify_state.py` and `acs_ingest.py` |
| `lint-shell` | ShellCheck warnings on `setup.sh` and `scripts/init_acs.sh` |
| `check-docs` | Required files present (README, LICENSE, protocol docs, etc.) |

All three are configured as required status checks on `main`. No PR can merge
without all three passing.

To set up branch protection on a fork:

```bash
gh api repos/YOUR_USERNAME/ACS-MULTI-PROVIDER/branches/main/protection \
  -X PUT -H "Accept: application/vnd.github+json" \
  --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "verify-scripts", "app_id": 15368 },
      { "context": "lint-shell",     "app_id": 15368 },
      { "context": "check-docs",     "app_id": 15368 }
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null
}
EOF
```

---

## Migrating from the Claude-Only ACS Repo

If you are already using
[CLAUDE-ABSOLUTE-CONTINUITY-SYSTEM-ACS-](https://github.com/seamusmacasgaill-debug/CLAUDE-ABSOLUTE-CONTINUITY-SYSTEM-ACS-)
and want to switch to multi-provider, see **[docs/MIGRATION.md](docs/MIGRATION.md)**.

The short version: rename `.claude/` to `.acs/`, rename `CLAUDE.md` to `AGENT.md`,
and replace `acs_ingest.py` with the version from this repo. Your `STATE.md`,
`MEMORY.md`, and `MUST_READ.md` content is fully portable — no reformatting needed.

---

## Provider Setup Details

For API key locations, model names, pricing, and Ollama installation:
**[docs/PROVIDERS.md](docs/PROVIDERS.md)**

---

## Requirements

- Python 3.8+
- Git
- One of: `anthropic`, `openai`, `google-generativeai`, or `ollama` Python package
- `python-docx` (only if ingesting `.docx` files)

---

## License

MIT — see [LICENSE](LICENSE)
