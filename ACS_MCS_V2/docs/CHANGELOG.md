# CHANGELOG

All notable changes to ACS are documented here.

Format: [Version] — Date — Description

---

## [1.1] — 2026-03-05

### Added
- `acs_ingest.py` — automated population of ACS documents from planning files
- `setup.sh` — single-command project setup combining all scripts
- Automated ingestion supports `.md`, `.txt`, and `.docx` input formats
- Multiple planning documents can be merged in a single ingestion run
- `--dry-run`, `--json-only`, and `--force` flags for `acs_ingest.py`
- `.env.example` template generated automatically by `setup.sh`
- Security checks in `verify_state.py`: detects secrets in `CLAUDE.md`
- `docs/ACS_PROTOCOL.md` — unified canonical documentation (replaces five
  separate supplementary documents)

### Changed
- `init_acs.sh` now called from `setup.sh` rather than directly
- `CLAUDE.md` template now under 100 lines with clearer scope boundaries
- `verify_state.py` adds checks for `CLAUDE.md` presence and secret detection

### Removed
- Separate supplementary documents (`ACS_CLAUDE_CODE_INTEGRATION.md`,
  `ACS_Ingestion_Addendum.md`) — content merged into `ACS_PROTOCOL.md`

---

## [1.0] — 2026-03-01

### Initial release

- Five-mechanism session management protocol
- `verify_state.py` — startup verification script
- `init_acs.sh` — project initialisation script
- Five document templates (MUST_READ, STATE, MEMORY, CHECKPOINT, PROTOCOL)
- `CLAUDE.md` template for Claude Code auto-trigger
- Support for Claude.ai Chat (manual) and Claude Code CLI (automatic)
- Complete protocol documentation
