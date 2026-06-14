#!/usr/bin/env bash
# setup-governance.sh — apply the standing GitHub cornerstones to a repo, once,
# right after `gh repo create`. Idempotent; safe to re-run.
#
#   main branch protection:
#     - required status check `ci` must pass (strict: branch up to date)
#     - conversations must be resolved before merge (no unresolved comments)
#     - a pull request is required, 0 required approvals (solo can't self-approve)
#     - enforce_admins: false  → admin bypass allowed (you review and merge)
#   security:
#     - vulnerability alerts on
#     - automated security fixes on
#
# Usage: scripts/setup-governance.sh [owner/repo] [required-check]
#   owner/repo     defaults to the current repo (gh repo view)
#   required-check defaults to "ci" (match your ci.yml workflow/job name)
set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo "gh CLI required" >&2; exit 1; }
gh auth token >/dev/null 2>&1 || { echo "gh not authenticated — run: gh auth login" >&2; exit 1; }

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
CHECK="${2:-ci}"

echo "Applying governance to $REPO (required check: $CHECK)"

gh api -X PUT "repos/$REPO/branches/main/protection" --input - >/dev/null <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["$CHECK"] },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 0
  },
  "required_conversation_resolution": true,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "  branch protection: on (CI green + conversations resolved + admin bypass)"

gh api -X PUT "repos/$REPO/vulnerability-alerts"       >/dev/null && echo "  vulnerability alerts: on"
gh api -X PUT "repos/$REPO/automated-security-fixes"   >/dev/null && echo "  automated security fixes: on"

echo "Done. Verify:"
echo "  gh api repos/$REPO/branches/main/protection -q '.required_status_checks.contexts, .required_conversation_resolution, .enforce_admins.enabled'"
