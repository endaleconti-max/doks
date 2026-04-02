#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${AUTO_COMMIT_INTERVAL_SECONDS:-120}"
COMMIT_PREFIX="${AUTO_COMMIT_MESSAGE_PREFIX:-chore(auto):}"
FALLBACK_PREFIX="${AUTO_COMMIT_FALLBACK_PREFIX:-autosync}"

push_with_fallback() {
  local branch="$1"
  local push_output
  local upstream_ref
  local upstream_remote="origin"
  local upstream_branch="$branch"

  upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
  if [[ -n "${upstream_ref}" && "${upstream_ref}" == */* ]]; then
    upstream_remote="${upstream_ref%%/*}"
    upstream_branch="${upstream_ref#*/}"
  fi

  if push_output="$(git push "${upstream_remote}" "HEAD:refs/heads/${upstream_branch}" 2>&1)"; then
    echo "[auto-commit] Commit and push succeeded."
    return 0
  fi

  if [[ "${push_output}" =~ GH006|protected\ branch|pull\ request|Required\ status\ check ]]; then
    local fallback_branch="${FALLBACK_PREFIX}/${branch}"
    echo "[auto-commit] Protected branch detected; pushing to ${fallback_branch} instead."
    if git push -u "${upstream_remote}" "HEAD:refs/heads/${fallback_branch}"; then
      echo "[auto-commit] Pushed to fallback branch ${fallback_branch}."
      return 0
    fi
    echo "[auto-commit] Fallback push failed; will retry on next cycle."
    return 1
  fi

  echo "[auto-commit] Push failed; trying pull --rebase --autostash then push."
  if git pull --rebase --autostash && git push "${upstream_remote}" "HEAD:refs/heads/${upstream_branch}"; then
    echo "[auto-commit] Recovered from remote divergence and pushed."
    return 0
  fi

  echo "[auto-commit] Push still failing; will retry on next cycle."
  return 1
}

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
        push_with_fallback "${branch}" || true
      else
        if git push -u origin "${branch}"; then
          echo "[auto-commit] Set upstream and pushed branch ${branch}."
        elif [[ "${branch}" == "main" || "${branch}" == "master" ]]; then
          fallback_branch="${FALLBACK_PREFIX}/${branch}"
          echo "[auto-commit] Upstream push blocked; using fallback branch ${fallback_branch}."
          if git push -u origin "HEAD:refs/heads/${fallback_branch}"; then
            echo "[auto-commit] Set upstream and pushed fallback branch ${fallback_branch}."
          else
            echo "[auto-commit] Could not push fallback branch ${fallback_branch}; retrying later."
          fi
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
