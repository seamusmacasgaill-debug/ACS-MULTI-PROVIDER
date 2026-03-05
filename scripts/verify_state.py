#!/usr/bin/env python3
"""
verify_state.py — ACS Protocol Session Startup Verifier
Run at the start of EVERY session before any new work.

Usage: python .claude/scripts/verify_state.py
Returns: exit 0 if clean, exit 1 if discrepancies found
"""
import subprocess
import re
import sys
import json
from pathlib import Path
from datetime import datetime

DISCREPANCIES = []
VERIFIED = []
WARNINGS = []


def run(cmd: str) -> tuple[str, str, int]:
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def check_required_files():
    """Confirm all ACS protocol files exist."""
    required = [
        '.claude/MUST_READ.md',
        '.claude/STATE.md',
        '.claude/MEMORY.md',
        '.claude/PROTOCOL.md',
    ]
    for f in required:
        if not Path(f).exists():
            DISCREPANCIES.append({
                'type': 'E',
                'severity': 'HIGH',
                'message': f'Required ACS file missing: {f}',
                'action': f'Create {f} from the template in PROJECT_PROTOCOL_MASTER.md'
            })
        else:
            VERIFIED.append(f'ACS file exists: {f}')


def check_git_available():
    """Confirm we are in a git repo."""
    _, _, rc = run('git rev-parse --git-dir')
    if rc != 0:
        DISCREPANCIES.append({
            'type': 'E',
            'severity': 'CRITICAL',
            'message': 'Not in a git repository',
            'action': 'Run git init and make an initial commit before using ACS protocol'
        })
        return False
    return True


def check_git_commits():
    """Verify every commit hash in STATE.md actually exists in git log."""
    state_path = Path('.claude/STATE.md')
    if not state_path.exists():
        return

    state = state_path.read_text()
    # Find all patterns like: VERIFIED [abc1234] or VERIFIED [abc1234abcd...]
    hashes = re.findall(r'VERIFIED\s+\[([a-f0-9]{7,40})\]', state)

    if not hashes:
        WARNINGS.append('No VERIFIED commit hashes found in STATE.md — project may be at start')
        return

    for h in hashes:
        stdout, _, rc = run(f'git cat-file -t {h} 2>/dev/null')
        if rc != 0 or stdout.strip() != 'commit':
            DISCREPANCIES.append({
                'type': 'A',
                'severity': 'HIGH',
                'message': f'Commit hash [{h}] in STATE.md does NOT exist in this git repository',
                'action': (
                    'Determine what should have been committed for this state entry. '
                    'Either commit it now with message "SESSION-RECOVERY: [step name]" '
                    'or correct the STATE.md entry to remove the false hash.'
                )
            })
        else:
            VERIFIED.append(f'Commit {h[:8]}: confirmed in git')


def check_git_uncommitted():
    """Warn if there are uncommitted changes."""
    stdout, _, rc = run('git status --porcelain')
    if stdout:
        # Separate untracked from modified
        modified = [l for l in stdout.split('\n') if l.startswith(' M') or l.startswith('M')]
        untracked = [l for l in stdout.split('\n') if l.startswith('??')]
        staged = [l for l in stdout.split('\n') if l.startswith('A ') or l.startswith('M ')]

        if modified or staged:
            DISCREPANCIES.append({
                'type': 'D',
                'severity': 'MEDIUM',
                'message': (
                    f'Uncommitted changes detected ({len(modified + staged)} files):\n  '
                    + '\n  '.join(modified + staged)
                ),
                'action': (
                    'These may be leftover from a previous session. '
                    'If intentional work-in-progress: commit with "WIP: [description]". '
                    'If accidental: git checkout -- [files] to discard.'
                )
            })
        if untracked:
            WARNINGS.append(
                f'{len(untracked)} untracked files present (may be normal for new work): '
                + ', '.join([u.split()[-1] for u in untracked[:5]])
            )
    else:
        VERIFIED.append('Git working tree: clean (nothing to commit)')


def check_git_push_status():
    """Check if local is ahead of or behind remote."""
    # First check if remote exists
    stdout, _, rc = run('git remote -v')
    if not stdout:
        WARNINGS.append('No git remote configured — changes are local only, not pushed')
        return

    # Fetch quietly to update remote tracking
    run('git fetch --quiet 2>/dev/null')

    stdout, _, rc = run('git status -sb')
    if 'ahead' in stdout:
        count = re.search(r'ahead (\d+)', stdout)
        n = count.group(1) if count else '?'
        DISCREPANCIES.append({
            'type': 'A',
            'severity': 'MEDIUM',
            'message': f'Local branch is {n} commit(s) ahead of remote — not pushed',
            'action': 'Run: git push origin [branch-name]'
        })
    elif 'behind' in stdout:
        count = re.search(r'behind (\d+)', stdout)
        n = count.group(1) if count else '?'
        WARNINGS.append(
            f'Local branch is {n} commit(s) behind remote — pull before starting work. '
            'Run: git pull origin [branch-name]'
        )
    else:
        VERIFIED.append('Git remote: local and remote in sync')


def check_tests():
    """Run test suite if tests directory exists."""
    test_dirs = ['tests', 'test']
    test_dir = next((d for d in test_dirs if Path(d).exists()), None)

    if not test_dir:
        WARNINGS.append('No tests/ directory found — skipping test verification')
        return

    print('  Running test suite (this may take a moment)...')
    stdout, stderr, rc = run(
        f'python -m pytest {test_dir}/ -v --tb=short -q 2>&1 | tail -30'
    )

    if rc != 0:
        DISCREPANCIES.append({
            'type': 'B',
            'severity': 'HIGH',
            'message': f'Tests FAILING:\n{stdout}',
            'action': (
                'DO NOT START NEW WORK. '
                'Investigate and fix failing tests before adding any new code. '
                'Document the failure and fix in MEMORY.md.'
            )
        })
    else:
        # Extract pass count
        pass_match = re.search(r'(\d+) passed', stdout)
        count = pass_match.group(1) if pass_match else '?'
        VERIFIED.append(f'Test suite: {count} tests passing')


def check_checkpoint():
    """Detect if previous session ended mid-task."""
    cp = Path('.claude/CHECKPOINT.md')
    if not cp.exists():
        VERIFIED.append('CHECKPOINT.md: not present (clean session start)')
        return

    content = cp.read_text()

    # Check for emergency termination flag
    if 'EMERGENCY TERMINATION' in content:
        DISCREPANCIES.append({
            'type': 'D',
            'severity': 'HIGH',
            'message': 'CHECKPOINT.md contains EMERGENCY TERMINATION block — previous session ended abruptly',
            'action': (
                'READ CHECKPOINT.md carefully before doing anything. '
                'Find the "Emergency Recovery" section and follow those exact instructions. '
                'Either complete the interrupted ATU or roll it back cleanly.'
            )
        })
        return

    # Check for in-progress status
    status_match = re.search(r'\*\*Status\*\*:\s*(\w+)', content)
    if status_match:
        status = status_match.group(1)
        if status == 'IN_PROGRESS':
            # Find what was in progress
            in_progress = re.findall(r'### ATU-[\w-]+:.*?🔄 IN PROGRESS', content)
            DISCREPANCIES.append({
                'type': 'D',
                'severity': 'HIGH',
                'message': (
                    f'CHECKPOINT.md status is IN_PROGRESS — previous session ended mid-task.\n'
                    f'Incomplete ATUs: {in_progress if in_progress else "check CHECKPOINT.md"}'
                ),
                'action': (
                    'Read CHECKPOINT.md. Find the incomplete ATU. '
                    'Option A: Complete it before starting today\'s planned tasks. '
                    'Option B: Roll it back with git checkout -- [files]. '
                    'Never leave partial work undocumented.'
                )
            })
        elif status == 'COMPLETED':
            VERIFIED.append('CHECKPOINT.md: previous session completed cleanly')


def check_services():
    """Check if key services are running (Docker-based)."""
    _, _, rc = run('docker info 2>/dev/null')
    if rc != 0:
        WARNINGS.append('Docker not running — infrastructure services may be unavailable')
        return

    stdout, _, rc = run('docker-compose ps --services --filter status=running 2>/dev/null')
    if rc == 0 and stdout:
        running = stdout.split('\n')
        VERIFIED.append(f'Docker services running: {", ".join(running)}')
    else:
        WARNINGS.append(
            'No docker-compose services running — '
            'run docker-compose up -d if infrastructure is needed this session'
        )


def generate_report() -> bool:
    """Print the verification report and return True if safe to proceed."""
    print()
    print('=' * 65)
    print('  ACS SESSION STARTUP VERIFICATION REPORT')
    print(f'  {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('=' * 65)

    if VERIFIED:
        print(f'\n✅ VERIFIED ({len(VERIFIED)} items):')
        for v in VERIFIED:
            print(f'   ✓  {v}')

    if WARNINGS:
        print(f'\n⚡ WARNINGS ({len(WARNINGS)} items — review but can proceed):')
        for w in WARNINGS:
            print(f'   ⚠  {w}')

    if DISCREPANCIES:
        print(f'\n🚨 DISCREPANCIES ({len(DISCREPANCIES)} items — RESOLVE BEFORE NEW WORK):')
        for i, d in enumerate(DISCREPANCIES, 1):
            print(f'\n   [{i}] Type {d["type"]} | Severity: {d["severity"]}')
            print(f'       Issue:  {d["message"]}')
            print(f'       Action: {d["action"]}')
        print()
        print('   ❌ NOT SAFE TO PROCEED — resolve discrepancies above first')
    else:
        print()
        print('   ✅ SAFE TO PROCEED — all checks passed')

    print()
    print('=' * 65)

    # Write machine-readable report for programmatic use
    report = {
        'timestamp': datetime.now().isoformat(),
        'safe_to_proceed': len(DISCREPANCIES) == 0,
        'discrepancy_count': len(DISCREPANCIES),
        'warning_count': len(WARNINGS),
        'verified_count': len(VERIFIED),
        'discrepancies': DISCREPANCIES,
        'warnings': WARNINGS,
        'verified': VERIFIED,
    }
    Path('.claude/last_verification.json').write_text(
        json.dumps(report, indent=2)
    )

    return len(DISCREPANCIES) == 0


def main():
    print('ACS Protocol — Session Startup Verification')
    print('Checking project state against STATE.md claims...\n')

    check_required_files()

    git_ok = check_git_available()
    if git_ok:
        check_git_commits()
        check_git_uncommitted()
        check_git_push_status()

    check_tests()
    check_checkpoint()
    check_services()

    safe = generate_report()
    sys.exit(0 if safe else 1)


if __name__ == '__main__':
    main()
