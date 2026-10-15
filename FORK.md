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

Base: `@core/sync-service@1.8.1` (`0f404200`). Applied patches: **none** (release `1.8.1-ef.0` is upstream 1.8.1
exactly, built by us). Besides patches, the branch only adds this file and `.github/workflows/ef-sync-service-release.yml`.

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
