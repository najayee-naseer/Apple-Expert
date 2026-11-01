"use client"

import { useEffect, useMemo, useState } from 'react'
import { LoaderCircle, Printer } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { issueProductBarcode, listProductBarcodes, productsAllowingSharedBarcode, type ProductBarcode } from '@/lib/admin/barcodes'
import { buildLabelPdf, buildProductLabelPdf, buildShelfLabelPdf, openPdf, unitToLabel, LABEL_LAYOUTS, type LabelLayout, type ShelfLabelItem } from '@/lib/admin/labels'
import { canReceiveStock, describeUnitError, type GrnLineRow, type UnitView } from '@/lib/admin/units'
import { ErrorNote, SELECT_CLASS, UnitStatusBadge } from './shared'

const CARD = 'rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card space-y-3'

/** Units still physically in the shop: the ones a new label can be stuck on. */
function isInShop(unit: UnitView): boolean {
  return unit.status === 'in_stock' || unit.status === 'reserved' || unit.status === 'quarantined'
}

function activeCodes(line: GrnLineRow, barcodes: ProductBarcode[]): string[] {
  return barcodes
    .filter((b) => b.productId === line.product_id && b.variantId === line.variant_id && b.status === 'active')
    .map((b) => b.value)
}

/** How this line is sold at the counter. */
function counterNote(line: GrnLineRow, allowed: Set<string>, barcodes: ProductBarcode[]): string {
  const codes = activeCodes(line, barcodes)
  if (codes.length > 0) return `Scans at the counter with its product barcode: ${codes.join(', ')}.`
  if (allowed.has(line.product_id)) return 'No barcode yet, so add it from the product list at the counter. An owner or admin can issue one.'
  return 'No barcode, so add it from the product list at the counter.'
}

function LayoutPicker({ value, disabled, onChange }: { value: LabelLayout; disabled: boolean; onChange: (v: LabelLayout) => void }) {
  return (
    <div>
      <select aria-label="Label layout" value={value} disabled={disabled}
        onChange={(e) => onChange(e.target.value as LabelLayout)} className={cn(SELECT_CLASS, 'w-full')}>
        {LABEL_LAYOUTS.map((l) => <option key={l.value} value={l.value}>{l.label}</option>)}
      </select>
      <p className="mt-1.5 text-[11.5px] text-muted-foreground">{LABEL_LAYOUTS.find((l) => l.value === value)?.hint}</p>
    </div>
  )
}

/**
 * A GRN's barcoded units: choose some and print, or print everything still in the
 * shop. A sold or written-off unit can still be selected by hand for a reprint.
 */
export function UnitLabelsPanel({ units, lines, grnNumber }: { units: UnitView[]; lines: GrnLineRow[]; grnNumber: string }) {
  const [lineFilter, setLineFilter] = useState('all')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [layout, setLayout] = useState<LabelLayout>('sticker')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const unitLines = lines.filter((l) => l.tracking_mode_snapshot === 'unit')
  const visible = useMemo(
    () => units.filter((u) => lineFilter === 'all' || u.grn_line_id === lineFilter),
    [units, lineFilter],
  )
  const chosen = units.filter((u) => selected.has(u.id))
  const inShop = units.filter(isInShop)
  const allVisibleChosen = visible.length > 0 && visible.every((u) => selected.has(u.id))

  function toggleVisible(checked: boolean) {
    setSelected((prev) => {
      const next = new Set(prev)
      for (const u of visible) {
        if (checked) next.add(u.id); else next.delete(u.id)
      }
      return next
    })
  }

  async function print(items: UnitView[], suffix: string) {
    setBusy(true)
    setError(null)
    try {
      await openPdf(await buildLabelPdf(items.map(unitToLabel), layout), `${grnNumber}-${suffix}.pdf`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the labels.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className={CARD}>
      <div>
        <h3 className="text-[14px] font-bold text-foreground">Barcode labels</h3>
        <p className="text-[12px] text-muted-foreground">Each item has its own barcode. Stick one label on each item. The counter scanner reads the barcode; a phone camera reads the QR.</p>
      </div>

      <LayoutPicker value={layout} disabled={busy} onChange={setLayout} />

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button className="flex-1" onClick={() => void print(chosen, 'selected-labels')} disabled={busy || chosen.length === 0}>
          {busy ? <LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> : <Printer size={15} className="mr-1.5" />}
          Print selected ({chosen.length})
        </Button>
        <Button className="flex-1" variant="secondary" onClick={() => void print(inShop, 'labels')} disabled={busy || inShop.length === 0}>
          <Printer size={15} className="mr-1.5" /> Print all in shop ({inShop.length})
        </Button>
      </div>
      {error && <ErrorNote message={error} />}

      {unitLines.length > 1 && (
        <select aria-label="Which product" value={lineFilter} onChange={(e) => setLineFilter(e.target.value)} className={cn(SELECT_CLASS, 'w-full')}>
          <option value="all">All products ({units.length})</option>
          {unitLines.map((l) => (
            <option key={l.id} value={l.id}>
              {l.product_name_snapshot}{l.variant_label_snapshot ? ` · ${l.variant_label_snapshot}` : ''} ({l.accepted_quantity})
            </option>
          ))}
        </select>
      )}

      <div className="overflow-hidden rounded-2xl border border-mint/70 dark:border-border">
        <label className="flex items-center gap-3 border-b border-mint/70 dark:border-border bg-muted/60 px-3.5 py-2.5 text-[12.5px] font-semibold">
          <input type="checkbox" checked={allVisibleChosen} onChange={(e) => toggleVisible(e.target.checked)} />
          Select all ({visible.length})
        </label>
        <ul className="divide-y divide-mint/50 dark:divide-border/70">
          {visible.map((u) => (
            <li key={u.id}>
              <label className="flex items-center gap-3 px-3.5 py-2.5">
                <input type="checkbox" aria-label={`Select ${u.barcode}`} checked={selected.has(u.id)}
                  onChange={(e) => setSelected((prev) => {
                    const next = new Set(prev)
                    if (e.target.checked) next.add(u.id); else next.delete(u.id)
                    return next
                  })} />
                <span className="min-w-0 flex-1">
                  <span className="block font-mono text-[13px] font-semibold text-foreground">{u.barcode}</span>
                  <span className="block truncate text-[11.5px] text-muted-foreground">
                    {u.variantName ?? u.productName}{u.serial_number ? ` · ${u.serial_number}` : ' · no IMEI / serial'}
                  </span>
                </span>
                <UnitStatusBadge status={u.status} />
              </label>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

/**
 * Barcode labels for quantity-tracked accessories and parts on a GRN: the product's
 * shared code, one copy per item received by default. Owner/admin can issue a code
 * from here, on request. Shows nothing for lines in other categories, so a device
 * received by quantity stays on shelf labels and is never given a shared code.
 */
function ProductLabelsPanel({ lines, grnNumber, allowed, barcodes, onIssued }: {
  lines: GrnLineRow[]
  grnNumber: string
  allowed: Set<string>
  barcodes: ProductBarcode[]
  onIssued: () => Promise<void>
}) {
  const { role } = useAdminAuth()
  const canIssue = canReceiveStock(role)
  const [copies, setCopies] = useState<Record<string, string>>({})
  const [layout, setLayout] = useState<LabelLayout>('sticker')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const eligible = lines.filter((l) => l.accepted_quantity > 0 && allowed.has(l.product_id))

  const shopCode = (l: GrnLineRow) => barcodes.find((b) =>
    b.productId === l.product_id && b.variantId === l.variant_id && b.source === 'shop' && b.status === 'active')

  async function issue(l: GrnLineRow) {
    setBusy(true)
    setError(null)
    try {
      await issueProductBarcode(l.product_id, l.variant_id)
      await onIssued()
    } catch (err) {
      setError(describeUnitError(err, 'The barcode could not be issued.'))
    } finally {
      setBusy(false)
    }
  }

  async function print() {
    const items = []
    for (const l of eligible) {
      const code = shopCode(l)
      if (!code) continue
      const n = Number(copies[l.id] ?? l.accepted_quantity)
      if (!Number.isInteger(n) || n < 0 || n > 500) { setError(`${l.product_name_snapshot}: copies must be a whole number from 0 to 500.`); return }
      if (n > 0) items.push({ barcode: code.value, title: l.product_name_snapshot, subtitle: l.variant_label_snapshot, copies: n })
    }
    if (items.length === 0) { setError('Issue a barcode and enter how many labels to print.'); return }
    setBusy(true)
    setError(null)
    try {
      await openPdf(await buildProductLabelPdf(items, layout), `${grnNumber}-product-labels.pdf`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the labels.')
    } finally {
      setBusy(false)
    }
  }

  if (eligible.length === 0) return null

  return (
    <section className={CARD}>
      <div>
        <h3 className="text-[14px] font-bold text-foreground">Product barcodes</h3>
        <p className="text-[12px] leading-snug text-muted-foreground">One code per product or variant, the same on every item. Scanning it at the counter adds one to the bill.</p>
      </div>
      <ul className="space-y-2">
        {eligible.map((l) => {
          const code = shopCode(l)
          return (
            <li key={l.id} className="flex items-center gap-3 text-[13px]">
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold text-foreground">{l.product_name_snapshot}</span>
                <span className="block truncate text-[11.5px] text-muted-foreground">
                  {[l.variant_label_snapshot, code?.value ?? 'No shop barcode yet'].filter(Boolean).join(' · ')}
                  {!code && activeCodes(l, barcodes).length > 0 && ` · scans as ${activeCodes(l, barcodes).join(', ')}`}
                </span>
              </span>
              {code ? (
                <input type="number" inputMode="numeric" min={0} max={500} aria-label={`Copies of ${l.product_name_snapshot}`}
                  value={copies[l.id] ?? String(l.accepted_quantity)} disabled={busy}
                  onChange={(e) => setCopies((prev) => ({ ...prev, [l.id]: e.target.value }))}
                  className="focus-ring w-20 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-sm tabular-nums focus:outline-none focus:border-primary/45" />
              ) : canIssue ? (
                <Button size="sm" variant="secondary" disabled={busy} onClick={() => void issue(l)}>Issue</Button>
              ) : null}
            </li>
          )
        })}
      </ul>
      <LayoutPicker value={layout} disabled={busy} onChange={setLayout} />
      <Button variant="secondary" fullWidth onClick={() => void print()} disabled={busy || !eligible.some(shopCode)}>
        {busy ? <LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> : <Printer size={15} className="mr-1.5" />}
        Print product labels
      </Button>
      {error && <ErrorNote message={error} />}
    </section>
  )
}

/**
 * Quantity-tracked lines have no unit barcodes, so these are plain shelf labels:
 * name, variant and GRN number. Nothing scannable is printed, because nothing in
 * the database could resolve it at the counter.
 */
function ShelfLabelsPanel({ lines, grnNumber, allowed, barcodes, known }: {
  lines: GrnLineRow[]
  grnNumber: string
  allowed: Set<string>
  barcodes: ProductBarcode[]
  /** False until barcodes load, or if they cannot: say nothing rather than guess. */
  known: boolean
}) {
  const [copies, setCopies] = useState<Record<string, string>>({})
  const [layout, setLayout] = useState<LabelLayout>('sticker')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const accepted = lines.filter((l) => l.accepted_quantity > 0)
  // One by default: this labels a shelf, not each item.
  const copiesOf = (l: GrnLineRow) => copies[l.id] ?? '1'

  async function print() {
    const items: ShelfLabelItem[] = []
    for (const l of accepted) {
      const text = copiesOf(l).trim()
      if (text === '' || text === '0') continue
      const n = Number(text)
      if (!Number.isInteger(n) || n < 0 || n > 500) { setError(`${l.product_name_snapshot}: copies must be a whole number from 0 to 500.`); return }
      for (let i = 0; i < n; i++) {
        items.push({ title: l.product_name_snapshot, subtitle: l.variant_label_snapshot, reference: grnNumber })
      }
    }
    if (items.length === 0) { setError('Enter how many labels to print.'); return }
    setBusy(true)
    setError(null)
    try {
      await openPdf(await buildShelfLabelPdf(items, layout), `${grnNumber}-shelf-labels.pdf`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the labels.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className={CARD}>
      <div>
        <h3 className="text-[14px] font-bold text-foreground">Tracked by quantity</h3>
        <p className="text-[12px] leading-snug text-muted-foreground">
          Stock is a number here, not individual items, so no item has its own barcode. Shelf labels carry only the name and GRN number.
        </p>
      </div>

      {accepted.length > 0 && (
        <>
          <ul className="space-y-2">
            {accepted.map((l) => (
              <li key={l.id} className="flex items-center gap-3 text-[13px]">
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-semibold text-foreground">{l.product_name_snapshot}</span>
                  {l.variant_label_snapshot && <span className="block truncate text-[11.5px] text-muted-foreground">{l.variant_label_snapshot}</span>}
                  {known && <span className="block text-[11.5px] text-muted-foreground">{counterNote(l, allowed, barcodes)}</span>}
                </span>
                <input type="number" inputMode="numeric" min={0} max={500} aria-label={`Copies of ${l.product_name_snapshot}`}
                  value={copiesOf(l)} disabled={busy}
                  onChange={(e) => setCopies((prev) => ({ ...prev, [l.id]: e.target.value }))}
                  className="focus-ring w-20 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-sm tabular-nums focus:outline-none focus:border-primary/45" />
              </li>
            ))}
          </ul>
          <LayoutPicker value={layout} disabled={busy} onChange={setLayout} />
          <Button variant="secondary" fullWidth onClick={() => void print()} disabled={busy}>
            {busy ? <LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> : <Printer size={15} className="mr-1.5" />}
            Print shelf labels
          </Button>
          <p className="text-[11.5px] leading-snug text-muted-foreground">
            Every copy is identical: they all mean the same product and variant, not separate items you can tell apart. A shelf label has no barcode of its own and cannot be scanned.
          </p>
        </>
      )}
      {error && <ErrorNote message={error} />}
    </section>
  )
}

/**
 * A GRN's quantity-tracked lines. Some scan with a shared product barcode and some
 * have no barcode at all, so both panels work from the same loaded facts. If loading
 * fails, only plain shelf labels show.
 */
export function QuantityLabelPanels({ lines, grnNumber }: { lines: GrnLineRow[]; grnNumber: string }) {
  const [allowed, setAllowed] = useState<Set<string>>(new Set())
  const [barcodes, setBarcodes] = useState<ProductBarcode[]>([])
  const [known, setKnown] = useState(false)
  const idsKey = [...new Set(lines.map((l) => l.product_id))].join(',')

  useEffect(() => {
    let cancelled = false
    const ids = idsKey.split(',')
    Promise.all([productsAllowingSharedBarcode(ids), listProductBarcodes(ids)])
      .then(([open, rows]) => {
        if (!cancelled) { setAllowed(open); setBarcodes(rows); setKnown(true) }
      })
      .catch(() => {})
    return () => { cancelled = true }
  }, [idsKey])

  return (
    <>
      <ProductLabelsPanel lines={lines} grnNumber={grnNumber} allowed={allowed} barcodes={barcodes}
        onIssued={async () => setBarcodes(await listProductBarcodes(idsKey.split(',')))} />
      <ShelfLabelsPanel lines={lines} grnNumber={grnNumber} allowed={allowed} barcodes={barcodes} known={known} />
    </>
  )
}
