# espaciofuturoio/electric — fork

Owner rule (2026-10-04): we carry what we need ourselves and follow upstream; we never wait on a maintainer. Policy:
Neo `official-docs/operations/own-forks-and-upstream-sync.md`. Nothing is posted upstream without the owner's go.

## Two lines in this fork

| Branch | What it carries | Consumers |
| --- | --- | --- |
| `main` | Upstream `main` + agents-server / agents-runtime / CRM patches (`runtime-0.6.3-*` tags) | neo-crm (Electric Agents) |
| `ef/sync-service` | An upstream `@core/sync-service@X` release tag + our sync-service patches, released as our image | Neo `apps/fly-electric`, `apps/tablekit-electric`, `infra/dev-stack/compose.yml` |

The two lines never merge into each other. `ef/sync-service` stays a short patch stack on a release tag:
`git log --oneline '@core/sync-service@<base>'..ef/sync-service` is the patch list.

## Patch list (`ef/sync-service`)

Base: `@core/sync-service@1.8.1` (`0f404200`). Release `1.8.1-ef.0` is upstream 1.8.1 exactly, built by us.
`1.8.1-ef.1` (2026-11-14) adds ONE security patch: Hex deps raised (bandit 1.14.1, plug 1.20.3, phoenix 1.8.16,
phoenix_live_view 1.2.13, phoenix_html 4.4.0, postgrex 0.22.4, ecto 3.14.3, plug_crypto 2.2.1, hpax 1.1.0, decimal 3.2.0)
and the image on Elixir 1.20.5 / OTP 29.1.2 / Debian bookworm-20261104. Advisories and reasons: `FORK.md` on `main`,
§ Security review 2026-11-14 (same set; the agents line was tested with the full sync suite). Besides patches, the branch only adds this file and `.github/workflows/ef-sync-service-release.yml`.

`1.8.1-ef.2` (2026-11-24) moves the image base to Debian trixie (ai-agents plan 027 R2c-5).
`1.8.1-ef.3` (2026-11-24, security-hardening doc 06 WS-SH6) raises four prod deps past their 2026-11 advisories: mint 1.9.0→1.11.0
(through `req`; 1.9.1, 1.10.0 and 1.10.1 still carry advisories in Hex, 1.11.0 is the first clean one), phoenix 1.8.16→1.8.17,
phoenix_live_view 1.2.13→1.2.14 (both through `phoenix_live_dashboard`), plug 1.20.3→1.20.4; `mix` also moved bandit 1.14.1→1.15.0
and telemetry 1.4.2→1.4.3 as their dependants. Still open in `mix hex.audit`: `protobuf` 0.13.0 (fix is ≥ 0.17.1; upstream pins
`~> 0.13.0` because Protox from pg_query_ex clashes; the sync service only ENCODES with it) and `ssl_verify_fun` 1.1.7
(IS in the prod release, via opentelemetry_exporter → tls_certificate_check; only an OTLP/TLS export would verify a certificate
with it and no stack configures one, so unreachable). Review both when the pins can move.

Candidates, not applied:
- `1bdae5c2a` on `main` — LiveDashboard Metrics page + request logger for the sync service.

## Release

1. Bump only after reading the release notes **and** https://github.com/electric-sql/electric/security
   (2026-10-15: Neo ran 1.7.2 and was exposed to GHSA-m4f6-p2j8-rq76).
2. Tag `sync-service-v<upstream>-ef.<n>` on `ef/sync-service` and push it, or run the workflow by hand.
   The workflow builds `packages/sync-service/Dockerfile` (linux/amd64), pushes
   `ghcr.io/espaciofuturoio/electric-sync-service:<upstream>-ef.<n>`, then smoke-tests that image: a row inserted in
   Postgres comes back through `/v1/shape`, and with `ELECTRIC_SECRET` set both `/v1/shape` and `/v1/shape/` answer 401.
   A failed smoke fails the run and creates no GitHub release.
3. Point consumers at the exact tag (never `latest`), deploy, and verify per Neo doc 10 «Upgrading or restarting Electric».

## Sync by hand

```sh
git fetch upstream --tags
git switch ef/sync-service
git rebase --onto '@core/sync-service@<new>' '@core/sync-service@<old>' ef/sync-service
# resolve, push --force-with-lease, then release <new>-ef.0
```

Upstream's own publishing workflows (Docker Hub, npm, changesets) are disabled in this fork's Actions settings so
nothing is published under upstream's names from here.
