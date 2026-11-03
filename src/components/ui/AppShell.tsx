"use client"

import { usePathname } from 'next/navigation'
import { BottomNavigation } from './BottomNavigation'
import { AtmosphericBackground } from './AtmosphericBackground'
import { GuestModeBanner } from './GuestModeBanner'

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  // Full-bleed entry screens: onboarding and the experience chooser both come
  // before the customer is "in" the store, so neither gets the bottom nav or
  // the space reserved for it.
  const isEntryScreen =
    (pathname?.startsWith('/onboarding') ?? false) || (pathname?.startsWith('/welcome') ?? false)
  // Onboarding paints its gradient behind the status bar and insets its own top
  // bar, so the shell must not add the safe area a second time.
  const insetsOwnTop = pathname?.startsWith('/onboarding') ?? false

  return (
    <div
      className="flex flex-col min-h-screen bg-background w-full max-w-[480px] mx-auto sm:border-x sm:border-border sm:shadow-float sm:my-0 relative overflow-hidden"
      style={{
        paddingTop: insetsOwnTop ? undefined : 'var(--safe-top)',
        paddingBottom: isEntryScreen ? undefined : 'var(--nav-safe-pad)',
      }}
    >
      {/* Keeps the status bar readable once the page scrolls beneath it. Zero
          height where there is no inset. Under z-50 so modal backdrops dim it. */}
      {!insetsOwnTop && (
        <div
          aria-hidden
          className="fixed inset-x-0 top-0 z-[45] bg-glass"
          style={{ height: 'var(--safe-top)' }}
        />
      )}
      {/* Light mode is a pure white canvas — green is an accent, never a page
          wash. The atmospheric orbs stay in dark mode, where they give the dark
          theme its depth. */}
      <AtmosphericBackground variant="ambient" className="hidden dark:block" />
      {/* Renders only while a Guest Test Mode session is active, which is only
          possible in a build made with NEXT_PUBLIC_ENABLE_GUEST_MODE=true. */}
      <GuestModeBanner />
      <main className="relative flex-1 w-full h-full overflow-x-hidden">
        {children}
      </main>
      {!isEntryScreen && <BottomNavigation />}
    </div>
  )
}
