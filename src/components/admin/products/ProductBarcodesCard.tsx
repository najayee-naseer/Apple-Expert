"use client"

import { useCallback, useEffect, useState } from 'react'
import { LoaderCircle, Printer } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { ErrorNote, SELECT_CLASS } from '@/components/admin/inventory/shared'
import {
  issueProductBarcode, listProductBarcodes, productsAllowingSharedBarcode, registerManufacturerBarcode, retireProductBarcode,
  type ProductBarcode,
} from '@/lib/admin/barcodes'
import { buildProductLabelPdf, openPdf, LABEL_LAYOUTS, type LabelLayout } from '@/lib/admin/labels'
import { canReceiveStock, describeUnitError } from '@/lib/admin/units'

const INPUT =
  'focus-ring rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

export interface BarcodeItem {
  /** Null for a product sold without variants. */
  variantId: string | null
  label: string | null
  mode: 'quantity' | 'unit'
}

/**
 * The shared barcodes of a quantity-tracked accessory or part: a shop code issued
 * on request, plus any manufacturer barcodes. Issued per variant when the product
 * has variants. Every rule is enforced by the database; this explains them.
 */
export function ProductBarcodesCard({ productId, productName, items }: { productId: string; productName: string; items: BarcodeItem[] }) {
  const { role } = useAdminAuth()
  const canManage = canReceiveStock(role)
  const [allowed, setAllowed] = useState<boolean | null>(null)
  const [barcodes, setBarcodes] = useState<ProductBarcode[]>([])
  const [unavailable, setUnavailable] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [layout, setLayout] = useState<LabelLayout>('sticker')
  const [copies, setCopies] = useState('1')
  const [manufacturer, setManufacturer] = useState<Record<string, string>>({})
  const [retiring, setRetiring] = useState<{ id: string; note: string } | null>(null)

  const reload = useCallback(async () => {
    const [ids, rows] = await Promise.all([productsAllowingSharedBarcode([productId]), listProductBarcodes([productId])])
    setAllowed(ids.has(productId))
    setBarcodes(rows)
  }, [productId])

  useEffect(() => {
    let cancelled = false
    Promise.all([productsAllowingSharedBarcode([productId]), listProductBarcodes([productId])])
      .then(([ids, rows]) => { if (!cancelled) { setAllowed(ids.has(productId)); setBarcodes(rows) } })
      .catch(() => { if (!cancelled) setUnavailable(true) })
    return () => { cancelled = true }
  }, [productId])

  async function act(work: () => Promise<void>, fallback: string) {
    setBusy(true)
    setError(null)
    try {
      await work()
      await reload()
    } catch (err) {
      setError(describeUnitError(err, fallback))
    } finally {
      setBusy(false)
    }
  }

  async function print(item: BarcodeItem, barcode: string) {
    const n = Number(copies)
    if (!Number.isInteger(n) || n < 1 || n > 500) { setError('Copies must be a whole number from 1 to 500.'); return }
    setBusy(true)
    setError(null)
    try {
      await openPdf(await buildProductLabelPdf([{ barcode, title: productName, subtitle: item.label, copies: n }], layout), `${barcode}-labels.pdf`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the labels.')
    } finally {
      setBusy(false)
    }
  }

  if (unavailable) {
    return <p className="text-[12.5px] text-muted-foreground">Product barcodes become available after the next server update.</p>
  }
  if (allowed === null) return <p className="text-[12.5px] text-muted-foreground">Loading…</p>
  if (!allowed) {
    return <p className="text-[12.5px] text-muted-foreground">Items in this category use individual unit barcodes, printed from the GRN. Shared barcodes are for accessories and parts only.</p>
  }

  return (
    <div className="space-y-3">
      {items.map((item) => {
        const key = item.variantId ?? 'product'
        const mine = barcodes.filter((b) => b.variantId === item.variantId)
        const active = mine.filter((b) => b.status === 'active')
        const shop = active.find((b) => b.source === 'shop')
        const retired = mine.filter((b) => b.status === 'retired')
        return (
          <div key={key} className="space-y-2 rounded-2xl border border-mint/70 dark:border-border p-3">
            {item.label && <p className="text-[13px] font-semibold text-foreground">{item.label}</p>}
            {item.mode === 'unit' ? (
              <p className="text-[12.5px] text-muted-foreground">Tracked individually, so each item has its own barcode from the GRN.</p>
            ) : (
              <>
                {active.length === 0 && <p className="text-[12.5px] text-muted-foreground">No barcode yet.</p>}
                <ul className="space-y-1.5">
                  {active.map((b) => (
                    <li key={b.id} className="flex flex-wrap items-center gap-2 text-[13px]">
                      <span className="font-mono font-semibold">{b.value}</span>
                      <span className="text-[11.5px] text-muted-foreground">{b.source === 'shop' ? 'Shop' : 'Manufacturer'}</span>
                      <span className="ml-auto flex gap-1.5">
                        {b.source === 'shop' && (
                          <Button size="sm" variant="secondary" disabled={busy} onClick={() => void print(item, b.value)}>
                            <Printer size={14} className="mr-1" /> Print
                          </Button>
                        )}
                        {canManage && <Button size="sm" variant="ghost" disabled={busy} onClick={() => setRetiring({ id: b.id, note: '' })}>Retire</Button>}
                      </span>
                      {retiring?.id === b.id && (
                        <div className="w-full space-y-1.5 rounded-xl bg-muted/60 p-2.5">
                          <p className="text-[12px]">{b.value} stops scanning and can never be used again, on any item.</p>
                          <div className="flex gap-2">
                            <input className={cn(INPUT, 'min-w-0 flex-1')} placeholder="Why? (required)" aria-label={`Reason for retiring ${b.value}`}
                              value={retiring.note} disabled={busy} onChange={(e) => setRetiring({ id: b.id, note: e.target.value })} />
                            <Button size="sm" variant="secondary" disabled={busy} onClick={() => setRetiring(null)}>Keep</Button>
                            <Button size="sm" disabled={busy || retiring.note.trim().length < 3}
                              onClick={() => void act(async () => {
                                await retireProductBarcode(b.id, retiring.note)
                                setRetiring(null)
                              }, 'The barcode could not be retired.')}>
                              Retire
                            </Button>
                          </div>
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
                {canManage && (
                  <div className="flex flex-wrap gap-2">
                    {!shop && (
                      <Button size="sm" variant="secondary" disabled={busy}
                        onClick={() => void act(() => issueProductBarcode(productId, item.variantId), 'The barcode could not be issued.')}>
                        Issue shop barcode
                      </Button>
                    )}
                    <input className={cn(INPUT, 'min-w-0 flex-1 font-mono')} inputMode="numeric" placeholder="Manufacturer UPC / EAN"
                      aria-label={`Manufacturer barcode${item.label ? ` for ${item.label}` : ''}`} value={manufacturer[key] ?? ''} disabled={busy}
                      onChange={(e) => setManufacturer((prev) => ({ ...prev, [key]: e.target.value }))} />
                    <Button size="sm" variant="secondary" disabled={busy || !manufacturer[key]?.trim()}
                      onClick={() => void act(async () => {
                        await registerManufacturerBarcode(productId, item.variantId, manufacturer[key])
                        setManufacturer((prev) => ({ ...prev, [key]: '' }))
                      }, 'The barcode could not be registered.')}>
                      Register
                    </Button>
                  </div>
                )}
                {retired.length > 0 && (
                  <p className="text-[11.5px] text-muted-foreground">Retired, never reused: <span className="font-mono">{retired.map((b) => b.value).join(', ')}</span></p>
                )}
              </>
            )}
          </div>
        )
      })}
      <div className="grid gap-2 sm:grid-cols-[1fr_90px]">
        <select aria-label="Label layout" value={layout} disabled={busy} onChange={(e) => setLayout(e.target.value as LabelLayout)} className={cn(SELECT_CLASS, 'w-full')}>
          {LABEL_LAYOUTS.map((l) => <option key={l.value} value={l.value}>{l.label}</option>)}
        </select>
        <input type="number" inputMode="numeric" min={1} max={500} aria-label="Copies" className={cn(INPUT, 'tabular-nums')} value={copies} disabled={busy}
          onChange={(e) => setCopies(e.target.value)} />
      </div>
      {busy && <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" />}
      {error && <ErrorNote message={error} />}
    </div>
  )
}
