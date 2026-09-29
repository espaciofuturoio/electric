---
'@electric-ax/agents-server': patch
---

The startup banner prints the Postgres URL with its password redacted (it was printed verbatim into the container log).
