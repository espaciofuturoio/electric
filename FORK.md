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
