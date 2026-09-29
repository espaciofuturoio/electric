---
'@electric-ax/agents-server': patch
---

pgSync bridges no longer lose rows across a coordinator restart:

- they resume their persisted cursor with `log=changes_only`, the mode their shape was created with (resuming with `full` made Electric answer 409 and the bridge restart at `now`, losing the gap);
- each bridge start writes in a new producer epoch (the producer id and the server's `(epoch, seq)` state survive a restart, so a restarted bridge at epoch 0 had its first appends dropped as duplicates).
