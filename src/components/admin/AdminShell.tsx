"use client"

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Menu, X, LogOut, Sun, Moon, ShieldCheck, ChevronDown, Store } from 'lucide-react'
import { cn } from '@/lib/utils'
import { useTheme } from '@/context/ThemeContext'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { ROLE_LABEL } from '@/lib/admin/roles'
import { ADMIN_NAV, isAdminNavActive, isNavGroup, type AdminNavGroup } from './adminNav'

function NavGroup({ group, pathname, onNavigate }: {
  group: AdminNavGroup
  pathname: string
  onNavigate?: () => void
}) {
  const hasActive = group.children.some((c) => isAdminNavActive(pathname, c.href))
  const [open, setOpen] = useState(hasActive)
  const expanded = open || hasActive
  const Icon = group.icon

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={expanded}
        className={cn(
          'focus-ring group flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 min-h-[44px] text-left transition-colors duration-200 border border-transparent',
          hasActive ? 'text-foreground font-semibold' : 'text-muted-foreground hover:bg-primary-soft/60 hover:text-foreground',
        )}
      >
        <span className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-xl transition-colors',
          hasActive ? 'bg-card text-primary' : 'bg-muted text-muted-foreground group-hover:text-primary')}>
          <Icon size={17} strokeWidth={2} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-sm leading-tight truncate">{group.label}</span>
          <span className="block text-[11px] leading-tight text-muted-foreground/75 truncate lg:hidden">{group.hint}</span>
        </span>
        <ChevronDown size={16} className={cn('shrink-0 transition-transform', expanded && 'rotate-180')} />
      </button>
      {expanded && (
        <div className="ml-[26px] mt-1 flex flex-col gap-0.5 border-l border-mint-deep/70 dark:border-border pl-3">
          {group.children.map(({ href, label }) => {
            const active = isAdminNavActive(pathname, href)
            return (
              <Link key={href} href={href} onClick={onNavigate} aria-current={active ? 'page' : undefined}
                className={cn(
                  'focus-ring rounded-xl px-3 py-2 min-h-[38px] flex items-center text-[13px] transition-colors',
                  active ? 'bg-primary-soft text-primary font-semibold' : 'text-muted-foreground hover:bg-primary-soft/60 hover:text-foreground',
                )}>
                {label}
              </Link>
            )
          })}
        </div>
      )}
    </div>
  )
}

function SidebarNav({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname() ?? ''

  return (
    <nav className="flex flex-col gap-1" aria-label="Admin sections">
      {ADMIN_NAV.map((entry) => {
        if (isNavGroup(entry)) {
          return <NavGroup key={entry.group} group={entry} pathname={pathname} onNavigate={onNavigate} />
        }
        const { href, label, icon: Icon, hint } = entry
        const active = isAdminNavActive(pathname, href)
        return (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            aria-current={active ? 'page' : undefined}
            className={cn(
              'focus-ring group flex items-center gap-3 rounded-2xl px-3 py-2.5 min-h-[44px] transition-colors duration-200',
              active
                ? 'bg-primary-soft text-primary border border-mint-deep font-semibold'
                : 'text-muted-foreground border border-transparent hover:bg-primary-soft/60 hover:text-foreground',
            )}
          >
            <span
              className={cn(
                'flex h-8 w-8 shrink-0 items-center justify-center rounded-xl transition-colors',
                active ? 'bg-card text-primary' : 'bg-muted text-muted-foreground group-hover:text-primary',
              )}
            >
              <Icon size={17} strokeWidth={2} />
            </span>
            <span className="min-w-0">
              <span className="block text-sm leading-tight truncate">{label}</span>
              <span className="block text-[11px] leading-tight text-muted-foreground/75 truncate lg:hidden">
                {hint}
              </span>
            </span>
          </Link>
        )
      })}
    </nav>
  )
}

function BrandMark() {
  return (
    <div className="flex items-center gap-2.5 min-w-0">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-cta text-white shadow-glow">
        <ShieldCheck size={18} strokeWidth={2.2} />
      </span>
      <span className="min-w-0">
        <span className="block text-[15px] font-bold tracking-tight text-foreground leading-tight truncate">
          Apple Expert
        </span>
        <span className="block text-[11px] font-medium uppercase tracking-[0.14em] text-primary leading-tight">
          Admin
        </span>
      </span>
    </div>
  )
}

/** The installed app version (next.config.ts env), so staff can confirm their APK. */
function AppVersion() {
  return (
    <p className="mt-1 text-[11px] font-medium tabular-nums text-muted-foreground/80">
      Apple Expert admin v{process.env.APP_VERSION}
    </p>
  )
}

export function AdminShell({ children }: { children: React.ReactNode }) {
  const [drawerOpen, setDrawerOpen] = useState(false)
  const { theme, toggleTheme } = useTheme()
  const { email, role, signOut } = useAdminAuth()

  // The drawer is closed by every link's onNavigate, the close button and the
  // overlay, so no route-change effect is needed.

  // Escape closes the drawer.
  useEffect(() => {
    if (!drawerOpen) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setDrawerOpen(false) }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [drawerOpen])

  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* ---------- Desktop sidebar ---------- */}
      <aside className="hidden lg:flex fixed inset-y-0 left-0 z-30 w-[260px] flex-col border-r border-mint/80 dark:border-border bg-surface">
        <div className="px-5 py-5 border-b border-mint/70 dark:border-border">
          <BrandMark />
        </div>
        <div className="flex-1 overflow-y-auto px-3 py-4">
          <SidebarNav />
        </div>
        <div className="px-5 py-4 border-t border-mint/70 dark:border-border">
          <p className="text-[11px] text-muted-foreground leading-relaxed">
            Access is enforced by the database, not this interface.
          </p>
          <AppVersion />
        </div>
      </aside>

      {/* ---------- Mobile drawer ---------- */}
      {drawerOpen && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <button
            type="button"
            aria-label="Close navigation"
            onClick={() => setDrawerOpen(false)}
            className="absolute inset-0 bg-black/45 backdrop-blur-[2px]"
          />
          <div className="relative w-[272px] max-w-[82vw] h-full bg-surface border-r border-mint/80 dark:border-border shadow-float flex flex-col">
            <div className="flex items-center justify-between px-4 py-4 border-b border-mint/70 dark:border-border">
              <BrandMark />
              <button
                type="button"
                onClick={() => setDrawerOpen(false)}
                aria-label="Close navigation"
                className="focus-ring flex h-9 w-9 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition"
              >
                <X size={18} />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-3 py-4">
              <SidebarNav onNavigate={() => setDrawerOpen(false)} />
            </div>
            <div className="px-5 py-3 border-t border-mint/70 dark:border-border">
              <AppVersion />
            </div>
          </div>
        </div>
      )}

      {/* ---------- Main column ---------- */}
      <div className="lg:pl-[260px] flex min-h-screen flex-col">
        <header className="sticky top-0 z-20 border-b border-mint/80 dark:border-border bg-glass backdrop-blur-xl">
          <div className="flex items-center gap-3 px-4 sm:px-6 h-16">
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              aria-label="Open navigation"
              className="focus-ring lg:hidden flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-mint-deep bg-card text-primary active:scale-95 transition"
            >
              <Menu size={18} />
            </button>

            <div className="lg:hidden min-w-0"><BrandMark /></div>

            <div className="ml-auto flex items-center gap-2">
              <Link
                href="/"
                aria-label="Back to store"
                title="Customer Store"
                className="focus-ring flex items-center gap-1.5 h-10 px-3 rounded-xl border border-mint-deep bg-card text-xs font-semibold text-primary hover:bg-primary-soft active:scale-95 transition"
              >
                <Store size={15} />
                <span>Store</span>
              </Link>

              <button
                type="button"
                onClick={toggleTheme}
                aria-label="Toggle dark mode"
                aria-pressed={theme === 'dark'}
                className="focus-ring flex h-10 w-10 items-center justify-center rounded-xl border border-mint-deep bg-card text-primary active:scale-95 transition"
              >
                {theme === 'dark' ? <Moon size={17} /> : <Sun size={17} />}
              </button>

              {/* Current administrator */}
              <div className="hidden sm:flex flex-col items-end min-w-0 max-w-[220px] px-1">
                <span className="text-[13px] font-semibold text-foreground leading-tight truncate max-w-full">
                  {email ?? 'Administrator'}
                </span>
                {role && (
                  <span className="text-[11px] font-medium text-primary leading-tight">
                    {ROLE_LABEL[role]}
                  </span>
                )}
              </div>

              <button
                type="button"
                onClick={() => void signOut()}
                className="focus-ring flex items-center gap-1.5 h-10 px-3 rounded-xl border border-mint-deep bg-card text-sm font-semibold text-foreground hover:bg-surface-strong active:scale-95 transition"
              >
                <LogOut size={16} className="text-muted-foreground" />
                <span className="hidden sm:inline">Sign out</span>
              </button>
            </div>
          </div>
        </header>

        <main className="flex-1 px-4 sm:px-6 py-6 sm:py-8">
          <div className="mx-auto w-full max-w-6xl">{children}</div>
        </main>
      </div>
    </div>
  )
}
