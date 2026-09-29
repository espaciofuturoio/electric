---
'@electric-ax/agents-runtime': patch
---

Webhook signature verification refetches the JWKS (at most once per 10 s) when a signature names an unknown `kid`. The coordinator generates a new signing key on every boot unless `ELECTRIC_AGENTS_WEBHOOK_SIGNING_PRIVATE_KEY` is set, so after a coordinator restart every wake was rejected (401) until the cached JWKS expired — up to five minutes with no wakes for existing entities.
