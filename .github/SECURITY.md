# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Active support |

## Reporting a Vulnerability

ACS scripts execute on user machines with local file and git access.
Security issues in these scripts are taken seriously and treated as priority issues.

**Do not open a public GitHub Issue for security vulnerabilities.**
Public disclosure before a fix is available puts all users at risk.

### Report via GitHub Security Advisories (preferred)

Repository → Security tab → Advisories → Report a vulnerability

This creates a private discussion visible only to maintainers.

### Report via email

[your-email@domain.com]

Please include:
- A description of the vulnerability
- The script or file affected
- Steps to reproduce the issue
- The potential impact (what could an attacker do?)
- A suggested fix if you have one

You will receive an acknowledgement within 48 hours.
Confirmed vulnerabilities will be patched promptly and disclosed via a
GitHub Security Advisory. Reporters will be credited unless they prefer
to remain anonymous.

## Security Design of ACS Scripts

Understanding what these scripts do helps identify what a vulnerability would mean:

**`setup.sh`**
- Creates directories and files in the current working directory
- Runs `git init` if no repository exists
- Runs `git add` and `git commit`
- Does not make network requests
- Does not require elevated privileges
- Does not read or transmit credentials

**`verify_state.py`**
- Reads files in the `.claude/` directory
- Runs `git` commands (status, log, fetch)
- Runs `python -m pytest` if a tests/ directory exists
- Runs `docker-compose ps` if Docker is available
- Does not make network requests
- Does not write credentials or sensitive data anywhere

**`acs_ingest.py`**
- Reads planning documents specified by the user (`--input` flag)
- Sends document content to `api.anthropic.com` via HTTPS
- Reads `ANTHROPIC_API_KEY` from environment or `.env` file
- Writes ACS document files to `.claude/`
- The API key is never logged, printed, or written to any file

**What these scripts do NOT do:**
- Execute arbitrary code from the internet
- Use `eval()` or `exec()` on untrusted input
- Request sudo/administrator privileges
- Write outside the current project directory
- Store credentials anywhere other than reading from `.env`

## Security Recommendations for Users

1. **Read scripts before running them.** All scripts are plain text.
   Review `setup.sh` and `verify_state.py` before your first use.

2. **Verify commits are signed.** Every commit on main shows a green
   "Verified" badge. An unsigned commit is anomalous.

3. **Install from a tagged release, not from main.**
   Tags are immutable. `main` can theoretically change between your
   `git clone` and your `bash setup.sh`.

4. **Verify the release checksum.**
   SHA256SUMS.txt is attached to every release. Verify before extracting:
   ```bash
   sha256sum -c SHA256SUMS.txt
   ```

5. **Your `ANTHROPIC_API_KEY` belongs in `.env` only.**
   Never add it to `CLAUDE.md`, `MUST_READ.md`, or any committed file.
   `verify_state.py` checks `CLAUDE.md` for common secret patterns and
   will warn if it finds any.

6. **Do not run ACS scripts with `sudo`.**
   They do not need elevated privileges. If something seems to require
   `sudo`, that is unexpected behaviour — report it.
