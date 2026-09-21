---
'@electric-ax/agents-runtime': patch
'@electric-ax/agents': patch
'@electric-ax/agents-server-ui': patch
'@electric-ax/agents-mobile': patch
'electric-ax': patch
---

Raise the TanStack DB stack to the current line: `@tanstack/db` `^0.6.6` → `^0.9.2` (pulling
`@tanstack/db-ivm` 0.1.18 → 0.1.22), `@tanstack/react-db` `^0.1.85` → `^0.4.1` and
`@tanstack/electric-db-collection` `^0.3.5` → `^0.4.10`. `react-db` 0.4.1 and
`electric-db-collection` 0.4.10 both hard-pin `@tanstack/db@0.9.2`, so a consumer that installs
either alongside the runtime now resolves a single `@tanstack/db` copy instead of two.

`agents-runtime`'s optional `@tanstack/react-db` peer moves to `>=0.4.0` for the same reason: the
old `>=0.1.78` let a consumer satisfy the peer with a 0.1.x `react-db` that pins `db@0.6.x`, which
is a second copy of the query engine in the same bundle.

No source change was required. The `useLiveQuery(query, deps)` dependency-array form that all 58
call sites in this repo use is deprecated in `react-db` 0.3.0 but still drives query identity; it
only adds a once-per-callsite `console.warn` outside production.
