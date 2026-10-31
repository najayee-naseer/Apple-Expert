/**
 * Supabase Auth "Send SMS" hook -> SMSlenz.
 *
 * Supabase Auth generates the one-time code, stores it and verifies it. This
 * function only DELIVERS a code Supabase has already issued: it is called by
 * Supabase Auth (never by the app) with a Standard Webhooks signed payload, and
 * relays the code to the customer's phone through SMSlenz.
 *
 * It deliberately has no database access, no Supabase client and no
 * service-role key. The only credentials it holds are server-side Edge
 * Function secrets:
 *
 *   SEND_SMS_HOOK_SECRET   signing secret from Auth -> Hooks ("v1,whsec_...")
 *   SMSLENZ_USER_ID        SMSlenz account user id
 *   SMSLENZ_API_KEY        SMSlenz API key
 *   SMSLENZ_SENDER_ID      approved sender id (case-sensitive)
 *   SMSLENZ_API_BASE_URL   optional, defaults to https://www.smslenz.lk/api
 *
 * JWT verification is switched off for this function in config.toml because
 * Supabase Auth calls it without a user JWT. The webhook signature check below
 * is therefore the ONLY thing standing between the public URL and a free SMS
 * relay billed to the SMSlenz account, and it is never skipped.
 *
 * Logging rule: never the code, never a credential, never a full phone number,
 * never the raw SMSlenz response (it can carry recipient and balance details).
 */

import { Webhook } from 'npm:standardwebhooks@1.0.0'

const DEFAULT_SMSLENZ_API_BASE_URL = 'https://www.smslenz.lk/api'
const SMSLENZ_TIMEOUT_MS = 4000

interface SendSmsHookPayload {
  user?: { phone?: unknown }
  sms?: { otp?: unknown }
}

function json(status: number, body: unknown, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...extraHeaders },
  })
}

function hookError(status: number, message: string): Response {
  return json(status, { error: { http_code: status, message } })
}

/** The one failure customers see, whatever actually went wrong. */
function sendFailed(): Response {
  return hookError(500, 'Unable to send verification SMS.')
}

/**
 * Accepts both forms the secret is handed out in: "v1,whsec_<base64>" as
 * copied from the dashboard, and the bare "whsec_<base64>" / "<base64>".
 */
function webhookSecret(raw: string): string {
  return raw.trim().replace(/^v1,/, '').replace(/^whsec_/, '')
}

/**
 * Supabase Auth stores phone numbers as digits without the leading '+'
 * (it strips it on input), so the hook payload usually carries "94771234567".
 * SMSlenz requires E.164 with the '+'. Returns null for anything that is not
 * a plausible E.164 number once normalised.
 */
function toE164(phone: unknown): string | null {
  if (typeof phone !== 'string') return null
  const trimmed = phone.trim()
  const e164 = trimmed.startsWith('+') ? trimmed : `+${trimmed}`
  return /^\+[1-9]\d{7,14}$/.test(e164) ? e164 : null
}

/** "+94771234567" -> "+94*******67". Safe to log. */
function maskPhone(e164: string): string {
  if (e164.length <= 5) return '***'
  return `${e164.slice(0, 3)}${'*'.repeat(e164.length - 5)}${e164.slice(-2)}`
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return hookError(405, 'Method not allowed.')
  }

  const rawSecret = Deno.env.get('SEND_SMS_HOOK_SECRET')
  if (!rawSecret) {
    // Fail closed: without the secret no request can be authenticated.
    console.error('send-sms: SEND_SMS_HOOK_SECRET is not set')
    return sendFailed()
  }

  // The signature covers the exact bytes received, so read the body as text
  // and verify BEFORE parsing or acting on anything in it.
  const body = await req.text()
  let payload: SendSmsHookPayload
  try {
    const wh = new Webhook(webhookSecret(rawSecret))
    payload = wh.verify(body, {
      'webhook-id': req.headers.get('webhook-id') ?? '',
      'webhook-timestamp': req.headers.get('webhook-timestamp') ?? '',
      'webhook-signature': req.headers.get('webhook-signature') ?? '',
    }) as SendSmsHookPayload
  } catch {
    console.warn('send-sms: rejected request with missing or invalid webhook signature')
    return hookError(401, 'Invalid webhook signature.')
  }

  const contact = toE164(payload.user?.phone)
  const otp = payload.sms?.otp
  if (!contact) {
    console.error('send-sms: payload phone is missing or not E.164')
    return sendFailed()
  }
  if (typeof otp !== 'string' || !/^\d{6}$/.test(otp)) {
    console.error('send-sms: payload otp is missing or not 6 digits')
    return sendFailed()
  }

  const userId = Deno.env.get('SMSLENZ_USER_ID')
  const apiKey = Deno.env.get('SMSLENZ_API_KEY')
  const senderId = Deno.env.get('SMSLENZ_SENDER_ID')
  if (!userId || !apiKey || !senderId) {
    // Names only, never values.
    console.error('send-sms: SMSLENZ_USER_ID, SMSLENZ_API_KEY or SMSLENZ_SENDER_ID is not set')
    return sendFailed()
  }
  const baseUrl = (Deno.env.get('SMSLENZ_API_BASE_URL') || DEFAULT_SMSLENZ_API_BASE_URL).replace(/\/+$/, '')

  const message =
    `Your Apple Expert verification code is ${otp}. It expires in 10 minutes. Do not share this code.`

  const masked = maskPhone(contact)
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), SMSLENZ_TIMEOUT_MS)

  try {
    const response = await fetch(`${baseUrl}/send-sms`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        user_id: userId,
        api_key: apiKey,
        sender_id: senderId,
        contact,
        message,
      }),
      signal: controller.signal,
    })

    let result: { success?: unknown; data?: { campaign_id?: unknown } } | null = null
    try {
      result = await response.json()
    } catch {
      result = null
    }

    if (!response.ok || result?.success !== true) {
      console.error(
        `send-sms: SMSlenz rejected message to ${masked} (http ${response.status}, success=${String(result?.success)})`,
      )
      return sendFailed()
    }

    const campaignId = typeof result.data?.campaign_id === 'number' ? result.data.campaign_id : 'n/a'
    console.log(`send-sms: SMSlenz accepted message to ${masked} (campaign ${campaignId})`)
    return json(200, {})
  } catch (err) {
    const reason = err instanceof DOMException && err.name === 'AbortError' ? 'timed out' : 'network error'
    console.error(`send-sms: SMSlenz request for ${masked} failed (${reason})`)
    return sendFailed()
  } finally {
    clearTimeout(timer)
  }
})
