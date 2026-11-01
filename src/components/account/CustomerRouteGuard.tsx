"use client"

import { useEffect, useState } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { AlertCircle, Clock, LoaderCircle, LogOut, Mail, MessageCircle, Phone, RotateCw, Wrench } from 'lucide-react'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { decideAccess, type UnavailableReason } from '@/lib/customer/access'
import { useStoreSettings, type StoreSettings } from '@/lib/store/settings'
import { hasCompletedOnboarding } from '@/utils/onboarding'
import { getExperience } from '@/utils/experience'
import { openAdminLogin } from '@/lib/admin/entry'

/**
 * Route protection for the whole customer app.
 *
 * `output: "export"` means there is no server and no middleware, so the check
 * runs here, before any store screen renders: the store shell (bottom nav
 * included) is withheld until decideAccess() says `render`, which cannot happen
 * until the session and the account's profiles.customer_type are loaded. A
 * Wholesale VIP therefore never sees the Retail home flash up before being
 * redirected, and vice versa.
 *
 * Mounted once in the (shop) layout, so it covers normal navigation, direct
 * URLs, refreshes, Capacitor deep links and session restoration alike: each of
 * those is just a pathname change or a new session reaching this component.
 */
export function CustomerRouteGuard({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() ?? '/'
  const router = useRouter()
  const { access } = useCustomerAuth()
  // Admin-controlled switches from /admin/settings (public.store_settings).
  const { settings, status: settingsStatus } = useStoreSettings()

  // The local entry flags only sequence the signed-out screens (onboarding,
  // then type selection, then sign-in). They are read during render; on the
  // server and the first client render `access` is 'loading', so they are not
  // consulted until after hydration.
  const decision = decideAccess(access, pathname, {
    onboarded: typeof window !== 'undefined' && hasCompletedOnboarding(),
    experienceChosen: typeof window !== 'undefined' && getExperience() !== null,
  }, {
    loaded: settingsStatus !== 'loading',
    maintenance: settings.maintenance_mode,
    retailEnabled: settings.retail_enabled,
    wholesaleEnabled: settings.wholesale_enabled,
  })
  const redirectTo = decision.kind === 'redirect' ? decision.to : null

  useEffect(() => {
    if (redirectTo) router.replace(redirectTo)
  }, [redirectTo, router])

  if (decision.kind === 'render') return <>{children}</>
  if (decision.kind === 'error') return <AccountUnavailable />
  if (decision.kind === 'unavailable') {
    return <StoreUnavailable reason={decision.reason} settings={settings} signedIn={access !== 'unauthenticated'} />
  }
  return <div className="min-h-screen bg-background" aria-busy="true" />
}

const UNAVAILABLE_COPY: Record<UnavailableReason, { title: string; body: string }> = {
  maintenance: {
    title: 'We’ll be right back',
    body: 'The store is undergoing scheduled maintenance. Please check back shortly.',
  },
  'retail-closed': {
    title: 'The retail store is unavailable',
    body: 'Online retail shopping is paused at the moment. Please contact us to place an order.',
  },
  'wholesale-closed': {
    title: 'The wholesale store is unavailable',
    body: 'Online wholesale ordering is paused at the moment. Please contact us to place an order.',
  },
}

/** Maintenance mode, or a storefront switched off in /admin/settings. */
function StoreUnavailable({
  reason, settings, signedIn,
}: {
  reason: UnavailableReason
  settings: StoreSettings
  signedIn: boolean
}) {
  const { signOut } = useCustomerAuth()
  const copy = UNAVAILABLE_COPY[reason]
  const contacts = [
    settings.contact_phone && { icon: Phone, label: settings.contact_phone, href: `tel:${settings.contact_phone.replace(/[^\d+]/g, '')}` },
    settings.whatsapp_number && { icon: MessageCircle, label: `WhatsApp ${settings.whatsapp_number}`, href: `https://wa.me/${settings.whatsapp_number.replace(/\D/g, '')}` },
    settings.email && { icon: Mail, label: settings.email, href: `mailto:${settings.email}` },
  ].filter((c): c is { icon: typeof Phone; label: string; href: string } => Boolean(c))

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-5">
      <div className="w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 text-center shadow-card">
        <span className="mx-auto mb-4 flex h-13 w-13 items-center justify-center rounded-full border border-mint-deep bg-well-strong text-primary">
          <Wrench size={22} strokeWidth={1.9} />
        </span>
        <p className="mb-1 text-[11px] font-bold uppercase tracking-[0.16em] text-primary">{settings.store_name}</p>
        <h1 className="mb-1.5 text-lg font-bold tracking-tight">{copy.title}</h1>
        <p className="text-[13px] leading-relaxed text-muted-foreground">{copy.body}</p>

        {(contacts.length > 0 || settings.opening_hours) && (
          <div className="mt-5 space-y-2 rounded-2xl border border-mint/70 dark:border-border bg-card p-3.5 text-left">
            {contacts.map(({ icon: Icon, label, href }) => (
              <a key={href} href={href} className="flex items-center gap-2.5 text-[13px] font-medium text-foreground hover:text-primary">
                <Icon size={15} className="shrink-0 text-primary" />
                <span className="truncate">{label}</span>
              </a>
            ))}
            {settings.opening_hours && (
              <p className="flex items-start gap-2.5 text-[12.5px] text-muted-foreground">
                <Clock size={15} className="mt-0.5 shrink-0 text-primary" />
                <span className="whitespace-pre-line">{settings.opening_hours}</span>
              </p>
            )}
          </div>
        )}

        {signedIn && reason !== 'maintenance' && (
          <button
            type="button"
            onClick={() => void signOut()}
            className="focus-ring mt-4 inline-flex h-11 items-center justify-center gap-2 rounded-full px-4 text-[13.5px] font-semibold text-red-500"
          >
            <LogOut size={16} />
            Sign out
          </button>
        )}

        {/* Maintenance closes every store screen, so this is how an owner on the
            APK reaches the setting that reopens them. */}
        {reason === 'maintenance' && (
          <button
            type="button"
            onClick={openAdminLogin}
            className="focus-ring mt-4 inline-flex h-11 items-center justify-center rounded-full px-4 text-[12px] font-medium text-muted-foreground hover:text-foreground"
          >
            Apple Expert personnel: Admin Login
          </button>
        )}
      </div>
    </div>
  )
}

/** Signed in, but the account's type could not be read — so nothing is shown. */
function AccountUnavailable() {
  const { refresh, signOut } = useCustomerAuth()
  const [retrying, setRetrying] = useState(false)

  async function retry() {
    setRetrying(true)
    try { await refresh() } finally { setRetrying(false) }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-5">
      <div className="w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 text-center shadow-card">
        <span className="mx-auto mb-4 flex h-13 w-13 items-center justify-center rounded-full border border-amber-500/30 bg-amber-500/10 text-amber-600 dark:text-amber-400">
          <AlertCircle size={23} strokeWidth={1.9} />
        </span>
        <h1 className="mb-1.5 text-lg font-bold tracking-tight">We could not load your account</h1>
        <p className="mb-5 text-[13px] leading-relaxed text-muted-foreground">
          You are still signed in. Check your connection and try again.
        </p>
        <div className="flex flex-col gap-2.5">
          <button
            type="button"
            onClick={() => void retry()}
            disabled={retrying}
            className="focus-ring flex h-12 items-center justify-center gap-2 rounded-full bg-gradient-cta text-[14px] font-semibold text-white shadow-glow disabled:opacity-70"
          >
            {retrying
              ? <LoaderCircle size={17} className="animate-spin motion-reduce:animate-none" />
              : <RotateCw size={16} />}
            Try again
          </button>
          <button
            type="button"
            onClick={() => void signOut()}
            className="focus-ring flex h-11 items-center justify-center gap-2 rounded-full text-[13.5px] font-semibold text-red-500"
          >
            <LogOut size={16} />
            Sign out
          </button>
        </div>
      </div>
    </div>
  )
}
