/**
 * Releases online orders not confirmed within 48 hours.
 *
 * For an external scheduler, because pg_cron and pg_net are deliberately not
 * enabled. Optional: availability already ignores overdue holds and every stock
 * path sweeps the products it touches. This only keeps order statuses current when
 * nothing else is happening. Safe to call repeatedly.
 *
 * Authorised by a shared secret, compared in constant time. Secrets:
 *   RESERVATION_EXPIRY_SECRET   chosen by whoever configures the scheduler
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   provided by the platform
 *
 * The service role key can only do what public.expire_pending_orders() does here.
 */

function safeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a)
  const right = new TextEncoder().encode(b)
  if (left.length !== right.length) return false
  let diff = 0
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i]
  return diff === 0
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  const secret = Deno.env.get('RESERVATION_EXPIRY_SECRET')
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!secret || !url || !key) return new Response('Not configured', { status: 503 })

  if (!safeEqual(req.headers.get('x-expiry-secret') ?? '', secret)) {
    return new Response('Forbidden', { status: 403 })
  }

  const response = await fetch(`${url}/rest/v1/rpc/expire_pending_orders`, {
    method: 'POST',
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_limit: 200 }),
  })

  // Never relays a database error body: it is logged by the platform, not the caller.
  if (!response.ok) return new Response('Expiry failed', { status: 502 })
  return new Response(await response.text(), { headers: { 'Content-Type': 'application/json' } })
})
