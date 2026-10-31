"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Eye, Plus, LoaderCircle, ScanBarcode, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import { TextAreaField, FieldLabel } from '@/components/admin/products/fields'
import { ListHeader, ListTable, RowAction, StatusPill, type Column } from '@/components/admin/purchasing/ListTable'
import { ErrorNote, SuccessNote } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { todayInColombo, formatDate, loadCosts, UNIT_STATUS_LABEL, type CostRow, type UnitStatus } from '@/lib/admin/units'
import {
  listSupplierReturns, loadSupplierReturnItems, createSupplierReturn, listSuppliers, findUnitForReturn,
  reverseSupplierReturn, listReturnableLines,
  canManagePurchasing, describePurchasingError, formatRupeesFromCents, returnTypeLabel, newRequestId, RETURN_TYPES,
  type SupplierReturnListItem, type SupplierReturnItemRow, type SupplierRow, type ReturnType, type ReturnUnit, type ReturnableLine,
} from '@/lib/admin/purchasing'

const CONTROL =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

export default function SupplierReturnsPage() {
  const { role } = useAdminAuth()
  const canManage = canManagePurchasing(role)

  const [rows, setRows] = useState<SupplierReturnListItem[] | null>(null)
  const [suppliers, setSuppliers] = useState<SupplierRow[]>([])
  const [costs, setCosts] = useState<Map<string, CostRow>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [creating, setCreating] = useState(false)
  const [viewing, setViewing] = useState<SupplierReturnListItem | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const load = useCallback(async () => {
    const [r, s] = await Promise.all([listSupplierReturns(), listSuppliers()])
    // Return values come separately: staff are refused them by the database.
    const c = canManage ? await loadCosts('supplier_return', r.map((x) => x.id)) : new Map<string, CostRow>()
    return [r, s, c] as const
  }, [canManage])
  const refresh = useCallback(() => {
    load().then(([r, s, c]) => { setRows(r); setSuppliers(s); setCosts(c); setError(null) })
      .catch((err) => setError(describePurchasingError(err, 'Could not load supplier returns.')))
  }, [load])

  useEffect(() => {
    let cancelled = false
    load()
      .then(([r, s, c]) => { if (!cancelled) { setRows(r); setSuppliers(s); setCosts(c) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load supplier returns.')) })
    return () => { cancelled = true }
  }, [load])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return (rows ?? []).filter((r) => !q || r.return_number.toLowerCase().includes(q) || r.supplierName.toLowerCase().includes(q))
  }, [rows, search])

  const columns: Column<SupplierReturnListItem>[] = [
    { key: 'id', header: 'Return ID', render: (r) => <span className="font-semibold whitespace-nowrap">{r.return_number}</span> },
    { key: 'supplier', header: 'Supplier', render: (r) => <span className="block min-w-[150px]">{r.supplierName}</span> },
    { key: 'date', header: 'Date', render: (r) => <span className="whitespace-nowrap">{formatDate(r.return_date)}</span> },
    { key: 'type', header: 'Return Type', render: (r) => r.reversed_at
      ? <StatusPill label="Reversed" tone="red" />
      : <StatusPill label={returnTypeLabel(r.return_type)} tone={r.return_type === 'cash' ? 'green' : 'blue'} /> },
    { key: 'items', header: 'Items', align: 'right', render: (r) => <span className="tabular-nums">{r.total_units}</span> },
    ...(canManage ? [{
      key: 'total', header: 'Value', align: 'right' as const,
      render: (r: SupplierReturnListItem) => <span className="tabular-nums whitespace-nowrap">{formatRupeesFromCents(costs.get(r.id)?.cents ?? 0)}</span>,
    }] : []),
    { key: 'actions', header: 'Actions', align: 'right', render: (r) => <RowAction label="View" onClick={() => setViewing(r)}><Eye size={16} /></RowAction> },
  ]

  return (
    <>
      <ListHeader title="Supplier Returns" crumb="View" search={search} onSearch={setSearch}
        searchPlaceholder="Search returns…"
        action={canManage && <Button onClick={() => setCreating(true)} disabled={rows === null}><Plus size={16} className="mr-1.5" /> New Return</Button>} />

      {notice && <SuccessNote message={notice} className="mb-4" />}

      <ListTable columns={columns} rows={filtered} rowKey={(r) => r.id} loading={rows === null && !error} error={error}
        empty={rows?.length ? 'No returns match.' : 'No supplier returns yet.'} onRowClick={setViewing} />

      {creating && (
        <ReturnCreator suppliers={suppliers} onClose={() => setCreating(false)}
          onCreated={(msg) => { setCreating(false); setNotice(msg); refresh() }} />
      )}
      {viewing && (
        <ReturnView ret={viewing} total={costs.get(viewing.id)?.cents ?? null} canManage={canManage} onClose={() => setViewing(null)}
          onReversed={(msg) => { setViewing(null); setNotice(msg); refresh() }} />
      )}
    </>
  )
}

function ReturnCreator({ suppliers, onClose, onCreated }: {
  suppliers: SupplierRow[]
  onClose: () => void
  onCreated: (message: string) => void
}) {
  const [requestId] = useState(newRequestId)
  const [supplierId, setSupplierId] = useState('')
  const [returnDate, setReturnDate] = useState(todayInColombo)
  const [returnType, setReturnType] = useState<ReturnType>('credit')
  const [note, setNote] = useState('')
  const [items, setItems] = useState<ReturnUnit[]>([])
  const [itemCosts, setItemCosts] = useState<Map<string, CostRow>>(new Map())
  const [returnable, setReturnable] = useState<ReturnableLine[]>([])
  const [quantities, setQuantities] = useState<Record<string, string>>({})
  const [code, setCode] = useState('')
  const [scanning, setScanning] = useState(false)
  const [scanError, setScanError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const scanRef = useRef<HTMLInputElement>(null)

  const supplier = suppliers.find((s) => s.id === supplierId)
  const total = items.reduce((sum, u) => sum + (itemCosts.get(u.id)?.cents ?? 0), 0)
  const quantityLines = returnable
    .map((l) => ({ grnLineId: l.id, quantity: Number(quantities[l.id] ?? 0) }))
    .filter((l) => Number.isInteger(l.quantity) && l.quantity > 0)

  useEffect(() => {
    if (!supplierId) return
    let cancelled = false
    listReturnableLines(supplierId)
      .then((rows) => { if (!cancelled) setReturnable(rows) })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load this supplier\'s deliveries.')) })
    return () => { cancelled = true }
  }, [supplierId])

  async function scan() {
    const value = code.trim()
    if (!value) return
    setScanError(null)
    if (!supplierId) { setScanError('Choose the supplier first.'); return }
    setScanning(true)
    try {
      const unit = await findUnitForReturn(value)
      if (!unit) setScanError(`No item with barcode or IMEI ${value.toUpperCase()}.`)
      else if (items.some((u) => u.id === unit.id)) setScanError(`${unit.barcode} is already on this return.`)
      else if (unit.status !== 'in_stock' && unit.status !== 'quarantined') setScanError(`${unit.barcode} is ${(UNIT_STATUS_LABEL[unit.status as UnitStatus] ?? unit.status.replace(/_/g, ' ')).toLowerCase()} — only items on the shelf or in quarantine can be returned.`)
      else if (unit.grnSupplierId && unit.grnSupplierId !== supplierId) setScanError(`${unit.barcode} came from ${unit.grnSupplierName} (${unit.grnNumber}), not ${supplier?.name}.`)
      else {
        const cost = await loadCosts('unit', [unit.id])
        if (cost.get(unit.id)?.cents == null) setScanError(`${unit.barcode} has no cost yet. State the cost on ${unit.grnNumber ?? 'its GRN'} first.`)
        else {
          setItemCosts((prev) => new Map(prev).set(unit.id, cost.get(unit.id) as CostRow))
          setItems((prev) => [...prev, unit])
        }
      }
    } catch (err) {
      setScanError(describePurchasingError(err, 'That code could not be looked up.'))
    } finally {
      setScanning(false)
      setCode('')
      scanRef.current?.focus()
    }
  }

  async function submit() {
    if (!supplierId) { setError('Choose the supplier.'); return }
    if (items.length === 0 && quantityLines.length === 0) { setError('Scan an item or enter a quantity.'); return }
    setBusy(true)
    setError(null)
    try {
      const r = await createSupplierReturn({
        supplierId, returnDate, returnType, note: note.trim(), requestId, codes: items.map((u) => u.barcode), quantityLines,
      })
      onCreated(r.replayed
        ? `${r.return_number} had already been saved.`
        : `${r.return_number} saved: ${r.total_units} item${r.total_units === 1 ? '' : 's'} (${formatRupeesFromCents(r.total_cents)}) returned to ${supplier?.name}. Stock reduced.`)
    } catch (err) {
      setError(describePurchasingError(err, 'The return could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <AdminDrawer title="New supplier return" subtitle="Scan each item you are sending back" onClose={busy ? () => {} : onClose}
      footer={<>
        <span className="mr-auto text-[12.5px] text-muted-foreground tabular-nums">{items.length + quantityLines.reduce((n, l) => n + l.quantity, 0)} items{items.length > 0 ? ` · ${formatRupeesFromCents(total)} scanned` : ''}</span>
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy || (items.length === 0 && quantityLines.length === 0)}>
          {busy ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Saving…</> : 'Save return'}
        </Button>
      </>}>
      <label className="block">
        <FieldLabel>Supplier</FieldLabel>
        <select className={CONTROL} value={supplierId} disabled={busy || items.length > 0}
          onChange={(e) => { setSupplierId(e.target.value); setReturnable([]); setQuantities({}); setError(null) }}>
          <option value="">Choose a supplier…</option>
          {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}{s.is_active ? '' : ' (inactive)'}</option>)}
        </select>
      </label>
      <div className="grid grid-cols-2 gap-3">
        <label className="block">
          <FieldLabel>Return date</FieldLabel>
          <input type="date" className={CONTROL} value={returnDate} max={todayInColombo()} disabled={busy} onChange={(e) => setReturnDate(e.target.value)} />
        </label>
        <label className="block">
          <FieldLabel>Return type</FieldLabel>
          <select className={CONTROL} value={returnType} disabled={busy} onChange={(e) => setReturnType(e.target.value as ReturnType)}>
            {RETURN_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
        </label>
      </div>
      <p className="-mt-1 text-[11.5px] text-muted-foreground">{RETURN_TYPES.find((t) => t.value === returnType)?.hint}.</p>

      <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); void scan() }}>
        <div className="relative flex-1">
          <span className="pointer-events-none absolute inset-y-0 left-0 flex w-10 items-center justify-center text-muted-foreground">
            {scanning ? <LoaderCircle size={16} className="animate-spin motion-reduce:animate-none" /> : <ScanBarcode size={16} />}
          </span>
          <input ref={scanRef} value={code} disabled={busy || !supplierId} onChange={(e) => setCode(e.target.value)}
            placeholder={supplierId ? 'Scan barcode or IMEI, then Enter' : 'Choose the supplier first'} aria-label="Scan item"
            className={cn(CONTROL, 'pl-10 font-mono')} />
        </div>
        <Button type="submit" variant="secondary" disabled={busy || scanning || !code.trim()}>Add</Button>
      </form>
      {scanError && <ErrorNote message={scanError} />}

      {items.length > 0 && (
        <ul className="divide-y divide-mint/50 dark:divide-border/70 rounded-[22px] border border-mint/80 dark:border-border bg-surface shadow-card">
          {items.map((u) => (
            <li key={u.id} className="flex items-center gap-3 px-4 py-2.5">
              <span className="min-w-0 flex-1">
                <span className="block font-semibold truncate">{u.productName}</span>
                <span className="block text-[11.5px] text-muted-foreground truncate">{[u.variantName, u.barcode, u.serial].filter(Boolean).join(' · ')}</span>
              </span>
              <span className="shrink-0 tabular-nums text-[13px]">{formatRupeesFromCents(itemCosts.get(u.id)?.cents ?? 0)}</span>
              <button type="button" aria-label={`Remove ${u.barcode}`} disabled={busy}
                onClick={() => setItems((prev) => prev.filter((x) => x.id !== u.id))}
                className="focus-ring flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-red-500/10 hover:text-red-500">
                <Trash2 size={15} />
              </button>
            </li>
          ))}
        </ul>
      )}

      {returnable.length > 0 && (
        <section className="space-y-2 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
          <h3 className="text-[14px] font-bold text-foreground">Quantity-tracked goods</h3>
          <p className="text-[11.5px] text-muted-foreground">Valued at what that delivery cost.</p>
          {returnable.map((l) => (
            <label key={l.id} className="flex items-center gap-3 text-[13px]">
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold">{l.productName}{l.variantName ? ` · ${l.variantName}` : ''}</span>
                <span className="block text-[11.5px] text-muted-foreground">{l.grnNumber} · up to {l.returnable}</span>
              </span>
              <input type="number" inputMode="numeric" min={0} max={l.returnable} aria-label={`Quantity of ${l.productName}`}
                className={cn(CONTROL, 'w-20 tabular-nums')} value={quantities[l.id] ?? ''} disabled={busy}
                onChange={(e) => setQuantities((prev) => ({ ...prev, [l.id]: e.target.value }))} />
            </label>
          ))}
        </section>
      )}

      <TextAreaField id="ret-note" label="Reason / note (optional)" rows={2} value={note} disabled={busy} onChange={setNote} />
      <p className="text-[11.5px] text-muted-foreground">The value is each item&apos;s cost price from its GRN. A saved return is not edited; a mistake is reversed, and the record stays.</p>
      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}

function ReturnView({ ret, total, canManage, onClose, onReversed }: {
  ret: SupplierReturnListItem
  total: number | null
  canManage: boolean
  onClose: () => void
  onReversed: (message: string) => void
}) {
  const [items, setItems] = useState<SupplierReturnItemRow[] | null>(null)
  const [itemCosts, setItemCosts] = useState<Map<string, CostRow>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [reversing, setReversing] = useState(false)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let cancelled = false
    Promise.all([
      loadSupplierReturnItems(ret.id),
      canManage ? loadCosts('supplier_return_item', [ret.id]) : Promise.resolve(new Map<string, CostRow>()),
    ])
      .then(([i, c]) => { if (!cancelled) { setItems(i); setItemCosts(c) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load the items.')) })
    return () => { cancelled = true }
  }, [ret.id, canManage])

  async function reverse() {
    if (note.trim().length < 3) { setError('Say why this return is being reversed.'); return }
    setBusy(true)
    setError(null)
    try {
      await reverseSupplierReturn(ret.id, note.trim())
      onReversed(`${ret.return_number} reversed. Stock and what is owed were restored.`)
    } catch (err) {
      setError(describePurchasingError(err, 'The return could not be reversed.'))
      setBusy(false)
    }
  }

  return (
    <AdminDrawer title={ret.return_number} subtitle={`${ret.supplierName} · ${formatDate(ret.return_date)}`} onClose={onClose}
      footer={canManage && !ret.reversed_at && !reversing
        ? <Button variant="ghost" onClick={() => setReversing(true)}>Reverse this return</Button>
        : undefined}>
      <dl className="grid grid-cols-2 gap-3 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 text-[13px] shadow-card">
        <div><dt className="text-[11.5px] text-muted-foreground">Return type</dt><dd>{returnTypeLabel(ret.return_type)}</dd></div>
        {canManage && <div><dt className="text-[11.5px] text-muted-foreground">Total</dt><dd className="font-bold tabular-nums">{formatRupeesFromCents(total ?? 0)}</dd></div>}
        {ret.note && <div className="col-span-2"><dt className="text-[11.5px] text-muted-foreground">Note</dt><dd>{ret.note}</dd></div>}
        {ret.reversed_at && <div className="col-span-2"><dt className="text-[11.5px] text-muted-foreground">Reversed {formatDate(ret.reversed_at)}</dt><dd>{ret.reversal_note}</dd></div>}
      </dl>
      {reversing && (
        <section className="space-y-3 rounded-[22px] border border-red-500/25 bg-red-500/5 p-4">
          <p className="text-[13px]">Each item goes back where it came from, and this return stops counting against what is owed. The record stays.</p>
          <textarea rows={2} value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} placeholder="Why? (required)" className={CONTROL} />
          <div className="flex gap-2">
            <Button variant="ghost" onClick={() => setReversing(false)} disabled={busy}>Back</Button>
            <Button onClick={() => void reverse()} disabled={busy}>{busy ? 'Saving…' : 'Confirm reversal'}</Button>
          </div>
        </section>
      )}
      {error && <ErrorNote message={error} />}
      {!items && !error && <p className="py-8 text-center text-sm text-muted-foreground">Loading…</p>}
      {items && (
        <ul className="divide-y divide-mint/50 dark:divide-border/70 rounded-[22px] border border-mint/80 dark:border-border bg-surface shadow-card">
          {items.map((i) => (
            <li key={i.id} className="flex items-center justify-between gap-3 px-4 py-2.5 text-[13px]">
              <span className="min-w-0">
                <span className="block font-semibold truncate">{i.product_name_snapshot}{i.quantity > 1 ? ` × ${i.quantity}` : ''}</span>
                <span className="block text-[11.5px] text-muted-foreground truncate">{[i.variant_label_snapshot, i.barcode_snapshot, i.serial_snapshot].filter(Boolean).join(' · ')}</span>
              </span>
              {canManage && <span className="shrink-0 tabular-nums">{formatRupeesFromCents(itemCosts.get(i.id)?.cents ?? 0)}</span>}
            </li>
          ))}
        </ul>
      )}
    </AdminDrawer>
  )
}
