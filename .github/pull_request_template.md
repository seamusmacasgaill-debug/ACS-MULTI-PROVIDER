## Description
[What does this PR change and why?]

## Type of change
- [ ] Bug fix
- [ ] New feature or enhancement
- [ ] Documentation update
- [ ] Security fix
- [ ] Dependency update

## Testing completed
- [ ] `python -m py_compile scripts/verify_state.py` — no syntax errors
- [ ] `python -m py_compile scripts/acs_ingest.py` — no syntax errors
- [ ] `bash -n setup.sh` — no syntax errors
- [ ] `bash -n scripts/init_acs.sh` — no syntax errors
- [ ] `bash setup.sh "Test" "Test" --dry-run` — runs without error
- [ ] `bash setup.sh "Test" "Test" --force` on a clean directory — runs without error
- [ ] `python .claude/scripts/verify_state.py` on result — exits 0

## Security checklist
- [ ] No credentials, tokens, API keys, or secrets in any file
- [ ] No calls to external services beyond `api.anthropic.com` (acs_ingest.py only)
- [ ] Shell scripts do not use `eval` on untrusted input
- [ ] Python scripts do not use `exec()` or `eval()` on untrusted input
- [ ] File operations are scoped to the current working directory
- [ ] No new executable permissions set on non-script files
- [ ] `templates/CLAUDE.md` remains under 100 lines

## Documentation
- [ ] `docs/CHANGELOG.md` updated if this is a user-visible change
- [ ] `docs/ACS_PROTOCOL.md` updated if behaviour changes
- [ ] README.md updated if install instructions change
