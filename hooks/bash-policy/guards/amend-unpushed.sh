#!/usr/bin/env bash
# amend-unpushed.sh — is `git commit --amend` about to rewrite a pushed commit?
#
# Named by the policy's `guard` verb. Exit 0 allow, 1 refuse, 2 ask; the
# reason goes on stdout, and the policy's `because:` is the fallback when
# nothing is printed.
#
# An amend is safe while HEAD is only local. It is a force-push
# conversation once HEAD is on the remote, so the check is whether HEAD
# is an ancestor of the remote's main branch. That costs one fetch per
# amend, which is cheaper than the conversation it prevents.
#
# Anything it cannot determine — no repo, no origin, an unreachable
# remote — allows: this guard exists to catch a known-bad case, not to
# stand between the operator and a local repo.

set -uo pipefail

ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GIT=(git -C "$ROOT")

"${GIT[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not a git work tree; nothing to amend against"; exit 0; }

"${GIT[@]}" remote get-url origin >/dev/null 2>&1 \
  || { echo "no origin remote; an amend here cannot become a force-push"; exit 0; }

# main when the remote has it, else whatever the remote calls its HEAD.
remote_branch() {
  if "${GIT[@]}" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    echo main
    return 0
  fi
  local head
  head="$("${GIT[@]}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || head=''
  if [ -n "$head" ]; then
    echo "${head#origin/}"
    return 0
  fi
  "${GIT[@]}" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1
}

BRANCH="$(remote_branch)"
[ -n "$BRANCH" ] || { echo "origin has no default branch to compare against; the amend is local"; exit 0; }

"${GIT[@]}" fetch origin "$BRANCH" -q 2>/dev/null \
  || { echo "could not reach origin to check $BRANCH; the amend was not blocked"; exit 0; }

REF="origin/$BRANCH"
"${GIT[@]}" rev-parse --verify --quiet "$REF" >/dev/null 2>&1 || REF=FETCH_HEAD

if "${GIT[@]}" merge-base --is-ancestor HEAD "$REF" 2>/dev/null; then
  echo "HEAD is already on origin/$BRANCH; amending it means a force-push"
  exit 1
fi

echo "HEAD is not on origin/$BRANCH yet; the amend is local"
exit 0
