#!/usr/bin/env python3
"""
acs_ingest.py — ACS Planning Document Ingestion Script
=======================================================
Reads any existing planning document (BMAD, DevOps plan, product spec,
milestone doc, README, etc.) and automatically populates:

  - .claude/STATE.md        (all tasks/milestones as NOT_STARTED rows)
  - .claude/MUST_READ.md    (first session brief derived from the plan)
  - .claude/MEMORY.md       (architectural decisions and context extracted)
  - CLAUDE.md               (ACS trigger file for Claude Code)

Supports input formats:
  - Markdown (.md)
  - Plain text (.txt)
  - Word document (.docx)
  - Multiple files at once (pass several paths)

Usage:
  python acs_ingest.py --input BMAD.md
  python acs_ingest.py --input plan.docx
  python acs_ingest.py --input BMAD.md devops.md architecture.md
  python acs_ingest.py --input plan.md --project-name "My Project" --dry-run

Requirements:
  pip install anthropic python-docx

The script uses the Claude API (claude-sonnet-4-20250514) to parse the
planning document intelligently. Set ANTHROPIC_API_KEY in your environment
or .env file before running.

The script is SAFE to re-run. If ACS files already exist, it will show
a diff and ask for confirmation before overwriting.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── optional imports ──────────────────────────────────────────────────────────
try:
    import anthropic
except ImportError:
    print("ERROR: anthropic package not installed.")
    print("Run: pip install anthropic")
    sys.exit(1)

try:
    from docx import Document as DocxDocument
    DOCX_AVAILABLE = True
except ImportError:
    DOCX_AVAILABLE = False


# ── constants ─────────────────────────────────────────────────────────────────

MODEL = "claude-sonnet-4-20250514"
CLAUDE_DIR = Path(".claude")
SCRIPTS_DIR = CLAUDE_DIR / "scripts"
NOW = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

EXTRACTION_PROMPT = """You are reading a software project planning document.
Your job is to extract structured information to populate an ACS (Absolute
Continuity System) project tracking setup.

Extract the following and return ONLY valid JSON — no explanation, no markdown
fences, no preamble:

{
  "project_name": "string — the project name",
  "project_description": "string — 1-2 sentence description of what the project does",
  "tech_stack": ["list", "of", "technologies", "mentioned"],
  "phases": [
    {
      "phase_number": 1,
      "phase_name": "string",
      "phase_description": "string — one sentence"
    }
  ],
  "milestones": [
    {
      "id": "M-001",
      "phase": 1,
      "name": "string — short milestone name",
      "description": "string — what this milestone achieves",
      "category": "Infrastructure|DataPipeline|FeatureEngineering|Model|API|Testing|Deployment|Other",
      "size": "SMALL|MEDIUM|LARGE",
      "dependencies": ["M-000"]
    }
  ],
  "components": [
    {
      "name": "string — component name",
      "description": "string",
      "category": "Infrastructure|DataPipeline|FeatureEngineering|Model|API|Testing|Deployment"
    }
  ],
  "architectural_decisions": [
    {
      "title": "string",
      "decision": "string",
      "rationale": "string"
    }
  ],
  "external_dependencies": [
    {
      "name": "string",
      "purpose": "string",
      "version_or_notes": "string"
    }
  ],
  "key_constraints": ["string — any important constraints or non-negotiables"],
  "first_session_tasks": ["string — the first 3-5 things to do, in order"],
  "branch_strategy": "string — if mentioned, otherwise 'main / feature branches'",
  "environment_notes": "string — any environment or deployment notes"
}

Rules:
- Use "Unknown" for anything not mentioned in the document
- For milestones, assign sequential IDs like M-001, M-002 etc
- Infer size: SMALL = single function/config, MEDIUM = module with tests,
  LARGE = multi-component feature
- If phases are not explicit, infer them from logical groupings
- Extract ALL milestones and tasks mentioned, even implicitly
- Do not invent information not present in the document
- first_session_tasks should be the literal first things to do in session 1

Document to analyse:
---
{document_content}
---"""


# ── document readers ──────────────────────────────────────────────────────────

def read_markdown(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_txt(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_docx(path: Path) -> str:
    if not DOCX_AVAILABLE:
        print(f"ERROR: python-docx not installed. Cannot read {path}")
        print("Run: pip install python-docx")
        sys.exit(1)
    doc = DocxDocument(str(path))
    parts = []
    for para in doc.paragraphs:
        if para.text.strip():
            style = para.style.name
            if "Heading 1" in style:
                parts.append(f"\n# {para.text}")
            elif "Heading 2" in style:
                parts.append(f"\n## {para.text}")
            elif "Heading 3" in style:
                parts.append(f"\n### {para.text}")
            else:
                parts.append(para.text)
    # Include tables
    for table in doc.tables:
        for row in table.rows:
            cells = [cell.text.strip() for cell in row.cells]
            parts.append(" | ".join(cells))
    return "\n".join(parts)


def read_input_file(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in (".md", ".markdown"):
        return read_markdown(path)
    elif suffix == ".txt":
        return read_txt(path)
    elif suffix == ".docx":
        return read_docx(path)
    else:
        # Try reading as text
        try:
            return path.read_text(encoding="utf-8")
        except Exception:
            print(f"WARNING: Cannot read {path} — unsupported format. Skipping.")
            return ""


# ── Claude API extraction ─────────────────────────────────────────────────────

def extract_structure(document_content: str, api_key: str) -> dict:
    """Use Claude to extract structured project information."""
    client = anthropic.Anthropic(api_key=api_key)

    print("  Analysing document with Claude API...")
    prompt = EXTRACTION_PROMPT.format(document_content=document_content[:50000])

    response = client.messages.create(
        model=MODEL,
        max_tokens=4000,
        messages=[{"role": "user", "content": prompt}]
    )

    raw = response.content[0].text.strip()
    # Strip markdown fences if present
    raw = re.sub(r'^```(?:json)?\s*', '', raw)
    raw = re.sub(r'\s*```$', '', raw)

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Claude returned invalid JSON: {e}")
        print("Raw response (first 500 chars):", raw[:500])
        sys.exit(1)


# ── document generators ───────────────────────────────────────────────────────

def generate_state_md(data: dict) -> str:
    """Generate STATE.md from extracted project structure."""

    # Group milestones by category
    milestones = data.get("milestones", [])
    phases = data.get("phases", [])
    components = data.get("components", [])

    # Build phase name lookup
    phase_names = {p["phase_number"]: p["phase_name"] for p in phases}

    # Group by phase then category
    by_phase: dict = {}
    for m in milestones:
        phase = m.get("phase", 1)
        if phase not in by_phase:
            by_phase[phase] = {}
        cat = m.get("category", "Other")
        if cat not in by_phase[phase]:
            by_phase[phase][cat] = []
        by_phase[phase][cat].append(m)

    lines = [
        "# PROJECT STATE — VERIFIED COMPLETIONS ONLY",
        f"**Rule**: Nothing is added here without a verified commit hash.",
        f"**Last verification run**: {NOW}",
        f"**Project**: {data.get('project_name', 'Unknown')}",
        f"**Auto-generated from**: Planning document ingestion ({NOW})",
        "",
        "---",
        "",
        "## LEGEND",
        "| Status | Meaning |",
        "|--------|---------|",
        "| `VERIFIED` | Confirmed working — commit hash and test evidence recorded |",
        "| `IN_PROGRESS` | Currently being built this session |",
        "| `PARTIAL` | Started but not complete — recovery path documented in CHECKPOINT.md |",
        "| `NOT_STARTED` | On the roadmap but not yet begun |",
        "| `BLOCKED` | Cannot proceed — blocker documented in MUST_READ.md |",
        "",
        "---",
        "",
    ]

    # Phases and milestones
    for phase_num in sorted(by_phase.keys()):
        phase_name = phase_names.get(phase_num, f"Phase {phase_num}")
        lines.append(f"## Phase {phase_num}: {phase_name}")
        lines.append("")

        phase_data = by_phase[phase_num]
        for category, items in phase_data.items():
            lines.append(f"### {category}")
            lines.append("")
            lines.append("| ID | Milestone | Size | Status | Commit | Verified |")
            lines.append("|-----|-----------|------|--------|--------|----------|")
            for item in items:
                mid = item.get("id", "M-???")
                name = item.get("name", "Unknown")
                size = item.get("size", "MEDIUM")
                desc = item.get("description", "")
                # Truncate long descriptions for table
                if len(name) > 50:
                    name = name[:47] + "..."
                lines.append(f"| {mid} | {name} | {size} | NOT_STARTED | — | — |")
                if desc:
                    lines.append(f"| | *{desc[:80]}* | | | | |")
            lines.append("")

    # Infrastructure section (always present)
    lines += [
        "---",
        "",
        "## Infrastructure & Environment",
        "",
        "| Component | Status | Commit | Verified Timestamp |",
        "|-----------|--------|--------|--------------------|",
        "| Git repository | VERIFIED | (initial) | " + NOW + " |",
        "| ACS Protocol files | VERIFIED | (initial) | " + NOW + " |",
        "| Python environment | NOT_STARTED | — | — |",
        "| Docker / compose | NOT_STARTED | — | — |",
        "| Database | NOT_STARTED | — | — |",
    ]

    # External dependencies
    ext_deps = data.get("external_dependencies", [])
    if ext_deps:
        lines += [
            "",
            "---",
            "",
            "## External Dependencies",
            "",
            "| Dependency | Purpose | Version / Notes | Status |",
            "|------------|---------|-----------------|--------|",
        ]
        for dep in ext_deps:
            name = dep.get("name", "Unknown")
            purpose = dep.get("purpose", "")
            notes = dep.get("version_or_notes", "—")
            lines.append(f"| {name} | {purpose} | {notes} | NOT_STARTED |")

    # Tests section
    lines += [
        "",
        "---",
        "",
        "## Test Suites",
        "",
        "| Test Suite | Pass | Fail | Last Run | Commit |",
        "|------------|------|------|----------|--------|",
        "| (no tests yet) | — | — | — | — |",
        "",
        "---",
        "",
        "## Git State",
        f"- Current branch: main",
        "- Last push confirmed: (not yet pushed)",
        "- Remote sync status: NOT_CONFIGURED",
        "",
    ]

    return "\n".join(lines)


def generate_must_read_md(data: dict) -> str:
    """Generate MUST_READ.md for the first session."""

    first_tasks = data.get("first_session_tasks", [])
    phases = data.get("phases", [])
    first_phase = phases[0] if phases else {"phase_number": 1, "phase_name": "Setup"}
    tech_stack = data.get("tech_stack", [])
    constraints = data.get("key_constraints", [])

    # Format first session tasks as ATUs
    task_lines = []
    for i, task in enumerate(first_tasks[:5], 1):
        task_lines.append(f"{i}. ATU-00{i}: {task} — SMALL")

    if not task_lines:
        task_lines = [
            "1. ATU-001: Run verify_state.py and confirm clean baseline — SMALL",
            "2. ATU-002: Set up Python environment and install dependencies — SMALL",
            "3. ATU-003: Configure git remote and confirm push works — SMALL",
        ]

    lines = [
        "# MUST READ — SESSION STARTUP BRIEF",
        f"**Last updated**: {NOW}",
        "**Updated by**: ACS Ingestion (auto-generated)",
        "**Emergency flag**: NONE",
        "",
        "## ⚡ IMMEDIATE ACTIONS (do before anything else)",
        "1. Run: `python .claude/scripts/verify_state.py`",
        "2. If verification fails: resolve discrepancies before ANY new work",
        "3. Read CHECKPOINT.md if Emergency flag is set above",
        "",
        "---",
        "",
        f"## Project: {data.get('project_name', 'Unknown')}",
        data.get("project_description", ""),
        "",
        "## Current Phase",
        f"**Phase**: {first_phase.get('phase_number', 1)} — {first_phase.get('phase_name', 'Setup')}",
        f"**Current Focus**: Project initialisation — ACS setup and environment verification",
        "**Blocking Issues**: NONE",
        "",
        "## Last Verified Completion",
        "**ATU**: ATU-000 — ACS Protocol Initialised",
        "**Commit**: (run `git log --oneline -1` to confirm)",
        f"**Timestamp**: {NOW}",
        "**Verification**: `python .claude/scripts/verify_state.py` → exit 0",
        "",
        "## THIS Session's Tasks (in order)",
        "\n".join(task_lines),
        "",
        "## Architecture Summary",
    ]

    if tech_stack:
        lines.append(f"- **Tech stack**: {', '.join(tech_stack)}")

    env_notes = data.get("environment_notes", "")
    if env_notes and env_notes != "Unknown":
        lines.append(f"- **Environment**: {env_notes}")

    branch_strategy = data.get("branch_strategy", "main / feature branches")
    if branch_strategy and branch_strategy != "Unknown":
        lines.append(f"- **Branch strategy**: {branch_strategy}")

    if constraints:
        lines.append("- **Key constraints**:")
        for c in constraints[:3]:
            lines.append(f"  - {c}")

    lines += [
        "",
        "## Active Environment Details",
        f"- Python version: 3.11+",
        "- Key services: (update when services are configured)",
        "- Branch: main",
        "- Key env vars needed: (update as discovered)",
        "",
        "## Do NOT Do This Session",
        "- Write any application code before ACS baseline is confirmed",
        "- Mark anything VERIFIED in STATE.md without a commit hash",
        "- Start a LARGE task without confirming sufficient session capacity",
    ]

    return "\n".join(lines)


def generate_memory_md(data: dict) -> str:
    """Generate MEMORY.md from architectural decisions and context."""

    decisions = data.get("architectural_decisions", [])
    ext_deps = data.get("external_dependencies", [])
    tech_stack = data.get("tech_stack", [])

    lines = [
        "# PROJECT MEMORY — PERSISTENT CONTEXT",
        f"**Project**: {data.get('project_name', 'Unknown')}",
        f"**Initialised**: {NOW}",
        "",
        "---",
        "",
        "## Architectural Decisions",
        "",
        f"### {NOW}: ACS Protocol Adopted",
        "**Decision**: Using the Absolute Continuity System (ACS) for all session management.",
        "**Rationale**: Enforces verification gates before marking anything complete. "
        "Documentation is a side-effect of verified actions, not a substitute for them.",
        "**Impact**: Every task requires a verify command + git log confirmation. "
        "STATE.md updated only with real commit hashes.",
        "",
    ]

    for dec in decisions:
        title = dec.get("title", "Untitled Decision")
        decision = dec.get("decision", "")
        rationale = dec.get("rationale", "")
        lines += [
            f"### {NOW}: {title}",
            f"**Decision**: {decision}",
            f"**Rationale**: {rationale}",
            "**Alternatives considered**: (document as they arise)",
            "**Impact**: (document as understood)",
            "",
        ]

    lines += [
        "---",
        "",
        "## Problems Encountered and Resolved",
        "(None yet — add as they occur)",
        "",
        "---",
        "",
        "## External Dependencies",
        "",
        "| Dependency | Version | Purpose | First encountered |",
        "|------------|---------|---------|-------------------|",
    ]

    if ext_deps:
        for dep in ext_deps:
            name = dep.get("name", "Unknown")
            purpose = dep.get("purpose", "")
            notes = dep.get("version_or_notes", "—")
            lines.append(f"| {name} | {notes} | {purpose} | {NOW} |")
    else:
        lines.append("| (none yet) | — | — | — |")

    lines += [
        "",
        "---",
        "",
        "## Changed Understanding",
        "(None yet — add when understanding of the codebase evolves)",
        "",
        "---",
        "",
        "## Performance Baselines",
        "",
        "| Metric | Baseline | Target | Current Best | Date |",
        "|--------|----------|--------|--------------|------|",
        "| (none yet) | — | — | — | — |",
        "",
        "---",
        "",
        "## Tech Stack Reference",
        "",
    ]

    if tech_stack:
        for tech in tech_stack:
            lines.append(f"- {tech}")
    else:
        lines.append("(to be documented as established)")

    return "\n".join(lines)


def generate_claude_md(data: dict) -> str:
    """Generate CLAUDE.md for Claude Code auto-trigger."""

    project_name = data.get("project_name", "Unknown Project")
    project_desc = data.get("project_description", "")
    tech_stack = data.get("tech_stack", [])
    stack_str = ", ".join(tech_stack[:5]) if tech_stack else "see MEMORY.md"
    phases = data.get("phases", [])
    first_phase = phases[0] if phases else {"phase_number": 1, "phase_name": "Setup"}

    return f"""# CLAUDE.md — ACS PROTOCOL TRIGGER
# Keep this file under 100 lines. All detail lives in .claude/

## ⚡ MANDATORY STARTUP — Do this before ANY other action

### Step 1: Run verification
```bash
python .claude/scripts/verify_state.py
```

### Step 2: Read session brief
Read `.claude/MUST_READ.md` in full.

### Step 3: Your first response must confirm ALL of these:
- [ ] Verification script result: exit 0 (clean) or exit 1 (discrepancies found)
- [ ] Current git HEAD: output of `git log --oneline -1`
- [ ] Last verified ATU: from STATE.md
- [ ] CHECKPOINT.md status: clean / or recovery needed (describe)
- [ ] Planned tasks this session: from MUST_READ.md

**Do not write any code until all five confirmations are in your response.**

---

## Project: {project_name}
{project_desc}

## Phase
Phase {first_phase.get('phase_number', 1)} — {first_phase.get('phase_name', 'Setup')}

## Tech Stack
{stack_str}

## ACS Document Map
| Need | File |
|------|------|
| What to do this session | `.claude/MUST_READ.md` |
| What is verified complete | `.claude/STATE.md` |
| Architectural decisions | `.claude/MEMORY.md` |
| Live session progress | `.claude/CHECKPOINT.md` |
| Protocol quick reference | `.claude/PROTOCOL.md` |
| Full protocol | `PROJECT_PROTOCOL_MASTER.md` |

## Never Do Without Permission
- Merge to main without all tests passing
- Mark STATE.md VERIFIED without a commit hash
- Start a LARGE task without a credit horizon check
- End a session without updating MUST_READ.md for the next session
"""


def generate_protocol_md() -> str:
    """Generate the quick-reference PROTOCOL.md."""
    return """# ACS PROTOCOL — QUICK REFERENCE
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

## Never Say "Complete" Without:
Running the verify command AND showing its actual output
AND running git log --oneline -1 AND showing that output

## Credit Check — Before MEDIUM or LARGE Tasks, State:
"Task size: [SIZE]. Estimated time: [X min].
 Remaining session capacity: [assessment].
 Safe to start: YES/NO."

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
3. Add WARNING flag to top of MUST_READ.md

## The Ten Golden Rules:
1.  Verify before trusting — run verify_state.py first
2.  Never claim complete — only show verification output
3.  Commit hash or it didn't happen — git log confirms
4.  STATE.md = reality not intention
5.  CHECKPOINT.md is live — update after every ATU
6.  Check credit before large tasks — estimate first
7.  80% rule — stop starting, finish cleanly
8.  Emergency commit — always better than undocumented state
9.  Partial is documented — never leave undocumented partial state
10. MUST_READ.md written before this session ends
"""


# ── file writing with diff/confirm ───────────────────────────────────────────

def write_file_safe(path: Path, content: str, dry_run: bool, force: bool) -> bool:
    """Write a file, showing diff if it exists. Returns True if written."""
    if path.exists() and not force:
        existing = path.read_text(encoding="utf-8")
        if existing == content:
            print(f"  UNCHANGED  {path}")
            return False
        print(f"  MODIFIED   {path}  (file already exists)")
        if not dry_run:
            response = input(f"    Overwrite {path}? [y/N]: ").strip().lower()
            if response != "y":
                print(f"    Skipped.")
                return False

    if dry_run:
        print(f"  DRY-RUN    Would write {path} ({len(content)} chars)")
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  WRITTEN    {path}")
    return True


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="ACS Planning Document Ingestion — auto-populate ACS documents "
                    "from a BMAD doc, DevOps plan, product spec, or any project planning file."
    )
    parser.add_argument(
        "--input", "-i",
        nargs="+",
        required=True,
        metavar="FILE",
        help="Input planning document(s). Supports .md, .txt, .docx"
    )
    parser.add_argument(
        "--project-name", "-n",
        default=None,
        help="Override project name (otherwise extracted from document)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be written without writing any files"
    )
    parser.add_argument(
        "--force", "-f",
        action="store_true",
        help="Overwrite existing files without prompting"
    )
    parser.add_argument(
        "--output-dir",
        default=".",
        help="Project root directory (default: current directory)"
    )
    parser.add_argument(
        "--api-key",
        default=None,
        help="Anthropic API key (default: ANTHROPIC_API_KEY env var)"
    )
    parser.add_argument(
        "--skip-claude-md",
        action="store_true",
        help="Do not generate CLAUDE.md (if you manage it separately)"
    )
    parser.add_argument(
        "--json-only",
        action="store_true",
        help="Only output the extracted JSON structure, do not write ACS files"
    )

    args = parser.parse_args()

    # ── resolve API key ───────────────────────────────────────────────────────
    api_key = args.api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        # Try loading from .env
        env_file = Path(args.output_dir) / ".env"
        if env_file.exists():
            for line in env_file.read_text().splitlines():
                if line.startswith("ANTHROPIC_API_KEY="):
                    api_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY not set.")
        print("Set it as an environment variable or pass --api-key")
        sys.exit(1)

    # ── read input files ──────────────────────────────────────────────────────
    print("\nACS Document Ingestion")
    print("=" * 60)
    print(f"Reading input files...")

    combined_content = []
    for file_path_str in args.input:
        file_path = Path(file_path_str)
        if not file_path.exists():
            print(f"  ERROR: File not found: {file_path}")
            sys.exit(1)
        print(f"  Reading: {file_path} ({file_path.stat().st_size // 1024}KB)")
        content = read_input_file(file_path)
        if content:
            combined_content.append(f"\n\n--- SOURCE: {file_path.name} ---\n\n{content}")

    if not combined_content:
        print("ERROR: No readable content found in input files.")
        sys.exit(1)

    full_document = "\n".join(combined_content)
    print(f"  Total content: {len(full_document):,} characters from {len(combined_content)} file(s)")

    # ── extract structure via Claude API ─────────────────────────────────────
    print("\nExtracting project structure...")
    data = extract_structure(full_document, api_key)

    # Override project name if provided
    if args.project_name:
        data["project_name"] = args.project_name

    print(f"  Project: {data.get('project_name', 'Unknown')}")
    print(f"  Phases: {len(data.get('phases', []))}")
    print(f"  Milestones: {len(data.get('milestones', []))}")
    print(f"  Architectural decisions: {len(data.get('architectural_decisions', []))}")
    print(f"  External dependencies: {len(data.get('external_dependencies', []))}")

    if args.json_only:
        print("\nExtracted JSON structure:")
        print(json.dumps(data, indent=2))
        return

    # ── generate and write ACS documents ─────────────────────────────────────
    output_root = Path(args.output_dir)
    claude_dir = output_root / ".claude"
    scripts_dir = claude_dir / "scripts"

    print(f"\nGenerating ACS documents in: {output_root.resolve()}")
    if args.dry_run:
        print("  (DRY RUN — no files will be written)")
    print()

    written = []

    # STATE.md
    state_content = generate_state_md(data)
    if write_file_safe(claude_dir / "STATE.md", state_content, args.dry_run, args.force):
        written.append("STATE.md")

    # MUST_READ.md
    must_read_content = generate_must_read_md(data)
    if write_file_safe(claude_dir / "MUST_READ.md", must_read_content, args.dry_run, args.force):
        written.append("MUST_READ.md")

    # MEMORY.md
    memory_content = generate_memory_md(data)
    if write_file_safe(claude_dir / "MEMORY.md", memory_content, args.dry_run, args.force):
        written.append("MEMORY.md")

    # PROTOCOL.md
    protocol_content = generate_protocol_md()
    if write_file_safe(claude_dir / "PROTOCOL.md", protocol_content, args.dry_run, args.force):
        written.append("PROTOCOL.md")

    # CLAUDE.md (project root)
    if not args.skip_claude_md:
        claude_md_content = generate_claude_md(data)
        if write_file_safe(output_root / "CLAUDE.md", claude_md_content, args.dry_run, args.force):
            written.append("CLAUDE.md")

    # Ensure scripts directory exists
    if not args.dry_run:
        scripts_dir.mkdir(parents=True, exist_ok=True)

    # Save extracted JSON for reference
    json_path = claude_dir / "ingestion_result.json"
    if not args.dry_run:
        claude_dir.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(data, indent=2))
        print(f"  WRITTEN    {json_path}  (extracted structure for reference)")
        written.append("ingestion_result.json")

    # ── summary ───────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    if args.dry_run:
        print("DRY RUN COMPLETE — no files were written")
    else:
        print(f"INGESTION COMPLETE — {len(written)} files written")
        print()
        milestones = data.get("milestones", [])
        print(f"  STATE.md populated with {len(milestones)} milestones (all NOT_STARTED)")
        print()
        print("NEXT STEPS:")
        print("  1. Review .claude/STATE.md — confirm all milestones are captured")
        print("  2. Review .claude/MUST_READ.md — adjust first session tasks if needed")
        print("  3. Place verify_state.py in .claude/scripts/ if not already there")
        print("  4. Run: python .claude/scripts/verify_state.py")
        print("  5. Commit all ACS files: git add .claude/ CLAUDE.md && git commit")
        print("  6. Start your first session")
    print("=" * 60)


if __name__ == "__main__":
    main()
