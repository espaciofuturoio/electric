---
'@electric-ax/agents-server': patch
---

The coordinator records the offset each runtime acks on a stream (`stream_acks`, migration 0017) and a wake hands the runtime the older of that and Durable Streams' own ack. Durable Streams keeps subscriptions in memory and links a stream again at its current tail after a restart, so messages appended just before a coordinator crash were acked without any handler seeing them.
