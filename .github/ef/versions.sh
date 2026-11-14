#!/usr/bin/env bash
# Rewrite the fork's version table in README.md, between `<!-- ef-versions:start -->` and `<!-- ef-versions:end -->`:
# what we ship vs the newest upstream / published release of each key piece. Run from the repo root.
#   .github/ef/versions.sh            # edits README.md in place; prints nothing when nothing changed
set -euo pipefail
npmv() { npm view "$1" version 2>/dev/null || echo "?"; }
pin() { jq -r --arg p "$2" '.dependencies[$p] // .devDependencies[$p] // "-"' "$1"; }
ghrel() { gh release list -R "$1" --limit 40 --exclude-pre-releases --json tagName -q "[.[].tagName|select(test(\"$2\"))][0]" 2>/dev/null || echo "?"; }
tool() { sed -nE "s/^$1 (.*)$/\1/p" .tool-versions; }
R=packages/agents-runtime/package.json; S=packages/agents-server/package.json
SELF="${GITHUB_REPOSITORY:-espaciofuturoio/electric}"; EL="$(tool elixir)"; OT="$(tool erlang)"
img="$(gh release list -R "$SELF" --limit 20 --json tagName -q '[.[].tagName|select(startswith("images-"))][0]' 2>/dev/null || true)"
pg18="$(curl -fsS 'https://hub.docker.com/v2/repositories/library/postgres/tags?page_size=100&name=18.&ordering=last_updated' 2>/dev/null |
  jq -r '.results[].name' | grep -E '^18\.[0-9]+-alpine$' | sort -V | tail -1 | sed 's/-alpine//' || echo "?")"
node22="$(curl -fsS https://nodejs.org/dist/index.json 2>/dev/null | jq -r '[.[]|select(.version|startswith("v22."))][0].version' || echo "?")"
ours_pg="$(grep -oE 'postgres:18\.[0-9]+' .github/workflows/ef-fork-images.yml | head -1 | cut -d: -f2)"
table="$(cat <<EOF
| Piece | This fork | Newest upstream / published |
| --- | --- | --- |
| Coordinator \`@electric-ax/agents-server\` | $(jq -r .version $S) + fork patches | $(npmv @electric-ax/agents-server) (npm) |
| Runtime \`@electric-ax/agents-runtime\` | $(jq -r .version $R) + fork patches | $(npmv @electric-ax/agents-runtime) (npm) |
| Sync service \`@core/sync-service\` | $(jq -r .version packages/sync-service/package.json) | $(ghrel neondatabase/electric '^@core/sync-service@' | sed 's/.*@//') (neondatabase/electric) |
| Elixir | $(tool elixir) | $(ghrel elixir-lang/elixir "^v${EL%.*}\\\\.[0-9]+\$" | sed 's/^v//') (newest ${EL%.*}.x) |
| Erlang/OTP | $(tool erlang) | $(ghrel erlang/otp "^OTP-${OT%%.*}\\\\.[0-9.]+\$" | sed 's/^OTP-//') (newest ${OT%%.*}.x) |
| Node (coordinator base \`node:22-bookworm-slim\`, rebuilt weekly) | 22 | ${node22#v} |
| Postgres (image smoke and boxes) | ${ours_pg:-?} | ${pg18} |
| \`@earendil-works/pi-agent-core\` (Pi; pi-durable shares the core) | $(pin $R @earendil-works/pi-agent-core) | $(npmv @earendil-works/pi-agent-core) |
| \`@durable-streams/server\` | $(pin $S @durable-streams/server) | $(npmv @durable-streams/server) |
| \`@tanstack/db\` | $(pin $R @tanstack/db) | $(npmv @tanstack/db) |
| Latest image release | ${img:-none} | — |
EOF
)"
python3 -I - README.md "$table" <<'PY'
import re, sys
path, table = sys.argv[1], sys.argv[2]
s = open(path).read()
block = "<!-- ef-versions:start -->\n" + table + "\n<!-- ef-versions:end -->"
if "<!-- ef-versions:start -->" in s:
    new = re.sub(r"<!-- ef-versions:start -->.*?<!-- ef-versions:end -->", lambda _: block, s, flags=re.S)
else:
    head = ("## This fork (espaciofuturoio/electric)\n\nOur own agent runtime on top of Electric; how we keep it current: "
            "[FORK.md](FORK.md). Table refreshed weekly by `ef-versions.yml`.\n\n")
    new = head + block + "\n\n" + s
if new != s:
    open(path, "w").write(new)
PY
