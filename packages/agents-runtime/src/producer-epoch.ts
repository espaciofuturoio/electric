/**
 * The epoch this process's idempotent producers write with.
 *
 * It is NOT the wake's epoch. The wake epoch is the durable-streams webhook generation, and it restarts at 1
 * whenever the coordinator restarts, while the stream server keeps every producer's `(epoch, seq)`. A producer id
 * is stable per entity (`entity-<url>`, `shared-state-<url>-<id>`), so a wake that reused a stored epoch counted
 * `seq` from 0 again and the server answered its appends `duplicate`: the writes were dropped silently and the
 * wake failed waiting for its own txid.
 *
 * A time-based epoch that only grows within the process is higher than every epoch stored before, including the
 * wake generations the older runtime used, and later wakes still fence earlier ones.
 */
let lastProducerEpoch = 0

export function nextProducerEpoch(now: number = Date.now()): number {
  lastProducerEpoch = Math.max(now, lastProducerEpoch + 1)
  return lastProducerEpoch
}
