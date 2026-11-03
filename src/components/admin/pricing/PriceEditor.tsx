"use client"

import { useEffect, useState } from 'react'
import { X, LoaderCircle, Check, AlertCircle, History, Lock, Info } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { formatPrice } from '@/utils/formatPrice'
import {
  loadPriceHistory, setPrice, parseRupeeInput, centsToRupees,
  TIER_LABEL, type PricingTarget, type PriceRow, type TierCode,
} from '@/lib/admin/pricing'

type Save = { kind: 'idle' } | { kind: 'saving' } | { kind: 'saved'; message: string } | { kind: 'error'; message: string }

const PENDING_PART = /^part-(display|battery)-/

/**
 * Text typed into one price field, tagged with the stored value it was typed
 * against. `null` means "nothing typed since the last refresh".
 */
type Draft = { against: number | null; text: string } | null

/**
 * What one price input shows: the draft while it still refers to the price
 * currently in the database, otherwise that price itself. This is the whole
 * synchronisation rule — a saved price arrives as a new `cents`, which retires
 * the draft without any state to reset.
 */
function draftText(draft: Draft, cents: number | null): string {
  if (draft && draft.against === cents) return draft.text
  return cents === null ? '' : String(centsToRupees(cents))
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

export function PriceEditor({
  target, canEdit, onClose, onSaved,
}: {
  target: PricingTarget
  canEdit: boolean
  onClose: () => void
  onSaved: () => void
}) {
  // Each field is a DERIVED value, not a copy of the price taken when the drawer
  // opened. A draft is tagged with the cents value it was typed against, so the
  // moment the page hands this drawer a refreshed row the draft is stale by
  // definition and the input falls back to the refreshed price — no closing and
  // reopening, no page reload.
  //
  // The two tiers are tagged separately, which is what keeps them independent:
  // saving retail moves `target.retailCents` only, so the wholesale field's
  // draft is still current and is left untouched, and vice versa.
  const [retailDraft, setRetailDraft] = useState<Draft>(null)
  const [vipDraft, setVipDraft] = useState<Draft>(null)

  const [save, setSave] = useState<Save>({ kind: 'idle' })
  const [history, setHistory] = useState<PriceRow[] | null>(null)
  const [historyError, setHistoryError] = useState<string | null>(null)

  const retail = draftText(retailDraft, target.retailCents)
  const vip = draftText(vipDraft, target.vipCents)

  useEffect(() => {
    let cancelled = false
    loadPriceHistory(target.productId, target.variantId)
      .then((rows) => { if (!cancelled) setHistory(rows) })
      .catch((err) => { if (!cancelled) setHistoryError(err instanceof Error ? err.message : 'Could not load history.') })
    return () => { cancelled = true }
  }, [target.productId, target.variantId])

  const isPendingPart = PENDING_PART.test(target.productId)

  async function handleSave() {
    setSave({ kind: 'saving' })
    const changes: { tier: TierCode; rupees: number }[] = []

    // Retail: only sent when the admin actually changed it.
    if (retail.trim() !== '') {
      const parsed = parseRupeeInput(retail)
      if (!parsed.ok) { setSave({ kind: 'error', message: `Retail price — ${parsed.reason}` }); return }
      if (target.retailCents === null || centsToRupees(target.retailCents) !== parsed.rupees) {
        changes.push({ tier: 'retail', rupees: parsed.rupees })
      }
    }

    // VIP: a blank field never creates a row. The catalog intentionally holds
    // zero wholesale_vip rows until an owner types a real one.
    if (vip.trim() !== '') {
      const parsed = parseRupeeInput(vip)
      if (!parsed.ok) { setSave({ kind: 'error', message: `Wholesale VIP price — ${parsed.reason}` }); return }
      if (target.vipCents === null || centsToRupees(target.vipCents) !== parsed.rupees) {
        changes.push({ tier: 'wholesale_vip', rupees: parsed.rupees })
      }
    }

    if (changes.length === 0) { setSave({ kind: 'error', message: 'Nothing changed.' }); return }

    try {
      for (const change of changes) {
        await setPrice({
          productId: target.productId,
          variantId: target.variantId,
          tierCode: change.tier,
          rupees: change.rupees,
        })
      }
      setHistory(await loadPriceHistory(target.productId, target.variantId))
      setSave({
        kind: 'saved',
        message: changes.map((c) => `${TIER_LABEL[c.tier]} set to ${formatPrice(c.rupees)}`).join(' · '),
      })
      onSaved()
    } catch (err) {
      setSave({ kind: 'error', message: err instanceof Error ? err.message : 'The database refused the change.' })
    }
  }

  const disabled = !canEdit || save.kind === 'saving'
  const inputClass =
    'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm tabular-nums text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 transition-colors disabled:opacity-60'

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label="Edit price"
        className="relative safe-y flex h-full w-full max-w-lg flex-col bg-background border-l border-mint/80 dark:border-border shadow-float">

        <header className="flex items-start gap-3 border-b border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">{target.productName}</h2>
            <p className="truncate text-[12px] text-muted-foreground">
              {target.variantLabel
                ? <>Variant <span className="font-mono">{target.variantLegacyKey}</span> · {target.variantLabel}</>
                : 'Product-level price'}
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
          {!canEdit && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-amber-500/25 bg-amber-500/10 px-4 py-3">
              <Lock size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">
                Read-only. The database refuses price changes for your role.
              </p>
            </div>
          )}

          {isPendingPart && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-4 py-3">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">
                This replacement part has <strong>no confirmed business price</strong>. Enter the real
                rupee amount only — never an estimate or a converted figure. Nothing is pre-filled.
              </p>
            </div>
          )}

          <section className="bg-surface border border-mint/80 dark:border-border rounded-[22px] shadow-card p-5">
            <h3 className="text-[15px] font-bold tracking-tight text-foreground mb-1">Prices</h3>
            <p className="mb-4 text-[12.5px] text-muted-foreground leading-relaxed">
              Whole rupees only. Saving retires the current price and records a new one — history is never overwritten.
            </p>

            <div className="grid gap-4">
              <label htmlFor="price-retail" className="block">
                <span className="mb-1.5 flex items-baseline justify-between gap-2">
                  <span className="text-[13px] font-semibold text-foreground">Retail</span>
                  <span className="text-[11px] text-muted-foreground">
                    {target.retailCents === null ? 'not set' : `now ${formatPrice(centsToRupees(target.retailCents))}`}
                  </span>
                </span>
                <div className="relative">
                  <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-[13px] font-semibold text-muted-foreground">Rs.</span>
                  <input id="price-retail" type="text" inputMode="numeric" className={`${inputClass} pl-11`}
                    value={retail} disabled={disabled} placeholder="490000"
                    onChange={(e) => { setRetailDraft({ against: target.retailCents, text: e.target.value }); setSave({ kind: 'idle' }) }} />
                </div>
              </label>

              <label htmlFor="price-vip" className="block">
                <span className="mb-1.5 flex items-baseline justify-between gap-2">
                  <span className="text-[13px] font-semibold text-foreground">Wholesale VIP</span>
                  <span className="text-[11px] text-muted-foreground">
                    {target.vipCents === null ? 'not set — leave blank to keep it unset' : `now ${formatPrice(centsToRupees(target.vipCents))}`}
                  </span>
                </span>
                <div className="relative">
                  <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-[13px] font-semibold text-muted-foreground">Rs.</span>
                  <input id="price-vip" type="text" inputMode="numeric" className={`${inputClass} pl-11`}
                    value={vip} disabled={disabled} placeholder="Leave blank"
                    onChange={(e) => { setVipDraft({ against: target.vipCents, text: e.target.value }); setSave({ kind: 'idle' }) }} />
                </div>
              </label>
            </div>

            <div className="mt-4 flex items-start gap-2 rounded-xl border border-mint/70 dark:border-border bg-muted px-3 py-2.5">
              <Info size={14} className="mt-0.5 shrink-0 text-muted-foreground" />
              <p className="text-[12px] leading-snug text-muted-foreground">
                VIP customers fall back to the retail price wherever no VIP price exists, so a blank
                field is a valid, safe state.
              </p>
            </div>
          </section>

          <section className="bg-surface border border-mint/80 dark:border-border rounded-[22px] shadow-card p-5">
            <h3 className="mb-3 flex items-center gap-2 text-[15px] font-bold tracking-tight text-foreground">
              <History size={16} className="text-muted-foreground" /> Price history
            </h3>

            {historyError && <p className="text-[13px] text-red-500">{historyError}</p>}
            {!history && !historyError && (
              <p className="flex items-center gap-2 text-[13px] text-muted-foreground">
                <LoaderCircle size={14} className="animate-spin motion-reduce:animate-none" /> Loading…
              </p>
            )}
            {history && history.length === 0 && (
              <p className="text-[13px] text-muted-foreground">No price has been recorded yet.</p>
            )}

            {history && history.length > 0 && (
              <ol className="space-y-2">
                {history.map((row) => {
                  const live = row.ends_at === null
                  return (
                    <li key={row.id}
                      className={`rounded-xl border px-3 py-2.5 ${live ? 'border-mint-deep bg-primary-soft' : 'border-mint/60 dark:border-border bg-card'}`}>
                      <div className="flex items-baseline justify-between gap-2">
                        <span className={`text-[14px] font-bold tabular-nums ${live ? 'text-primary' : 'text-foreground'}`}>
                          {formatPrice(centsToRupees(row.price_cents))}
                        </span>
                        <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider ${
                          row.tier_code === 'wholesale_vip'
                            ? 'bg-muted text-muted-foreground'
                            : 'bg-card text-muted-foreground border border-mint/60 dark:border-border'}`}>
                          {TIER_LABEL[row.tier_code as TierCode] ?? row.tier_code}
                        </span>
                      </div>
                      <p className="mt-1 text-[11px] text-muted-foreground">
                        {live ? 'Current' : 'Superseded'} · from {formatDate(row.starts_at)}
                        {row.ends_at && <> · until {formatDate(row.ends_at)}</>}
                      </p>
                    </li>
                  )
                })}
              </ol>
            )}
            <p className="mt-3 text-[11px] text-muted-foreground">Audit records — read-only.</p>
          </section>
        </div>

        <footer className="border-t border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          {save.kind === 'error' && (
            <div className="mb-3 flex items-start gap-2 rounded-xl border border-red-500/25 bg-red-500/8 px-3 py-2">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[12.5px] text-foreground">{save.message}</p>
            </div>
          )}
          {save.kind === 'saved' && (
            <div className="mb-3 flex items-start gap-2 rounded-xl border border-mint-deep bg-primary-soft px-3 py-2">
              <Check size={15} className="mt-0.5 shrink-0 text-primary" />
              <p className="text-[12.5px] font-medium text-primary">{save.message}</p>
            </div>
          )}
          <div className="flex items-center gap-2.5">
            <Button variant="ghost" onClick={onClose} disabled={save.kind === 'saving'}>Cancel</Button>
            <Button className="flex-1" onClick={() => void handleSave()} disabled={disabled}>
              {save.kind === 'saving'
                ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</>
                : 'Save price'}
            </Button>
          </div>
        </footer>
      </div>
    </div>
  )
}
