"use client"

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Ban, Plus, LoaderCircle } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import { TextField, TextAreaField, FieldLabel } from '@/components/admin/products/fields'
import { ListHeader, ListTable, RowAction, StatusPill, type Column } from '@/components/admin/purchasing/ListTable'
import { ErrorNote, SuccessNote, parseRupees } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { todayInColombo, formatDate } from '@/lib/admin/units'
import {
  listSupplierPayments, recordSupplierPayment, voidSupplierPayment, listSuppliers, loadSupplierBalances, loadOpenGrns,
  canManagePurchasing, describePurchasingError, formatRupeesFromCents, supplierPaymentMethodLabel, newRequestId,
  SUPPLIER_PAYMENT_METHODS,
  type SupplierPaymentListItem, type SupplierRow, type SupplierBalance, type SupplierPaymentMethod, type OpenGrn,
} from '@/lib/admin/purchasing'

const CONTROL =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

export default function SupplierPaymentsPage() {
  const { role } = useAdminAuth()
  const canManage = canManagePurchasing(role)

  const [rows, setRows] = useState<SupplierPaymentListItem[] | null>(null)
  const [suppliers, setSuppliers] = useState<SupplierRow[]>([])
  const [balances, setBalances] = useState<Map<string, SupplierBalance>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [creating, setCreating] = useState(false)
  const [voiding, setVoiding] = useState<SupplierPaymentListItem | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const load = useCallback(() => Promise.all([listSupplierPayments(), listSuppliers(), loadSupplierBalances()]), [])
  const refresh = useCallback(() => {
    load().then(([p, s, b]) => { setRows(p); setSuppliers(s); setBalances(b); setError(null) })
      .catch((err) => setError(describePurchasingError(err, 'Could not load payments.')))
  }, [load])

  useEffect(() => {
    if (!canManage) return
    let cancelled = false
    load()
      .then(([p, s, b]) => { if (!cancelled) { setRows(p); setSuppliers(s); setBalances(b) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load payments.')) })
    return () => { cancelled = true }
  }, [load, canManage])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return (rows ?? []).filter((p) => !q || [p.payment_number, p.supplierName, p.reference ?? ''].some((v) => v.toLowerCase().includes(q)))
  }, [rows, search])

  const totalOwed = [...balances.values()].reduce((sum, b) => sum + Math.max(b.balanceCents, 0), 0)

  if (!canManage) {
    return (
      <>
        <ListHeader title="Supplier Payments" crumb="View" search="" onSearch={() => {}} searchPlaceholder="Search payments…" />
        <ErrorNote message="Supplier payments are visible to the owner and admins only." />
      </>
    )
  }

  const columns: Column<SupplierPaymentListItem>[] = [
    { key: 'no', header: 'Payment ID', render: (p) => <span className={cn('font-semibold whitespace-nowrap', p.voided_at && 'line-through text-muted-foreground')}>{p.payment_number}</span> },
    { key: 'supplier', header: 'Supplier', render: (p) => <span className="block min-w-[150px]">{p.supplierName}</span> },
    { key: 'date', header: 'Date', render: (p) => <span className="whitespace-nowrap">{formatDate(p.paid_on)}</span> },
    { key: 'method', header: 'Method', render: (p) => (
      <span className="block">
        <span className="block">{supplierPaymentMethodLabel(p.method)}</span>
        {p.reference && <span className="block text-[11.5px] text-muted-foreground">{p.reference}</span>}
      </span>
    ) },
    { key: 'status', header: 'Status', render: (p) => p.voided_at
      ? <span title={p.void_note ?? ''}><StatusPill label="Voided" tone="red" /></span>
      : <StatusPill label="Paid" tone="green" /> },
    { key: 'amount', header: 'Amount', align: 'right', render: (p) => <span className={cn('tabular-nums whitespace-nowrap font-semibold', p.voided_at && 'line-through text-muted-foreground font-normal')}>{formatRupeesFromCents(p.amount_cents)}</span> },
    { key: 'actions', header: 'Actions', align: 'right', render: (p) => !p.voided_at && (
      <RowAction label="Void payment" tone="danger" onClick={() => setVoiding(p)}><Ban size={15} /></RowAction>
    ) },
  ]

  return (
    <>
      <ListHeader title="Supplier Payments" crumb="View" search={search} onSearch={setSearch}
        searchPlaceholder="Search payments…"
        action={<Button onClick={() => setCreating(true)} disabled={rows === null}><Plus size={16} className="mr-1.5" /> New Payment</Button>} />

      {rows && (
        <p className="mb-3 text-[13px] text-muted-foreground">
          Total owed to all suppliers: <strong className="text-foreground tabular-nums">{formatRupeesFromCents(totalOwed)}</strong>
        </p>
      )}
      {notice && <SuccessNote message={notice} className="mb-4" />}

      <ListTable columns={columns} rows={filtered} rowKey={(p) => p.id} loading={rows === null && !error} error={error}
        empty={rows?.length ? 'No payments match.' : 'No supplier payments yet.'} />

      {creating && (
        <PaymentCreator suppliers={suppliers} balances={balances} onClose={() => setCreating(false)}
          onCreated={(msg) => { setCreating(false); setNotice(msg); refresh() }} />
      )}
      {voiding && (
        <VoidDialog payment={voiding} onClose={() => setVoiding(null)}
          onDone={() => { setNotice(`${voiding.payment_number} voided.`); setVoiding(null); refresh() }} />
      )}
    </>
  )
}

function PaymentCreator({ suppliers, balances, onClose, onCreated }: {
  suppliers: SupplierRow[]
  balances: Map<string, SupplierBalance>
  onClose: () => void
  onCreated: (message: string) => void
}) {
  const [requestId] = useState(newRequestId)
  const [supplierId, setSupplierId] = useState('')
  const [paidOn, setPaidOn] = useState(todayInColombo)
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<SupplierPaymentMethod>('cash')
  const [reference, setReference] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [openGrns, setOpenGrns] = useState<OpenGrn[]>([])
  const [allocations, setAllocations] = useState<Record<string, string>>({})

  const owed = supplierId ? balances.get(supplierId)?.balanceCents ?? 0 : null

  useEffect(() => {
    if (!supplierId) return
    let cancelled = false
    loadOpenGrns(supplierId)
      .then((rows) => { if (!cancelled) setOpenGrns(rows) })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load this supplier\'s open GRNs.')) })
    return () => { cancelled = true }
  }, [supplierId])

  async function submit() {
    if (!supplierId) { setError('Choose the supplier.'); return }
    const cents = parseRupees(amount)
    if (cents === null || cents <= 0) { setError('Enter the amount paid.'); return }
    if (method === 'cheque' && !reference.trim()) { setError('Enter the cheque number.'); return }
    const allocated: { grnId: string; amountCents: number }[] = []
    for (const g of openGrns) {
      const text = (allocations[g.grnId] ?? '').trim()
      if (!text) continue
      const value = parseRupees(text)
      if (value === null || value <= 0) { setError(`${g.grnNumber}: enter an amount in rupees.`); return }
      if (value > g.outstandingCents) { setError(`${g.grnNumber} has only ${formatRupeesFromCents(g.outstandingCents)} left to settle.`); return }
      allocated.push({ grnId: g.grnId, amountCents: value })
    }
    if (allocated.reduce((sum, a) => sum + a.amountCents, 0) > cents) { setError('The amounts applied to GRNs are more than the payment.'); return }
    setBusy(true)
    setError(null)
    try {
      const r = await recordSupplierPayment({ supplierId, paidOn, amountCents: cents, method, reference: reference.trim(), note: note.trim(), allocations: allocated, requestId })
      onCreated(r.replayed ? `${r.payment_number} had already been saved.` : `${r.payment_number} saved: ${formatRupeesFromCents(cents)} paid.`)
    } catch (err) {
      setError(describePurchasingError(err, 'The payment could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <AdminDrawer title="New supplier payment" subtitle="Money paid to a supplier" onClose={busy ? () => {} : onClose}
      footer={<>
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy}>
          {busy ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Saving…</> : 'Save payment'}
        </Button>
      </>}>
      <label className="block">
        <FieldLabel>Supplier</FieldLabel>
        <select className={CONTROL} value={supplierId} disabled={busy} onChange={(e) => { setSupplierId(e.target.value); setOpenGrns([]); setAllocations({}); setError(null) }}>
          <option value="">Choose a supplier…</option>
          {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </label>
      {owed !== null && (
        <p className="rounded-2xl border border-mint-deep bg-primary-soft px-3.5 py-2.5 text-[13px]">
          Currently owed: <strong className="tabular-nums">{formatRupeesFromCents(owed)}</strong>
          {owed > 0 && (
            <button type="button" className="ml-2 text-primary underline underline-offset-2" onClick={() => setAmount(String(owed / 100))}>Pay all</button>
          )}
        </p>
      )}
      <div className="grid grid-cols-2 gap-3">
        <label className="block">
          <FieldLabel>Date</FieldLabel>
          <input type="date" className={CONTROL} value={paidOn} max={todayInColombo()} disabled={busy} onChange={(e) => setPaidOn(e.target.value)} />
        </label>
        <label className="block">
          <FieldLabel hint="Rs.">Amount</FieldLabel>
          <input inputMode="decimal" className={cn(CONTROL, 'tabular-nums')} placeholder="0" value={amount} disabled={busy} onChange={(e) => { setAmount(e.target.value); setError(null) }} />
        </label>
      </div>
      <label className="block">
        <FieldLabel>Method</FieldLabel>
        <select className={CONTROL} value={method} disabled={busy} onChange={(e) => setMethod(e.target.value as SupplierPaymentMethod)}>
          {SUPPLIER_PAYMENT_METHODS.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
        </select>
      </label>
      <TextField id="pay-ref" label={method === 'cheque' ? 'Cheque number' : 'Reference'} hint={method === 'cheque' ? 'required' : 'optional · bank ref, receipt no.'}
        value={reference} disabled={busy} onChange={setReference} />
      {openGrns.length > 0 && (
        <section className="space-y-2 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
          <h3 className="text-[14px] font-bold text-foreground">Apply to GRNs <span className="font-normal text-muted-foreground">(optional)</span></h3>
          {openGrns.map((g) => (
            <label key={g.grnId} className="flex items-center gap-3 text-[13px]">
              <span className="min-w-0 flex-1">
                <span className="block font-semibold">{g.grnNumber}{g.supplierInvoice ? ` · ${g.supplierInvoice}` : ''}</span>
                <span className="block text-[11.5px] text-muted-foreground tabular-nums">{formatDate(g.receivedOn)} · {formatRupeesFromCents(g.outstandingCents)} left</span>
              </span>
              <input inputMode="decimal" aria-label={`Amount for ${g.grnNumber}`} className={cn(CONTROL, 'w-28 tabular-nums')} placeholder="Rs."
                value={allocations[g.grnId] ?? ''} disabled={busy}
                onChange={(e) => setAllocations((prev) => ({ ...prev, [g.grnId]: e.target.value }))} />
            </label>
          ))}
        </section>
      )}
      <TextAreaField id="pay-note" label="Note (optional)" rows={2} value={note} disabled={busy} onChange={setNote} />
      <p className="text-[11.5px] text-muted-foreground">Payments cannot be edited. A mistake is voided, and stays in the list for the record.</p>
      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}

function VoidDialog({ payment, onClose, onDone }: { payment: SupplierPaymentListItem; onClose: () => void; onDone: () => void }) {
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    if (note.trim().length < 3) { setError('Add a short reason.'); return }
    setBusy(true)
    setError(null)
    try {
      await voidSupplierPayment(payment.id, note.trim())
      onDone()
    } catch (err) {
      setError(describePurchasingError(err, 'The payment could not be voided.'))
      setBusy(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center px-5">
      <button type="button" aria-label="Cancel" onClick={busy ? undefined : onClose} className="absolute inset-0 bg-black/55 backdrop-blur-[2px]" />
      <div role="dialog" aria-modal="true" aria-label="Void payment"
        className="relative w-full max-w-sm space-y-3.5 rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float">
        <div>
          <h3 className="text-lg font-bold">Void {payment.payment_number}?</h3>
          <p className="mt-1 text-[13px] text-muted-foreground">
            {formatRupeesFromCents(payment.amount_cents)} to {payment.supplierName} will no longer count as paid. This cannot be undone.
          </p>
        </div>
        <textarea rows={2} value={note} disabled={busy} onChange={(e) => { setNote(e.target.value); setError(null) }}
          placeholder="Reason (e.g. cheque bounced)" className={CONTROL} />
        {error && <ErrorNote message={error} />}
        <div className="flex gap-2.5">
          <Button variant="ghost" fullWidth onClick={onClose} disabled={busy}>Cancel</Button>
          <Button fullWidth onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Void payment'}</Button>
        </div>
      </div>
    </div>
  )
}
