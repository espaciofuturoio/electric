---
'@electric-ax/agents-server': patch
---

Wakes the coordinator appends itself (pgSync changes, observed entities, cron ticks, runFinished, scheduled sends) re-link the subscriber's dispatch subscription first. The durable-streams server keeps subscriptions in memory and only the spawn/send/fork routes re-linked them, so after a coordinator restart an entity woken only by such wakes was never dispatched again until an inbox message arrived.
