#!/usr/bin/env bash
# =============================================================================
# ACS — Absolute Continuity System
# setup.sh — Single-command project setup
# =============================================================================
#
# Usage:
#   bash setup.sh "Project Name" "Description"
#   bash setup.sh "Project Name" "Description" --input BMAD.md
#   bash setup.sh "Project Name" "Description" --input plan.md devops.md
#   bash setup.sh "Project Name" "Description" --input spec.docx --force
#
# Options:
#   --input FILE [FILE...]   Planning document(s) to ingest (optional)
#   --force                  Overwrite existing ACS files without prompting
#   --skip-ingest            Initialise structure only, skip document ingestion
#   --dry-run                Show what would happen without writing files
#   --api-key KEY            Anthropic API key (otherwise reads from env / .env)
#
# Requirements:
#   - Python 3.8+
#   - Git repository initialised (git init) or will be initialised
#   - pip install anthropic python-docx   (only if using --input)
#
# =============================================================================

set -euo pipefail

# ── colour output ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}  ▸${NC}  $*"; }
success() { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}$*${NC}"; }

# ── parse arguments ───────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"
PROJECT_DESC="${2:-}"
INPUT_FILES=()
FORCE=false
DRY_RUN=false
SKIP_INGEST=false
API_KEY=""

if [[ -z "$PROJECT_NAME" ]]; then
    error "Usage: bash setup.sh \"Project Name\" \"Description\" [--input FILE...]"
    exit 1
fi

shift 2 2>/dev/null || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            shift
            while [[ $# -gt 0 && ! "$1" == --* ]]; do
                INPUT_FILES+=("$1")
                shift
            done
            ;;
        --force)       FORCE=true;       shift ;;
        --dry-run)     DRY_RUN=true;     shift ;;
        --skip-ingest) SKIP_INGEST=true; shift ;;
        --api-key)     API_KEY="$2";     shift 2 ;;
        *) warn "Unknown option: $1"; shift ;;
    esac
done

# ── locate ACS scripts ────────────────────────────────────────────────────────
# Works whether setup.sh is run from the acs repo or copied into a project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACS_SCRIPTS_DIR=""

for candidate in \
    "$SCRIPT_DIR/scripts" \
    "$SCRIPT_DIR" \
    "$(pwd)/.acs-setup/scripts" \
    "$(pwd)/scripts"
do
    if [[ -f "$candidate/verify_state.py" ]]; then
        ACS_SCRIPTS_DIR="$candidate"
        break
    fi
done

if [[ -z "$ACS_SCRIPTS_DIR" ]]; then
    error "Cannot locate ACS scripts (verify_state.py, init_acs.sh, acs_ingest.py)."
    error "Ensure setup.sh is run from the ACS repository root, or copy the"
    error "scripts/ directory into your project first."
    exit 1
fi

# ── verify python ─────────────────────────────────────────────────────────────
PYTHON=""
for py in python3 python; do
    if command -v "$py" &>/dev/null; then
        version=$("$py" --version 2>&1 | awk '{print $2}')
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [[ "$major" -ge 3 && "$minor" -ge 8 ]]; then
            PYTHON="$py"
            break
        fi
    fi
done

if [[ -z "$PYTHON" ]]; then
    error "Python 3.8+ is required. Please install Python and re-run."
    exit 1
fi

# ── verify git ────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    error "Git is required. Please install Git and re-run."
    exit 1
fi

# ── print banner ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   ACS — Absolute Continuity System                ║${NC}"
echo -e "${BOLD}║   Project Setup                                    ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
info "Project:     $PROJECT_NAME"
info "Description: $PROJECT_DESC"
info "Python:      $($PYTHON --version)"
info "Scripts dir: $ACS_SCRIPTS_DIR"
[[ ${#INPUT_FILES[@]} -gt 0 ]] && info "Input files: ${INPUT_FILES[*]}"
[[ "$DRY_RUN" == true ]]        && warn "DRY RUN MODE — no files will be written"
echo ""

# ── check / initialise git repo ───────────────────────────────────────────────
header "Step 1 — Git Repository"

if ! git rev-parse --git-dir &>/dev/null 2>&1; then
    warn "No git repository found. Initialising..."
    if [[ "$DRY_RUN" == false ]]; then
        git init
        success "Git repository initialised"
    else
        info "[dry-run] Would run: git init"
    fi
else
    success "Git repository detected ($(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no branch yet'))"
fi

# ── create directory structure ────────────────────────────────────────────────
header "Step 2 — Directory Structure"

CLAUDE_DIR=".claude"
SCRIPTS_DEST="$CLAUDE_DIR/scripts"

if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$SCRIPTS_DEST"
    success "Created $SCRIPTS_DEST/"
else
    info "[dry-run] Would create: $SCRIPTS_DEST/"
fi

# ── copy scripts ──────────────────────────────────────────────────────────────
header "Step 3 — Installing Scripts"

for script in verify_state.py acs_ingest.py; do
    src="$ACS_SCRIPTS_DIR/$script"
    dst="$SCRIPTS_DEST/$script"
    if [[ -f "$src" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            cp "$src" "$dst"
            chmod +x "$dst"
            success "Installed $dst"
        else
            info "[dry-run] Would install: $dst"
        fi
    else
        warn "Script not found: $src — skipping"
    fi
done

# ── run init_acs.sh ───────────────────────────────────────────────────────────
header "Step 4 — Initialising ACS Documents"

INIT_SCRIPT="$ACS_SCRIPTS_DIR/init_acs.sh"

if [[ -f "$INIT_SCRIPT" ]]; then
    FORCE_FLAG=""
    [[ "$FORCE" == true ]] && FORCE_FLAG="--force"
    DRY_FLAG=""
    # DRY_FLAG removed — dry-run passed directly to acs_ingest.py

    if [[ "$DRY_RUN" == false ]]; then
        bash "$INIT_SCRIPT" "$PROJECT_NAME" "$PROJECT_DESC" $FORCE_FLAG
    else
        info "[dry-run] Would run: bash init_acs.sh \"$PROJECT_NAME\" \"$PROJECT_DESC\""
    fi
else
    warn "init_acs.sh not found — creating minimal document structure"
    if [[ "$DRY_RUN" == false ]]; then
        # Minimal fallback if init_acs.sh not available
        for template_file in MUST_READ.md STATE.md MEMORY.md PROTOCOL.md; do
            if [[ ! -f "$CLAUDE_DIR/$template_file" ]] || [[ "$FORCE" == true ]]; then
                touch "$CLAUDE_DIR/$template_file"
                info "Created (empty): $CLAUDE_DIR/$template_file"
            fi
        done
    fi
fi

# ── configure .gitignore ──────────────────────────────────────────────────────
header "Step 5 — Security: .gitignore"

GITIGNORE_ENTRIES=(
    ""
    "# ACS — runtime files (never commit these)"
    ".claude/last_verification.json"
    ".claude/ingestion_result.json"
    ""
    "# Environment and secrets (never commit these)"
    ".env"
    ".env.local"
    ".env.*.local"
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "secrets.json"
    "secrets.yaml"
    "secrets.yml"
    ""
    "# Python"
    "__pycache__/"
    "*.py[cod]"
    "*.egg-info/"
    ".venv/"
    "venv/"
    "env/"
    ".pytest_cache/"
    ".mypy_cache/"
    ""
    "# Node (if applicable)"
    "node_modules/"
    ""
    "# OS"
    ".DS_Store"
    "Thumbs.db"
    "desktop.ini"
)

if [[ "$DRY_RUN" == false ]]; then
    touch .gitignore
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if [[ -z "$entry" ]] || ! grep -qF "$entry" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
        fi
    done
    success ".gitignore configured with security entries"
else
    info "[dry-run] Would configure .gitignore"
fi

# ── create .env.example ───────────────────────────────────────────────────────
header "Step 6 — Environment Template"

ENV_EXAMPLE=".env.example"
ENV_ACTUAL=".env"

if [[ ! -f "$ENV_EXAMPLE" ]] || [[ "$FORCE" == true ]]; then
    if [[ "$DRY_RUN" == false ]]; then
        cat > "$ENV_EXAMPLE" << 'EOF'
# ACS Environment Variables Template
# Copy this file to .env and fill in your values
# NEVER commit .env to git

# Required for acs_ingest.py (planning document ingestion)
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Add your project-specific environment variables below
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname
# REDIS_URL=redis://localhost:6379
EOF
        success "Created $ENV_EXAMPLE (safe to commit — no real values)"
    else
        info "[dry-run] Would create: $ENV_EXAMPLE"
    fi
else
    info "$ENV_EXAMPLE already exists — skipping"
fi

# Create .env if it doesn't exist (empty, gitignored)
if [[ ! -f "$ENV_ACTUAL" ]] && [[ "$DRY_RUN" == false ]]; then
    cp "$ENV_EXAMPLE" "$ENV_ACTUAL"
    warn ".env created from template — add your ANTHROPIC_API_KEY before running acs_ingest.py"
fi

# ── document ingestion (if --input provided) ──────────────────────────────────
INGEST_RAN=false

if [[ ${#INPUT_FILES[@]} -gt 0 ]] && [[ "$SKIP_INGEST" == false ]]; then
    header "Step 7 — Planning Document Ingestion"

    # Check anthropic package
    if ! "$PYTHON" -c "import anthropic" 2>/dev/null; then
        warn "anthropic package not installed."
        info "Run: pip install anthropic python-docx"
        info "Then re-run: python .claude/scripts/acs_ingest.py --input ${INPUT_FILES[*]}"
        warn "Skipping ingestion — ACS structure initialised without planning document data"
    else
        # Resolve API key
        INGEST_API_ARG=""
        if [[ -n "$API_KEY" ]]; then
            INGEST_API_ARG="--api-key $API_KEY"
        elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
            info "Using ANTHROPIC_API_KEY from environment"
        elif [[ -f ".env" ]] && grep -q "ANTHROPIC_API_KEY" .env; then
            info "Using ANTHROPIC_API_KEY from .env file"
        else
            warn "ANTHROPIC_API_KEY not found."
            warn "Set it in .env or pass --api-key KEY"
            info "Skipping ingestion — run manually later:"
            info "  python .claude/scripts/acs_ingest.py --input ${INPUT_FILES[*]}"
            SKIP_INGEST=true
        fi

        if [[ "$SKIP_INGEST" == false ]]; then
            # Verify input files exist
            MISSING=false
            for f in "${INPUT_FILES[@]}"; do
                if [[ ! -f "$f" ]]; then
                    error "Input file not found: $f"
                    MISSING=true
                fi
            done

            if [[ "$MISSING" == false ]]; then
                INGEST_ARGS=("--input" "${INPUT_FILES[@]}")
                [[ "$FORCE" == true ]]   && INGEST_ARGS+=("--force")
                [[ "$DRY_RUN" == true ]] && INGEST_ARGS+=("--dry-run")
                [[ -n "$INGEST_API_ARG" ]] && IFS=" " read -r -a _api_arg <<< "$INGEST_API_ARG" && INGEST_ARGS+=("${_api_arg[@]}")

                info "Running: python .claude/scripts/acs_ingest.py ${INGEST_ARGS[*]}"
                "$PYTHON" "$SCRIPTS_DEST/acs_ingest.py" "${INGEST_ARGS[@]}"
                INGEST_RAN=true
            fi
        fi
    fi
else
    header "Step 7 — Planning Document Ingestion"
    info "No --input files provided. ACS documents initialised with templates."
    info "To ingest a planning document later:"
    info "  python .claude/scripts/acs_ingest.py --input YOUR_PLAN.md"
fi

# ── run verification ──────────────────────────────────────────────────────────
header "Step 8 — Verification"

VERIFY_SCRIPT="$SCRIPTS_DEST/verify_state.py"

if [[ -f "$VERIFY_SCRIPT" ]] && [[ "$DRY_RUN" == false ]]; then
    info "Running verify_state.py..."
    echo ""
    "$PYTHON" "$VERIFY_SCRIPT" || true  # Don't exit on verify failure — show result only
    echo ""
else
    info "[dry-run] Would run: python $VERIFY_SCRIPT"
fi

# ── initial git commit ────────────────────────────────────────────────────────
header "Step 9 — Initial Commit"

if [[ "$DRY_RUN" == false ]]; then
    # Stage ACS files
    git add .claude/ .gitignore .env.example 2>/dev/null || true
    [[ -f "CLAUDE.md" ]] && git add CLAUDE.md
    [[ -f "PROJECT_PROTOCOL_MASTER.md" ]] && git add PROJECT_PROTOCOL_MASTER.md

    # Check if there's anything to commit
    if git diff --cached --quiet 2>/dev/null; then
        info "Nothing new to commit (ACS already committed)"
    else
        COMMIT_MSG="chore: initialise ACS Absolute Continuity System

- .claude/MUST_READ.md: session startup brief
- .claude/STATE.md: verified completion tracking
- .claude/MEMORY.md: persistent project context
- .claude/PROTOCOL.md: quick reference
- .claude/scripts/verify_state.py: startup verification
- .claude/scripts/acs_ingest.py: planning document ingestion"

        [[ "$INGEST_RAN" == true ]] && \
            COMMIT_MSG="$COMMIT_MSG
- ACS documents auto-populated from: ${INPUT_FILES[*]}"

        git commit -m "$COMMIT_MSG"
        success "Initial ACS commit: $(git log --oneline -1)"
    fi
else
    info "[dry-run] Would commit all ACS files"
fi

# ── final summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   ACS SETUP COMPLETE                               ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    warn "DRY RUN — no files were written or committed"
    echo ""
    exit 0
fi

success "Project:  $PROJECT_NAME"
success "Location: $(pwd)"
echo ""

if [[ "$INGEST_RAN" == true ]]; then
    echo -e "  ${GREEN}STATE.md has been populated from your planning document.${NC}"
    echo -e "  Review ${BOLD}.claude/STATE.md${NC} to confirm all milestones are captured."
else
    echo -e "  ${YELLOW}STATE.md contains template rows only.${NC}"
    echo -e "  Populate ${BOLD}.claude/STATE.md${NC} with your project milestones before your first session."
    echo -e "  Or run: ${BOLD}python .claude/scripts/acs_ingest.py --input YOUR_PLAN.md${NC}"
fi

echo ""
echo "  Next steps:"
echo ""
echo "  1. Review and adjust the generated ACS documents:"
echo "       .claude/MUST_READ.md   — set your first session tasks"
echo "       .claude/STATE.md       — verify all milestones are listed"
echo "       .claude/MEMORY.md      — add any known architectural decisions"
echo ""
echo "  2. Add your ANTHROPIC_API_KEY to .env (if using acs_ingest.py)"
echo ""
echo "  3. Start your first session:"
echo "     Claude Code:  cd $(pwd) && claude"
echo "     Claude Chat:  paste .claude/MUST_READ.md as your first message"
echo ""
echo "  Full documentation: docs/ACS_PROTOCOL.md"
echo ""
echo -e "  ${BOLD}The one rule: STATE.md = reality, not intention.${NC}"
echo ""
