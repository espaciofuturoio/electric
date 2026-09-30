import { and, eq, sql } from 'drizzle-orm'
import { streamAcks } from './db/schema.js'
import type { DrizzleDB } from './db/index.js'

/**
 * Durable Streams keeps its subscriptions in memory. After a coordinator restart an entity's stream is linked again
 * with its CURRENT tail as the acked offset, so messages appended just before the crash that no handler saw would be
 * acked unseen. The coordinator therefore keeps the last offset each runtime acked (every wake callback passes
 * through it) and a wake hands the runtime the OLDER of the two acks. A failed write here only re-delivers events;
 * it never skips one.
 */

/** Offsets are fixed-width strings (`-1` = before the first event), so they order as plain strings. */
export function olderOffset(a: string, b: string | undefined): string {
  return b !== undefined && b < a ? b : a
}

/** Records each ack, moving a stream's offset forward only. */
export async function recordStreamAcks(
  db: DrizzleDB,
  tenantId: string,
  acks: Array<{ stream: string; offset: string }>
): Promise<void> {
  for (const { stream, offset } of acks) {
    if (!stream || !offset) continue
    await db
      .insert(streamAcks)
      .values({ tenantId, stream, ackedOffset: offset })
      .onConflictDoUpdate({
        target: [streamAcks.tenantId, streamAcks.stream],
        set: { ackedOffset: offset, updatedAt: sql`now()` },
        setWhere: sql`${streamAcks.ackedOffset} COLLATE "C" < ${offset} COLLATE "C"`,
      })
  }
}

export async function persistedAckedOffset(
  db: DrizzleDB,
  tenantId: string,
  stream: string
): Promise<string | undefined> {
  const rows = await db
    .select({ ackedOffset: streamAcks.ackedOffset })
    .from(streamAcks)
    .where(
      and(eq(streamAcks.tenantId, tenantId), eq(streamAcks.stream, stream))
    )
    .limit(1)
  return rows[0]?.ackedOffset
}
