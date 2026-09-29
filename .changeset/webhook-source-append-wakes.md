---
'@electric-ax/agents-server': patch
---

Appends to a `webhook()` source stream (`/_webhooks/<endpoint>[/<bucket>]`) evaluate wakes, as shared-state appends do. A standalone coordinator has no webhook ingest, and these appends were forwarded without wake evaluation, so an entity observing `webhook()` was never woken.
