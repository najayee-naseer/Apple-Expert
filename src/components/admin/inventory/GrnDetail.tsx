"use client"

import { useCallback, useEffect, useState } from 'react'
import { LoaderCircle } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import {
  loadGrn, loadCosts, describeUnitError, formatDate, newRequestId,
  type CostRow, type GrnDetail as GrnData, type GrnLineRow,
} from '@/lib/admin/units'
import { setGrnLineCost, correctGrnLine, describePurchasingError } from '@/lib/admin/purchasing'
import { ErrorNote, SuccessNote, parseRupees } from './shared'
import { QuantityLabelPanels, UnitLabelsPanel } from './LabelPanels'

const CONTROL =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-sm text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

/** One GRN: what arrived, what was accepted or refused, its units and their labels. */
export function GrnDetail({ grnId, showMoney, justPosted, onClose, onChanged }: {
  grnId: string
  /** Owner/admin. Staff are refused by the database, so they are never asked. */
  showMoney: boolean
  /** Shown once, right after posting. */
  justPosted?: string | null
  onClose: () => void
  onChanged?: () => void
}) {
  const [data, setData] = useState<GrnData | null>(null)
  const [grnCost, setGrnCost] = useState<CostRow | null>(null)
  const [lineCosts, setLineCosts] = useState<Map<string, CostRow>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [action, setAction] = useState<{ kind: 'cost' | 'correct'; line: GrnLineRow } | null>(null)

  const fetchAll = useCallback(async () => {
    const [d, grnCosts, lines] = await Promise.all([
      loadGrn(grnId),
      showMoney ? loadCosts('grn', [grnId]) : Promise.resolve(new Map<string, CostRow>()),
      showMoney ? loadCosts('grn_line', [grnId]) : Promise.resolve(new Map<string, CostRow>()),
    ])
    return { d, grnCost: grnCosts.get(grnId) ?? null, lines }
  }, [grnId, showMoney])

  const reload = useCallback(() => {
    fetchAll()
      .then((r) => { setData(r.d); setGrnCost(r.grnCost); setLineCosts(r.lines) })
      .catch((err) => setError(describeUnitError(err, 'Could not load this GRN.')))
  }, [fetchAll])

  useEffect(() => {
    let cancelled = false
    fetchAll()
      .then((r) => { if (!cancelled) { setData(r.d); setGrnCost(r.grnCost); setLineCosts(r.lines) } })
      .catch((err) => { if (!cancelled) setError(describeUnitError(err, 'Could not load this GRN.')) })
    return () => { cancelled = true }
  }, [fetchAll])

  return (
    <AdminDrawer
      title={data ? data.grn.grn_number : 'GRN'}
      subtitle={data ? `${data.grn.supplier_name} · ${formatDate(data.grn.received_on)}` : undefined}
      onClose={onClose}
    >
      {justPosted && <SuccessNote message={justPosted} />}
      {notice && <SuccessNote message={notice} />}
      {error && <ErrorNote message={error} />}
      {!data && !error && (
        <div className="flex items-center justify-center gap-2 py-12 text-sm text-muted-foreground">
          <LoaderCircle size={17} className="animate-spin motion-reduce:animate-none" /> Loading…
        </div>
      )}

      {data && (
        <>
          <dl className="grid grid-cols-2 gap-3 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 text-[13px] shadow-card">
            <div><dt className="text-muted-foreground text-[11.5px]">Accepted</dt><dd className="font-bold tabular-nums">{data.grn.total_units}</dd></div>
            <div><dt className="text-muted-foreground text-[11.5px]">Rejected</dt><dd className="font-bold tabular-nums">{data.grn.rejected_units}</dd></div>
            {showMoney && grnCost && (
              <div className="col-span-2">
                <dt className="text-muted-foreground text-[11.5px]">Amount owed for this GRN</dt>
                <dd className="font-bold tabular-nums">
                  {formatPrice(centsToRupees(grnCost.cents ?? 0))}
                  {grnCost.pending && <span className="ml-2 text-[12px] font-semibold text-amber-600 dark:text-amber-400">some costs still pending</span>}
                </dd>
              </div>
            )}
            <div><dt className="text-muted-foreground text-[11.5px]">Supplier invoice</dt><dd>{data.grn.supplier_invoice || '—'}</dd></div>
            <div><dt className="text-muted-foreground text-[11.5px]">Received on</dt><dd>{formatDate(data.grn.received_on)}</dd></div>
            {data.grn.note && <div className="col-span-2"><dt className="text-muted-foreground text-[11.5px]">Note</dt><dd>{data.grn.note}</dd></div>}
            {data.grn.duplicate_invoice_note && <div className="col-span-2"><dt className="text-muted-foreground text-[11.5px]">Confirmed as same invoice</dt><dd>{data.grn.duplicate_invoice_note}</dd></div>}
          </dl>

          <section className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card space-y-3">
            <h3 className="text-[14px] font-bold text-foreground">Products</h3>
            {data.lines.map((l) => {
              const cost = lineCosts.get(l.id)
              return (
                <div key={l.id} className="space-y-1 border-b border-mint/50 dark:border-border/70 pb-3 last:border-0 last:pb-0 text-[13px]">
                  <div className="flex items-baseline justify-between gap-3">
                    <span className="min-w-0">
                      <span className="block font-semibold text-foreground truncate">{l.product_name_snapshot}</span>
                      {l.variant_label_snapshot && <span className="block text-[11.5px] text-muted-foreground">{l.variant_label_snapshot}</span>}
                    </span>
                    <span className="shrink-0 text-right tabular-nums">
                      <span className="block font-semibold">{l.accepted_quantity} accepted</span>
                      {showMoney && cost && (
                        <span className="block text-[11.5px] text-muted-foreground">
                          {cost.cents === null ? 'cost pending' : `${formatPrice(centsToRupees(cost.cents))} each`}
                        </span>
                      )}
                    </span>
                  </div>
                  <p className="text-[11.5px] text-muted-foreground tabular-nums">
                    {l.ordered_quantity !== null && <>Due on PO {l.ordered_quantity} · </>}
                    Received {l.received_quantity}
                    {l.rejected_quantity > 0 && <> · Rejected {l.rejected_quantity}: {l.rejection_reason}</>}
                    {l.corrected_quantity > 0 && <> · Corrected out {l.corrected_quantity}</>}
                    {l.returned_quantity > 0 && <> · Returned {l.returned_quantity}</>}
                  </p>
                  {showMoney && (
                    <div className="flex gap-3 pt-0.5">
                      <button type="button" className="focus-ring rounded text-[12px] font-semibold text-primary"
                        onClick={() => { setNotice(null); setAction({ kind: 'cost', line: l }) }}>
                        {cost?.cents === null ? 'State cost' : 'Correct cost'}
                      </button>
                      {l.accepted_quantity - l.corrected_quantity - l.returned_quantity > 0 && (
                        <button type="button" className="focus-ring rounded text-[12px] font-semibold text-primary"
                          onClick={() => { setNotice(null); setAction({ kind: 'correct', line: l }) }}>
                          Received by mistake
                        </button>
                      )}
                    </div>
                  )}
                </div>
              )
            })}
          </section>

          {action?.kind === 'cost' && (
            <CostForm line={action.line} onClose={() => setAction(null)}
              onDone={() => { setAction(null); setNotice('Cost saved.'); reload(); onChanged?.() }} />
          )}
          {action?.kind === 'correct' && (
            <CorrectionForm line={action.line} units={data.units.filter((u) => u.grn_line_id === action.line.id && u.status === 'in_stock')}
              onClose={() => setAction(null)}
              onDone={() => { setAction(null); setNotice('Correction saved: stock, the purchase order and what is owed were updated.'); reload(); onChanged?.() }} />
          )}

          {data.units.length > 0 && <UnitLabelsPanel units={data.units} lines={data.lines} grnNumber={data.grn.grn_number} />}
          {data.lines.some((l) => l.tracking_mode_snapshot === 'quantity') && (
            <QuantityLabelPanels lines={data.lines.filter((l) => l.tracking_mode_snapshot === 'quantity')} grnNumber={data.grn.grn_number} />
          )}
        </>
      )}
    </AdminDrawer>
  )
}

function CostForm({ line, onClose, onDone }: { line: GrnLineRow; onClose: () => void; onDone: () => void }) {
  const [cost, setCost] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    const cents = cost.trim() === '' ? null : parseRupees(cost)
    if (cents === null) { setError('Enter the unit cost in rupees.'); return }
    if (note.trim().length < 3) { setError('Add a note: it is kept with the change.'); return }
    setBusy(true)
    setError(null)
    try {
      await setGrnLineCost(line.id, cents, note.trim())
      onDone()
    } catch (err) {
      setError(describePurchasingError(err, 'The cost could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <section className="space-y-2.5 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
      <h3 className="text-[14px] font-bold text-foreground">Unit cost · {line.product_name_snapshot}</h3>
      <input inputMode="decimal" aria-label="Unit cost in rupees" placeholder="Rs., per unit" className={CONTROL} value={cost} disabled={busy} onChange={(e) => setCost(e.target.value)} />
      <input aria-label="Note" placeholder="Note (required)" className={CONTROL} value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} />
      {error && <ErrorNote message={error} />}
      <div className="flex gap-2">
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Save cost'}</Button>
      </div>
    </section>
  )
}

function CorrectionForm({ line, units, onClose, onDone }: {
  line: GrnLineRow
  /** This line's units still on the shelf. */
  units: GrnData['units']
  onClose: () => void
  onDone: () => void
}) {
  const [requestId] = useState(newRequestId)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [quantity, setQuantity] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isUnit = line.tracking_mode_snapshot === 'unit'

  async function submit() {
    if (note.trim().length < 3) { setError('Say what went wrong: it is kept with the correction.'); return }
    if (isUnit && selected.size === 0) { setError('Choose the units received by mistake.'); return }
    if (!isUnit && !/^[1-9]\d*$/.test(quantity.trim())) { setError('Enter how many were received by mistake.'); return }
    setBusy(true)
    setError(null)
    try {
      await correctGrnLine({
        lineId: line.id,
        unitIds: isUnit ? [...selected] : null,
        quantity: isUnit ? null : Number(quantity),
        note: note.trim(),
        requestId,
      })
      onDone()
    } catch (err) {
      setError(describePurchasingError(err, 'The correction could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <section className="space-y-2.5 rounded-[22px] border border-red-500/25 bg-red-500/5 p-4">
      <h3 className="text-[14px] font-bold text-foreground">Received by mistake · {line.product_name_snapshot}</h3>
      <p className="text-[12px] text-muted-foreground">These leave stock, come off the purchase order, and are no longer owed. The IMEI can be received again correctly.</p>
      {isUnit ? (
        units.length === 0
          ? <p className="text-[12.5px] text-muted-foreground">None of this line&apos;s units are on the shelf, so none can be corrected here.</p>
          : (
            <ul className="max-h-48 space-y-1.5 overflow-y-auto text-[13px]">
              {units.map((u) => (
                <li key={u.id}>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" checked={selected.has(u.id)} disabled={busy}
                      onChange={(e) => setSelected((prev) => {
                        const next = new Set(prev)
                        if (e.target.checked) next.add(u.id); else next.delete(u.id)
                        return next
                      })} />
                    <span className="font-mono">{u.barcode}</span>
                    {u.serial_number && <span className="truncate text-[11.5px] text-muted-foreground">{u.serial_number}</span>}
                  </label>
                </li>
              ))}
            </ul>
          )
      ) : (
        <input type="number" inputMode="numeric" min={1} aria-label="Quantity" placeholder="How many" className={CONTROL} value={quantity} disabled={busy} onChange={(e) => setQuantity(e.target.value)} />
      )}
      <input aria-label="Note" placeholder="What went wrong (required)" className={CONTROL} value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} />
      {error && <ErrorNote message={error} />}
      <div className="flex gap-2">
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Save correction'}</Button>
      </div>
    </section>
  )
}
