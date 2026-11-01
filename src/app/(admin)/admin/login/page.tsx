"use client"

import { useEffect, useState, useSyncExternalStore, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { ShieldCheck, Eye, EyeOff, LoaderCircle, AlertCircle, ArrowLeft } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { getSupabaseClient, isSupabaseConfigured } from '@/lib/supabase/client'

const noop = () => () => {}

/**
 * Administrator sign-in.
 *
 * Lives outside the (panel) route group so AdminGuard never wraps it — a
 * guarded sign-in page would redirect to itself forever.
 *
 * Signing in proves identity only. Authorization is a separate database
 * decision made after the session exists: a customer with valid credentials
 * signs in here successfully and is then shown Access Denied.
 */
export default function AdminLoginPage() {
  const router = useRouter()
  const { status, refresh } = useAdminAuth()
  // Before React attaches, the browser would submit this form itself and put the
  // password in the URL. So the button waits; it also stops Enter submitting.
  const ready = useSyncExternalStore(noop, () => true, () => false)

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  // Already signed in and authorised? Go straight through.
  useEffect(() => {
    if (status === 'authorized') router.replace('/admin')
  }, [status, router])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    if (!isSupabaseConfigured()) {
      setFormError('Supabase is not configured for this build.')
      return
    }

    setSubmitting(true)
    try {
      const supabase = getSupabaseClient()
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })

      if (error) {
        // Deliberately generic: never reveal whether the address exists.
        setFormError('Those credentials were not accepted.')
        return
      }

      await refresh()
      router.replace('/admin')
    } catch {
      setFormError('Could not reach the server. Check your connection and try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const isUnauthorized = status === 'unauthorized'

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-5 py-14">
      <div className="w-full max-w-sm">
        <div className="text-center mb-7">
          <span
            className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-cta text-white shadow-glow"
            aria-hidden="true"
          >
            <ShieldCheck size={26} strokeWidth={2.1} />
          </span>
          <h1 className="text-[24px] font-bold tracking-tight text-foreground leading-tight">
            Apple Expert Admin
          </h1>
          <p className="mt-1.5 text-sm text-muted-foreground">
            Sign in with an authorised administrator account.
          </p>
        </div>

        <form
          onSubmit={handleSubmit}
          className="bg-surface border border-mint/80 dark:border-border rounded-[26px] shadow-card p-5 sm:p-6"
        >
          {isUnauthorized && (
            <div className="mb-4 flex items-start gap-2.5 rounded-2xl border border-amber-500/25 bg-amber-500/10 px-3.5 py-3">
              <AlertCircle size={16} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">
                That account is signed in but is not authorised for the admin panel.
              </p>
            </div>
          )}

          <label htmlFor="admin-email" className="block text-[13px] font-semibold text-foreground mb-1.5">
            Email
          </label>
          <input
            id="admin-email"
            name="email"
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="focus-ring w-full h-12 mb-4 rounded-2xl border border-mint-deep dark:border-border bg-card px-4 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 transition-colors"
            placeholder="you@appleexpert.lk"
          />

          <label htmlFor="admin-password" className="block text-[13px] font-semibold text-foreground mb-1.5">
            Password
          </label>
          <div className="relative mb-4">
            <input
              id="admin-password"
              name="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="focus-ring w-full h-12 rounded-2xl border border-mint-deep dark:border-border bg-card pl-4 pr-12 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 transition-colors"
              placeholder="••••••••"
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
              className="focus-ring absolute inset-y-0 right-0 flex w-12 items-center justify-center rounded-r-2xl text-muted-foreground hover:text-foreground transition-colors"
            >
              {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
            </button>
          </div>

          {formError && (
            <p role="alert" className="mb-4 text-[13px] font-medium text-red-500">
              {formError}
            </p>
          )}

          <Button type="submit" fullWidth size="lg" disabled={submitting || !ready}>
            {submitting ? (
              <>
                <LoaderCircle size={17} className="mr-2 animate-spin motion-reduce:animate-none" />
                Signing in…
              </>
            ) : (
              'Sign in'
            )}
          </Button>

          <p className="mt-3.5 text-center text-[12px] leading-snug text-muted-foreground">
            On this device, signing in here replaces any customer account that is signed in.
            Signing out ends both.
          </p>
        </form>

        <div className="mt-5 text-center">
          <Link
            href="/"
            className="focus-ring inline-flex items-center gap-1.5 rounded-full px-3 py-2 text-[13px] font-medium text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft size={15} />
            Back to the store
          </Link>
        </div>
      </div>
    </div>
  )
}
