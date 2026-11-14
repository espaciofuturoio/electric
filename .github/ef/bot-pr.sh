#!/usr/bin/env bash
# Push a bot branch and open (or reuse) its PR so that the REQUIRED `ef tests` checks run on it.
#   .github/ef/bot-pr.sh <branch> <title> <body-file> [--auto]
# Why each step (measured 2026-11-14): a push with GITHUB_TOKEN triggers no workflow and may not touch workflow files,
# so the branch goes up with the write deploy key (EF_RADAR_DEPLOY_KEY); the `pull_request` run that push starts on a
# bot-opened PR waits in `action_required`, so it is approved here; a `workflow_dispatch` run does NOT satisfy the
# PR's required checks. Prints the PR URL. Needs GH_TOKEN, GH_REPO and DEPLOY_KEY in the environment.
set -euo pipefail
BRANCH="$1"; TITLE="$2"; BODY="$3"; AUTO="${4:-}"
key="$RUNNER_TEMP/ef_bot_key"; printf '%s\n' "$DEPLOY_KEY" > "$key"; chmod 600 "$key"
GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git push -q -f "git@github.com:${GH_REPO}.git" "$BRANCH"
rm -f "$key"
url="$(gh pr list --head "$BRANCH" --json url -q '.[0].url')"
[ -n "$url" ] || url="$(gh pr create --base main --head "$BRANCH" --label ef --title "$TITLE" --body-file "$BODY")"
for _ in $(seq 1 12); do # the pull_request run shows up a few seconds after the push
  ids="$(gh run list --branch "$BRANCH" --status action_required --json databaseId -q '.[].databaseId')"
  [ -n "$ids" ] && break; sleep 5
done
for id in $ids; do gh api -X POST "repos/$GH_REPO/actions/runs/$id/approve" >/dev/null || echo "::warning::could not approve run $id" >&2; done
[ "$AUTO" = --auto ] && gh pr merge --auto --squash "$url" >/dev/null
echo "$url"
