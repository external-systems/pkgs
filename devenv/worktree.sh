# shellcheck shell=bash
# worktree: one git worktree per PR branch, so several sessions (people
# or agents) can work in one repo at once while the clone stays on main.
# Worktrees live in <clones dir>/.worktrees/<repo>/<branch>, next to the
# clones (~/external-systems/.worktrees/... for the org), outside every
# repo tree. Sourced by the org devenv shell's `worktree` script.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: worktree new <branch>   create <branch> from origin/main in its own worktree; print the path
       worktree list           list this repo's worktrees and their PR state
       worktree prune          remove worktrees whose PR merged or closed, then update main
USAGE
}

# The main clone, also when called from inside a worktree.
common=$(git rev-parse --path-format=absolute --git-common-dir)
clone=$(dirname "$common")
repo=$(basename "$clone")
root="${WORKTREE_ROOT:-$(dirname "$clone")/.worktrees}/$repo"

pr_state() {
  (cd "$clone" && gh pr view "$1" --json state --jq .state 2>/dev/null) || echo NONE
}

# Branch and path of every worktree except the main clone.
worktrees() {
  git -C "$clone" worktree list --porcelain | awk -v clone="$clone" '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { branch = substr($0, 19); if (path != clone) print branch "\t" path }
  '
}

update_main() {
  if [ "$(git -C "$clone" branch --show-current)" = main ] && [ -z "$(git -C "$clone" status --porcelain)" ]; then
    git -C "$clone" pull --ff-only --quiet && echo "main: $(git -C "$clone" log --oneline -1)"
  else
    echo "main clone is not a clean checkout of main; left as is: $clone" >&2
  fi
}

case "${1:-}" in
  new)
    branch=${2:?$(usage)}
    path="$root/$branch"
    git -C "$clone" fetch --quiet origin
    git -C "$clone" worktree add --quiet "$path" -b "$branch" origin/main
    # Git hooks live in the clone and all worktrees share them, but each
    # worktree reads its own .pre-commit-config.yaml, which the devenv
    # shell writes. Enter it once so the first commit finds the config.
    if [ -f "$path/devenv.yaml" ]; then
      (cd "$path" && devenv shell -- true >/dev/null 2>&1) ||
        echo "worktree: devenv shell failed in $path; enter it before committing" >&2
    fi
    echo "$path"
    ;;
  list)
    worktrees | while IFS=$'\t' read -r branch path; do
      printf '%-40s %-8s %s\n' "$branch" "$(pr_state "$branch")" "$path"
    done
    ;;
  prune)
    git -C "$clone" fetch --quiet --prune origin
    worktrees | while IFS=$'\t' read -r branch path; do
      state=$(pr_state "$branch")
      case "$state" in
        MERGED | CLOSED)
          if git -C "$clone" worktree remove "$path"; then
            git -C "$clone" branch -D "$branch" >/dev/null
            echo "removed $branch ($state)"
          else
            echo "kept $branch: its worktree has uncommitted changes ($path)" >&2
          fi
          ;;
        *) echo "kept $branch ($state)" ;;
      esac
    done
    git -C "$clone" worktree prune
    update_main
    ;;
  *)
    usage
    exit 2
    ;;
esac
