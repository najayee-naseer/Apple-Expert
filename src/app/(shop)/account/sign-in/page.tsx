"use client"

import { useEffect, useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import {
  LoaderCircle, ShieldCheck, MessageSquare, ArrowLeft, Mail, Info, AlertCircle,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { AuthShell, AuthField, PasswordField } from '@/components/account/AuthShell'
import { PhoneField } from '@/components/account/PhoneField'
import { OtpInput } from '@/components/account/OtpInput'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { getSupabaseClient, isSupabaseConfigured } from '@/lib/supabase/client'
import { fetchOwnProfile, updateOwnProfile, resolveCustomerType, resolvePostSignInDestination } from '@/lib/customer/profile'
import {
  fetchPhoneAuthAvailability, sendOtp, verifyOtp,
  OTP_LENGTH, RESEND_SECONDS, type PhoneAuthAvailability,
} from '@/lib/auth/otp'
import {
  fetchGoogleAuthAvailability, signInWithGoogle, type GoogleAuthAvailability,
} from '@/lib/auth/google'
import { parsePhone, formatE164, DEFAULT_COUNTRY_ISO } from '@/lib/auth/phone'
import { endGuestSession } from '@/lib/auth/guestMode'
import { openAdminLogin } from '@/lib/admin/entry'

/**
 * Customer authentication: phone number + SMS one-time code.
 *
 * ONE FLOW FOR SIGN-IN AND SIGN-UP. A phone number either belongs to an account
 * or it does not, and the customer should not have to know which — verifying
 * the code signs an existing customer in and creates the account for a new one.
 * That is why there is no separate registration screen any more.
 *
 * NOTHING IS EVER FAKED HERE. If this Supabase project has no SMS provider
 * configured, the form says so and refuses to send; there is no development
 * code, no bypass and no branch that can report a verified number without
 * GoTrue having verified it. Testing before the provider is bought is done
 * through Guest Test Mode, which is not authentication and never claims to be.
 *
 * WHAT SIGNING IN DOES NOT DO: it grants no pricing tier. The tier is whatever
 * public.profiles.customer_type already says, written only by
 * admin_set_customer_type(). A customer who came through the Wholesale entry
 * card arrives here exactly like everyone else and leaves as retail unless an
 * administrator has already approved them.
 */

type Step =
  | { kind: 'phone' }
  | { kind: 'code'; e164: string }
  /** First verification: the account exists, the profile has nothing in it yet. */
  | { kind: 'profile'; userId: string; e164: string }

/**
 * The email/password form kept as a SECONDARY path.
 *
 * Phone OTP is the primary and intended method; this exists only so accounts
 * created before the switch — and the team's own test logins — are not locked
 * out while the SMS provider is being arranged. Set this to false to remove the
 * fallback entirely; nothing else needs to change.
 */
const EMAIL_FALLBACK_ENABLED = true

/** The standard four-colour Google "G" mark, inlined so no icon font/library is needed. */
function GoogleGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
      <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.57 2.7-3.87 2.7-6.62Z" />
      <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.81.54-1.85.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.95v2.33A9 9 0 0 0 9 18Z" />
      <path fill="#FBBC05" d="M3.95 10.7A5.4 5.4 0 0 1 3.67 9c0-.59.1-1.17.28-1.7V4.97H.95A9 9 0 0 0 0 9c0 1.45.35 2.83.95 4.03l3-2.33Z" />
      <path fill="#EA4335" d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58C13.47.89 11.43 0 9 0A9 9 0 0 0 .95 4.97l3 2.33C4.66 5.17 6.65 3.58 9 3.58Z" />
    </svg>
  )
}

export default function CustomerSignInPage() {
  const router = useRouter()
  const { status, customerType, refresh } = useCustomerAuth()

  const [step, setStep] = useState<Step>({ kind: 'phone' })
  const [availability, setAvailability] = useState<PhoneAuthAvailability>('checking')
  const [googleAvailability, setGoogleAvailability] = useState<GoogleAuthAvailability>('checking')
  const [googleBusy, setGoogleBusy] = useState(false)

  const [iso, setIso] = useState(DEFAULT_COUNTRY_ISO)
  const [national, setNational] = useState('')
  const [code, setCode] = useState('')
  const [fullName, setFullName] = useState('')
  const [profileEmail, setProfileEmail] = useState('')

  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [secondsLeft, setSecondsLeft] = useState(0)

  const [showEmailForm, setShowEmailForm] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  // Already signed in? Nothing to do here — go to the storefront the DATABASE
  // assigns this account. Only from the first step: once a code is being
  // verified, submitCode()/submitProfile() route themselves, and leaving early
  // would skip the first-time "Almost there" name step.
  useEffect(() => {
    if (status === 'signed-in' && step.kind === 'phone') {
      router.replace(resolvePostSignInDestination(customerType))
    }
  }, [status, step.kind, customerType, router])

  // Ask the project what it can actually do, rather than assuming. Aborted on
  // unmount so a slow reply never writes into a screen that has gone.
  useEffect(() => {
    const controller = new AbortController()
    fetchPhoneAuthAvailability(controller.signal)
      .then((result) => setAvailability(result))
      .catch(() => setAvailability('unknown'))
    return () => controller.abort()
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    fetchGoogleAuthAvailability(controller.signal)
      .then((result) => setGoogleAvailability(result))
      .catch(() => setGoogleAvailability('unknown'))
    return () => controller.abort()
  }, [])

  // Resend cooldown. setState happens in the timer callback, never in the
  // effect body, so this never cascades a render.
  useEffect(() => {
    if (secondsLeft <= 0) return
    const id = window.setInterval(() => setSecondsLeft((s) => (s <= 1 ? 0 : s - 1)), 1000)
    return () => window.clearInterval(id)
  }, [secondsLeft])

  const smsBlocked = availability === 'unavailable'
  const googleBlocked = googleAvailability === 'unavailable'

  async function handleGoogleSignIn(): Promise<void> {
    setFormError(null)
    if (!isSupabaseConfigured()) {
      setFormError('Accounts are unavailable in this build.')
      return
    }
    setGoogleBusy(true)
    // Native only: if the customer closes the Google tab without finishing
    // (or after finishing — either way the tab closes), stop the spinner.
    // A completed sign-in has already navigated this page away by then.
    const result = await signInWithGoogle(() => setGoogleBusy(false))
    if (!result.ok) {
      setGoogleBusy(false)
      setFormError(result.message)
    }
    // On success, the browser is navigating away (web) or a system tab just
    // opened (native) — either way there is nothing further to render here.
  }

  async function requestCode(e164: string): Promise<void> {
    setBusy(true)
    setFormError(null)
    const result = await sendOtp(e164)
    setBusy(false)

    if (!result.ok) {
      if (result.kind === 'provider-disabled') setAvailability('unavailable')
      setFormError(result.message)
      return
    }

    setCode('')
    setSecondsLeft(RESEND_SECONDS)
    setNotice(`We sent a ${OTP_LENGTH}-digit code to ${formatE164(e164)}.`)
    setStep({ kind: 'code', e164 })
  }

  function handlePhoneSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault()
    setFormError(null)

    if (!isSupabaseConfigured()) {
      setFormError('Accounts are unavailable in this build.')
      return
    }
    const parsed = parsePhone(iso, national)
    if (!parsed.ok) {
      setFormError(parsed.reason)
      return
    }
    void requestCode(parsed.e164)
  }

  /**
   * Verifies the code, then decides whether the account still needs a name.
   *
   * The profile row itself already exists by this point — handle_new_user()
   * created it inside PostgreSQL when GoTrue inserted the auth user, with
   * customer_type taking its 'retail' default. This only fills in the details a
   * customer supplies about themselves.
   */
  async function submitCode(e164: string, token: string): Promise<void> {
    if (token.length !== OTP_LENGTH) {
      setFormError(`Enter the ${OTP_LENGTH}-digit code.`)
      return
    }

    setBusy(true)
    setFormError(null)
    const result = await verifyOtp(e164, token)

    if (!result.ok) {
      setBusy(false)
      setFormError(result.message)
      return
    }

    // A real session now exists, so a test identity must not linger over it.
    endGuestSession()

    const userId = result.session.user.id
    try {
      const profile = await fetchOwnProfile(userId)

      // Keep the profile's phone in step with the number that was verified.
      // handle_new_user() copies email and full_name only, so on a phone signup
      // this column starts empty.
      if (profile && !profile.phone) {
        try { await updateOwnProfile(userId, { phone: e164 }) } catch { /* cosmetic */ }
      }

      if (!profile?.full_name?.trim()) {
        setBusy(false)
        setNotice(null)
        setStep({ kind: 'profile', userId, e164 })
        return
      }

      await refresh()
      router.replace(resolvePostSignInDestination(resolveCustomerType(profile)))
    } catch {
      // Verified, but the profile read failed. Still signed in — let the
      // storefront load and show its own error rather than stranding them here.
      await refresh()
      router.replace('/')
    } finally {
      setBusy(false)
    }
  }

  async function submitProfile(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (step.kind !== 'profile') return

    const name = fullName.trim()
    if (name.length < 2) {
      setFormError('Enter your name so we know who to address orders to.')
      return
    }

    setBusy(true)
    setFormError(null)
    try {
      const updated = await updateOwnProfile(step.userId, {
        full_name: name,
        phone: step.e164,
        email: profileEmail.trim() === '' ? null : profileEmail.trim(),
      })
      await refresh()
      router.replace(resolvePostSignInDestination(resolveCustomerType(updated)))
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Could not save your details.')
    } finally {
      setBusy(false)
    }
  }

  async function handleEmailSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    setFormError(null)

    if (!isSupabaseConfigured()) {
      setFormError('Accounts are unavailable in this build.')
      return
    }

    setBusy(true)
    try {
      const { error } = await getSupabaseClient().auth.signInWithPassword({
        email: email.trim(),
        password,
      })
      if (error) {
        // Deliberately generic: never reveal whether the address has an account.
        setFormError('Those details were not accepted. Check your email and password.')
        return
      }
      endGuestSession()
      // The "already signed in" effect above routes by the account's
      // database tier as soon as the refreshed profile arrives.
      await refresh()
    } catch {
      setFormError('Could not reach the server. Check your connection and try again.')
    } finally {
      setBusy(false)
    }
  }

  const card = 'rounded-[26px] border border-mint/80 dark:border-border bg-surface p-5 shadow-card sm:p-6'

  // -------------------------------------------------------------------------
  // Step 3 — first-time profile details
  // -------------------------------------------------------------------------
  if (step.kind === 'profile') {
    return (
      <AuthShell
        title="Almost there"
        subtitle={`${formatE164(step.e164)} is verified. Tell us who you are.`}
        footer={
          <p className="flex items-start justify-center gap-2 text-[11.5px] leading-relaxed text-muted-foreground">
            <ShieldCheck size={13} className="mt-0.5 shrink-0" />
            <span className="max-w-[19rem] text-left">
              New accounts start on retail pricing. Wholesale pricing is granted by Apple Expert
              after reviewing a wholesale access request.
            </span>
          </p>
        }
      >
        <form onSubmit={(e) => void submitProfile(e)} className={card}>
          <AuthField
            label="Full name" value={fullName} onChange={setFullName}
            autoComplete="name" disabled={busy} placeholder="Your name"
          />
          <AuthField
            label="Email (optional)" type="email" value={profileEmail} onChange={setProfileEmail}
            autoComplete="email" inputMode="email" required={false} disabled={busy}
            placeholder="you@example.com"
            hint="Only for order receipts. You sign in with your phone."
          />

          {formError && (
            <p role="alert" className="mb-4 text-[13px] font-medium text-red-500">{formError}</p>
          )}

          <Button type="submit" fullWidth size="lg" disabled={busy}>
            {busy
              ? <><LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</>
              : 'Continue'}
          </Button>
        </form>
      </AuthShell>
    )
  }

  // -------------------------------------------------------------------------
  // Step 2 — the code
  // -------------------------------------------------------------------------
  if (step.kind === 'code') {
    return (
      <AuthShell
        title="Enter your code"
        subtitle={`Sent to ${formatE164(step.e164)}`}
        footer={
          <button
            type="button"
            onClick={() => { setStep({ kind: 'phone' }); setCode(''); setFormError(null); setNotice(null) }}
            className="focus-ring inline-flex items-center gap-1.5 rounded-full px-3 py-2 text-[13px] font-medium text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft size={15} />
            Use a different number
          </button>
        }
      >
        <form
          onSubmit={(e) => { e.preventDefault(); void submitCode(step.e164, code) }}
          className={card}
        >
          <OtpInput
            value={code}
            onChange={(next) => { setCode(next); setFormError(null) }}
            onComplete={(next) => void submitCode(step.e164, next)}
            disabled={busy}
            invalid={formError !== null}
          />

          {notice && !formError && (
            <p className="mt-4 flex items-start gap-2 text-[12.5px] leading-snug text-muted-foreground">
              <MessageSquare size={13} className="mt-0.5 shrink-0" />
              {notice}
            </p>
          )}
          {formError && (
            <p role="alert" className="mt-4 text-[13px] font-medium text-red-500">{formError}</p>
          )}

          <Button type="submit" fullWidth size="lg" className="mt-5" disabled={busy || code.length !== OTP_LENGTH}>
            {busy
              ? <><LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />Verifying…</>
              : 'Verify and continue'}
          </Button>

          <button
            type="button"
            disabled={busy || secondsLeft > 0}
            onClick={() => void requestCode(step.e164)}
            className="focus-ring mt-3 w-full rounded-full py-2 text-[13px] font-semibold text-primary transition-colors disabled:text-muted-foreground"
          >
            {secondsLeft > 0 ? `Resend code in ${secondsLeft}s` : 'Resend code'}
          </button>
        </form>
      </AuthShell>
    )
  }

  // -------------------------------------------------------------------------
  // Step 1 — the phone number
  // -------------------------------------------------------------------------
  return (
    <AuthShell
      title="Sign in"
      subtitle="Continue with Google, or use your phone number."
      footer={
        <p className="flex items-start justify-center gap-2 text-[11.5px] leading-relaxed text-muted-foreground">
          <ShieldCheck size={13} className="mt-0.5 shrink-0" />
          <span className="max-w-[19rem] text-left">
            No password to remember. If this account is new to Apple Expert, signing in creates it
            on retail pricing.
          </span>
        </p>
      }
    >
      <div className={card}>
        <button
          type="button"
          onClick={() => void handleGoogleSignIn()}
          disabled={googleBusy || googleBlocked || googleAvailability === 'checking'}
          className="focus-ring flex h-12 w-full items-center justify-center gap-3 rounded-2xl border border-mint-deep dark:border-border bg-card text-[14px] font-semibold text-foreground transition-colors hover:bg-well-strong disabled:opacity-60"
        >
          {googleBusy ? (
            <><LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" />Opening Google…</>
          ) : (
            <><GoogleGlyph />Continue with Google</>
          )}
        </button>

        {googleBlocked && (
          <div className="mt-4 flex items-start gap-2.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-4 py-3">
            <Info size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
            <p className="text-[13px] leading-snug text-foreground">
              <strong className="font-semibold">Google sign-in will be available soon.</strong>{' '}
              Apple Expert is finishing the setup with Google. Use your phone number below in the
              meantime.
            </p>
          </div>
        )}
      </div>

      <div className="my-4 flex items-center gap-3 px-1" aria-hidden="true">
        <span className="h-px flex-1 bg-mint/70 dark:bg-border" />
        <span className="text-[11.5px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">or</span>
        <span className="h-px flex-1 bg-mint/70 dark:bg-border" />
      </div>

      <form onSubmit={handlePhoneSubmit} className={card}>
        <PhoneField
          iso={iso} onIsoChange={setIso}
          national={national} onNationalChange={(value) => { setNational(value); setFormError(null) }}
          disabled={busy || smsBlocked}
          autoFocus
        />

        {/* The project's real capability, read from GoTrue — never a guess. */}
        {smsBlocked && (
          <div className="mt-4 flex items-start gap-2.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-4 py-3">
            <Info size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
            <p className="text-[13px] leading-snug text-foreground">
              <strong className="font-semibold">SMS verification will be available soon.</strong>{' '}
              Apple Expert is finishing the setup with its SMS provider. Nothing is sent until then.
            </p>
          </div>
        )}
        {availability === 'unknown' && (
          <p className="mt-4 flex items-start gap-2 text-[12.5px] leading-snug text-muted-foreground">
            <AlertCircle size={13} className="mt-0.5 shrink-0" />
            We could not check SMS availability. You can still try — you will be told if it fails.
          </p>
        )}

        {formError && (
          <p role="alert" className="mt-4 text-[13px] font-medium text-red-500">{formError}</p>
        )}

        <Button
          type="submit" fullWidth size="lg" className="mt-5"
          disabled={busy || smsBlocked || availability === 'checking'}
        >
          {busy
            ? <><LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />Sending code…</>
            : availability === 'checking'
              ? <><LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />Checking…</>
              : 'Send code'}
        </Button>
      </form>

      {EMAIL_FALLBACK_ENABLED && (
        <div className="mt-4">
          {!showEmailForm ? (
            <button
              type="button"
              onClick={() => { setShowEmailForm(true); setFormError(null) }}
              className="focus-ring mx-auto flex items-center gap-2 rounded-full px-3 py-2 text-[13px] font-medium text-muted-foreground transition-colors hover:text-foreground"
            >
              <Mail size={15} />
              Have an older account? Sign in with email
            </button>
          ) : (
            <form onSubmit={(e) => void handleEmailSubmit(e)} className={card}>
              <p className="mb-4 text-[12.5px] leading-relaxed text-muted-foreground">
                For accounts created before phone sign-in. New customers should use their phone
                number above.
              </p>
              <AuthField
                label="Email" type="email" value={email} onChange={setEmail}
                autoComplete="username" inputMode="email" disabled={busy}
                placeholder="you@example.com"
              />
              <PasswordField
                label="Password" value={password} onChange={setPassword}
                autoComplete="current-password" disabled={busy}
              />
              <Button type="submit" fullWidth variant="secondary" disabled={busy}>
                {busy
                  ? <><LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />Signing in…</>
                  : 'Sign in with email'}
              </Button>
            </form>
          )}
        </div>
      )}

      {/* Staff may have no customer account, so Profile is out of their reach here. */}
      <button
        type="button"
        onClick={openAdminLogin}
        className="focus-ring mx-auto mt-3 flex rounded-full px-3 py-2 text-[12px] font-medium text-muted-foreground hover:text-foreground transition-colors"
      >
        Apple Expert personnel: Admin Login
      </button>
    </AuthShell>
  )
}
