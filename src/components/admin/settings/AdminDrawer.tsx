"use client"

import { useEffect } from 'react'
import { X } from 'lucide-react'

/**
 * Right-hand editor drawer — the same markup the pricing and product editors
 * use, shared here by the Settings screen's banner editor and product picker.
 */
export function AdminDrawer({
  title, subtitle, onClose, children, footer,
}: {
  title: string
  subtitle?: string
  onClose: () => void
  children: React.ReactNode
  footer?: React.ReactNode
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label={title}
        className="relative safe-y flex h-full w-full max-w-lg flex-col bg-background border-l border-mint/80 dark:border-border shadow-float">
        <header className="flex items-start gap-3 border-b border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">{title}</h2>
            {subtitle && <p className="truncate text-[12px] text-muted-foreground">{subtitle}</p>}
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">{children}</div>

        {footer && (
          <footer className="flex items-center justify-end gap-2 border-t border-mint/80 dark:border-border px-5 py-3.5 bg-glass backdrop-blur-xl">
            {footer}
          </footer>
        )}
      </div>
    </div>
  )
}

/** One-line result of a save: nothing, in progress, done, or the admin error. */
export type SaveState =
  | { kind: 'idle' }
  | { kind: 'saving' }
  | { kind: 'saved'; message: string }
  | { kind: 'error'; message: string }

export function SaveFeedback({ state }: { state: SaveState }) {
  if (state.kind === 'saved') {
    return <p role="status" className="text-[12.5px] font-medium text-primary">{state.message}</p>
  }
  if (state.kind === 'error') {
    return <p role="alert" className="text-[12.5px] font-medium text-red-500 break-words">{state.message}</p>
  }
  return null
}

/** Settings card chrome: title, one-line description, optional header action. */
export function SettingsCard({
  title, description, action, children,
}: {
  title: string
  description: string
  action?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <section className="bg-surface border border-mint/80 dark:border-border rounded-[22px] shadow-card p-5">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h2 className="text-[16px] font-bold tracking-tight text-foreground">{title}</h2>
          <p className="mt-0.5 text-[12.5px] text-muted-foreground leading-relaxed">{description}</p>
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}
