import { describe, expect, it, vi } from 'vitest'
import { EntityManager } from '../src/entity-manager'
import { SchemaValidator } from '../src/electric-agents/schema-validator'

/**
 * The durable-streams server keeps dispatch subscriptions in memory. After a
 * coordinator restart, wakes the coordinator appends itself (pgSync, observed
 * entities, cron, runFinished) must re-link the subscriber first, or they land
 * on a stream nothing watches and the entity is never dispatched.
 */
describe(`internal wakes re-link the subscriber's dispatch subscription`, () => {
  function setup(status: `idle` | `stopped`) {
    const order: Array<string> = []
    const subscriber = {
      url: `/crm_desk/a`,
      type: `crm_desk`,
      status,
      streams: { main: `/crm_desk/a/main` },
      write_token: `token`,
      tags: {},
      spawn_args: {},
      created_at: Date.now(),
      updated_at: Date.now(),
    }
    const wakeResult = {
      tenantId: `default`,
      subscriberUrl: subscriber.url,
      registrationDbId: 7,
      sourceEventKey: `row-1`,
      wakeMessage: {
        source: `/_electric/pg-sync/crm`,
        timeout: false,
        changes: [{ collection: `pg_sync_change`, kind: `insert`, key: `1` }],
      },
    }
    const wakeRegistry = {
      evaluate: vi.fn(() => [wakeResult]),
      setTimeoutCallback: vi.fn(),
      setDebounceCallback: vi.fn(),
    }
    const dispatchLinker = vi.fn(async () => {
      order.push(`link`)
    })
    const manager = new EntityManager({
      registry: {
        tenantId: `default`,
        getEntity: vi.fn().mockResolvedValue(subscriber),
      } as any,
      streamClient: {
        appendIdempotent: vi.fn(async () => {
          order.push(`append`)
        }),
      } as any,
      validator: new SchemaValidator(),
      wakeRegistry: wakeRegistry as any,
      dispatchLinker,
    })
    return { manager, dispatchLinker, order }
  }

  it(`links before appending the wake`, async () => {
    const { manager, dispatchLinker, order } = setup(`idle`)

    await manager.evaluateWakes(`/_electric/pg-sync/crm`, { type: `x` })

    expect(dispatchLinker).toHaveBeenCalledWith(
      expect.objectContaining({ url: `/crm_desk/a` })
    )
    expect(order).toEqual([`link`, `append`])
  })

  it(`does not re-link a stopped entity`, async () => {
    const { manager, dispatchLinker } = setup(`stopped`)

    await manager.evaluateWakes(`/_electric/pg-sync/crm`, { type: `x` })

    expect(dispatchLinker).not.toHaveBeenCalled()
  })
})
