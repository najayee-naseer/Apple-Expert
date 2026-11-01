"use client"

import { LoaderCircle, RefreshCw, TriangleAlert } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { centsToRupees } from '@/lib/admin/pricing'
import { priceChangeReason, type PriceChange } from '@/lib/admin/posCart'
import { formatPrice } from '@/utils/formatPrice'

const NOTICE = 'space-y-3 rounded-[22px] border border-amber-500/30 bg-amber-500/8 p-4'

/** Checkout stopped: prices differ from the bill. Nothing was sold. */
export function PriceChangesPanel({ changes, onAccept }: { changes: PriceChange[]; onAccept: () => void }) {
  return (
    <section role="alert" className={NOTICE}>
      <div>
        <h2 className="flex items-center gap-1.5 text-[14px] font-bold text-foreground"><TriangleAlert size={15} /> Prices changed. Nothing was sold.</h2>
        <p className="text-[12.5px] text-muted-foreground">Tell the customer before you continue. A discount approved for the old prices has to be approved again.</p>
      </div>
      <ul className="space-y-2">
        {changes.map((c) => (
          <li key={c.code ?? `${c.product_id}|${c.variant_id ?? ''}`} className="flex flex-wrap items-baseline justify-between gap-x-3 text-[13px]">
            <span className="min-w-0">
              <span className="block font-semibold text-foreground">{[c.product_name, c.variant_name].filter(Boolean).join(' · ')}</span>
              <span className="block text-[11.5px] text-muted-foreground">{priceChangeReason(c)}</span>
            </span>
            <span className="tabular-nums">
              <span className="text-muted-foreground line-through">{formatPrice(centsToRupees(c.previous_cents))}</span>
              {' → '}
              <span className="font-semibold">{c.current_cents === null ? 'No price' : formatPrice(centsToRupees(c.current_cents))}</span>
            </span>
          </li>
        ))}
      </ul>
      <Button fullWidth onClick={onAccept}>Update bill to current prices</Button>
    </section>
  )
}

export type InterruptedStep = 'interrupted' | 'working' | 'not_saved' | 'still_offline'

/**
 * No answer from the server, so nobody knows yet whether the sale was saved. The
 * bill stays frozen. Checking and retrying both use the original request id, so the
 * database can only ever sell it once.
 */
export function InterruptedSalePanel({ step, onCheck, onRetry, onDiscard }: {
  step: InterruptedStep
  onCheck: () => void
  onRetry: () => void
  onDiscard: () => void
}) {
  const working = step === 'working'
  return (
    <section role="alert" className={NOTICE}>
      <div>
        <h2 className="flex items-center gap-1.5 text-[14px] font-bold text-foreground"><TriangleAlert size={15} /> The connection was interrupted</h2>
        {step === 'not_saved' ? (
          <p className="text-[12.5px] text-muted-foreground">
            This sale is not saved yet. Retrying is safe: if the first attempt still arrives, the items are not sold twice.
          </p>
        ) : (
          <p className="text-[12.5px] text-muted-foreground">
            This sale may already have been saved. Do not start it again or take payment twice. Check it first.
          </p>
        )}
        {step === 'still_offline' && <p className="mt-1 text-[12.5px] font-semibold">Still no connection. Nothing has changed. Try again when you are back online.</p>}
      </div>
      <div className="flex flex-wrap gap-2">
        {step === 'not_saved' ? (
          <>
            <Button size="sm" disabled={working} onClick={onRetry}>Retry this sale</Button>
            <Button size="sm" variant="secondary" disabled={working} onClick={onCheck}><RefreshCw size={14} className="mr-1" /> Check again</Button>
            <Button size="sm" variant="ghost" disabled={working} onClick={onDiscard}>Discard this bill</Button>
          </>
        ) : (
          <Button size="sm" disabled={working} onClick={onCheck}>
            {working ? <LoaderCircle size={14} className="mr-1 animate-spin motion-reduce:animate-none" /> : <RefreshCw size={14} className="mr-1" />}
            Check sale
          </Button>
        )}
      </div>
    </section>
  )
}
