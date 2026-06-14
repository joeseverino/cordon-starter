#!/usr/bin/env bash
# setup-governance.sh — apply the standing GitHub cornerstones to a repo, once,
# right after `gh repo create`. Idempotent, re-runnable, and it VERIFIES what it
# sets rather than trusting a 2xx.
#
#   <branch> protection (the repo's default branch):
#     - required status check `ci` must pass (strict: branch up to date)
#     - conversations must be resolved before merge (no unresolved comments)
#     - a pull request is required, 0 required approvals (solo can't self-approve)
#     - enforce_admins: false  → admin bypass allowed (you review and merge)
#   security (free on private repos):
#     - vulnerability alerts on
#     - automated security fixes (Dependabot security updates) on
#
# Branch protection on a PRIVATE repo needs GitHub Pro; on the free plan it is
# only available for PUBLIC repos. When that is the blocker this script SKIPS
# protection with guidance and STILL applies the security settings — it never
# leaves the repo half-configured because one step is gated by plan tier.
#
# Usage: scripts/setup-governance.sh [owner/repo] [required-check]
#   owner/repo     defaults to the current repo (gh repo view)
#   required-check defaults to "ci" (must match the ci.yml job name)
set -euo pipefail

# ── preflight ────────────────────────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || { echo "error: gh CLI not installed" >&2; exit 1; }
gh auth token   >/dev/null 2>&1 || { echo "error: gh not authenticated — run: gh auth login" >&2; exit 1; }

REPO="${1:-}"
[[ -n "$REPO" ]] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
[[ -n "$REPO" ]] || { echo "error: no repo — pass owner/repo or run inside a gh repo" >&2; exit 1; }
CHECK="${2:-ci}"

# Confirm access and read live facts — never assume the branch is "main".
BRANCH="$(gh api "repos/$REPO" -q .default_branch 2>/dev/null || true)"
[[ -n "$BRANCH" ]] || { echo "error: repo not found or no access: $REPO" >&2; exit 1; }
VISIBILITY="$(gh api "repos/$REPO" -q .visibility 2>/dev/null || echo unknown)"

echo "Repo:           $REPO"
echo "Default branch: $BRANCH"
echo "Visibility:     $VISIBILITY"
echo "Required check: $CHECK"
echo

# The required check is a job NAME. If it doesn't exist, protection will wedge
# every PR (a check that never reports). Warn early when we can see the workflow.
script_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$script_dir/.github/workflows/ci.yml" ]] \
   && ! grep -qE "^[[:space:]]+${CHECK}:[[:space:]]*$" "$script_dir/.github/workflows/ci.yml"; then
    echo "warning: no job named '$CHECK' in .github/workflows/ci.yml — a required" >&2
    echo "         check that never reports will block every merge." >&2
    echo
fi

# ── branch protection ────────────────────────────────────────────────────────
protection_payload="$(cat <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["$CHECK"] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "dismiss_stale_reviews": true, "required_approving_review_count": 0 },
  "required_conversation_resolution": true,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
)"

protect_rc=0
perr="$(gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
          --input - <<<"$protection_payload" 2>&1 >/dev/null)" || protect_rc=$?

if [[ $protect_rc -eq 0 ]]; then
    # Read it back — trust the state, not the status code.
    verify="$(gh api "repos/$REPO/branches/$BRANCH/protection" \
        -q '"\(.required_status_checks.contexts|join(",")) \(.required_conversation_resolution.enabled) \(.enforce_admins.enabled)"' \
        2>/dev/null || true)"
    read -r got_ctx got_conv got_admins <<<"$verify"
    if [[ ",$got_ctx," == *",$CHECK,"* && "$got_conv" == "true" && "$got_admins" == "false" ]]; then
        echo "  branch protection: on  (checks=[$got_ctx] conversations_resolved=yes admin_bypass=yes)"
    else
        echo "  branch protection: applied but verification mismatched — checks=[$got_ctx] conv=$got_conv enforce_admins=$got_admins" >&2
        exit 1
    fi
elif printf '%s' "$perr" | grep -qiE "Upgrade to GitHub Pro|make this repository public"; then
    echo "  branch protection: SKIPPED — needs a public repo or GitHub Pro (this repo is $VISIBILITY)."
    echo "      make public:  gh repo edit $REPO --visibility public --accept-visibility-change-consequences"
    echo "      or upgrade to GitHub Pro, then re-run this script."
    echo "      until then, 'never commit to $BRANCH' holds by discipline, not the platform."
else
    echo "  branch protection: FAILED" >&2
    printf '      %s\n' "$perr" >&2
    exit 1
fi

# ── security settings (free on private repos) ────────────────────────────────
sec_fail=0
if gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null 2>&1; then
    echo "  vulnerability alerts: on"
else
    echo "  vulnerability alerts: FAILED — token likely missing the 'repo' scope (gh auth refresh -s repo)" >&2
    sec_fail=1
fi
if gh api -X PUT "repos/$REPO/automated-security-fixes" >/dev/null 2>&1; then
    echo "  automated security fixes: on"
else
    echo "  automated security fixes: FAILED — token likely missing the 'repo' scope" >&2
    sec_fail=1
fi

echo
if [[ $sec_fail -eq 0 ]]; then
    echo "Done."
else
    echo "Done with errors — see above." >&2
    exit 1
fi
