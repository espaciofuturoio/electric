---
'@electric-ax/agents-runtime': patch
---

The entity and shared-state producers no longer write with the wake epoch. That epoch is the webhook generation and restarts at 1 with the coordinator, while the stream server keeps each producer's `(epoch, seq)`. So the first wake of an existing entity after a coordinator restart had its writes answered `duplicate` and dropped, and it failed with `Timeout waiting for txid`. The producers now use a per-process, strictly increasing, time-based epoch.
