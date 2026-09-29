import { describe, expect, it, vi } from 'vitest'
import {
  createStreamAppendRouteRequest,
  electricAgentsStreamAppendRouter,
} from '../src/routing/stream-append'

/**
 * `webhook("crm", { bucket })` observes `/_webhooks/crm/<bucket>` with an
 * insert wake. A standalone coordinator has no webhook ingest, so an append to
 * that stream must evaluate wakes like a shared-state append does, or the
 * observer is never woken.
 */
describe(`stream appends to observed source streams`, () => {
  function setup() {
    const evaluateWakePayload = vi.fn(async () => undefined)
    const runtime = {
      manager: {
        registry: { getEntityByStream: vi.fn(async () => null) },
        isAttachmentStreamPath: vi.fn(() => false),
        isForkWriteLockedStream: vi.fn(() => false),
      },
      evaluateWakePayload,
      checkRunFinished: vi.fn(),
      syncManifestWakes: vi.fn(async () => undefined),
      syncManifestEntitySources: vi.fn(async () => undefined),
      syncManifestSchedules: vi.fn(async () => undefined),
    }
    const forward = vi.fn(async () => new Response(null, { status: 204 }))
    const append = (path: string, event: Record<string, unknown>) =>
      electricAgentsStreamAppendRouter.fetch(
        createStreamAppendRouteRequest(
          new Request(`http://coordinator${path}`, {
            method: `POST`,
            headers: { 'content-type': `application/json` },
            body: JSON.stringify(event),
          })
        ),
        runtime as any,
        forward
      )
    return { append, evaluateWakePayload, forward }
  }

  const row = {
    type: `webhook_event`,
    key: `evt-1`,
    value: { key: `evt-1` },
    headers: { operation: `insert` },
  }

  it(`evaluates wakes for a webhook source stream append`, async () => {
    const { append, evaluateWakePayload, forward } = setup()

    const response = await append(`/_webhooks/crm/org-1`, row)

    expect(response?.status).toBe(204)
    expect(forward).toHaveBeenCalledTimes(1)
    expect(evaluateWakePayload).toHaveBeenCalledWith(
      `/_webhooks/crm/org-1`,
      row
    )
  })

  it(`still leaves other non-entity streams to plain forwarding`, async () => {
    const { append, evaluateWakePayload, forward } = setup()

    const response = await append(`/some/other/stream`, row)

    expect(response).toBeUndefined()
    expect(forward).not.toHaveBeenCalled()
    expect(evaluateWakePayload).not.toHaveBeenCalled()
  })
})
