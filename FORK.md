# espaciofuturoio/electric — fork (`main` line)

This fork is our own agent runtime (owner decision D, ai-agents
`docs/research/2026-11-14-electric-agents-future.md`). `main` = upstream `main` + our agents-server / agents-runtime
patches. The `ef/sync-service` branch is a separate line (upstream sync-service release tags + patches); its `FORK.md`
lives there. Nothing is posted upstream without the owner's go.

## Images (`.github/workflows/ef-fork-images.yml`)

One manual run builds both images the agents stacks run from ONE commit of `main`, pushes them to GHCR (public),
smoke-tests them together (postgres:18-alpine + sync + coordinator, pulled by digest: type registered, entity spawned,
a restart keeps the type) and writes a GitHub release `images-<coordinator tag>` with both digests.

| Image | Tag |
| --- | --- |
| `ghcr.io/espaciofuturoio/electric-agents-server` | `<agents-server version>-fork.<sha9>` |
| `ghcr.io/espaciofuturoio/electric-sync-service` | `<sync-service version>-fork.<sha9>` (the `-ef.<n>` tags are the other line) |

```sh
gh workflow run ef-fork-images.yml -R espaciofuturoio/electric --ref main -f ref=<sha>
```

Consumers pin `image@sha256:<digest>` (the tag beside it is only for people). A published tag is never overwritten.

Before 2026-11-14 the coordinator image existed only as `electricax/agents-server:0.6.4-fork.d3cd4eb73-amd64`, built on
a laptop and `docker load`ed onto three boxes; the sync image as `electricsql/electric:1.8.1-fork.c1f73b5fc-amd64`.
Those local tags stay on the boxes as the rollback target until the GHCR pins have run a week.

## Security review 2026-11-14

Sources read: electric-sql/electric security advisories and its 113 open PRs; `pnpm audit --prod` filtered to what the
coordinator image ships (`agents-server`, `agents-runtime`, `agents-mcp`, `agents-server-ui`, `typescript-client`);
OSV for every Hex package in `packages/sync-service/mix.lock`; erlang/otp and elixir-lang/elixir advisories;
postgresql.org/support/security; nodejs.org release index.

**Tests:** sync-service suite on Postgres 18.7, OTP 29.1.2: 2342/2348; the 6 were 3 flaky (pass on `--failed`) and 3
that fail identically on unpatched `main` in a local Docker network (hardcoded port 54321, IPv4 fallback). The
coordinator is proven by `ef-fork-images.yml`'s smoke on the new images.

**Applied here**

| Where | Change | Advisories closed |
| --- | --- | --- |
| sync-service `mix.lock` | bandit 1.12.0→1.14.1, plug 1.19.2→1.20.3, phoenix 1.8.7→1.8.16, phoenix_live_view 1.1.31→1.2.13, phoenix_html →4.4.0, postgrex 0.22.2→0.22.4, ecto →3.14.3, plug_crypto →2.2.1, hpax →1.1.0, decimal →3.2.0, mint →1.11.0 (a prod dep through `req`; the `ef/sync-service` lock took it in 1.8.1-ef.3), with their deps | 16 bandit (HTTP/1, HTTP/2, WebSocket DoS; Host/port spoofing), 4 plug (param-decoding DoS, multipart, cookie injection), 2 phoenix (channel-join DoS), LiveView open redirect, phoenix_html attribute injection, 2 postgrex SQL injection (Notifications reconnect, `:comment`), ecto query-cache growth, plug_crypto secret in stack traces, hpax HPACK DoS, decimal DoS |
| sync-service image | Elixir 1.20.2→1.20.5, OTP 29.0.2→29.1.2, Debian bookworm-20260623→20261104 | erts inet TCP driver length overflow (CVE-2026-75538, high), TLS 1.3 client skips server auth on unsolicited PSK (CVE-2026-89422, critical), TLS ticket store poisoning (CVE-2026-94200), Elixir URI/JSON parsing DoS, OS packages (OpenSSL) |
| coordinator (`pnpm.overrides`) | fast-uri ≥3.1.9, @fastify/busboy ≥3.2.5, @modelcontextprotocol/sdk ≥1.32.2, dompurify ≥3.4.17, mermaid ≥11.16.1 (11.x), uuid ≥11.1.1, prosemirror-view 1.42.9 | 13 fast-uri (host confusion / SSRF in ajv's URI handling), 3 busboy multipart DoS / CRLF, 6 MCP SDK (body-size DoS, cross-origin redirects, token audience), console XSS in mermaid / dompurify / prosemirror-view |
| image smoke | Postgres 18.7 (18.6 had ~30 CVEs, mostly authenticated-user code execution) and a LiveDashboard render check | — |

**Not applied, and why**

- `protobuf` ≥0.17.1 (recursion DoS decoding protobuf/JSON): only `otel_metric_exporter` uses it, to ENCODE metrics
  for an OTLP endpoint no stack configures; upstream pins `~> 0.13.0, override: true` because ≥0.14 clashes with Protox
  (pg_query_ex). Revisit when that pin can move.
- coordinator UI `zod` 3.x (GHSA-mrhx-c7xc-m3w5) and `katex` (GHSA-238p, low, needs a prior prototype pollution):
  browser-only in the operator console; zod 4 / katex 0.18 are major moves for a self-DoS. Renovate will raise them.
- `ssl_verify_fun` 1.1.7 (wildcard across labels): IS in the prod release (the daily radar read `/app/lib`, doc 06 WS-SH3) but unreachable: only `otel_exporter_otlp` uses it and that runs only with `ELECTRIC_OTLP_ENDPOINT`, set in no stack.
- vite / vitest / undici / jsdom advisories: test tooling (`agents-server-conformance-tests`), not in any image.
- Upstream open PRs: none is a security fix for sync or agents. Robustness fixes worth a later cherry-pick (radar):
  #4711 (terminate serves whose clients stop reading), #4838/#4837 (SSE), #4685 (non-English PG errors). Agents
  wake-path PRs #4720/#4726/#4632 overlap our own fixes #2–#10 and need a dedicated card. #4853/#4854 (hono) only
  touch examples and the desktop app.
- Upstream advisories GHSA-m4f6 (1.7.12), GHSA-c82q (1.6.10), GHSA-h5rg (1.5.0): already in the 1.8.1 base.

## Staying current (owner 2026-11-14: «que nuestro fork trate de ir al día, con las dependencias»)

A standing practice, not a one-off. Every piece runs from this repo's Actions; each has its rollback.

What these bots do not see (Go and Debian release support, the durable-streams engine fork, the consumers' lockfiles)
and how a finding becomes a production change, one deploy at a time: the maintenance runbook
<https://github.com/espaciofuturoio/ai-agents/blob/main/docs/ops/electric-stack-maintenance.md>. The monthly radar issue
carries its checklist (§ Stack audit).

**Inherited workflows disabled (2026-11-14).** GitHub turned Actions off on this fork «due to the scale of GitHub Actions
usage» (the inherited upstream workflows: desktop/mobile builds on every PR sync, benchmarks, Claude review). After the
owner re-enabled it, these were disabled with `gh workflow disable` (reversible: `gh workflow enable <name>`), because none
covers what we ship (the coordinator and sync images): Agents Desktop Build, Agents Desktop PR, Agents Mobile Build,
Agents Mobile Build (manual), Agents Mobile iOS Simulator, Agents Mobile PR, Auto-approve durable streams PRs, Benchmark
a PR, Benchmark comments, Benchmark Electric image from DockerHub, Check Skills, Claude Code, Claude Code Review, Load test
a PR, PR, Teardown Examples PR stack, and our finished `ef spike no sync`. Active: the `ef-*` workflows, Check Changeset
and Dependabot Updates. A new upstream workflow arrives enabled with the monthly merge: the radar PR reviewer disables it
unless it covers a shipped image.

| Cadence | Piece | What it does | Rollback |
| --- | --- | --- | --- |
| every PR, push to `main`, weekly | `ef-tests.yml` | sync-service suite on Postgres 18 (+pgbouncer, one retry of failures only) and the agents-runtime / agents-server suites against our own sync image by digest. Required on `main`. | Remove the required checks in branch protection; disable the workflow. |
| weekly (Mon) | `dependabot.yml` + `ef-dependabot-automerge.yml` | One grouped PR per ecosystem (Hex, npm for the agents packages, the coordinator Dockerfile, Actions) with all patch + minor updates, auto-merged when `ef tests` is green; each major is its own PR, labelled `major-needs-review`, never auto-merged. Security updates on. | Disable the automerge workflow (`gh pr merge --disable-auto` on open PRs); delete `dependabot.yml`. |
| weekly (Mon 05:07) | `ef-base-images.yml` (`.github/ef/base-images.sh`) | Sync image base: newest Elixir patch / OTP patch on the same minor/major and newest Debian bookworm slim; PR, tests, auto-merge. Never crosses a major. | Revert the PR. |
| weekly (Mon 07:41) | `ef-fork-images.yml` (schedule) | Rebuilds `main` with `--pull --no-cache`, tags `<v>-fork.<sha9>.w<YYYYMMDD>`, smoke, release with digests — OS / Node / OpenSSL patches land without a code change. Consumers adopt a digest by PR (ai-agents `infra/fork-images.env`, neo's two session composes). | Consumers keep their pinned digests; disable the schedule. |
| weekly + push | `ef-versions.yml` (`.github/ef/versions.sh`) | The README table: this fork vs newest upstream / published for each key piece. PR, auto-merge. | Disable; the table just stops refreshing. |
| monthly (1st) | `ef-radar.yml` (`.github/ef/radar.sh`) | Merges neondatabase/electric `main` into `ef/upstream-<YYYY-MM>` (or cherry-picks with a conflict note naming each skipped commit and its files), opens the PR (a person merges it as a MERGE commit), runs `ef tests` on it, and opens the issue «Fork radar <YYYY-MM>» with Pi (earendil-works/pi: pi-agent-core, pi-ai, pi-durable), Durable Streams, TanStack DB versions and the advisories (upstream GHSA, OSV over the Hex lock, `pnpm audit` over the coordinator's packages). | Disable; close the PR and delete the branch. |

Bots open their PRs through `.github/ef/bot-pr.sh`: the branch is pushed with the write deploy key (a `GITHUB_TOKEN`
push triggers nothing and may not touch workflow files), and the `pull_request` run of `ef tests`, which waits in
`action_required` on a bot PR, is approved — a `workflow_dispatch` run does not satisfy a PR's required checks.
Settings → Actions → «Allow GitHub Actions to create and approve pull requests» is on for this.
The fork-PR approval policy is «first-time contributors new to GitHub» (was «first-time contributors», which held every
bot PR's run in `action_required`; a `GITHUB_TOKEN` approval returns 201 but does not release it — measured on #25).
If a bot PR still shows `action_required`, approve the run in the UI (`gh api -X POST …/actions/runs/<id>/approve`).

Repo settings changed 2026-11-14 (all reversible in Settings): issues, auto-merge and merge commits enabled;
Dependabot alerts and security updates enabled; a write deploy key `ef-radar` (private half only in the secret
`EF_RADAR_DEPLOY_KEY`: the radar's upstream branch touches workflow files, which `GITHUB_TOKEN` may not push); labels `ef`, `dependencies`, `major-needs-review`; upstream workflows
that wait forever for `blacksmith-*` runners disabled (`ensure_sync_service_image`, `elixir_check_formatting`,
`server_rust_tests`, `electric_telemetry_tests`, `integration_tests`, `elixir_client_tests`, `sync_service_tests`,
`ts_tests`, `ts_check_formatting`) — `ef tests` replaces the two that cover what we ship.
