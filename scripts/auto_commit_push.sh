#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${AUTO_COMMIT_INTERVAL_SECONDS:-120}"
COMMIT_PREFIX="${AUTO_COMMIT_MESSAGE_PREFIX:-chore(auto):}"

if ! command -v git >/dev/null 2>&1; then
  echo "[auto-commit] git is not available in PATH."
  exit 1
fi

if [[ ! -d .git ]]; then
  echo "[auto-commit] Not in a git repository."
  exit 1
fi

echo "[auto-commit] Running every ${INTERVAL_SECONDS}s in $(pwd)"

while true; do
  if [[ -n "$(git status --porcelain)" ]]; then
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    commit_message="${COMMIT_PREFIX} snapshot ${timestamp}"

    echo "[auto-commit] Changes detected. Creating commit..."

    git add -A

    # Commit can fail when changes are only in ignored paths after add.
    if git commit -m "${commit_message}" >/dev/null 2>&1; then
      branch="$(git rev-parse --abbrev-ref HEAD)"

      if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        if ! git push; then
          echo "[auto-commit] Push failed; trying pull --rebase --autostash then push."
          if git pull --rebase --autostash && git push; then
            echo "[auto-commit] Recovered from remote divergence and pushed."
          else
            echo "[auto-commit] Push still failing; will retry on next cycle."
          fi
        else
          echo "[auto-commit] Commit and push succeeded (${commit_message})."
        fi
      else
        if git push -u origin "${branch}"; then
          echo "[auto-commit] Set upstream and pushed branch ${branch}."
        else
          echo "[auto-commit] Could not set upstream for ${branch}; retrying later."
        fi
      fi
    else
      echo "[auto-commit] Nothing to commit after staging."
    fi
  fi

  sleep "${INTERVAL_SECONDS}"
done
