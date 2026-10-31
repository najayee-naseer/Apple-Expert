"use client"

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { LoaderCircle, Plus, Trash2, ScanBarcode } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import { TextField, TextAreaField, FieldLabel, CheckboxField } from '@/components/admin/products/fields'
import {
  newRequestId, todayInColombo, splitCodes, isValidSerial, isValidImei, trackingModeOf, loadCosts,
  type GrnProductOption, type TrackingMode,
} from '@/lib/admin/units'
import {
  receiveGoods, loadPurchaseOrder, describePurchasingError, GRN_SOURCES,
  type SupplierRow, type PurchaseOrderListItem, type PurchaseOrderLineRow, type GrnResult, type GrnSourceType,
} from '@/lib/admin/purchasing'
import { ErrorNote, parseCost, parseRupees } from './shared'

const CONTROL =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 transition-colors disabled:opacity-60'

interface LineDraft {
  key: string
  productId: string
  variantId: string
  purchaseOrderLineId: string | null
  /** What the PO line expected; null without a PO. */
  poUnitCostCents: number | null
  received: string
  rejected: string
  rejectionReason: string
  cost: string
  costPending: boolean
  costNote: string
  serialText: string
  reentryReason: string
}

function emptyLine(): LineDraft {
  return {
    key: newRequestId(), productId: '', variantId: '', purchaseOrderLineId: null, poUnitCostCents: null,
    received: '1', rejected: '', rejectionReason: '', cost: '', costPending: false, costNote: '', serialText: '', reentryReason: '',
  }
}

interface LineCheck {
  product: GrnProductOption | undefined
  mode: TrackingMode
  received: number | null
  rejected: number
  accepted: number
  costCents: number | null
  serials: string[]
  problems: string[]
  /** An item that must be tracked individually, still set to quantity: posting is blocked. */
  needsIndividualTracking: boolean
}

function checkLine(line: LineDraft, products: Map<string, GrnProductOption>, dueOnPo: number | null, source: GrnSourceType): LineCheck {
  const product = products.get(line.productId)
  const mode: TrackingMode = product ? trackingModeOf(product, line.variantId || null) : 'quantity'
  const received = /^\d+$/.test(line.received.trim()) ? Number(line.received) : null
  const rejected = /^\d+$/.test(line.rejected.trim()) ? Number(line.rejected) : 0
  const accepted = Math.max((received ?? 0) - rejected, 0)
  const parsedCost = parseCost(line.cost)
  const serials = mode === 'unit' ? splitCodes(line.serialText) : []
  const problems: string[] = []
  // Posting this as a number would create no units, and so no barcodes to print.
  const needsIndividualTracking = !!product && accepted > 0 && mode === 'quantity'
    && (product.categoryTrackingMode === 'unit' || product.requiresSerial)

  if (!product) problems.push('Choose a product.')
  if (product && product.variants.length > 0 && !line.variantId) problems.push('Choose the variant (colour / storage).')
  if (received === null || received < 1 || received > 2000) problems.push('Received must be 1 to 2000.')
  else if (dueOnPo !== null && received > dueOnPo) problems.push(`Only ${dueOnPo} still due on the purchase order.`)
  if (line.rejected.trim() !== '' && !/^\d+$/.test(line.rejected.trim())) problems.push('Rejected must be a whole number.')
  if (received !== null && rejected > received) problems.push('Cannot reject more than was received.')
  if (rejected > 0 && line.rejectionReason.trim().length < 3) problems.push('Say why the items were rejected.')

  // Blank is not zero: either a stated cost, or explicitly pending.
  let costCents: number | null = null
  if (line.costPending) {
    if (line.cost.trim() !== '') problems.push('Clear the cost, or untick cost pending.')
  } else if (parsedCost === 'blank') {
    problems.push('Enter the unit cost, or tick cost pending. Blank is never treated as free.')
  } else if (parsedCost === null) {
    problems.push('Unit cost must be an amount in rupees.')
  } else {
    costCents = parsedCost
    if (source === 'supplier' && line.poUnitCostCents !== null && parsedCost !== line.poUnitCostCents && line.costNote.trim().length < 3) {
      problems.push('This cost differs from the purchase order. Add a note explaining why.')
    }
  }

  if (mode === 'unit') {
    if (product?.requiresSerial && serials.length !== accepted) {
      problems.push(`Scan ${accepted} IMEI / serial number${accepted === 1 ? '' : 's'} for the accepted items — ${serials.length} entered.`)
    } else if (!product?.requiresSerial && serials.length > 0 && serials.length !== accepted) {
      problems.push(`Serial numbers are optional, but if given there must be one per accepted item (${serials.length} for ${accepted}).`)
    }
    const bad = serials.filter((s) => !isValidSerial(s) || (product?.requiresSerial && /^\d{15}$/.test(s) && !isValidImei(s)))
    if (bad.length) problems.push(`Check ${bad.slice(0, 3).join(', ')}${bad.length > 3 ? ` and ${bad.length - 3} more` : ''} — not a valid IMEI / serial.`)
    const dupes = serials.filter((s, i) => serials.indexOf(s) !== i)
    if (dupes.length) problems.push(`Scanned twice: ${[...new Set(dupes)].slice(0, 3).join(', ')}.`)
  }
  if (needsIndividualTracking) {
    problems.unshift(`${product?.name} must be tracked individually before it can be received. Count its existing stock and switch it in the product editor.`)
  }

  return { product, mode, received, rejected, accepted, costCents, serials, problems, needsIndividualTracking }
}

function lineFromPo(l: PurchaseOrderLineRow, unitCost: number | null): LineDraft {
  return {
    ...emptyLine(),
    productId: l.product_id,
    variantId: l.variant_id ?? '',
    purchaseOrderLineId: l.id,
    poUnitCostCents: unitCost,
    received: String(l.quantity - l.received_quantity),
    cost: unitCost === null ? '' : String(unitCost / 100),
    costPending: unitCost === null,
  }
}

/**
 * New GRN — record a delivery: what arrived, what was accepted, what was refused
 * and why. Posting raises stock for accepted items only. One request id per open
 * drawer, so pressing Post again after a lost response never receives goods twice.
 */
export function GrnCreator({ products, suppliers, purchaseOrders, initialPoId, onClose, onPosted }: {
  products: GrnProductOption[]
  suppliers: SupplierRow[]
  /** Purchase orders that can still receive goods. */
  purchaseOrders: PurchaseOrderListItem[]
  /** Opened from a purchase order: preselects it and fills the lines. */
  initialPoId?: string | null
  onClose: () => void
  onPosted: (result: GrnResult) => void
}) {
  const [requestId] = useState(newRequestId)
  const initialPo = purchaseOrders.find((po) => po.id === initialPoId) ?? null
  const [source, setSource] = useState<GrnSourceType>('supplier')
  const [sourceName, setSourceName] = useState('')
  const [supplierId, setSupplierId] = useState(initialPo?.supplier_id ?? '')
  const [poId, setPoId] = useState(initialPo?.id ?? '')
  const [poLines, setPoLines] = useState<PurchaseOrderLineRow[] | null>(null)
  const [poLoading, setPoLoading] = useState(!!initialPo)
  const [invoice, setInvoice] = useState('')
  const [receivedOn, setReceivedOn] = useState(todayInColombo)
  const [note, setNote] = useState('')
  const [lines, setLines] = useState<LineDraft[]>(() => [emptyLine()])
  const [search, setSearch] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showProblems, setShowProblems] = useState(false)
  // The server said this invoice was already received: a person must confirm.
  const [duplicateAsked, setDuplicateAsked] = useState(false)
  const [duplicateConfirmed, setDuplicateConfirmed] = useState(false)
  const [duplicateNote, setDuplicateNote] = useState('')

  const byId = useMemo(() => new Map(products.map((p) => [p.id, p])), [products])
  // What is still due on the chosen PO, per product + variant.
  const due = useMemo(() => {
    const m = new Map<string, number>()
    for (const l of poLines ?? []) {
      const k = `${l.product_id}|${l.variant_id ?? ''}`
      m.set(k, (m.get(k) ?? 0) + l.quantity - l.received_quantity)
    }
    return m
  }, [poLines])
  const checks = lines.map((l) => checkLine(l, byId, poId ? (due.get(`${l.productId}|${l.variantId}`) ?? 0) : null, source))
  const activeSuppliers = suppliers.filter((s) => s.is_active || s.id === supplierId)
  const supplierPos = purchaseOrders.filter((po) => po.supplier_id === supplierId)

  async function fetchPo(id: string) {
    const [d, costs] = await Promise.all([loadPurchaseOrder(id), loadCosts('po_line', [id])])
    const open = d.lines.filter((l) => l.received_quantity < l.quantity)
    return { lines: d.lines, drafts: open.length ? open.map((l) => lineFromPo(l, costs.get(l.id)?.cents ?? null)) : [emptyLine()] }
  }

  function applyPo(id: string) {
    setPoId(id)
    setError(null)
    if (!id) { setPoLines(null); setLines([emptyLine()]); return }
    setPoLoading(true)
    fetchPo(id)
      .then((r) => { setPoLines(r.lines); setLines(r.drafts) })
      .catch((err) => setError(describePurchasingError(err, 'Could not load the purchase order.')))
      .finally(() => setPoLoading(false))
  }

  // Opened from a PO: load its lines once.
  useEffect(() => {
    if (!initialPo) return
    let cancelled = false
    fetchPo(initialPo.id)
      .then((r) => { if (!cancelled) { setPoLines(r.lines); setLines(r.drafts) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load the purchase order.')) })
      .finally(() => { if (!cancelled) setPoLoading(false) })
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- runs once for the PO the drawer opened with
  }, [])
  const totalAccepted = checks.reduce((n, c) => n + c.accepted, 0)
  const totalRejected = checks.reduce((n, c) => n + c.rejected, 0)
  const totalCost = checks.reduce((n, c) => n + c.accepted * (c.costCents ?? 0), 0)
  const anyPending = lines.some((l) => l.costPending)

  const options = useMemo(() => {
    const q = search.trim().toLowerCase()
    return products.filter((p) => !q || p.name.toLowerCase().includes(q) || p.id.includes(q))
  }, [products, search])

  function update(key: string, patch: Partial<LineDraft>) {
    setLines((prev) => prev.map((l) => (l.key === key ? { ...l, ...patch } : l)))
    setError(null)
  }

  async function submit() {
    setShowProblems(true)
    if (source === 'supplier' && !supplierId) { setError('Choose the supplier.'); return }
    if (source === 'buyback' && sourceName.trim().length < 2) { setError('Enter who the device was bought from.'); return }
    if (poLoading) { setError('The purchase order is still loading.'); return }
    const firstBad = checks.findIndex((c) => c.problems.length > 0)
    if (firstBad >= 0) { setError(`Line ${firstBad + 1}: ${checks[firstBad].problems[0]}`); return }
    if (duplicateAsked && (!duplicateConfirmed || duplicateNote.trim().length < 3)) {
      setError('Confirm this is another part of the same invoice, with a note.')
      return
    }

    setBusy(true)
    setError(null)
    try {
      const result = await receiveGoods({
        sourceType: source,
        supplierId: source === 'supplier' ? supplierId : null,
        sourceName: sourceName.trim(),
        purchaseOrderId: source === 'supplier' ? (poId || null) : null,
        supplierInvoice: invoice.trim(),
        confirmDuplicateInvoice: duplicateConfirmed,
        duplicateInvoiceNote: duplicateNote.trim(),
        receivedOn,
        note: note.trim(),
        requestId,
        lines: lines.map((l, i) => ({
          productId: l.productId,
          variantId: l.variantId || null,
          purchaseOrderLineId: l.purchaseOrderLineId,
          receivedQuantity: checks[i].received as number,
          rejectedQuantity: checks[i].rejected,
          rejectionReason: l.rejectionReason.trim(),
          unitCostCents: l.costPending ? null : checks[i].costCents,
          costPending: l.costPending,
          costNote: l.costNote.trim(),
          serials: checks[i].serials,
          serialReentryReason: l.reentryReason.trim(),
        })),
      })
      onPosted(result)
    } catch (err) {
      const message = (err as { message?: string })?.message ?? ''
      if (message.startsWith('possible_duplicate_delivery')) setDuplicateAsked(true)
      setError(describePurchasingError(err, 'The GRN could not be posted.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AdminDrawer
      title="New GRN"
      subtitle="Goods received — record what arrived, what you accepted and what you refused"
      onClose={busy ? () => {} : onClose}
      footer={
        <>
          <span className="mr-auto text-[12.5px] text-muted-foreground tabular-nums">
            {totalAccepted} accepted{totalRejected > 0 ? ` · ${totalRejected} rejected` : ''} · {formatPrice(centsToRupees(totalCost))}{anyPending ? ' + cost pending' : ''}
          </span>
          <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
          <Button onClick={() => void submit()} disabled={busy || checks.some((c) => c.needsIndividualTracking)}>
            {busy ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Posting…</> : 'Post GRN'}
          </Button>
        </>
      }
    >
      <label htmlFor="grn-source" className="block">
        <FieldLabel>Where it came from</FieldLabel>
        <select id="grn-source" className={CONTROL} value={source} disabled={busy || !!initialPo}
          onChange={(e) => { setSource(e.target.value as GrnSourceType); setSupplierId(''); applyPo('') }}>
          {GRN_SOURCES.map((s) => <option key={s.value} value={s.value}>{s.label}</option>)}
        </select>
        <span className="mt-1.5 block text-[11.5px] text-muted-foreground">{GRN_SOURCES.find((s) => s.value === source)?.hint}</span>
      </label>

      {source === 'supplier' && activeSuppliers.length === 0 && (
        <ErrorNote message="No suppliers yet. Add the supplier in Purchase & Returns → Supplier Details first." />
      )}
      <div className="grid gap-3.5 sm:grid-cols-2">
        {source === 'supplier' && (
          <>
            <label htmlFor="grn-supplier" className="block">
              <FieldLabel>Supplier</FieldLabel>
              <select id="grn-supplier" className={CONTROL} value={supplierId} disabled={busy}
                onChange={(e) => { setSupplierId(e.target.value); applyPo('') }}>
                <option value="">Choose a supplier…</option>
                {activeSuppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </label>
            <label htmlFor="grn-po" className="block">
              <FieldLabel hint={poLoading ? 'loading…' : 'optional'}>Purchase order</FieldLabel>
              <select id="grn-po" className={CONTROL} value={poId} disabled={busy || !supplierId || poLoading}
                onChange={(e) => applyPo(e.target.value)}>
                <option value="">No purchase order</option>
                {supplierPos.map((po) => <option key={po.id} value={po.id}>{po.po_number} · {po.order_date}</option>)}
              </select>
            </label>
            <TextField id="grn-invoice" label="Supplier invoice no." hint="optional" value={invoice} disabled={busy}
              onChange={(v) => { setInvoice(v); setDuplicateAsked(false); setDuplicateConfirmed(false); setError(null) }} />
          </>
        )}
        {source === 'buyback' && (
          <TextField id="grn-seller" label="Bought from" value={sourceName} disabled={busy}
            onChange={(v) => { setSourceName(v); setError(null) }} />
        )}
        <label htmlFor="grn-date" className="block">
          <FieldLabel>Received on</FieldLabel>
          <input id="grn-date" type="date" className={CONTROL} value={receivedOn} max={todayInColombo()} disabled={busy}
            onChange={(e) => { setReceivedOn(e.target.value); setError(null) }} />
        </label>
        <label htmlFor="grn-search" className="block">
          <FieldLabel hint="filters the product lists">Find product</FieldLabel>
          <input id="grn-search" type="search" className={CONTROL} value={search} placeholder="iPhone 14…"
            onChange={(e) => setSearch(e.target.value)} />
        </label>
      </div>

      {duplicateAsked && (
        <section className="space-y-2.5 rounded-[22px] border border-amber-500/30 bg-amber-500/8 p-4">
          <p className="text-[13px] font-semibold text-foreground">This invoice has already been received from this supplier.</p>
          <CheckboxField id="grn-dup" label="This is another part of the same invoice, not the same delivery again"
            checked={duplicateConfirmed} disabled={busy} onChange={setDuplicateConfirmed} />
          <TextField id="grn-dup-note" label="Note" value={duplicateNote} disabled={busy}
            placeholder="e.g. second part delivered today" onChange={setDuplicateNote} />
        </section>
      )}

      {lines.map((line, i) => {
        const c = checks[i]
        const p = c.product
        const productOptions = p && !options.some((o) => o.id === p.id) ? [p, ...options] : options
        const costDiffers = !line.costPending && line.poUnitCostCents !== null && parseRupees(line.cost) !== line.poUnitCostCents
        return (
          <section key={line.key} className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card space-y-3">
            <div className="flex items-center gap-2">
              <h3 className="text-[14px] font-bold text-foreground">Line {i + 1}</h3>
              {p && (
                <span className="rounded-full border border-mint-deep dark:border-border px-2 py-0.5 text-[10.5px] font-semibold text-muted-foreground">
                  {c.mode === 'unit' ? 'Individually tracked' : 'Quantity tracked'}
                </span>
              )}
              {p?.requiresSerial && (
                <span className="rounded-full border border-amber-500/30 bg-amber-500/10 px-2 py-0.5 text-[10.5px] font-semibold text-amber-700 dark:text-amber-300">
                  IMEI required
                </span>
              )}
              {lines.length > 1 && (
                <button type="button" aria-label={`Remove line ${i + 1}`} disabled={busy}
                  onClick={() => setLines((prev) => prev.filter((l) => l.key !== line.key))}
                  className="focus-ring ml-auto flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground hover:bg-red-500/10 hover:text-red-500">
                  <Trash2 size={15} />
                </button>
              )}
            </div>

            {c.needsIndividualTracking && (
              <div role="alert" className="rounded-2xl border border-red-500/25 bg-red-500/8 px-3.5 py-3 text-[12.5px] leading-snug text-foreground">
                <p className="font-semibold">This cannot be received yet.</p>
                <p className="mt-0.5">
                  {p?.name} must be tracked individually, but is still set to quantity, so posting would create no barcodes. Count its existing stock, set it to 0 with Adjust stock, then choose Track individually in{' '}
                  <Link href="/admin/products" className="font-semibold text-primary underline underline-offset-2">Products</Link>.
                </p>
              </div>
            )}

            <label className="block">
              <FieldLabel>Product</FieldLabel>
              <select className={CONTROL} value={line.productId} disabled={busy || !!line.purchaseOrderLineId}
                onChange={(e) => update(line.key, { productId: e.target.value, variantId: '' })}>
                <option value="">Choose a product…</option>
                {productOptions.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.name}{o.categoryName ? ` · ${o.categoryName}` : ''}{o.isActive ? '' : ' (hidden)'}
                  </option>
                ))}
              </select>
            </label>

            {p && p.variants.length > 0 && (
              <label className="block">
                <FieldLabel>Variant</FieldLabel>
                <select className={CONTROL} value={line.variantId} disabled={busy || !!line.purchaseOrderLineId}
                  onChange={(e) => update(line.key, { variantId: e.target.value })}>
                  <option value="">Choose colour / storage…</option>
                  {p.variants.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
                </select>
              </label>
            )}

            <div className="grid grid-cols-3 gap-3">
              <label className="block">
                <FieldLabel hint="arrived">Received</FieldLabel>
                <input type="number" inputMode="numeric" min={1} max={2000} className={cn(CONTROL, 'tabular-nums')}
                  value={line.received} disabled={busy} onChange={(e) => update(line.key, { received: e.target.value })} />
              </label>
              <label className="block">
                <FieldLabel hint="refused">Rejected</FieldLabel>
                <input type="number" inputMode="numeric" min={0} className={cn(CONTROL, 'tabular-nums')} placeholder="0"
                  value={line.rejected} disabled={busy} onChange={(e) => update(line.key, { rejected: e.target.value })} />
              </label>
              <div>
                <FieldLabel hint="into stock">Accepted</FieldLabel>
                <p className={cn(CONTROL, 'tabular-nums font-semibold bg-transparent')}>{c.accepted}</p>
              </div>
            </div>

            {c.rejected > 0 && (
              <TextField id={`grn-rej-${line.key}`} label="Why rejected" value={line.rejectionReason} disabled={busy}
                placeholder="e.g. cracked in transit" onChange={(v) => update(line.key, { rejectionReason: v })} />
            )}

            <div className="grid gap-3 sm:grid-cols-2">
              <label className="block">
                <FieldLabel hint={line.poUnitCostCents !== null ? `PO: ${formatPrice(centsToRupees(line.poUnitCostCents))}` : 'Rs., per unit'}>Actual unit cost</FieldLabel>
                <input type="text" inputMode="decimal" className={cn(CONTROL, 'tabular-nums')}
                  value={line.cost} disabled={busy || line.costPending} onChange={(e) => update(line.key, { cost: e.target.value })} />
              </label>
              <div className="flex items-end pb-1">
                <CheckboxField id={`grn-pending-${line.key}`} label="Cost pending (not known yet)" checked={line.costPending} disabled={busy}
                  onChange={(v) => update(line.key, { costPending: v, cost: v ? '' : line.cost })} />
              </div>
            </div>
            {costDiffers && (
              <TextField id={`grn-cost-note-${line.key}`} label="Why the cost differs from the PO" value={line.costNote} disabled={busy}
                onChange={(v) => update(line.key, { costNote: v })} />
            )}

            {c.mode === 'unit' && (
              <>
                <label className="block">
                  <FieldLabel hint={p?.requiresSerial ? `${c.serials.length} / ${c.accepted} scanned` : 'optional · one per line'}>
                    <span className="inline-flex items-center gap-1.5"><ScanBarcode size={14} /> IMEI / serial numbers</span>
                  </FieldLabel>
                  <textarea rows={p?.requiresSerial ? 5 : 3} className={cn(CONTROL, 'font-mono text-[13px] leading-relaxed')}
                    placeholder={'Scan the box barcode of each accepted item.\nOne IMEI per line.'}
                    value={line.serialText} disabled={busy}
                    onChange={(e) => update(line.key, { serialText: e.target.value })} />
                </label>
                <TextField id={`grn-reentry-${line.key}`} label="Coming back into stock?" hint="only if an IMEI was recorded before"
                  value={line.reentryReason} disabled={busy} placeholder="e.g. repaired by supplier, bought back"
                  onChange={(v) => update(line.key, { reentryReason: v })} />
              </>
            )}

            {showProblems && c.problems.length > 0 && (
              <ul className="space-y-1 text-[12px] text-red-600 dark:text-red-400">
                {c.problems.map((m) => <li key={m}>• {m}</li>)}
              </ul>
            )}
          </section>
        )
      })}

      <Button variant="secondary" fullWidth disabled={busy || lines.length >= 100}
        onClick={() => setLines((prev) => [...prev, emptyLine()])}>
        <Plus size={15} className="mr-1.5" /> Add another product
      </Button>

      <TextAreaField id="grn-note" label="Note (optional)" rows={2} value={note} disabled={busy}
        onChange={(v) => { setNote(v); setError(null) }} />

      <p className="text-[11.5px] leading-snug text-muted-foreground">
        Posting cannot be undone. Goods recorded by mistake are taken back out with a correction on the GRN, which also corrects the purchase order and what is owed.
      </p>

      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}
