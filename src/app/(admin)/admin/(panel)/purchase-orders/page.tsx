"use client"

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, PackagePlus, Plus, Trash2, LoaderCircle, Ban } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import { TextAreaField, FieldLabel, CheckboxField } from '@/components/admin/products/fields'
import { ListHeader, ListTable, RowAction, StatusPill, type Column } from '@/components/admin/purchasing/ListTable'
import { ErrorNote, SuccessNote, parseCost, SELECT_CLASS } from '@/components/admin/inventory/shared'
import { GrnCreator } from '@/components/admin/inventory/GrnCreator'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { listProductsForGrn, todayInColombo, formatDate, loadCosts, type CostRow, type GrnProductOption } from '@/lib/admin/units'
import {
  listPurchaseOrders, loadPurchaseOrder, createPurchaseOrder, closePurchaseOrder, listSuppliers,
  canManagePurchasing, describePurchasingError, formatRupeesFromCents, isPoReceivable, newRequestId,
  PO_STATUSES, PO_STATUS_LABEL,
  type PurchaseOrderListItem, type PurchaseOrderDetail, type SupplierRow, type PoStatus,
} from '@/lib/admin/purchasing'

const CONTROL =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

const STATUS_TONE: Record<PoStatus, 'green' | 'amber' | 'grey' | 'red' | 'blue'> = {
  open: 'blue', partially_received: 'amber', received: 'green', closed: 'grey', cancelled: 'red',
}

function PoStatusPill({ status }: { status: string }) {
  const s = (status in STATUS_TONE ? status : 'open') as PoStatus
  return <StatusPill label={PO_STATUS_LABEL[s]} tone={STATUS_TONE[s]} />
}

export default function PurchaseOrdersPage() {
  const { role } = useAdminAuth()
  const canManage = canManagePurchasing(role)

  const [rows, setRows] = useState<PurchaseOrderListItem[] | null>(null)
  const [suppliers, setSuppliers] = useState<SupplierRow[]>([])
  const [products, setProducts] = useState<GrnProductOption[]>([])
  const [costs, setCosts] = useState<Map<string, CostRow>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<string>('all')
  const [creating, setCreating] = useState(false)
  const [viewing, setViewing] = useState<string | null>(null)
  const [receiving, setReceiving] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const load = useCallback(async () => {
    const [o, s, p] = await Promise.all([listPurchaseOrders(), listSuppliers(), listProductsForGrn()])
    // Purchase values come separately: staff are refused them by the database.
    const c = canManage ? await loadCosts('po', o.map((x) => x.id)) : new Map<string, CostRow>()
    return [o, s, p, c] as const
  }, [canManage])
  const refresh = useCallback(() => {
    load().then(([o, s, p, c]) => { setRows(o); setSuppliers(s); setProducts(p); setCosts(c); setError(null) })
      .catch((err) => setError(describePurchasingError(err, 'Could not load purchase orders.')))
  }, [load])

  useEffect(() => {
    let cancelled = false
    load()
      .then(([o, s, p, c]) => { if (!cancelled) { setRows(o); setSuppliers(s); setProducts(p); setCosts(c) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load purchase orders.')) })
    return () => { cancelled = true }
  }, [load])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return (rows ?? []).filter((o) => (status === 'all' || o.status === status)
      && (!q || o.po_number.toLowerCase().includes(q) || o.supplierName.toLowerCase().includes(q)))
  }, [rows, search, status])

  const receivable = (rows ?? []).filter((o) => isPoReceivable(o.status))

  const columns: Column<PurchaseOrderListItem>[] = [
    { key: 'no', header: 'PO No', render: (o) => <span className="font-semibold whitespace-nowrap">{o.po_number}</span> },
    { key: 'supplier', header: 'Supplier', render: (o) => <span className="block min-w-[150px]">{o.supplierName}</span> },
    { key: 'date', header: 'Order date', render: (o) => <span className="whitespace-nowrap">{formatDate(o.order_date)}</span> },
    { key: 'expected', header: 'Expected', render: (o) => <span className="whitespace-nowrap text-muted-foreground">{o.expected_date ? formatDate(o.expected_date) : '—'}</span> },
    { key: 'status', header: 'Status', render: (o) => <PoStatusPill status={o.status} /> },
    ...(canManage ? [{
      key: 'total', header: 'Total', align: 'right' as const,
      render: (o: PurchaseOrderListItem) => (
        <span className="tabular-nums whitespace-nowrap">
          {formatRupeesFromCents(costs.get(o.id)?.cents ?? 0)}
          {costs.get(o.id)?.pending && <span className="block text-[11px] font-semibold text-amber-600 dark:text-amber-400">cost pending</span>}
        </span>
      ),
    }] : []),
    { key: 'actions', header: 'Actions', align: 'right', render: (o) => (
      <span className="inline-flex gap-0.5">
        <RowAction label="View" onClick={() => setViewing(o.id)}><Eye size={16} /></RowAction>
        {canManage && isPoReceivable(o.status) && (
          <RowAction label="Receive goods (GRN)" onClick={() => setReceiving(o.id)}><PackagePlus size={16} /></RowAction>
        )}
      </span>
    ) },
  ]

  return (
    <>
      <ListHeader title="Purchase Orders" crumb="View" search={search} onSearch={setSearch}
        searchPlaceholder="Search PO number or supplier…"
        action={<>
          <select aria-label="Status" value={status} onChange={(e) => setStatus(e.target.value)} className={SELECT_CLASS}>
            <option value="all">All statuses</option>
            {PO_STATUSES.map((s) => <option key={s} value={s}>{PO_STATUS_LABEL[s]}</option>)}
          </select>
          {canManage && <Button onClick={() => setCreating(true)} disabled={rows === null}><Plus size={16} className="mr-1.5" /> New Order</Button>}
        </>} />

      {notice && <SuccessNote message={notice} className="mb-4" />}

      <ListTable columns={columns} rows={filtered} rowKey={(o) => o.id} loading={rows === null && !error} error={error}
        empty={rows?.length ? 'No purchase orders match.' : 'No purchase orders yet.'}
        onRowClick={(o) => setViewing(o.id)} />

      {creating && (
        <PoCreator suppliers={suppliers} products={products} onClose={() => setCreating(false)}
          onCreated={(no) => { setCreating(false); setNotice(`${no} created.`); refresh() }} />
      )}
      {viewing && (
        <PoView key={viewing} poId={viewing} canManage={canManage} onClose={() => setViewing(null)}
          onReceive={() => { setReceiving(viewing); setViewing(null) }}
          onChanged={(msg) => { setNotice(msg); refresh() }} />
      )}
      {receiving && (
        <GrnCreator products={products} suppliers={suppliers} purchaseOrders={receivable} initialPoId={receiving}
          onClose={() => setReceiving(null)}
          onPosted={(r) => {
            setReceiving(null)
            setNotice(r.replayed ? `${r.grn_number} had already been posted.` : `${r.grn_number} posted: ${r.total_units} units received. Print their labels from Good Receive Notice.`)
            refresh()
          }} />
      )}
    </>
  )
}

interface LineDraft { key: string; productId: string; variantId: string; quantity: string; cost: string; costPending: boolean }
const emptyLine = (): LineDraft => ({ key: newRequestId(), productId: '', variantId: '', quantity: '1', cost: '', costPending: false })

/** cents, or null when pending or not valid. */
function lineCost(l: LineDraft): number | null {
  const c = parseCost(l.cost)
  return l.costPending || c === 'blank' ? null : c
}

function PoCreator({ suppliers, products, onClose, onCreated }: {
  suppliers: SupplierRow[]
  products: GrnProductOption[]
  onClose: () => void
  onCreated: (poNumber: string) => void
}) {
  const [requestId] = useState(newRequestId)
  const [supplierId, setSupplierId] = useState('')
  const [orderDate, setOrderDate] = useState(todayInColombo)
  const [expected, setExpected] = useState('')
  const [note, setNote] = useState('')
  const [lines, setLines] = useState<LineDraft[]>(() => [emptyLine()])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const byId = useMemo(() => new Map(products.map((p) => [p.id, p])), [products])
  const active = suppliers.filter((s) => s.is_active)
  const total = lines.reduce((sum, l) => sum + (Number(l.quantity) || 0) * (lineCost(l) ?? 0), 0)

  function update(key: string, patch: Partial<LineDraft>) {
    setLines((prev) => prev.map((l) => (l.key === key ? { ...l, ...patch } : l)))
    setError(null)
  }

  async function submit() {
    if (!supplierId) { setError('Choose the supplier.'); return }
    for (const [i, l] of lines.entries()) {
      const p = byId.get(l.productId)
      if (!p) { setError(`Line ${i + 1}: choose a product.`); return }
      if (p.variants.length > 0 && !l.variantId) { setError(`Line ${i + 1}: choose the variant.`); return }
      if (!/^\d+$/.test(l.quantity) || Number(l.quantity) < 1 || Number(l.quantity) > 2000) { setError(`Line ${i + 1}: quantity must be 1 to 2000.`); return }
      if (!l.costPending) {
        const c = parseCost(l.cost)
        if (c === 'blank') { setError(`Line ${i + 1}: enter the cost, or tick cost pending. Blank is never treated as free.`); return }
        if (c === null) { setError(`Line ${i + 1}: cost must be an amount in rupees.`); return }
      }
    }
    setBusy(true)
    setError(null)
    try {
      const r = await createPurchaseOrder({
        supplierId, orderDate, expectedDate: expected || null, note: note.trim(), requestId,
        lines: lines.map((l) => ({ productId: l.productId, variantId: l.variantId || null, quantity: Number(l.quantity), unitCostCents: lineCost(l) })),
      })
      onCreated(r.po_number)
    } catch (err) {
      setError(describePurchasingError(err, 'The purchase order could not be created.'))
      setBusy(false)
    }
  }

  return (
    <AdminDrawer title="New purchase order" subtitle="What you are ordering from a supplier" onClose={busy ? () => {} : onClose}
      footer={<>
        <span className="mr-auto text-[12.5px] text-muted-foreground tabular-nums">Total {formatRupeesFromCents(total)}</span>
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy}>
          {busy ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Saving…</> : 'Create order'}
        </Button>
      </>}>
      {active.length === 0 && <ErrorNote message="No suppliers yet. Add one in Supplier Details first." />}
      <label className="block">
        <FieldLabel>Supplier</FieldLabel>
        <select className={CONTROL} value={supplierId} disabled={busy} onChange={(e) => { setSupplierId(e.target.value); setError(null) }}>
          <option value="">Choose a supplier…</option>
          {active.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </label>
      <div className="grid grid-cols-2 gap-3">
        <label className="block">
          <FieldLabel>Order date</FieldLabel>
          <input type="date" className={CONTROL} value={orderDate} max={todayInColombo()} disabled={busy} onChange={(e) => setOrderDate(e.target.value)} />
        </label>
        <label className="block">
          <FieldLabel hint="optional">Expected</FieldLabel>
          <input type="date" className={CONTROL} value={expected} min={orderDate} disabled={busy} onChange={(e) => setExpected(e.target.value)} />
        </label>
      </div>

      {lines.map((l, i) => {
        const p = byId.get(l.productId)
        return (
          <section key={l.key} className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card space-y-3">
            <div className="flex items-center">
              <h3 className="text-[14px] font-bold">Item {i + 1}</h3>
              {lines.length > 1 && (
                <button type="button" aria-label={`Remove item ${i + 1}`} disabled={busy}
                  onClick={() => setLines((prev) => prev.filter((x) => x.key !== l.key))}
                  className="focus-ring ml-auto flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground hover:bg-red-500/10 hover:text-red-500">
                  <Trash2 size={15} />
                </button>
              )}
            </div>
            <select aria-label="Product" className={CONTROL} value={l.productId} disabled={busy}
              onChange={(e) => update(l.key, { productId: e.target.value, variantId: '' })}>
              <option value="">Choose a product…</option>
              {products.map((o) => <option key={o.id} value={o.id}>{o.name}{o.categoryName ? ` · ${o.categoryName}` : ''}</option>)}
            </select>
            {p && p.variants.length > 0 && (
              <select aria-label="Variant" className={CONTROL} value={l.variantId} disabled={busy} onChange={(e) => update(l.key, { variantId: e.target.value })}>
                <option value="">Choose colour / storage…</option>
                {p.variants.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
              </select>
            )}
            <div className="grid grid-cols-2 gap-3">
              <label className="block"><FieldLabel>Quantity</FieldLabel>
                <input type="number" inputMode="numeric" min={1} className={cn(CONTROL, 'tabular-nums')} value={l.quantity} disabled={busy}
                  onChange={(e) => update(l.key, { quantity: e.target.value })} /></label>
              <label className="block"><FieldLabel hint="Rs., per unit">Cost price</FieldLabel>
                <input inputMode="decimal" className={cn(CONTROL, 'tabular-nums')} value={l.cost} disabled={busy || l.costPending}
                  onChange={(e) => update(l.key, { cost: e.target.value })} /></label>
            </div>
            <CheckboxField id={`po-pending-${l.key}`} label="Cost pending (not known yet)" checked={l.costPending} disabled={busy}
              onChange={(v) => update(l.key, { costPending: v, cost: v ? '' : l.cost })} />
          </section>
        )
      })}
      <Button variant="secondary" fullWidth disabled={busy || lines.length >= 100} onClick={() => setLines((prev) => [...prev, emptyLine()])}>
        <Plus size={15} className="mr-1.5" /> Add another product
      </Button>
      <TextAreaField id="po-note" label="Note (optional)" rows={2} value={note} disabled={busy} onChange={setNote} />
      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}

function PoView({ poId, canManage, onClose, onReceive, onChanged }: {
  poId: string
  canManage: boolean
  onClose: () => void
  onReceive: () => void
  onChanged: (message: string) => void
}) {
  const [detail, setDetail] = useState<PurchaseOrderDetail | null>(null)
  const [poCost, setPoCost] = useState<CostRow | null>(null)
  const [lineCosts, setLineCosts] = useState<Map<string, CostRow>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [closing, setClosing] = useState(false)
  const [closeNote, setCloseNote] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let cancelled = false
    Promise.all([
      loadPurchaseOrder(poId),
      canManage ? loadCosts('po', [poId]) : Promise.resolve(new Map<string, CostRow>()),
      canManage ? loadCosts('po_line', [poId]) : Promise.resolve(new Map<string, CostRow>()),
    ])
      .then(([d, c, l]) => { if (!cancelled) { setDetail(d); setPoCost(c.get(poId) ?? null); setLineCosts(l) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load this order.')) })
    return () => { cancelled = true }
  }, [poId, canManage])

  async function close() {
    if (closeNote.trim().length < 3) { setError('Add a short note (why it is closed).'); return }
    setBusy(true)
    setError(null)
    try {
      const r = await closePurchaseOrder(poId, closeNote.trim())
      onChanged(`${detail?.po.po_number} ${r.status === 'cancelled' ? 'cancelled' : 'closed'}.`)
      onClose()
    } catch (err) {
      setError(describePurchasingError(err, 'The order could not be closed.'))
      setBusy(false)
    }
  }

  const open = detail && isPoReceivable(detail.po.status)

  return (
    <AdminDrawer title={detail?.po.po_number ?? 'Purchase order'} subtitle={detail ? `${detail.po.supplierName} · ${formatDate(detail.po.order_date)}` : undefined}
      onClose={busy ? () => {} : onClose}
      footer={canManage && open && !closing ? <>
        <Button variant="ghost" onClick={() => setClosing(true)}><Ban size={15} className="mr-1.5" /> Close order</Button>
        <Button onClick={onReceive}><PackagePlus size={15} className="mr-1.5" /> Receive goods</Button>
      </> : undefined}>
      {!detail && !error && <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>}
      {detail && (
        <>
          <div className="flex flex-wrap items-center gap-2">
            <PoStatusPill status={detail.po.status} />
            {detail.po.expected_date && <span className="text-[12.5px] text-muted-foreground">Expected {formatDate(detail.po.expected_date)}</span>}
          </div>
          <section className="rounded-[22px] border border-mint/80 dark:border-border bg-surface shadow-card overflow-hidden">
            <table className="w-full text-[13px]">
              <thead><tr className="border-b border-mint/70 dark:border-border bg-muted/60 text-[11px] uppercase tracking-[0.08em] text-muted-foreground">
                <th className="px-3 py-2.5 text-left">Item</th><th className="px-3 py-2.5 text-right">Ordered</th>
                <th className="px-3 py-2.5 text-right">Accepted</th><th className="px-3 py-2.5 text-right">Rejected</th>
                {canManage && <th className="px-3 py-2.5 text-right">Cost</th>}
              </tr></thead>
              <tbody>
                {detail.lines.map((l) => (
                  <tr key={l.id} className="border-b border-mint/50 dark:border-border/70 last:border-0">
                    <td className="px-3 py-2.5"><span className="block font-semibold">{l.product_name_snapshot}</span>
                      {l.variant_label_snapshot && <span className="block text-[11.5px] text-muted-foreground">{l.variant_label_snapshot}</span>}</td>
                    <td className="px-3 py-2.5 text-right tabular-nums">{l.quantity}</td>
                    <td className={cn('px-3 py-2.5 text-right tabular-nums', l.received_quantity < l.quantity ? 'text-amber-600 dark:text-amber-400' : 'text-primary')}>{l.received_quantity}</td>
                    <td className="px-3 py-2.5 text-right tabular-nums text-muted-foreground">{l.rejected_quantity}</td>
                    {canManage && (
                      <td className="px-3 py-2.5 text-right tabular-nums whitespace-nowrap">
                        {lineCosts.get(l.id)?.cents == null ? 'Pending' : formatRupeesFromCents(lineCosts.get(l.id)?.cents ?? 0)}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
            {canManage && poCost && (
              <div className="flex justify-between border-t border-mint/70 dark:border-border px-3 py-2.5 font-bold">
                <span>Total{poCost.pending ? ' (some costs pending)' : ''}</span><span className="tabular-nums">{formatRupeesFromCents(poCost.cents ?? 0)}</span>
              </div>
            )}
          </section>
          {detail.po.note && <p className="text-[13px]"><span className="text-muted-foreground">Note: </span>{detail.po.note}</p>}
          {detail.po.close_note && <p className="text-[13px]"><span className="text-muted-foreground">Closed: </span>{detail.po.close_note}</p>}
          <section className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
            <h3 className="mb-2 text-[14px] font-bold">Deliveries (GRN)</h3>
            {detail.grns.length === 0 ? <p className="text-[12.5px] text-muted-foreground">Nothing received yet.</p> : (
              <ul className="space-y-1.5 text-[13px]">
                {detail.grns.map((g) => <li key={g.id} className="flex justify-between"><span className="font-semibold">{g.grn_number}</span><span className="text-muted-foreground">{formatDate(g.received_on)} · {g.total_units} units</span></li>)}
              </ul>
            )}
          </section>
          {closing && (
            <section className="space-y-3 rounded-[22px] border border-red-500/25 bg-red-500/5 p-4">
              <p className="text-[13px]">
                {detail.lines.some((l) => l.received_quantity > 0)
                  ? 'Close this order: what has arrived stays, the rest will not be expected any more.'
                  : 'Nothing has arrived, so this order will be cancelled.'}
              </p>
              <textarea rows={2} value={closeNote} disabled={busy} onChange={(e) => setCloseNote(e.target.value)} placeholder="Why? (required)" className={CONTROL} />
              <div className="flex gap-2">
                <Button variant="ghost" onClick={() => setClosing(false)} disabled={busy}>Back</Button>
                <Button onClick={() => void close()} disabled={busy}>{busy ? 'Saving…' : 'Confirm'}</Button>
              </div>
            </section>
          )}
        </>
      )}
      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}
