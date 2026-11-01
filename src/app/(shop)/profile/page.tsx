"use client"

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Header } from '@/components/ui/Header'
import { Button } from '@/components/ui/Button'
import { ProfileIdentityCard } from '@/components/account/ProfileIdentityCard'
import { useTheme } from '@/context/ThemeContext'
import { useWishlist } from '@/context/WishlistContext'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { useGuestMode, endGuestSession } from '@/lib/auth/guestMode'
import { WHOLESALE_REQUEST_PATH } from '@/lib/customer/access'
import { clearExperience } from '@/utils/experience'
import { openAdminLogin } from '@/lib/admin/entry'
import { listOwnRequests, openRequest, latestDecision, type RequestStatus } from '@/lib/customer/wholesale'
import {
  Moon, Sun, ChevronRight, Package, CreditCard, Settings, HelpCircle, LogOut, Heart,
  LogIn, Store, Repeat, FlaskConical, Briefcase,
} from 'lucide-react'

export default function ProfilePage() {
  const router = useRouter()
  const { theme, toggleTheme } = useTheme()
  const { wishlist } = useWishlist()
  // Identity comes from the Supabase session and the customer's own profile row
  // under "profiles read own" — never from a constant in this file.
  const {
    status, userId, email, phone, profile, customerType, access, vipExpired, signOut, refresh,
  } = useCustomerAuth()
  /** A testing label, deliberately kept out of everything that decides pricing. */
  const guest = useGuestMode()

  // The retail account's wholesale application status, for the menu entry
  // below. Display only — the portal itself opens solely for wholesale_vip.
  const [applicationStatus, setApplicationStatus] = useState<RequestStatus | null>(null)
  useEffect(() => {
    if (access !== 'retail') return
    let cancelled = false
    listOwnRequests()
      .then((rows) => {
        if (cancelled) return
        const current = openRequest(rows) ?? latestDecision(rows)
        setApplicationStatus((current?.status as RequestStatus | undefined) ?? null)
      })
      .catch(() => { /* the entry falls back to "Apply for business pricing" */ })
    return () => { cancelled = true }
  }, [access])

  const APPLICATION_ENTRY: Partial<Record<RequestStatus, string>> = {
    draft: 'Draft saved — finish your application',
    pending: 'Application pending',
    assistance_requested: 'Assistance requested',
    under_review: 'Application under review',
    rejected: 'Changes required',
  }

  /** 'error' is still a session — only the profile read failed. */
  const hasSession = status === 'signed-in' || status === 'error'

  /** Returns to the entry screen so the customer can pick the other experience. */
  function switchExperience() {
    clearExperience()
    router.push('/welcome')
  }

  /** Leaves the test identity. There is no session to end — only a local flag. */
  function exitGuestMode() {
    endGuestSession()
    clearExperience()
    router.push('/welcome')
  }

  const CHIP = 'bg-well-strong border border-mint-deep text-primary'

  const menuItems = [
    { icon: Package, label: 'My Orders', description: 'View and track your orders', chip: CHIP, href: '/orders' },
    { icon: Heart, label: 'Wishlist', description: `${wishlist.length} saved item${wishlist.length === 1 ? '' : 's'}`, chip: CHIP, href: '/wishlist' },
    { icon: CreditCard, label: 'Payment Methods', description: 'Manage your saved cards', chip: CHIP },
    { icon: Settings, label: 'Account Settings', description: 'Personal details and security', chip: CHIP },
    { icon: HelpCircle, label: 'Help & Support', description: 'FAQ and contact information', chip: CHIP },
    // Retail accounts are never linked into the Wholesale storefront — only to
    // the request page in their own area. Decided by the database tier.
    access === 'wholesale_vip'
      ? { icon: Store, label: 'Wholesale Portal', description: 'Wholesale pricing is active', chip: CHIP, href: '/wholesale' }
      : {
          icon: Store, label: 'Wholesale Application', chip: CHIP, href: WHOLESALE_REQUEST_PATH,
          description: (applicationStatus && APPLICATION_ENTRY[applicationStatus]) || 'Apply for business pricing',
        },
  ]

  return (
    <div className="flex flex-col min-h-screen pb-8">
      <Header />

      <main className="px-4 py-6">
        {/* Profile Header */}
        {status === 'loading' || hasSession ? (
          // Keyed by account so an open edit form never carries over to a
          // different customer after an account switch.
          <ProfileIdentityCard
            key={userId ?? 'loading'}
            status={status}
            userId={userId}
            profile={profile}
            email={email}
            phone={phone}
            customerType={customerType}
            vipExpired={vipExpired}
            onReload={refresh}
          />
        ) : guest ? (
          /* Guest Test Mode. Rendered as a TEST artefact rather than an account:
             no avatar, no tier chip, no name — because there is no customer
             here, only a flag in this browser session. */
          <div className="mb-6 rounded-[26px] border-2 border-dashed border-amber-500/45 bg-amber-500/8 p-5 text-center">
            <span className="mx-auto mb-3.5 flex h-13 w-13 items-center justify-center rounded-full border border-amber-500/40 bg-amber-400/20 text-amber-700 dark:text-amber-400">
              <FlaskConical size={23} strokeWidth={1.9} />
            </span>
            <p className="mb-1 text-[11px] font-bold uppercase tracking-[0.14em] text-amber-700 dark:text-amber-400">
              Test mode — guest account
            </p>
            <h1 className="mb-1.5 text-lg font-bold tracking-tight">
              {guest === 'wholesale' ? 'Wholesale demo' : 'Retail demo'}
            </h1>
            <p className="mx-auto mb-4 max-w-xs text-[13px] leading-relaxed text-muted-foreground">
              You are not signed in. Orders, saved addresses and account pricing need a real
              verified account — this identity exists only to review the screens.
            </p>
            <div className="flex flex-col gap-2.5">
              <Link href="/account/sign-in"><Button fullWidth>Sign in with your phone</Button></Link>
              <Button fullWidth variant="secondary" onClick={exitGuestMode}>Exit test mode</Button>
            </div>
          </div>
        ) : (
          <div className="mb-6 bg-surface border border-mint/80 dark:border-border rounded-[26px] p-5 shadow-card text-center">
            <span className="mx-auto mb-3.5 flex h-13 w-13 items-center justify-center rounded-full bg-well-strong border border-mint-deep text-primary">
              <LogIn size={23} strokeWidth={1.8} />
            </span>
            <h1 className="text-lg font-bold tracking-tight mb-1.5">You are not signed in</h1>
            <p className="mx-auto mb-4 max-w-xs text-[13px] leading-relaxed text-muted-foreground">
              Sign in with your phone number to see your orders and the pricing set for your
              account.
            </p>
            <Link href="/account/sign-in"><Button fullWidth>Sign in with your phone</Button></Link>
          </div>
        )}

        {/* Theme Toggle */}
        <div className="bg-surface rounded-[26px] border border-mint/80 dark:border-border p-4 mb-4 flex items-center justify-between shadow-card">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-well-strong border border-mint-deep flex items-center justify-center text-primary">
              {theme === 'dark' ? <Moon size={19} /> : <Sun size={19} />}
            </div>
            <div>
              <div className="font-semibold text-sm">Appearance</div>
              <div className="text-xs text-muted-foreground">
                {theme === 'dark' ? 'Dark Mode' : 'Light Mode'}
              </div>
            </div>
          </div>
          <button
            onClick={toggleTheme}
            aria-label="Toggle dark mode"
            aria-pressed={theme === 'dark'}
            className={`w-13 h-7 rounded-full transition-all duration-300 relative flex items-center px-1 ${theme === 'dark' ? 'bg-gradient-cta shadow-glow' : 'bg-mint-deep'}`}
          >
            <div
              className={`w-5 h-5 bg-white rounded-full shadow-md transform transition-transform duration-300 ${theme === 'dark' ? 'translate-x-6' : 'translate-x-0'}`}
            />
          </button>
        </div>

        {/* Menu Items */}
        <div className="bg-surface rounded-[26px] border border-mint/80 dark:border-border overflow-hidden shadow-card mb-4">
          {menuItems.map((item, index) => {
            const Icon = item.icon
            const rowClassName = `w-full flex items-center justify-between p-4 text-left hover:bg-primary-soft/60 active:bg-primary-soft transition-colors min-h-[44px] ${
              index !== menuItems.length - 1 ? 'border-b border-mint/70 dark:border-border' : ''
            }`
            const content = (
              <>
                <div className="flex items-center gap-4">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 ${item.chip}`}>
                    <Icon size={20} strokeWidth={1.75} />
                  </div>
                  <div>
                    <div className="font-semibold text-sm">{item.label}</div>
                    <div className="text-xs text-muted-foreground">{item.description}</div>
                  </div>
                </div>
                <ChevronRight size={18} className="text-muted-foreground/50 shrink-0" />
              </>
            )

            return item.href ? (
              <Link key={item.label} href={item.href} className={rowClassName}>
                {content}
              </Link>
            ) : (
              <button key={item.label} className={rowClassName}>
                {content}
              </button>
            )
          })}
        </div>

        {/* Switch experience — clears only the local preference. It has never
            had any bearing on the customer's tier, so nothing about pricing
            changes here. */}
        <button
          onClick={switchExperience}
          className="w-full flex items-center justify-center gap-2 p-4 mb-4 font-semibold text-primary bg-primary-soft border border-mint-deep hover:bg-mint active:scale-[0.98] rounded-[26px] transition-all duration-300 min-h-[44px]"
        >
          <Repeat size={19} />
          Switch shopping experience
        </button>

        {/* Every account sees this and it grants nothing: sign-in, AdminGuard and
            the database decide who gets in. */}
        {hasSession && (
          <button
            onClick={openAdminLogin}
            className="w-full flex items-center justify-between gap-3 px-4 py-3 mb-4 text-left bg-surface border border-mint/80 dark:border-border hover:bg-primary-soft/60 rounded-[20px] transition-colors min-h-[44px]"
          >
            <span className="flex items-center gap-3 min-w-0">
              <Briefcase size={17} strokeWidth={1.75} className="text-muted-foreground shrink-0" />
              <span className="min-w-0">
                <span className="block text-[13px] font-semibold">Business Access</span>
                <span className="block text-[11.5px] text-muted-foreground">Admin Login for Apple Expert personnel</span>
              </span>
            </span>
            <ChevronRight size={16} className="text-muted-foreground/50 shrink-0" />
          </button>
        )}

        {/* Sign out */}
        {hasSession && (
          <button
            onClick={() => void signOut()}
            className="w-full flex items-center justify-center gap-2 p-4 text-red-500 font-semibold bg-red-500/8 border border-red-500/20 hover:bg-red-500/15 active:scale-[0.98] rounded-[26px] transition-all duration-300 min-h-[44px]"
          >
            <LogOut size={20} />
            Sign Out
          </button>
        )}
      </main>
    </div>
  )
}
