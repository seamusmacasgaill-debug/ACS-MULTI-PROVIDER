# ACS GITHUB REPOSITORY: SECURITY & SETTINGS GUIDE

**Why this matters more than a typical repo**

ACS scripts execute on user machines with broad permissions:
- `setup.sh` writes files, modifies `.gitignore`, makes git commits
- `verify_state.py` reads the entire project tree and runs the test suite
- `acs_ingest.py` reads files and sends content to an external API
- `init_acs.sh` creates directory structures and makes commits

A user who runs a tampered version of any of these scripts has handed that
script the same permissions as themselves on their machine. Supply chain
integrity is not optional for this package — it is the primary security concern.

Every setting in this document exists to ensure that what a user downloads is
exactly what was published, unmodified.

---

## PART 1: REPOSITORY CREATION SETTINGS

### 1.1 Visibility

**Setting**: Public  
**Location**: Settings → General → Danger Zone → Change repository visibility  
**Reason**: ACS is open source (MIT licence). Public visibility is required for
community trust — users need to be able to read every line of every script
before running it. A private repo offering "trust us" binaries is a red flag
for any security-conscious developer.

### 1.2 Repository Description and Topics

**Setting**: Complete these fields before first publish  
**Location**: Repository main page → gear icon next to "About"

```
Description: Session management protocol for multi-session AI-assisted development
Website:     (your documentation site if you create one, otherwise blank)
Topics:      claude, ai-development, session-management, devops, developer-tools,
             claude-code, llm, productivity
```

Topics improve discoverability and signal what the project is. Do not add
misleading topics — GitHub has policies against keyword stuffing.

### 1.3 Features to Enable

**Location**: Settings → General → Features

```
✅ Issues              — for bug reports and feature requests
✅ Discussions         — for community Q&A (recommended for a tool like this)
✅ Projects            — optional, useful for tracking ACS version roadmap
❌ Wiki                — disable; all documentation lives in docs/ACS_PROTOCOL.md
✅ Sponsorships        — optional; enable if you want to accept GitHub Sponsors
```

### 1.4 Pull Requests Settings

**Location**: Settings → General → Pull Requests

```
✅ Allow merge commits         — standard
❌ Allow squash merging        — disable; preserves commit history integrity
❌ Allow rebase merging        — disable; preserves linear, auditable history

✅ Always suggest updating pull request branches
✅ Allow auto-merge            — disable initially; re-enable if you add CI
✅ Automatically delete head branches after merge
```

Disabling squash and rebase is important for a security-sensitive repo.
Every commit to main should be individually auditable. Squashing obscures
what changed and when.

---

## PART 2: BRANCH PROTECTION — THE MOST CRITICAL SETTING

This is the setting that prevents unauthorised alteration of the canonical version.

### 2.1 Protect the Main Branch

**Location**: Settings → Branches → Add branch ruleset (or Add rule)  
**Branch name pattern**: `main`

**Required settings:**

```
✅ Restrict deletions
   — Prevents anyone (including you accidentally) from deleting main

✅ Require a pull request before merging
   Required approvals: 1
   ✅ Dismiss stale pull request approvals when new commits are pushed
   ✅ Require review from Code Owners (once CODEOWNERS file is in place)
   ❌ Allow specified actors to bypass required pull requests
      (Do NOT grant bypass — including to yourself. Force yourself
       through the PR process. This is the protection.)

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
   Status checks to require: (add your CI checks here — see Part 4)

✅ Require conversation resolution before merging

✅ Require signed commits
   — CRITICAL for this package. See Part 3.

✅ Require linear history
   — Prevents merge commits on main; keeps history clean and auditable

✅ Block force pushes
   — Prevents history rewriting. Even you cannot force-push to main.
   — Once a commit is on main, it is permanent.

✅ Restrict who can push to matching branches
   — Add only your GitHub username (and any co-maintainers)
```

**Why "Block force pushes" matters for ACS specifically:**
If a bad actor compromises your GitHub account, force push to main is the
fastest way to replace legitimate scripts with malicious ones and erase the
evidence. With this setting on, even a compromised account cannot silently
alter history. The old commits remain visible and the tamper is detectable.

### 2.2 Protect Release Tags

**Location**: Settings → Branches → Add branch ruleset  
**Branch name pattern**: `v*` (covers all version tags like v1.0, v1.1)

```
✅ Restrict deletions
✅ Block force pushes
✅ Restrict who can push: your username only
```

Tags are what users pin to in their installations. A tag that can be moved
or deleted silently is a supply chain risk.

---

## PART 3: COMMIT SIGNING — PROVING IT WAS YOU

### 3.1 Why Commit Signing Is Required for This Package

Without signed commits, anyone who briefly accesses your GitHub account
(session hijack, credential theft) can commit malicious code as you with
no cryptographic evidence of the tampering. With signed commits, every
legitimate commit carries a GPG or SSH signature that only you can produce.
Users and GitHub can verify that commits on main were made by the key holder.

### 3.2 Setting Up GPG Signing Locally

**On your machine (WSL Ubuntu, since that is your environment):**

```bash
# Generate a GPG key (use your real name and GitHub email)
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, does not expire (or set expiry if preferred)
# Use the same email as your GitHub account

# Get your key ID
gpg --list-secret-keys --keyid-format LONG

# Output looks like:
# sec   rsa4096/[KEY_ID_HERE] 2026-03-05 [SC]
#       [fingerprint]
# uid   [Your Name] <your@email.com>

# Export the public key
gpg --armor --export [KEY_ID_HERE]
# Copy the entire output including -----BEGIN PGP PUBLIC KEY BLOCK-----
```

**Add to GitHub:**
Settings → SSH and GPG keys → New GPG key → paste the exported public key

**Configure git to sign all commits:**
```bash
git config --global user.signingkey [KEY_ID_HERE]
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# If on WSL, you may need to set the GPG program explicitly:
git config --global gpg.program gpg
```

**Verify signing is working:**
```bash
git commit --allow-empty -m "test: verify GPG signing"
git log --show-signature -1
# Should show: gpg: Good signature from "Your Name <email>"
```

### 3.3 Alternative: SSH Signing (Simpler)

If GPG setup is complex in your WSL environment, GitHub now supports SSH
key signing as an alternative:

```bash
# Use your existing SSH key
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Then add the same SSH key as a "Signing Key" in GitHub Settings → SSH and
GPG keys (there is a separate "Signing keys" section from authentication keys).

### 3.4 Verified Badge

Once signing is configured and branch protection requires signed commits,
every commit on main will show a green "Verified" badge in the GitHub UI.
Users who inspect the repo before running scripts can confirm all commits
are signed. An unsigned commit on main is immediately visible as anomalous.

---

## PART 4: GITHUB ACTIONS — AUTOMATED INTEGRITY VERIFICATION

GitHub Actions provides automated checks that run on every push and PR.
For ACS, the most important check is that the scripts actually work.

### 4.1 Create the CI Workflow

**File to create:** `.github/workflows/ci.yml`

```yaml
name: ACS CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  verify-scripts:
    name: Verify scripts are functional
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install anthropic python-docx

      - name: Check script syntax (verify_state.py)
        run: python -m py_compile scripts/verify_state.py

      - name: Check script syntax (acs_ingest.py)
        run: python -m py_compile scripts/acs_ingest.py

      - name: Verify setup.sh is valid bash
        run: bash -n setup.sh

      - name: Verify init_acs.sh is valid bash
        run: bash -n scripts/init_acs.sh

      - name: Run setup in dry-run mode
        run: |
          mkdir /tmp/test-project
          cd /tmp/test-project
          git init
          git config user.email "ci@test.com"
          git config user.name "CI Test"
          bash $GITHUB_WORKSPACE/setup.sh "CI Test Project" "Testing" --dry-run

      - name: Run verify_state.py on a clean project
        run: |
          mkdir /tmp/verify-test
          cd /tmp/verify-test
          git init
          git config user.email "ci@test.com"
          git config user.name "CI Test"
          bash $GITHUB_WORKSPACE/setup.sh "Verify Test" "Testing" --force
          python .claude/scripts/verify_state.py

  lint-shell:
    name: Shell script linting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck
      - name: Lint setup.sh
        run: shellcheck setup.sh
      - name: Lint init_acs.sh
        run: shellcheck scripts/init_acs.sh

  check-no-secrets:
    name: Scan for accidentally committed secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks secret scanner
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 4.2 Add CI as a Required Status Check

After the first CI run completes:
Settings → Branches → main branch rule → Require status checks →
Add `verify-scripts`, `lint-shell`, `check-no-secrets`

A PR that breaks any of these checks cannot be merged. This means a
contributor cannot introduce a syntax error in `setup.sh` or accidentally
commit an API key without it being caught before it reaches main.

---

## PART 5: SECURITY POLICY AND VULNERABILITY REPORTING

### 5.1 Create SECURITY.md

**File to create:** `SECURITY.md` in the repository root

```markdown
# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes     |

## Reporting a Vulnerability

ACS scripts run on user machines with local file and git access.
Security vulnerabilities in these scripts are taken seriously.

**Do not open a public GitHub Issue for security vulnerabilities.**

Report security issues privately via GitHub's security advisory system:
Repository → Security tab → Advisories → New draft security advisory

Or email: [your-email@domain.com]

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

You will receive a response within 48 hours.
Confirmed vulnerabilities will be patched and disclosed via a
GitHub Security Advisory with credit to the reporter.

## Security Considerations for Users

ACS scripts execute on your local machine. Before running any script
from this or any repository:

1. Read the script source code before executing it
2. Verify commits are signed (green "Verified" badge on GitHub)
3. Pin to a specific release tag rather than cloning main directly
4. Never run scripts with elevated privileges (sudo) unless you
   understand exactly why they need it (ACS scripts do not)
5. Your ANTHROPIC_API_KEY should be in .env only, never in CLAUDE.md
   or any committed file
```

### 5.2 Enable Private Vulnerability Reporting

**Location**: Settings → Security → Private vulnerability reporting → Enable

This creates a private channel for security researchers to report issues
without exposing them publicly before a fix is available.

### 5.3 Enable Dependabot

**Location**: Settings → Security → Dependabot

```
✅ Dependency graph
✅ Dependabot alerts
✅ Dependabot security updates
```

ACS has Python dependencies (`anthropic`, `python-docx`). Dependabot will
alert you when a dependency has a known vulnerability and can auto-create
PRs to update them.

**Create** `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
```

---

## PART 6: RELEASES AND DISTRIBUTION INTEGRITY

### 6.1 Use GitHub Releases, Not Raw Branch Downloads

Users should install ACS by downloading a tagged release, not by cloning
main. A release is a snapshot — it cannot be silently altered after the fact.

**How to create a release:**

```bash
# Tag the release (signed tag)
git tag -s v1.0.0 -m "ACS v1.0.0 — initial release"
git push origin v1.0.0
```

Then in GitHub: Releases → Create a new release → Select tag v1.0.0 →
Write release notes → Publish release.

GitHub automatically generates `.zip` and `.tar.gz` archives of the tagged
commit. These are what users download via the quickstart in README.md.

**Update README.md install command to use a specific release:**

```bash
# Replace this (installs from main — mutable):
git clone https://github.com/yourusername/acs.git .acs-setup

# With this (installs from a specific tagged release — immutable):
curl -L https://github.com/yourusername/acs/archive/refs/tags/v1.0.0.tar.gz \
  | tar -xz --strip-components=1 -C .acs-setup/
```

Or even simpler — a one-line install that users can inspect before running:

```bash
# Install ACS v1.0.0
bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/acs/v1.0.0/setup.sh) \
  "Project Name" "Description"
```

### 6.2 Add SHA256 Checksums to Releases

After creating a release, add SHA256 checksums to the release notes so
users can verify the archive was not tampered with in transit:

```bash
# Generate checksums for the release archives
sha256sum acs-v1.0.0.tar.gz acs-v1.0.0.zip > SHA256SUMS.txt
```

Attach `SHA256SUMS.txt` to the GitHub release as an additional asset.

### 6.3 CODEOWNERS File

**File to create:** `.github/CODEOWNERS`

```
# All files require review from the repository owner
* @yourusername

# Scripts require explicit owner review (highest security concern)
/scripts/ @yourusername
/setup.sh @yourusername
```

This ensures that no PR touching any script file can be merged without
your explicit approval, regardless of any other settings.

---

## PART 7: ACCESS CONTROL

### 7.1 Two-Factor Authentication

**Location**: Your personal GitHub Settings → Password and authentication  
**Setting**: Enable two-factor authentication (2FA)

**Use an authenticator app, not SMS.** SMS 2FA is vulnerable to SIM-swapping
attacks. Use:
- GitHub Mobile app (simplest)
- Authy or Google Authenticator
- A hardware key (YubiKey) for highest security

This is the most important personal security step. Branch protection and
signed commits protect the repository, but 2FA protects the account that
controls those settings.

### 7.2 Personal Access Tokens

If you use Personal Access Tokens (PATs) to push to the repository:

- Use fine-grained tokens, not classic tokens
- Scope them to only the ACS repository
- Set an expiration (90 days maximum recommended)
- Never commit a PAT anywhere — if one appears in git history, rotate it immediately

### 7.3 Deploy Keys (if using CI/CD outside GitHub Actions)

If you set up external CI or deployment:
- Use deploy keys (SSH keys specific to one repo) rather than PATs
- Deploy keys should be read-only unless write access is explicitly required

---

## PART 8: REPOSITORY SETTINGS SPECIFIC TO THIS PROJECT TYPE

These settings are specifically relevant because ACS is a **developer tool
containing executable scripts**, not a library or application.

### 8.1 No GitHub Pages

**Setting**: Disable GitHub Pages  
**Location**: Settings → Pages → Source → None

ACS documentation lives in the repository. There is no need for a GitHub
Pages site, and an enabled Pages site creates an additional attack surface
(the Pages deployment process has had vulnerabilities historically).

### 8.2 No GitHub Packages

**Setting**: Do not publish to GitHub Packages (npm, pip, etc.)  
**Reason**: ACS is installed by cloning or downloading a release, not via
a package manager. Registering it as a pip package or npm package would
require maintaining that channel and adds complexity without benefit.
If a pip package is desired in the future, create a separate release process
with its own integrity verification (PyPI supports trusted publishers via
GitHub Actions).

### 8.3 Actions Permissions

**Location**: Settings → Actions → General

```
Actions permissions:
  ✅ Allow [yourusername] actions and reusable workflows
  ✅ Allow actions created by GitHub
  ❌ Allow all actions — DISABLE THIS

Workflow permissions:
  ✅ Read repository contents and packages permissions (default)
  ❌ Read and write permissions — keep read-only as default
  ✅ Allow GitHub Actions to create and approve pull requests — DISABLE
```

Restricting Actions permissions prevents a compromised or malicious GitHub
Action dependency from gaining write access to your repository.

### 8.4 Secrets in GitHub Actions

The CI workflow for ACS does **not** need `ANTHROPIC_API_KEY` — the CI
tests run in dry-run mode without ingesting documents. Keep this key out
of GitHub Actions secrets entirely.

If you add a CI test that actually calls the API in the future:
- Add it as a repository secret: Settings → Secrets and variables → Actions
- Name it `ANTHROPIC_API_KEY`
- Never echo it in CI logs (`echo $ANTHROPIC_API_KEY` in a workflow is a
  security mistake — GitHub will attempt to redact it but this is not foolproof)

---

## PART 9: COMMUNITY AND CONTRIBUTION SETTINGS

### 9.1 Issue Templates

**Create**: `.github/ISSUE_TEMPLATE/bug_report.yml` and `feature_request.yml`

This standardises reports and prevents issues from being used to report
security vulnerabilities publicly (the template directs security issues
to the private reporting channel).

### 9.2 Pull Request Template

**Create**: `.github/pull_request_template.md`

```markdown
## Description
[What does this PR change?]

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Security fix

## Testing
- [ ] I have run `python scripts/verify_state.py` on the result
- [ ] I have run `bash -n setup.sh` to check shell syntax
- [ ] I have run `bash setup.sh "Test" "Test" --dry-run` without errors
- [ ] Scripts do not request permissions beyond what is documented

## Security checklist
- [ ] No credentials, tokens, or API keys in any file
- [ ] No calls to external services not documented in README
- [ ] Shell scripts do not use `eval` on untrusted input
- [ ] Python scripts do not use `exec()` or `eval()` on untrusted input
- [ ] File operations are scoped to the project directory
```

This template makes reviewers explicitly check security properties before
approving, not just functional correctness.

---

## PART 10: COMPLETE SETTINGS CHECKLIST

Use this before the first public release:

**Repository**
- [ ] Public visibility
- [ ] Description and topics set
- [ ] Wiki disabled (docs are in the repo)
- [ ] Issues and Discussions enabled

**Branch Protection (main)**
- [ ] Restrict deletions
- [ ] Require PR before merging (1 approval)
- [ ] Require signed commits
- [ ] Require status checks (CI must pass)
- [ ] Require linear history
- [ ] Block force pushes
- [ ] Restrict push access to maintainer(s)

**Branch Protection (v* tags)**
- [ ] Restrict deletions
- [ ] Block force pushes

**Commit Signing**
- [ ] GPG or SSH key generated and added to GitHub
- [ ] `git config commit.gpgsign true` set locally
- [ ] `git config tag.gpgsign true` set locally
- [ ] Test commit shows "Verified" badge on GitHub

**Security**
- [ ] 2FA enabled on your GitHub account (authenticator app, not SMS)
- [ ] Private vulnerability reporting enabled
- [ ] Dependabot alerts enabled
- [ ] Gitleaks secret scanning in CI
- [ ] SECURITY.md present

**Actions**
- [ ] Actions restricted to trusted sources only
- [ ] Workflow permissions set to read-only default
- [ ] CI workflow created and passing on main
- [ ] CI added as required status check on main

**Release Process**
- [ ] v1.0.0 tag signed and pushed
- [ ] GitHub Release created from that tag
- [ ] SHA256SUMS.txt attached to release
- [ ] README install command points to tagged release, not main

**Community**
- [ ] CODEOWNERS file in `.github/`
- [ ] PR template in `.github/`
- [ ] Issue templates in `.github/ISSUE_TEMPLATE/`
- [ ] SECURITY.md in repository root
- [ ] CHANGELOG.md up to date

---

## SUMMARY: THE SETTINGS THAT MATTER MOST FOR THIS PROJECT TYPE

In priority order for a project containing executable scripts intended for
distribution to developers:

1. **Two-factor authentication on your account** — protects the master key
2. **Signed commits required on main** — cryptographic proof of authenticity
3. **Block force pushes on main** — prevents silent history rewriting
4. **CI with secret scanning** — catches accidents before they reach users
5. **Tagged releases with checksums** — immutable distribution points
6. **CODEOWNERS on scripts directory** — human review gate on the most sensitive files
7. **Private vulnerability reporting** — responsible disclosure channel

Everything else is good practice. These seven are the ones that directly
protect a user who runs your scripts from running a tampered version.

---

*ACS GitHub Security Guide v1.0*
*© 2026 James MacAskill. MIT Licence.*
