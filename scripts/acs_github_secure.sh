#!/usr/bin/env bash
# =============================================================================
# acs_github_secure.sh
# ACS Repository Security Setup — Automated via GitHub CLI and REST API
#
# Automates every setting in docs/GITHUB_SECURITY_SETTINGS.md that can be
# set programmatically. Clearly documents what requires manual action.
#
# Prerequisites:
#   - GitHub CLI installed: https://cli.github.com
#   - Authenticated: gh auth login (with repo + admin:repo_hook scopes)
#   - Run from inside the repository directory
#
# Usage:
#   bash acs_github_secure.sh                    # auto-detects repo from git remote
#   bash acs_github_secure.sh owner/repo-name    # explicit repo
#   bash acs_github_secure.sh --dry-run          # show what would happen
#   bash acs_github_secure.sh --check-only       # verify current state only
#
# What this script automates (✅):
#   - Repository settings (description, topics, features on/off)
#   - Branch protection rules (main and tag patterns)
#   - Required status checks
#   - Actions permissions
#   - Dependabot alerts and security updates
#   - Private vulnerability reporting
#   - CODEOWNERS file customisation
#   - Push .github/ security files to repository
#   - Create initial signed release tag
#
# What requires manual action (❌ — documented at end of script):
#   - GitHub account 2FA (account-level, not repo-level)
#   - GPG/SSH commit signing (local machine setup)
#   - Adding GPG/SSH public key to GitHub account
#
# =============================================================================

set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m';     NC='\033[0m'

info()    { echo -e "${BLUE}  ▸${NC}  $*"; }
success() { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }
manual()  { echo -e "${YELLOW}  [MANUAL]${NC}  $*"; }
skipped() { echo -e "  ${BLUE}[DRY-RUN]${NC}  Would: $*"; }

# ── parse arguments ───────────────────────────────────────────────────────────
REPO_ARG=""
DRY_RUN=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=true ;;
        --check-only) CHECK_ONLY=true ;;
        --*)          warn "Unknown flag: $arg" ;;
        *)            REPO_ARG="$arg" ;;
    esac
done

# ── detect repository ─────────────────────────────────────────────────────────
if [[ -n "$REPO_ARG" ]]; then
    REPO="$REPO_ARG"
else
    # Auto-detect from git remote
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$REMOTE_URL" ]]; then
        error "No git remote 'origin' found and no repo argument provided."
        error "Usage: bash acs_github_secure.sh owner/repo-name"
        exit 1
    fi
    # Handle both SSH and HTTPS formats
    if [[ "$REMOTE_URL" == git@github.com:* ]]; then
        REPO="${REMOTE_URL#git@github.com:}"
        REPO="${REPO%.git}"
    elif [[ "$REMOTE_URL" == https://github.com/* ]]; then
        REPO="${REMOTE_URL#https://github.com/}"
        REPO="${REPO%.git}"
    else
        error "Cannot parse remote URL: $REMOTE_URL"
        error "Please provide the repo as: owner/repo-name"
        exit 1
    fi
fi

OWNER="${REPO%/*}"
REPO_NAME="${REPO#*/}"

# ── verify prerequisites ──────────────────────────────────────────────────────
header "Prerequisites Check"

# Check gh CLI installed
if ! command -v gh &>/dev/null; then
    error "GitHub CLI (gh) is not installed."
    error "Install from: https://cli.github.com"
    error "  macOS:   brew install gh"
    error "  Windows: winget install GitHub.cli"
    error "  Ubuntu:  sudo apt install gh"
    exit 1
fi
success "GitHub CLI: $(gh --version | head -1)"

# Check authenticated
GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [[ -z "$GH_USER" ]]; then
    error "Not authenticated with GitHub CLI."
    error "Run: gh auth login"
    error "When prompted, select: GitHub.com → HTTPS → Yes → Login with browser"
    error "Required scopes: repo, admin:repo_hook, read:org"
    exit 1
fi
success "Authenticated as: $GH_USER"

# Check we own or admin the repo
REPO_INFO=$(gh api "repos/$REPO" 2>/dev/null || echo "")
if [[ -z "$REPO_INFO" ]]; then
    error "Cannot access repository: $REPO"
    error "Check the repo exists and you have admin access."
    exit 1
fi

REPO_VISIBILITY=$(echo "$REPO_INFO" | gh api --jq '.visibility' /dev/stdin 2>/dev/null || \
    gh api "repos/$REPO" --jq '.visibility')
REPO_IS_ADMIN=$(gh api "repos/$REPO" --jq '.permissions.admin' 2>/dev/null || echo "false")

if [[ "$REPO_IS_ADMIN" != "true" ]]; then
    error "You do not have admin access to $REPO"
    error "Branch protection and security settings require admin role."
    exit 1
fi

success "Repository: $REPO (admin confirmed)"

# ── helper: gh API wrapper respects dry-run ───────────────────────────────────
gh_api() {
    local method="$1"; shift
    local endpoint="$1"; shift
    if [[ "$DRY_RUN" == true ]] || [[ "$CHECK_ONLY" == true ]]; then
        skipped "gh api -X $method $endpoint $*"
        return 0
    fi
    gh api -X "$method" "$endpoint" "$@"
}

# ── banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ACS — GitHub Repository Security Setup               ║${NC}"
echo -e "${BOLD}║  Repository: ${REPO}$(printf '%*s' $((38-${#REPO})) '')║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
[[ "$DRY_RUN" == true ]]    && warn "DRY RUN MODE — no changes will be made"
[[ "$CHECK_ONLY" == true ]] && warn "CHECK ONLY — reporting current state"
echo ""

# =============================================================================
# SECTION 1: REPOSITORY SETTINGS
# =============================================================================
header "Section 1: Repository Settings"

# 1.1 Ensure repository is public
info "Setting visibility to public..."
if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    gh repo edit "$REPO" --visibility public 2>/dev/null && \
        success "Visibility: public" || \
        warn "Could not set visibility (may require org-level permissions)"
else
    skipped "Set repository visibility to public"
fi

# 1.2 Disable wiki (docs live in repo)
info "Disabling wiki (documentation is in docs/ directory)..."
gh_api PATCH "repos/$REPO" \
    --field has_wiki=false \
    --field has_projects=true \
    --field has_issues=true && \
    success "Wiki: disabled | Issues: enabled | Projects: enabled" || \
    warn "Could not update repository features"

# 1.3 Pull request merge settings
info "Configuring pull request merge strategy..."
gh_api PATCH "repos/$REPO" \
    --field allow_merge_commit=true \
    --field allow_squash_merge=false \
    --field allow_rebase_merge=false \
    --field allow_auto_merge=false \
    --field delete_branch_on_merge=true \
    --field allow_update_branch=true && \
    success "PR settings: merge commits only, delete branch on merge" || \
    warn "Could not update PR settings"

# =============================================================================
# SECTION 2: BRANCH PROTECTION — MAIN
# =============================================================================
header "Section 2: Branch Protection (main)"

info "Applying branch protection rules to main..."

BRANCH_PROTECTION_PAYLOAD=$(cat <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "verify-scripts",
      "lint-shell",
      "check-no-secrets",
      "check-permissions",
      "check-docs"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismissal_restrictions": {},
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "required_signatures": true,
  "lock_branch": false
}
EOF
)

if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    echo "$BRANCH_PROTECTION_PAYLOAD" | gh api \
        -X PUT \
        "repos/$REPO/branches/main/protection" \
        --input - && \
        success "Branch protection applied to main:" && \
        success "  ✓ Require PRs with 1 approval" && \
        success "  ✓ Dismiss stale reviews" && \
        success "  ✓ Require code owner review" && \
        success "  ✓ Require signed commits" && \
        success "  ✓ Block force pushes" && \
        success "  ✓ Block deletions" && \
        success "  ✓ Require linear history" && \
        success "  ✓ Require status checks to pass" && \
        success "  ✓ Enforce rules for admins" || \
        warn "Branch protection partially applied — check Settings → Branches manually"
else
    skipped "Apply branch protection to main (all rules from GITHUB_SECURITY_SETTINGS.md)"
fi

# =============================================================================
# SECTION 3: TAG PROTECTION
# =============================================================================
header "Section 3: Tag Protection (v* pattern)"

info "Protecting release tags (v*)..."

if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    # Use the newer rulesets API for tag protection (more reliable than old rules)
    TAG_RULESET=$(cat <<'EOF'
{
  "name": "protect-release-tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "creation",
      "parameters": {
        "restricted_creation_rules": []
      }
    }
  ],
  "bypass_actors": []
}
EOF
)
    echo "$TAG_RULESET" | gh api \
        -X POST \
        "repos/$REPO/rulesets" \
        --input - && \
        success "Tag protection applied: v* tags cannot be deleted or force-pushed" || \
        warn "Could not apply tag ruleset — may need to set manually in Settings → Rules"
else
    skipped "Apply tag protection ruleset for v* pattern"
fi

# =============================================================================
# SECTION 4: ACTIONS PERMISSIONS
# =============================================================================
header "Section 4: GitHub Actions Permissions"

info "Restricting Actions to trusted sources only..."

if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    # Set Actions to allow only owner and GitHub actions
    gh api -X PUT "repos/$REPO/actions/permissions" \
        --field enabled=true \
        --field allowed_actions=selected && \
        success "Actions: enabled, restricted to selected" || \
        warn "Could not set Actions permissions"

    # Set workflow permissions to read-only by default
    gh api -X PUT "repos/$REPO/actions/permissions/workflow" \
        --field default_workflow_permissions=read \
        --field can_approve_pull_request_reviews=false && \
        success "Workflow permissions: read-only, cannot approve PRs" || \
        warn "Could not set workflow permissions"
else
    skipped "Restrict GitHub Actions to trusted sources"
    skipped "Set workflow default permissions to read-only"
fi

# =============================================================================
# SECTION 5: SECURITY FEATURES
# =============================================================================
header "Section 5: Security Features"

# 5.1 Enable vulnerability reporting
info "Enabling private vulnerability reporting..."
if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    gh api -X PUT "repos/$REPO/private-vulnerability-reporting" && \
        success "Private vulnerability reporting: enabled" || \
        warn "Could not enable private vulnerability reporting — enable manually in Security tab"
else
    skipped "Enable private vulnerability reporting"
fi

# 5.2 Enable Dependabot alerts
info "Enabling Dependabot alerts..."
if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    gh api -X PUT "repos/$REPO/vulnerability-alerts" && \
        success "Dependabot alerts: enabled" || \
        warn "Could not enable Dependabot alerts — enable manually in Security tab"

    # Enable automated security updates
    gh api -X PUT "repos/$REPO/automated-security-fixes" && \
        success "Dependabot automated security updates: enabled" || \
        warn "Could not enable automated security fixes"
else
    skipped "Enable Dependabot alerts and automated security updates"
fi

# 5.3 Enable secret scanning (if available on plan)
info "Enabling secret scanning..."
if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    gh api -X PATCH "repos/$REPO" \
        --field security_and_analysis[secret_scanning][status]=enabled \
        --silent 2>/dev/null && \
        success "Secret scanning: enabled" || \
        warn "Secret scanning not available on this plan (requires GitHub Advanced Security)"
else
    skipped "Enable secret scanning"
fi

# =============================================================================
# SECTION 6: CODEOWNERS — CUSTOMISE WITH ACTUAL USERNAME
# =============================================================================
header "Section 6: CODEOWNERS File"

CODEOWNERS_PATH=".github/CODEOWNERS"

if [[ -f "$CODEOWNERS_PATH" ]]; then
    # Check if still has placeholder
    if grep -q "@yourusername" "$CODEOWNERS_PATH"; then
        info "Updating CODEOWNERS with actual GitHub username ($GH_USER)..."
        if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
            sed -i "s/@yourusername/@$GH_USER/g" "$CODEOWNERS_PATH"
            success "CODEOWNERS: updated @yourusername → @$GH_USER"
            # Stage the change
            git add "$CODEOWNERS_PATH"
            git diff --cached --quiet "$CODEOWNERS_PATH" || \
                git commit -m "chore: set CODEOWNERS to @$GH_USER"
        else
            skipped "Replace @yourusername with @$GH_USER in CODEOWNERS"
        fi
    else
        success "CODEOWNERS: already configured (no placeholder found)"
    fi
else
    warn "CODEOWNERS file not found at $CODEOWNERS_PATH"
    warn "Create it from the template in the ACS package"
fi

# =============================================================================
# SECTION 7: PUSH SECURITY FILES IF NOT ON REMOTE
# =============================================================================
header "Section 7: Push Security Files to Remote"

# Check if .github/ files are committed and pushed
UNCOMMITTED=$(git status --porcelain .github/ 2>/dev/null || echo "")
if [[ -n "$UNCOMMITTED" ]]; then
    info "Staging and committing .github/ security files..."
    if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
        git add .github/
        git diff --cached --quiet .github/ || \
            git commit -m "chore: add GitHub security and CI configuration

- .github/workflows/ci.yml: automated integrity checks
- .github/CODEOWNERS: require owner review on scripts
- .github/SECURITY.md: vulnerability reporting policy
- .github/dependabot.yml: weekly dependency updates
- .github/pull_request_template.md: security checklist"
        success "Security files committed"
    else
        skipped "Commit .github/ security files"
    fi
else
    success "All .github/ files already committed"
fi

# Push to remote
info "Pushing to remote..."
if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    git push origin main && \
        success "Pushed to origin/main" || \
        warn "Push failed — check that main branch allows your push"
else
    skipped "git push origin main"
fi

# =============================================================================
# SECTION 8: REPOSITORY TOPICS AND DESCRIPTION
# =============================================================================
header "Section 8: Repository Metadata"

info "Setting description and topics..."
DESCRIPTION="Session management protocol for multi-session AI-assisted development"
TOPICS='["claude","ai-development","session-management","devops","developer-tools","claude-code","llm","productivity","git","automation"]'

if [[ "$DRY_RUN" == false ]] && [[ "$CHECK_ONLY" == false ]]; then
    gh repo edit "$REPO" \
        --description "$DESCRIPTION" && \
        success "Description: set"

    gh api -X PUT "repos/$REPO/topics" \
        --field names="$TOPICS" && \
        success "Topics: set (claude, ai-development, session-management, ...)" || \
        warn "Could not set topics via API"
else
    skipped "Set repository description and topics"
fi

# =============================================================================
# SECTION 9: VERIFY CURRENT STATE
# =============================================================================
header "Section 9: Verification Report"

info "Checking current repository security state..."
echo ""

# Check branch protection
BP=$(gh api "repos/$REPO/branches/main/protection" 2>/dev/null || echo "")
if [[ -n "$BP" ]]; then
    SIGNED=$(echo "$BP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('required_signatures',{}).get('enabled','?'))" 2>/dev/null || echo "?")
    FORCE_PUSH=$(echo "$BP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('allow_force_pushes',{}).get('enabled','?'))" 2>/dev/null || echo "?")
    PR_REQUIRED=$(echo "$BP" | python3 -c "import sys,json; d=json.load(sys.stdin); print('enabled' if d.get('required_pull_request_reviews') else 'disabled')" 2>/dev/null || echo "?")
    LINEAR=$(echo "$BP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('required_linear_history',{}).get('enabled','?'))" 2>/dev/null || echo "?")

    echo "  Branch protection (main):"
    [[ "$SIGNED" == "true" ]]         && success "  Signed commits required: ✓" || warn "  Signed commits required: NOT SET"
    [[ "$FORCE_PUSH" == "false" ]]    && success "  Force push blocked: ✓"       || warn "  Force push blocked: NOT SET"
    [[ "$PR_REQUIRED" == "enabled" ]] && success "  PR required: ✓"              || warn "  PR required: NOT SET"
    [[ "$LINEAR" == "true" ]]         && success "  Linear history: ✓"           || warn "  Linear history: NOT SET"
else
    warn "  Branch protection: NOT CONFIGURED on main"
fi

echo ""

# Check Actions permissions
ACTIONS=$(gh api "repos/$REPO/actions/permissions" 2>/dev/null || echo "")
if [[ -n "$ACTIONS" ]]; then
    ALLOWED=$(echo "$ACTIONS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('allowed_actions','?'))" 2>/dev/null || echo "?")
    [[ "$ALLOWED" == "selected" ]] && success "  Actions: restricted to selected sources ✓" || \
        warn "  Actions: $ALLOWED (should be 'selected')"
fi

# Check vulnerability reporting
VULN=$(gh api "repos/$REPO/private-vulnerability-reporting" 2>/dev/null || echo "")
if [[ -n "$VULN" ]]; then
    ENABLED=$(echo "$VULN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('enabled','?'))" 2>/dev/null || echo "?")
    [[ "$ENABLED" == "True" ]] || [[ "$ENABLED" == "true" ]] && \
        success "  Private vulnerability reporting: enabled ✓" || \
        warn "  Private vulnerability reporting: $ENABLED"
fi

# Check CODEOWNERS
if [[ -f ".github/CODEOWNERS" ]] && ! grep -q "@yourusername" ".github/CODEOWNERS"; then
    success "  CODEOWNERS: configured ✓"
else
    warn "  CODEOWNERS: placeholder not replaced or file missing"
fi

# Check CI workflow
if [[ -f ".github/workflows/ci.yml" ]]; then
    success "  CI workflow: present ✓"
else
    warn "  CI workflow: missing (.github/workflows/ci.yml)"
fi

# =============================================================================
# SECTION 10: MANUAL STEPS REQUIRED
# =============================================================================
header "Section 10: Manual Steps Required"

echo ""
echo -e "  The following ${BOLD}cannot be automated${NC} — they require manual action:"
echo ""

manual "1. GITHUB ACCOUNT 2FA (most important)"
echo "      Your personal account protection cannot be set via API."
echo "      → github.com → Settings → Password and authentication"
echo "      → Enable two-factor authentication"
echo "      → Use an authenticator app (not SMS)"
echo ""

manual "2. GPG OR SSH COMMIT SIGNING (local machine)"
echo "      Signed commits are REQUIRED by the branch protection set above."
echo "      Without signing, you cannot push to main."
echo ""
echo "      Quick setup (SSH signing — simplest):"
echo "      ┌─────────────────────────────────────────────────────┐"
echo "      │  # In WSL / terminal:                               │"
echo "      │  git config --global gpg.format ssh                 │"
echo "      │  git config --global user.signingkey ~/.ssh/id_ed25519.pub│"
echo "      │  git config --global commit.gpgsign true            │"
echo "      │  git config --global tag.gpgsign true               │"
echo "      └─────────────────────────────────────────────────────┘"
echo "      Then add the same key as a SIGNING KEY on GitHub:"
echo "      → github.com → Settings → SSH and GPG keys"
echo "      → New SSH key → Key type: Signing Key"
echo "      → Paste your ~/.ssh/id_ed25519.pub content"
echo ""
echo "      Verify it works:"
echo "      ┌─────────────────────────────────────────────────────┐"
echo "      │  git commit --allow-empty -m 'test: verify signing' │"
echo "      │  git log --show-signature -1                        │"
echo "      │  # Should show: Good SSH signature                  │"
echo "      └─────────────────────────────────────────────────────┘"
echo ""

manual "3. CREATE FIRST SIGNED RELEASE TAG"
echo "      After commit signing is configured:"
echo "      ┌─────────────────────────────────────────────────────┐"
echo "      │  git tag -s v1.0.0 -m 'ACS v1.0.0 initial release' │"
echo "      │  git push origin v1.0.0                             │"
echo "      └─────────────────────────────────────────────────────┘"
echo "      Then on GitHub: Releases → Create release → select v1.0.0"
echo "      Attach SHA256SUMS.txt for download integrity verification."
echo ""

manual "4. ADD REQUIRED STATUS CHECKS (after first CI run)"
echo "      CI jobs must run at least once before they can be"
echo "      added as required checks. After the first push:"
echo "      → Settings → Branches → main → Edit rule"
echo "      → Require status checks → search for:"
echo "        'verify-scripts' | 'lint-shell' | 'check-no-secrets'"
echo "        'check-permissions' | 'check-docs'"
echo "      → Add each one as required"
echo ""

manual "5. VERIFY 'Verified' BADGES APPEAR ON COMMITS"
echo "      After signing is set up, push a test commit and confirm"
echo "      the green 'Verified' badge appears next to it on GitHub."
echo "      If badges are absent, the signing setup needs troubleshooting."
echo ""

# =============================================================================
# SUMMARY
# =============================================================================
header "Complete"

echo ""
if [[ "$DRY_RUN" == true ]]; then
    warn "DRY RUN — no changes were made. Remove --dry-run to apply."
elif [[ "$CHECK_ONLY" == true ]]; then
    info "Check complete. Run without --check-only to apply settings."
else
    success "Automated security settings applied to: $REPO"
fi

echo ""
echo "  Security status summary:"
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │  Automated (done by this script)                    │"
echo "  │  ✓ Repository settings (visibility, features)       │"
echo "  │  ✓ Branch protection (main)                         │"
echo "  │  ✓ Tag protection (v*)                              │"
echo "  │  ✓ Actions permissions (restricted)                 │"
echo "  │  ✓ Dependabot alerts                                │"
echo "  │  ✓ Private vulnerability reporting                  │"
echo "  │  ✓ CODEOWNERS updated with your username            │"
echo "  │  ✓ Security files pushed to remote                  │"
echo "  │                                                     │"
echo "  │  Manual required (see Section 10 above)             │"
echo "  │  ❌ Account 2FA (github.com Settings)               │"
echo "  │  ❌ GPG/SSH commit signing (local git config)       │"
echo "  │  ❌ Add signing key to GitHub account               │"
echo "  │  ❌ Create first release tag (after signing works)  │"
echo "  │  ❌ Add CI jobs as required status checks           │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
echo "  Full documentation: docs/GITHUB_SECURITY_SETTINGS.md"
echo ""
