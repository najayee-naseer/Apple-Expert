"use client"

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Search, LoaderCircle, Boxes, Ban, ShieldAlert, ShieldCheck } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { ErrorNote, SuccessNote, PrintLabels, UnitStatusBadge, TH, TABLE_CARD, SELECT_CLASS } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { unitToLabel } from '@/lib/admin/labels'
import {
  listUnits, loadInventoryDashboard, listProductsForGrn, expirePendingOrders, writeOffUnits, quarantineUnits,
  releaseQuarantineUnits, canReceiveStock, describeUnitError, formatDate, UNIT_STATUSES, UNIT_STATUS_LABEL, UNIT_FETCH_LIMIT,
  type UnitView, type DashboardRow, type UnitStatus, type GrnProductOption,
} from '@/lib/admin/units'
import {
  listQuarantineLots, resolveQuarantineLot, listOpenStockFlags, resolveStockFlag,
  type QuarantineLot, type ReconciliationFlag,
} from '@/lib/admin/returns'

type Tab = 'summary' | 'units' | 'quarantine'
type StatusFilter = 'all' | 'out' | 'low' | 'serialised' | 'shared' | 'own'

const STATUS_FILTERS: { value: StatusFilter; label: string }[] = [
  { value: 'all', label: 'All stock' },
  { value: 'out', label: 'Out of stock' },
  { value: 'low', label: 'Low stock' },
  { value: 'serialised', label: 'Individually tracked' },
  { value: 'shared', label: 'Shared stock' },
  { value: 'own', label: 'Own-stock variants' },
]

const SCOPE_LABEL: Record<DashboardRow['stockScope'], string> = {
  product: 'Product',
  shared: 'Shared pool',
  own: 'Own stock',
}

/**
 * Every figure here comes from one database function, for quantity-tracked and
 * individually tracked items alike. Totals only add up its rows; nothing is
 * derived independently on this screen.
 */
export default function AdminInventoryPage() {
  const { role } = useAdminAuth()
  const isAdmin = canReceiveStock(role)
  const [tab, setTab] = useState<Tab>('summary')

  const [products, setProducts] = useState<GrnProductOption[]>([])
  const [rows, setRows] = useState<DashboardRow[] | null>(null)
  const [summaryError, setSummaryError] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [query, setQuery] = useState('')
  const [lots, setLots] = useState<QuarantineLot[]>([])
  const [flags, setFlags] = useState<ReconciliationFlag[]>([])

  const [status, setStatus] = useState<UnitStatus | 'all'>('in_stock')
  const [productId, setProductId] = useState('')
  const [code, setCode] = useState('')
  const [units, setUnits] = useState<UnitView[] | null>(null)
  const [unitsError, setUnitsError] = useState<string | null>(null)
  const [selected, setSelected] = useState<Set<string>>(new Set())

  const [action, setAction] = useState<null
    | { kind: 'write_off' | 'quarantine' | 'release' }
    | { kind: 'lot'; lot: QuarantineLot }
    | { kind: 'flag'; flag: ReconciliationFlag }>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const loadSummary = useCallback(async () => {
    // Overdue online holds are released first, so the figures below are current.
    await expirePendingOrders().catch(() => 0)
    const [p, r, l, f] = await Promise.all([listProductsForGrn(), loadInventoryDashboard(), listQuarantineLots(), listOpenStockFlags()])
    return [p, r, l, f] as const
  }, [])

  useEffect(() => {
    let cancelled = false
    loadSummary()
      .then(([p, r, l, f]) => { if (!cancelled) { setProducts(p); setRows(r); setLots(l); setFlags(f) } })
      .catch((err) => { if (!cancelled) setSummaryError(describeUnitError(err, 'Could not load stock.')) })
    return () => { cancelled = true }
  }, [loadSummary])

  const searchUnits = useCallback(() => {
    setUnitsError(null)
    setSelected(new Set())
    listUnits({ status, productId: productId || null, code })
      .then(setUnits)
      .catch((err) => setUnitsError(describeUnitError(err, 'Could not load units.')))
  }, [status, productId, code])

  // Status / product filters apply straight away; the code box on Enter.
  useEffect(() => {
    if (tab === 'summary') return
    const effective = tab === 'quarantine' ? 'quarantined' : status
    let cancelled = false
    listUnits({ status: effective, productId: tab === 'quarantine' ? null : productId || null, code: '' })
      .then((found) => { if (!cancelled) { setUnits(found); setSelected(new Set()); setUnitsError(null) } })
      .catch((err) => { if (!cancelled) setUnitsError(describeUnitError(err, 'Could not load units.')) })
    return () => { cancelled = true }
  }, [tab, status, productId])

  function refreshAll() {
    if (tab === 'quarantine') {
      listUnits({ status: 'quarantined', productId: null, code: '' }).then((found) => { setUnits(found); setSelected(new Set()) }).catch(() => {})
    } else if (tab === 'units') {
      searchUnits()
    }
    loadSummary().then(([p, r, l, f]) => { setProducts(p); setRows(r); setLots(l); setFlags(f) }).catch(() => {})
  }

  const selectedUnits = useMemo(() => (units ?? []).filter((u) => selected.has(u.id)), [units, selected])
  const shelf = selectedUnits.filter((u) => u.status === 'in_stock')
  const quarantined = selectedUnits.filter((u) => u.status === 'quarantined')
  const writable = [...shelf, ...quarantined]

  function showUnitsFor(row: DashboardRow) {
    setProductId(row.productId)
    setStatus('in_stock')
    setCode('')
    setTab('units')
  }

  const visibleRows = useMemo(() => {
    const q = query.trim().toLowerCase()
    return (rows ?? []).filter((r) => {
      if (q && !`${r.productName} ${r.variantName ?? ''}`.toLowerCase().includes(q)) return false
      switch (statusFilter) {
        case 'out': return r.stockStatus === 'out'
        case 'low': return r.stockStatus === 'low'
        case 'serialised': return r.trackingMode === 'unit'
        case 'shared': return r.stockScope === 'shared'
        case 'own': return r.stockScope === 'own'
        default: return true
      }
    })
  }, [rows, query, statusFilter])

  const totals = (rows ?? []).reduce((t, r) => ({
    onHand: t.onHand + r.onHand,
    available: t.available + r.available,
    reserved: t.reserved + r.reserved,
    sold: t.sold + r.sold,
    quarantined: t.quarantined + r.quarantined,
    returned: t.returned + r.returnedToSupplier,
    serialised: t.serialised + r.serialisedUnits,
    low: t.low + (r.stockStatus === 'low' ? 1 : 0),
    out: t.out + (r.stockStatus === 'out' ? 1 : 0),
    shared: t.shared + (r.stockScope === 'shared' ? 1 : 0),
    own: t.own + (r.stockScope === 'own' ? 1 : 0),
  }), { onHand: 0, available: 0, reserved: 0, sold: 0, quarantined: 0, returned: 0, serialised: 0, low: 0, out: 0, shared: 0, own: 0 })

  const quarantineCount = (units && tab === 'quarantine' ? units.length : 0) + lots.length

  return (
    <>
      <AdminPageHeading title="Inventory"
        subtitle="What is in the shop, held for online orders, sold, in quarantine or back with suppliers. Oldest stock goes out first." />

      <div role="tablist" className="mb-4 inline-flex max-w-full overflow-x-auto rounded-full border border-mint-deep dark:border-border bg-card p-1">
        {([['summary', 'Stock by product'], ['units', 'Units & barcodes'], ['quarantine', 'Quarantine']] as const).map(([value, label]) => (
          <button key={value} type="button" role="tab" aria-selected={tab === value} onClick={() => setTab(value)}
            className={cn('focus-ring whitespace-nowrap rounded-full px-4 py-2 text-[13px] font-semibold transition',
              tab === value ? 'bg-primary text-white' : 'text-muted-foreground hover:text-foreground')}>
            {label}
          </button>
        ))}
      </div>

      {notice && <SuccessNote message={notice} className="mb-4" />}

      {flags.length > 0 && (
        <section className="mb-4 space-y-2 rounded-[22px] border border-amber-500/30 bg-amber-500/8 p-4">
          <h2 className="text-[14px] font-bold text-foreground">Needs reconciliation ({flags.length})</h2>
          <p className="text-[12px] text-muted-foreground">Pre-rollout orders that shipped when stock on record could not cover them. Nothing was deducted or guessed.</p>
          {flags.map((f) => (
            <div key={f.id} className="flex items-center justify-between gap-3 text-[13px]">
              <span className="min-w-0"><span className="font-semibold">{f.productId ?? 'Deleted product'} × {f.quantity}</span> <span className="text-muted-foreground">· {f.reason}</span></span>
              {isAdmin && <Button size="sm" variant="secondary" onClick={() => setAction({ kind: 'flag', flag: f })}>Resolve</Button>}
            </div>
          ))}
        </section>
      )}

      {tab === 'summary' && (
        <>
          {summaryError && <ErrorNote message={summaryError} />}
          {rows === null && !summaryError && (
            <div className="flex items-center justify-center gap-2.5 py-16 text-sm text-muted-foreground">
              <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading stock…
            </div>
          )}
          {rows && rows.length === 0 && (
            <div className="bg-surface border border-mint/80 dark:border-border rounded-[26px] shadow-card px-6 py-14 text-center">
              <span className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-well-strong border border-mint-deep text-primary"><Boxes size={24} /></span>
              <h2 className="text-lg font-bold mb-1.5">No products yet</h2>
              <p className="mx-auto max-w-md text-sm text-muted-foreground">Add products, then count or receive their stock.</p>
            </div>
          )}
          {rows && rows.length > 0 && (
            <>
              <dl className="mb-4 grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-6">
                {([
                  ['Total in shop', totals.onHand],
                  ['Available', totals.available],
                  ['Reserved', totals.reserved],
                  ['Sold', totals.sold],
                  ['Quarantine', totals.quarantined],
                  ['Back to supplier', totals.returned],
                ] as const).map(([label, value]) => (
                  <div key={label} className="rounded-[18px] border border-mint/80 dark:border-border bg-surface px-3.5 py-3 shadow-card">
                    <dt className="text-[11.5px] text-muted-foreground">{label}</dt>
                    <dd className="text-xl font-bold tabular-nums tracking-tight">{value.toLocaleString('en-US')}</dd>
                  </div>
                ))}
              </dl>
              <p className="mb-3 text-[12.5px] text-muted-foreground tabular-nums">
                {totals.low} low · {totals.out} out of stock · {totals.serialised} serialised units · {totals.shared} shared-stock · {totals.own} own-stock variants
              </p>
              <div className="mb-3 flex flex-col sm:flex-row gap-2.5">
                <input type="search" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search products" placeholder="Search products…"
                  className="focus-ring h-11 flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 text-sm placeholder:text-muted-foreground focus:outline-none focus:border-primary/45" />
                <select aria-label="Filter" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as StatusFilter)} className={SELECT_CLASS}>
                  {STATUS_FILTERS.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
                </select>
              </div>
              <div className={TABLE_CARD}>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-mint/70 dark:border-border bg-muted/60">
                        <th scope="col" className={TH}>Product</th>
                        <th scope="col" className={`${TH} text-right`}>In shop</th>
                        <th scope="col" className={`${TH} text-right`}>Available</th>
                        <th scope="col" className={`${TH} text-right`}>Reserved</th>
                        <th scope="col" className={`${TH} text-right`}>Sold</th>
                        <th scope="col" className={`${TH} text-right`}>Quarantine</th>
                        <th scope="col" className={`${TH} text-right`}>Returned</th>
                        <th scope="col" className={TH}>Oldest unit</th>
                        <th scope="col" className="px-4 py-3" />
                      </tr>
                    </thead>
                    <tbody>
                      {visibleRows.map((r) => (
                        <tr key={`${r.productId}:${r.variantId ?? ''}`} className="border-b border-mint/50 dark:border-border/70 last:border-0">
                          <td className="px-4 py-3 min-w-[200px]">
                            <span className="block font-semibold">{r.productName}</span>
                            {r.variantName && <span className="block text-[11.5px] text-muted-foreground">{r.variantName}</span>}
                            <span className="block text-[11px] text-muted-foreground">
                              {r.trackingMode === 'unit' ? 'Individually tracked' : 'Quantity tracked'} · {SCOPE_LABEL[r.stockScope]}{r.isActive ? '' : ' · hidden'}
                            </span>
                          </td>
                          <td className="px-4 py-3 text-right tabular-nums">{r.onHand}</td>
                          <td className={cn('px-4 py-3 text-right tabular-nums font-bold',
                            r.stockStatus === 'out' && 'text-red-600 dark:text-red-400',
                            r.stockStatus === 'low' && 'text-amber-600 dark:text-amber-400')}>{r.available}</td>
                          <td className="px-4 py-3 text-right tabular-nums">{r.reserved}</td>
                          <td className="px-4 py-3 text-right tabular-nums text-muted-foreground">{r.sold}</td>
                          <td className="px-4 py-3 text-right tabular-nums text-muted-foreground">{r.quarantined}</td>
                          <td className="px-4 py-3 text-right tabular-nums text-muted-foreground">{r.returnedToSupplier}</td>
                          <td className="px-4 py-3 whitespace-nowrap text-muted-foreground">{r.oldestReceivedOn ? formatDate(r.oldestReceivedOn) : '—'}</td>
                          <td className="px-4 py-3 text-right">
                            {r.trackingMode === 'unit' && <Button size="sm" variant="secondary" onClick={() => showUnitsFor(r)}>Units</Button>}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
              {visibleRows.length === 0 && <p className="py-8 text-center text-sm text-muted-foreground">Nothing matches.</p>}
            </>
          )}
        </>
      )}

      {tab !== 'summary' && (
        <>
          {tab === 'units' && (
            <div className="mb-4 flex flex-col lg:flex-row gap-2.5">
              <form className="relative flex-1" onSubmit={(e) => { e.preventDefault(); searchUnits() }}>
                <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-muted-foreground"><Search size={16} /></span>
                <input type="search" value={code} onChange={(e) => setCode(e.target.value)} aria-label="Find by barcode or IMEI"
                  placeholder="Scan or type a barcode / IMEI, then Enter"
                  className="focus-ring h-11 w-full rounded-xl border border-mint-deep dark:border-border bg-card pl-11 pr-3 font-mono text-sm placeholder:font-sans placeholder:text-muted-foreground focus:outline-none focus:border-primary/45" />
              </form>
              <select aria-label="Status" value={status} onChange={(e) => setStatus(e.target.value as UnitStatus | 'all')} className={SELECT_CLASS}>
                <option value="all">All statuses</option>
                {UNIT_STATUSES.map((s) => <option key={s} value={s}>{UNIT_STATUS_LABEL[s]}</option>)}
              </select>
              <select aria-label="Product" value={productId} onChange={(e) => setProductId(e.target.value)} className={cn(SELECT_CLASS, 'lg:max-w-[260px]')}>
                <option value="">All products</option>
                {products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
            </div>
          )}

          {tab === 'quarantine' && (
            <>
              <p className="mb-3 text-[12.5px] text-muted-foreground">
                Returned or doubtful items. They are not in stock and cannot be sold online or at the counter until a person verifies them.
                {quarantineCount === 0 && ' Nothing is waiting.'}
              </p>
              {lots.length > 0 && (
                <section className="mb-4 space-y-2.5 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
                  <h2 className="text-[14px] font-bold text-foreground">Returned quantity items</h2>
                  {lots.map((l) => (
                    <div key={l.id} className="flex items-center justify-between gap-3 text-[13px]">
                      <span className="min-w-0">
                        <span className="block font-semibold truncate">{l.productName}{l.variantName ? ` · ${l.variantName}` : ''} × {l.openQuantity}</span>
                        {l.note && <span className="block text-[11.5px] text-muted-foreground truncate">{l.note}</span>}
                      </span>
                      {isAdmin && <Button size="sm" variant="secondary" onClick={() => setAction({ kind: 'lot', lot: l })}>Decide</Button>}
                    </div>
                  ))}
                </section>
              )}
            </>
          )}

          {selectedUnits.length > 0 && (
            <div className="mb-4 space-y-3 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
              <p className="text-[13px] font-semibold">{selectedUnits.length} selected</p>
              <PrintLabels items={selectedUnits.map(unitToLabel)} fileName="unit-labels.pdf" label="Reprint labels" />
              {isAdmin && (
                <div className="flex flex-wrap gap-2">
                  {shelf.length > 0 && (
                    <Button variant="outline" onClick={() => setAction({ kind: 'quarantine' })}>
                      <ShieldAlert size={15} className="mr-1.5" /> Quarantine {shelf.length}
                    </Button>
                  )}
                  {quarantined.length > 0 && (
                    <Button variant="outline" onClick={() => setAction({ kind: 'release' })}>
                      <ShieldCheck size={15} className="mr-1.5" /> Verified: back to shelf ({quarantined.length})
                    </Button>
                  )}
                  <Button variant="outline" disabled={writable.length === 0} onClick={() => setAction({ kind: 'write_off' })}>
                    <Ban size={15} className="mr-1.5" /> Write off {writable.length}
                  </Button>
                </div>
              )}
            </div>
          )}

          {unitsError && <ErrorNote message={unitsError} />}
          {units === null && !unitsError && <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>}
          {units && units.length === 0 && tab === 'units' && <p className="py-10 text-center text-sm text-muted-foreground">No units match.</p>}
          {units && units.length > 0 && (
            <div className={TABLE_CARD}>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-mint/70 dark:border-border bg-muted/60">
                      <th scope="col" className="px-4 py-3 w-10">
                        <input type="checkbox" aria-label="Select all"
                          checked={units.length > 0 && selected.size === units.length}
                          onChange={(e) => setSelected(e.target.checked ? new Set(units.map((u) => u.id)) : new Set())} />
                      </th>
                      <th scope="col" className={TH}>Barcode</th>
                      <th scope="col" className={TH}>Item</th>
                      <th scope="col" className={TH}>Received</th>
                      <th scope="col" className={TH}>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {units.map((u) => (
                      <tr key={u.id} className="border-b border-mint/50 dark:border-border/70 last:border-0">
                        <td className="px-4 py-3">
                          <input type="checkbox" aria-label={`Select ${u.barcode}`} checked={selected.has(u.id)}
                            onChange={(e) => setSelected((prev) => {
                              const next = new Set(prev)
                              if (e.target.checked) next.add(u.id); else next.delete(u.id)
                              return next
                            })} />
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap">
                          <span className="block font-mono font-semibold">{u.barcode}</span>
                          {u.serial_number && <span className="block font-mono text-[11px] text-muted-foreground">{u.serial_number}</span>}
                        </td>
                        <td className="px-4 py-3 min-w-[180px]">
                          <span className="block">{u.productName}</span>
                          {u.variantName && <span className="block text-[11.5px] text-muted-foreground">{u.variantName}</span>}
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap text-muted-foreground">
                          <span className="block">{formatDate(u.received_on)}</span>
                          {u.grnNumber && <span className="block text-[11px]">{u.grnNumber}</span>}
                        </td>
                        <td className="px-4 py-3">
                          <UnitStatusBadge status={u.status} />
                          {u.status_note && <span className="mt-1 block max-w-[220px] truncate text-[11px] text-muted-foreground">{u.status_note}</span>}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
          {units && units.length >= UNIT_FETCH_LIMIT && (
            <p className="mt-3 text-[12px] text-muted-foreground">Showing the first {UNIT_FETCH_LIMIT}. Narrow by product or search a barcode.</p>
          )}
        </>
      )}

      {action && action.kind !== 'lot' && (
        <UnitActionDialog
          title={action.kind === 'write_off' ? `Write off ${writable.length} unit${writable.length === 1 ? '' : 's'}`
            : action.kind === 'quarantine' ? `Quarantine ${shelf.length} unit${shelf.length === 1 ? '' : 's'}`
            : action.kind === 'release' ? `Back to shelf: ${quarantined.length} unit${quarantined.length === 1 ? '' : 's'}`
            : 'Resolve reconciliation'}
          description={action.kind === 'write_off' ? 'The units leave the shop permanently (damaged or lost). The history is kept. A unit received by mistake is corrected on its GRN instead, which also corrects what is owed.'
            : action.kind === 'quarantine' ? 'The units leave sellable stock until someone verifies them.'
            : action.kind === 'release' ? 'You have checked these units and they can be sold again. They rejoin stock.'
            : 'Record what was done about this line. Stock is not changed here; use Adjust stock if the count needs correcting.'}
          withReason={action.kind === 'write_off'}
          onClose={() => setAction(null)}
          onConfirm={async (reason, note) => {
            if (action.kind === 'write_off') {
              const n = await writeOffUnits(writable.map((u) => u.id), reason, note)
              setNotice(`${n} unit${n === 1 ? '' : 's'} written off.`)
            } else if (action.kind === 'quarantine') {
              const n = await quarantineUnits(shelf.map((u) => u.id), note)
              setNotice(`${n} unit${n === 1 ? '' : 's'} moved to quarantine.`)
            } else if (action.kind === 'release') {
              const n = await releaseQuarantineUnits(quarantined.map((u) => u.id), note)
              setNotice(`${n} unit${n === 1 ? '' : 's'} back on the shelf.`)
            } else if (action.kind === 'flag') {
              await resolveStockFlag(action.flag.id, note)
              setNotice('Marked as resolved.')
            }
            setAction(null)
            refreshAll()
          }}
        />
      )}

      {action?.kind === 'lot' && (
        <LotDialog lot={action.lot} onClose={() => setAction(null)}
          onDone={() => { setAction(null); setNotice('Decision saved.'); refreshAll() }} />
      )}
    </>
  )
}

function UnitActionDialog({ title, description, withReason, onClose, onConfirm }: {
  title: string
  description: string
  withReason: boolean
  onClose: () => void
  onConfirm: (reason: 'damage' | 'correction', note: string) => Promise<void>
}) {
  const [reason, setReason] = useState<'damage' | 'correction'>('damage')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    const trimmed = note.trim()
    if (trimmed.length < 3 || trimmed.length > 500) { setError('Add a note of 3 to 500 characters.'); return }
    setBusy(true)
    setError(null)
    try {
      await onConfirm(reason, trimmed)
    } catch (err) {
      setError(describeUnitError(err, 'The change was not saved.'))
      setBusy(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
      <button type="button" aria-label="Cancel" onClick={busy ? undefined : onClose} className="absolute inset-0 bg-black/55 backdrop-blur-[2px]" />
      <div role="dialog" aria-modal="true" aria-label={title}
        className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float space-y-3.5">
        <div>
          <h3 className="text-lg font-bold tracking-tight">{title}</h3>
          <p className="mt-1 text-[13px] leading-snug text-muted-foreground">{description}</p>
        </div>
        {withReason && (
          <select aria-label="Reason" value={reason} disabled={busy} onChange={(e) => setReason(e.target.value as 'damage' | 'correction')} className={cn(SELECT_CLASS, 'w-full')}>
            <option value="damage">Damaged / lost</option>
            <option value="correction">Other correction</option>
          </select>
        )}
        <textarea rows={3} value={note} disabled={busy} onChange={(e) => { setNote(e.target.value); setError(null) }}
          placeholder="Note (required)"
          className="focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm focus:outline-none focus:border-primary/45" />
        {error && <ErrorNote message={error} />}
        <div className="flex gap-2.5">
          <Button variant="ghost" fullWidth onClick={onClose} disabled={busy}>Cancel</Button>
          <Button fullWidth onClick={() => void submit()} disabled={busy}>
            {busy ? <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" /> : 'Confirm'}
          </Button>
        </div>
      </div>
    </div>
  )
}

function LotDialog({ lot, onClose, onDone }: { lot: QuarantineLot; onClose: () => void; onDone: () => void }) {
  const [release, setRelease] = useState('')
  const [writeOff, setWriteOff] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    const r = release.trim() === '' ? 0 : Number(release)
    const w = writeOff.trim() === '' ? 0 : Number(writeOff)
    if (!Number.isInteger(r) || !Number.isInteger(w) || r < 0 || w < 0 || r + w === 0) { setError('Enter how many to release or write off.'); return }
    if (r + w > lot.openQuantity) { setError(`Only ${lot.openQuantity} are waiting.`); return }
    if (note.trim().length < 3) { setError('Add a note saying what you found.'); return }
    setBusy(true)
    setError(null)
    try {
      await resolveQuarantineLot(lot.id, lot.openQuantity, r, w, note.trim())
      onDone()
    } catch (err) {
      setError(describeUnitError(err, 'The decision was not saved.'))
      setBusy(false)
    }
  }

  const input = 'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm focus:outline-none focus:border-primary/45'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
      <button type="button" aria-label="Cancel" onClick={busy ? undefined : onClose} className="absolute inset-0 bg-black/55 backdrop-blur-[2px]" />
      <div role="dialog" aria-modal="true" aria-label="Quarantine decision"
        className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float space-y-3.5">
        <div>
          <h3 className="text-lg font-bold tracking-tight">{lot.productName}{lot.variantName ? ` · ${lot.variantName}` : ''}</h3>
          <p className="mt-1 text-[13px] text-muted-foreground">{lot.openQuantity} waiting. Released items rejoin stock; written-off items do not.</p>
        </div>
        <div className="grid grid-cols-2 gap-2.5">
          <input type="number" inputMode="numeric" min={0} aria-label="Release to stock" placeholder="Release" className={input} value={release} disabled={busy} onChange={(e) => setRelease(e.target.value)} />
          <input type="number" inputMode="numeric" min={0} aria-label="Write off" placeholder="Write off" className={input} value={writeOff} disabled={busy} onChange={(e) => setWriteOff(e.target.value)} />
        </div>
        <textarea rows={2} value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} placeholder="What you found (required)" className={input} />
        {error && <ErrorNote message={error} />}
        <div className="flex gap-2.5">
          <Button variant="ghost" fullWidth onClick={onClose} disabled={busy}>Cancel</Button>
          <Button fullWidth onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Confirm'}</Button>
        </div>
      </div>
    </div>
  )
}
