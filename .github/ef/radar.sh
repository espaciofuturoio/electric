#!/usr/bin/env bash
# The fork's monthly radar (FORK.md § Staying current). Run from a clean checkout of `main` with full history.
#   .github/ef/radar.sh <report.md>
# 1. Upstream: neondatabase/electric `main` (electric-sql/electric moved there). Merges it into a new branch
#    `ef/upstream-<YYYY-MM>`; when the merge conflicts, cherry-picks the upstream commits one by one instead and lists
#    the ones that conflicted (file names) — the conflict note. Writes BRANCH=<name> to $GITHUB_OUTPUT when it made one.
# 2. Versions we pin vs what is published: Pi (earendil-works/pi: pi-agent-core, pi-ai, pi-durable), Durable Streams
#    server, TanStack DB, the agents packages on npm, the sync service release.
# 3. Advisories: GitHub advisories of upstream, OSV over the sync service's Hex lock, `pnpm audit --prod` over the
#    packages our coordinator image ships.
# Read-only except for the local branch it creates; the workflow pushes it and opens the PR + issue.
set -uo pipefail
OUT="${1:?report path}"
UPSTREAM=neondatabase/electric
MONTH="$(date -u +%Y-%m)"
say() { printf '%s\n' "$*" >> "$OUT"; }
: > "$OUT"
say "# Fork radar $MONTH"
say ""

# --- 1. upstream -----------------------------------------------------------------------------------------------------
git remote add upstream "https://github.com/$UPSTREAM.git" 2>/dev/null || true
git fetch -q upstream main
NEW="$(git rev-list --count HEAD..upstream/main)"
say "## Upstream ($UPSTREAM \`main\`)"
say ""
if [ "$NEW" = 0 ]; then
  say "Nothing new: \`main\` already contains upstream \`$(git rev-parse --short upstream/main)\`."
else
  BRANCH="ef/upstream-$MONTH"
  git switch -q -c "$BRANCH"
  git config user.name "ef-bot"; git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  if git merge -q --no-ff --no-edit -m "ef: merge upstream $UPSTREAM main ($MONTH)" upstream/main 2>/dev/null; then
    say "$NEW upstream commit(s) merged cleanly into \`$BRANCH\` (merge commit: keep it a merge, never squash, so the"
    say "next radar sees them as taken)."
  else
    CONFLICTS="$(git diff --name-only --diff-filter=U | sed 's/^/`/; s/$/`/' | paste -sd, -)"
    git merge --abort
    picked=0; skipped=""
    for c in $(git rev-list --reverse --no-merges HEAD..upstream/main); do
      if git cherry-pick -x "$c" >/dev/null 2>&1; then picked=$((picked + 1))
      else
        files="$(git diff --name-only --diff-filter=U | paste -sd, -)"
        git cherry-pick --abort 2>/dev/null || git cherry-pick --skip 2>/dev/null
        skipped="$skipped\n- \`$(git rev-parse --short "$c")\` $(git log -1 --format=%s "$c") — conflicts in: ${files:-(empty pick)}"
      fi
    done
    say "**Conflict note.** A merge of the $NEW upstream commit(s) conflicts in: $CONFLICTS."
    say "The branch carries $picked of them as cherry-picks (\`-x\`, source sha in each message). Not taken, to resolve"
    say "by hand or to drop on purpose:"
    printf '%b\n' "${skipped:-\n- none}" >> "$OUT"
  fi
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "branch=$BRANCH" >> "$GITHUB_OUTPUT"
  git switch -q -
fi
say ""
say "Upstream activity since last month: $(git rev-list --count --since='35 days ago' upstream/main) commits on \`main\`."
say ""

# --- 2. versions -----------------------------------------------------------------------------------------------------
pin() { jq -r --arg p "$2" '.dependencies[$p] // .devDependencies[$p] // "-"' "$1"; }
npmv() { npm view "$1" version 2>/dev/null || echo "?"; }
say "## Versions"
say ""
say "| Package | We pin | Published |"
say "| --- | --- | --- |"
R=packages/agents-runtime/package.json; S=packages/agents-server/package.json
for p in @earendil-works/pi-agent-core @earendil-works/pi-ai; do say "| \`$p\` | $(pin $R "$p") | $(npmv "$p") |"; done
say "| \`@earendil-works/pi-durable\` (same core, not a dependency) | - | $(npmv @earendil-works/pi-durable) |"
say "| \`@durable-streams/server\` | $(pin $S @durable-streams/server) | $(npmv @durable-streams/server) |"
say "| \`@tanstack/db\` | $(pin $R @tanstack/db) | $(npmv @tanstack/db) |"
say "| \`@electric-ax/agents-server\` | $(jq -r .version $S) (fork) | $(npmv @electric-ax/agents-server) |"
say "| \`@electric-ax/agents-runtime\` | $(jq -r .version $R) (fork) | $(npmv @electric-ax/agents-runtime) |"
say "| \`@core/sync-service\` | $(jq -r .version packages/sync-service/package.json) (fork) | $(gh release list -R $UPSTREAM --limit 50 --json tagName -q '[.[].tagName|select(startswith("@core/sync-service@"))][0]' 2>/dev/null | sed 's/.*@//') |"
say ""
say "Pi releases in the last 35 days: $(gh release list -R earendil-works/pi --limit 30 --json tagName,publishedAt -q "[.[]|select(.publishedAt > \"$(date -u -d '35 days ago' +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v-35d +%Y-%m-%dT00:00:00Z)\")|.tagName]|join(\", \")" 2>/dev/null || echo '?')."
say ""

# --- 3. advisories ---------------------------------------------------------------------------------------------------
say "## Advisories"
say ""
say "Upstream GitHub advisories (newest 5):"
gh api "repos/$UPSTREAM/security-advisories?per_page=5" --jq '.[] | "- \(.published_at[0:10]) \(.severity) [\(.ghsa_id)](\(.html_url)) \(.summary)"' >> "$OUT" 2>/dev/null || say "- (could not read)"
say ""
say "Hex (OSV, \`packages/sync-service/mix.lock\`, prod and test deps):"
python3 -I - packages/sync-service/mix.lock >> "$OUT" <<'PY' || say "- (OSV query failed)"
import json, re, sys, urllib.request
pk = re.findall(r'"([a-z0-9_]+)": \{:hex, :([a-z0-9_]+), "([^"]+)"', open(sys.argv[1]).read())
q = [{"package": {"ecosystem": "Hex", "name": n}, "version": v} for _, n, v in pk]
req = urllib.request.Request("https://api.osv.dev/v1/querybatch", data=json.dumps({"queries": q}).encode(),
                             headers={"content-type": "application/json"})
res = json.load(urllib.request.urlopen(req))["results"]
hits = [(n, v, sorted({x["id"] for x in r.get("vulns", [])})) for (_, n, v), r in zip(pk, res) if r.get("vulns")]
print("\n".join(f"- `{n}` {v}: {', '.join(ids)}" for n, v, ids in hits) or "- none")
PY
say ""
say "npm (\`pnpm audit --prod\`, paths under the packages the coordinator image ships):"
{ pnpm audit --prod --json 2>/dev/null || true; } | python3 -I -c '
import json, sys
d = json.load(sys.stdin); roots = tuple(f"packages__{p}>" for p in ("agents-server", "agents-runtime", "agents-mcp", "agents-server-ui", "typescript-client"))
seen = {}
for a in d.get("advisories", {}).values():
    if any(p.startswith(roots) for f in a["findings"] for p in f["paths"]):
        seen[(a["module_name"], a["github_advisory_id"])] = a["severity"]
print("\n".join(f"- {s} `{m}` {g}" for (m, g), s in sorted(seen.items())) or "- none")' >> "$OUT" || say "- (pnpm audit failed)"
say ""
say "_Generated by \`.github/ef/radar.sh\`; what to do with each line is the reader's call (FORK.md § Staying current)._"
