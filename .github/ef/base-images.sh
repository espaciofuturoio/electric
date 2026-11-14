#!/usr/bin/env bash
# Raise the sync image's build base to the newest hexpm/elixir tag on the SAME Elixir minor and OTP major (patch
# releases only: security fixes such as OTP 29.0.2 → 29.1.2 on 2026-11-14), on the newest Debian bookworm slim it
# publishes, and keep .tool-versions in step. Prints what changed; changes nothing when already current.
#   .github/ef/base-images.sh            # edits packages/sync-service/Dockerfile and .tool-versions in place
# Majors (OTP 30, Elixir 1.21, Debian trixie) are a person's call: this never crosses them.
set -euo pipefail
DF=packages/sync-service/Dockerfile
arg() { sed -nE "s/^ARG $1=(.*)$/\1/p" "$DF" | head -1; }
ELIXIR="$(arg ELIXIR_VERSION)"; OTP="$(arg OTP_VERSION)"; DEB="$(arg DEBIAN_VERSION)"
EMINOR="${ELIXIR%.*}"; OMAJOR="${OTP%%.*}"
tags() { # the newest hexpm/elixir tags matching the prefix (Docker Hub API; deep pages answer 403, 5 pages suffice)
  local url="https://hub.docker.com/v2/repositories/hexpm/elixir/tags?page_size=100&ordering=last_updated&name=$1" n=0 page
  while [ -n "$url" ] && [ "$url" != null ] && [ $n -lt 5 ]; do
    page="$(curl -fsS "$url")" || break
    jq -r '.results[].name' <<<"$page"; url="$(jq -r '.next' <<<"$page")"; n=$((n + 1))
  done
}
best="$(tags "${EMINOR}." | grep -E "^${EMINOR//./\\.}\.[0-9]+-erlang-${OMAJOR}\.[0-9.]+-debian-bookworm-[0-9]{8}-slim$" |
  awk -F'[-]' '{print $1" "$3" "$6" "$0}' | sort -t' ' -k1,1V -k2,2V -k3,3n | tail -1 | cut -d' ' -f4)"
[ -n "$best" ] || { echo "no hexpm/elixir tag for Elixir ${EMINOR}.x / OTP ${OMAJOR}.x on bookworm-slim" >&2; exit 1; }
NE="${best%%-erlang-*}"; rest="${best#*-erlang-}"; NO="${rest%%-debian-*}"; ND="bookworm-${best##*-bookworm-}"
if [ "$NE $NO $ND" = "$ELIXIR $OTP $DEB" ]; then echo "current: elixir $ELIXIR, otp $OTP, $DEB"; exit 0; fi
sed -i -E "s/^ARG ELIXIR_VERSION=.*/ARG ELIXIR_VERSION=$NE/; s/^ARG OTP_VERSION=.*/ARG OTP_VERSION=$NO/; s/^ARG DEBIAN_VERSION=.*/ARG DEBIAN_VERSION=$ND/" "$DF"
sed -i -E "s/^elixir .*/elixir $NE/; s/^erlang .*/erlang $NO/" .tool-versions
echo "elixir $ELIXIR → $NE; otp $OTP → $NO; debian $DEB → $ND"
