import { createPublicKey, generateKeyPairSync, sign } from 'node:crypto'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { verifyWebhookSignature } from '../src/webhook-signature'
import type { KeyObject } from 'node:crypto'

function signingKey(kid: string) {
  const { privateKey } = generateKeyPairSync(`ed25519`)
  const jwk = createPublicKey(privateKey).export({ format: `jwk` }) as {
    x: string
  }
  return {
    privateKey,
    jwk: {
      kty: `OKP`,
      crv: `Ed25519`,
      x: jwk.x,
      kid,
      use: `sig`,
      alg: `EdDSA`,
    },
  }
}

function signedHeader(privateKey: KeyObject, kid: string, body: Uint8Array) {
  const t = Math.floor(Date.now() / 1000).toString()
  const signature = sign(
    null,
    Buffer.concat([Buffer.from(`${t}.`), Buffer.from(body)]),
    privateKey
  ).toString(`base64url`)
  return `t=${t},kid=${kid},ed25519=${signature}`
}

/** A JWKS endpoint that serves whichever key the "coordinator" currently signs with. */
function jwksServer(initial: ReturnType<typeof signingKey>) {
  let current = initial
  const fetchClient = vi.fn(
    async () =>
      new Response(JSON.stringify({ keys: [current.jwk] }), {
        headers: { 'content-type': `application/json` },
      })
  )
  return {
    fetchClient: fetchClient as unknown as typeof fetch,
    calls: () => fetchClient.mock.calls.length,
    rotate: (next: ReturnType<typeof signingKey>) => {
      current = next
    },
  }
}

const body = new TextEncoder().encode(`{"wake":1}`)

describe(`verifyWebhookSignature`, () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it(`accepts a server's new signing key after a restart without waiting for the JWKS cache to expire`, async () => {
    vi.useFakeTimers({ now: new Date(`2026-09-29T14:00:00Z`) })
    const before = signingKey(`boot-1`)
    const server = jwksServer(before)
    const config = {
      jwksUrl: `http://coordinator-restart/__ds/jwks.json`,
      fetchClient: server.fetchClient,
    }

    expect(
      await verifyWebhookSignature(
        body,
        signedHeader(before.privateKey, `boot-1`, body),
        config
      )
    ).toEqual({ ok: true })

    // The coordinator restarts 30 s later with a freshly generated key.
    vi.advanceTimersByTime(30_000)
    const after = signingKey(`boot-2`)
    server.rotate(after)

    expect(
      await verifyWebhookSignature(
        body,
        signedHeader(after.privateKey, `boot-2`, body),
        config
      )
    ).toEqual({ ok: true })
    expect(server.calls()).toBe(2)
  })

  it(`refetches for an unknown kid at most once per interval`, async () => {
    vi.useFakeTimers({ now: new Date(`2026-09-29T14:00:00Z`) })
    const known = signingKey(`known`)
    const server = jwksServer(known)
    const config = {
      jwksUrl: `http://coordinator-forged/__ds/jwks.json`,
      fetchClient: server.fetchClient,
    }
    const forged = signingKey(`forged`)
    const forgedHeader = () => signedHeader(forged.privateKey, `forged`, body)

    await verifyWebhookSignature(
      body,
      signedHeader(known.privateKey, `known`, body),
      config
    )
    vi.advanceTimersByTime(11_000)
    const first = await verifyWebhookSignature(body, forgedHeader(), config)
    const second = await verifyWebhookSignature(body, forgedHeader(), config)

    expect(first).toMatchObject({ ok: false, status: 401 })
    expect(second).toMatchObject({ ok: false, status: 401 })
    // One initial fetch + one refresh for the first unknown kid; the second is served from cache.
    expect(server.calls()).toBe(2)
  })
})
