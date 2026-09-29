---
'@electric-ax/agents-server': patch
---

pgSync bridges resume their persisted cursor with `log=changes_only`, the mode their shape was created with. Resuming with `full` (after a coordinator restart or a stream error) made Electric answer 409, the bridge restarted at `now` and lost every row committed in the gap.
