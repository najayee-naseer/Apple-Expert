import React from 'react'
import { Button } from './Button'

interface StickyActionBarProps {
  title: string
  price: string
  onAddToCart: () => void
  ctaLabel?: string
  disabled?: boolean
}

/** Floats just above the bottom navigation, sharing its geometry tokens so the
 *  two never overlap each other or the page content. */
export function StickyActionBar({ title, price, onAddToCart, ctaLabel = 'Add to Cart', disabled = false }: StickyActionBarProps) {
  return (
    <div
      className="fixed left-3 right-3 z-40 mx-auto w-auto max-w-[456px]"
      style={{ bottom: 'calc(var(--nav-offset) + 0.5rem)' }}
    >
      {/* Restrained green glow that bleeds softly beyond the bar's edges. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-3 -top-2 bottom-2 -z-10 rounded-[32px] bg-primary-bright/20 blur-xl dark:bg-primary-bright/10"
      />
      <div className="rounded-[26px] border border-primary/25 dark:border-primary/15 bg-purchase shadow-purchase px-3 py-2.5">
        <div className="flex items-center gap-3">
          <div className="flex-1 min-w-0">
            <div className="text-[13px] font-semibold truncate text-foreground">{title}</div>
            <div className="text-xs font-semibold tracking-tight text-[var(--purchase-price)]">{price}</div>
          </div>
          <Button
            className="w-auto px-6 h-11 shrink-0 text-sm bg-gradient-cta-deep hover:bg-gradient-cta-deep-hover shadow-purchase-cta hover:shadow-purchase-cta-hover hover:-translate-y-px active:translate-y-0"
            onClick={onAddToCart}
            disabled={disabled}
          >
            {ctaLabel}
          </Button>
        </div>
      </div>
    </div>
  )
}
