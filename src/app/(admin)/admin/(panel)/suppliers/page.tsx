"use client"

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, Pencil, Plus, LoaderCircle } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { AdminDrawer } from '@/components/admin/settings/AdminDrawer'
import { TextField, TextAreaField, CheckboxField } from '@/components/admin/products/fields'
import { ListHeader, ListTable, RowAction, StatusPill, type Column } from '@/components/admin/purchasing/ListTable'
import { ErrorNote, SuccessNote, parseRupees } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { getSupabaseClient } from '@/lib/supabase/client'
import { formatDate } from '@/lib/admin/units'
import {
  listSuppliers, saveSupplier, loadSupplierBalances, loadSupplierStatement, canManagePurchasing, describePurchasingError,
  formatRupeesFromCents, returnTypeLabel,
  type SupplierRow, type SupplierBalance, type StatementRow,
} from '@/lib/admin/purchasing'

export default function SuppliersPage() {
  const { role } = useAdminAuth()
  const canManage = canManagePurchasing(role)

  const [rows, setRows] = useState<SupplierRow[] | null>(null)
  const [balances, setBalances] = useState<Map<string, SupplierBalance>>(new Map())
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<SupplierRow | 'new' | null>(null)
  const [viewing, setViewing] = useState<SupplierRow | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const load = useCallback(async () => {
    const list = await listSuppliers()
    const bal = canManage ? await loadSupplierBalances() : new Map<string, SupplierBalance>()
    return [list, bal] as const
  }, [canManage])

  const refresh = useCallback(() => {
    load().then(([l, b]) => { setRows(l); setBalances(b); setError(null) })
      .catch((err) => setError(describePurchasingError(err, 'Could not load suppliers.')))
  }, [load])

  useEffect(() => {
    let cancelled = false
    load()
      .then(([l, b]) => { if (!cancelled) { setRows(l); setBalances(b) } })
      .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load suppliers.')) })
    return () => { cancelled = true }
  }, [load])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return (rows ?? []).filter((s) => !q || [s.name, s.supplier_code, s.contact_person ?? '', s.phone ?? '', s.email ?? '']
      .some((v) => v.toLowerCase().includes(q)))
  }, [rows, search])

  const columns: Column<SupplierRow>[] = [
    { key: 'code', header: 'Supplier ID', render: (s) => <span className="font-mono text-[12.5px] text-muted-foreground">{s.supplier_code}</span> },
    { key: 'name', header: 'Supplier', render: (s) => (
      <span className="block min-w-[160px]">
        <span className="block font-semibold text-foreground">{s.name}</span>
        {s.contact_person && <span className="block text-[11.5px] text-muted-foreground">{s.contact_person}</span>}
      </span>
    ) },
    { key: 'phone', header: 'Phone', render: (s) => <span className="whitespace-nowrap">{s.phone ?? '—'}</span> },
    { key: 'email', header: 'Email', render: (s) => <span className="text-muted-foreground">{s.email ?? '—'}</span> },
    ...(canManage ? [{
      key: 'balance', header: 'Amount owed', align: 'right' as const,
      render: (s: SupplierRow) => {
        const b = balances.get(s.id)?.balanceCents ?? 0
        return <span className={b > 0 ? 'font-semibold tabular-nums text-foreground' : 'tabular-nums text-muted-foreground'}>{formatRupeesFromCents(b)}</span>
      },
    }] : []),
    { key: 'status', header: 'Status', render: (s) => <StatusPill label={s.is_active ? 'Active' : 'Inactive'} tone={s.is_active ? 'green' : 'grey'} /> },
    { key: 'actions', header: 'Actions', align: 'right', render: (s) => (
      <span className="inline-flex gap-0.5">
        <RowAction label="View" onClick={() => setViewing(s)}><Eye size={16} /></RowAction>
        {canManage && <RowAction label="Edit" onClick={() => setEditing(s)}><Pencil size={15} /></RowAction>}
      </span>
    ) },
  ]

  return (
    <>
      <ListHeader title="Supplier Details" crumb="View" search={search} onSearch={setSearch}
        searchPlaceholder="Search suppliers…"
        action={canManage && <Button onClick={() => setEditing('new')}><Plus size={16} className="mr-1.5" /> New Supplier</Button>} />

      {notice && <SuccessNote message={notice} className="mb-4" />}

      <ListTable columns={columns} rows={filtered} rowKey={(s) => s.id} loading={rows === null && !error} error={error}
        empty={rows?.length ? 'No suppliers match.' : 'No suppliers yet. Add the companies you buy stock from.'}
        onRowClick={setViewing} />

      {editing && (
        <SupplierEditor supplier={editing === 'new' ? null : editing}
          currentOpening={editing === 'new' ? null : balances.get(editing.id)?.openingCents ?? null}
          onClose={() => setEditing(null)}
          onSaved={(name, isNew) => { setEditing(null); setNotice(`${name} ${isNew ? 'added' : 'saved'}.`); refresh() }} />
      )}
      {viewing && (
        <SupplierView supplier={viewing} balance={balances.get(viewing.id) ?? null} showMoney={canManage}
          onClose={() => setViewing(null)}
          onEdit={canManage ? () => { setEditing(viewing); setViewing(null) } : undefined} />
      )}
    </>
  )
}

function SupplierEditor({ supplier, currentOpening, onClose, onSaved }: {
  supplier: SupplierRow | null
  /** Staff cannot read this: only owner/admin ever reach the editor. */
  currentOpening: number | null
  onClose: () => void
  onSaved: (name: string, isNew: boolean) => void
}) {
  const [name, setName] = useState(supplier?.name ?? '')
  const [contact, setContact] = useState(supplier?.contact_person ?? '')
  const [phone, setPhone] = useState(supplier?.phone ?? '')
  const [email, setEmail] = useState(supplier?.email ?? '')
  const [address, setAddress] = useState(supplier?.address ?? '')
  const [note, setNote] = useState(supplier?.note ?? '')
  const [opening, setOpening] = useState(currentOpening === null ? '' : String(currentOpening / 100))
  const [openingNote, setOpeningNote] = useState('')
  const [active, setActive] = useState(supplier?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    if (name.trim().length < 2) { setError('Enter the supplier name.'); return }
    // Blank means none entered yet, never zero.
    const openingCents = opening.trim() === '' ? null : parseRupees(opening)
    if (opening.trim() !== '' && openingCents === null) { setError('The opening balance must be an amount in rupees.'); return }
    if (supplier && openingCents !== currentOpening && openingNote.trim().length < 3) {
      setError('Say why the opening balance is changing: it is kept in the audit trail.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      const saved = await saveSupplier({
        id: supplier?.id ?? null, name: name.trim(), contactPerson: contact, phone, email, address, note,
        openingBalanceCents: openingCents, openingBalanceNote: openingNote.trim(), isActive: active,
      })
      onSaved(saved.name, !supplier)
    } catch (err) {
      setError(describePurchasingError(err, 'The supplier could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <AdminDrawer title={supplier ? `Edit ${supplier.name}` : 'New supplier'} subtitle={supplier?.supplier_code}
      onClose={busy ? () => {} : onClose}
      footer={<>
        <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
        <Button onClick={() => void submit()} disabled={busy}>
          {busy ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Saving…</> : 'Save supplier'}
        </Button>
      </>}>
      <TextField id="sup-name" label="Supplier name" value={name} disabled={busy} placeholder="e.g. Tech Distributors (Pvt) Ltd" onChange={setName} />
      <div className="grid gap-3.5 sm:grid-cols-2">
        <TextField id="sup-contact" label="Contact person" hint="optional" value={contact} disabled={busy} onChange={setContact} />
        <TextField id="sup-phone" label="Phone" hint="optional" value={phone} disabled={busy} placeholder="077 123 4567" onChange={setPhone} />
      </div>
      <TextField id="sup-email" label="Email" hint="optional" value={email} disabled={busy} onChange={setEmail} />
      <TextAreaField id="sup-address" label="Address (optional)" rows={2} value={address} disabled={busy} onChange={setAddress} />
      <TextField id="sup-opening" label="Opening balance (Rs.)" hint="what you already owed before using this app"
        value={opening} disabled={busy} placeholder="Leave blank if not known yet" onChange={setOpening} />
      {supplier && (opening.trim() === '' ? null : parseRupees(opening)) !== currentOpening && (
        <TextField id="sup-opening-note" label="Why is the opening balance changing?" value={openingNote} disabled={busy} onChange={setOpeningNote} />
      )}
      <TextAreaField id="sup-note" label="Note (optional)" rows={2} value={note} disabled={busy} onChange={setNote} />
      {supplier && (
        <CheckboxField id="sup-active" label="Active" checked={active} disabled={busy} onChange={setActive}
          hint="An inactive supplier keeps its history but cannot get new orders or deliveries." />
      )}
      {error && <ErrorNote message={error} />}
    </AdminDrawer>
  )
}

interface Activity {
  grns: { id: string; grn_number: string; received_on: string; total_units: number }[]
  returns: { id: string; return_number: string; return_date: string; return_type: string }[]
}

function SupplierView({ supplier, balance, showMoney, onClose, onEdit }: {
  supplier: SupplierRow
  balance: SupplierBalance | null
  showMoney: boolean
  onClose: () => void
  onEdit?: () => void
}) {
  const [activity, setActivity] = useState<Activity | null>(null)
  const [statement, setStatement] = useState<StatementRow[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    if (showMoney) {
      // The statement carries every transaction with its amount; only owner/admin may call it.
      loadSupplierStatement(supplier.id)
        .then((rows) => { if (!cancelled) setStatement(rows) })
        .catch((err) => { if (!cancelled) setError(describePurchasingError(err, 'Could not load the history.')) })
    } else {
      const supabase = getSupabaseClient()
      Promise.all([
        supabase.from('grns').select('id, grn_number, received_on, total_units')
          .eq('supplier_id', supplier.id).order('received_on', { ascending: false }).limit(20),
        supabase.from('supplier_returns').select('id, return_number, return_date, return_type')
          .eq('supplier_id', supplier.id).order('return_date', { ascending: false }).limit(20),
      ]).then(([g, r]) => {
        if (cancelled) return
        const firstError = g.error ?? r.error
        if (firstError) { setError(describePurchasingError(firstError, 'Could not load the history.')); return }
        setActivity({ grns: g.data ?? [], returns: r.data ?? [] })
      })
    }
    return () => { cancelled = true }
  }, [supplier.id, showMoney])

  const card = 'rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card'

  return (
    <AdminDrawer title={supplier.name} subtitle={`${supplier.supplier_code}${supplier.is_active ? '' : ' · inactive'}`} onClose={onClose}
      footer={onEdit && <Button variant="secondary" onClick={onEdit}><Pencil size={14} className="mr-1.5" /> Edit</Button>}>
      <dl className={`${card} grid grid-cols-2 gap-3 text-[13px]`}>
        <div><dt className="text-[11.5px] text-muted-foreground">Contact</dt><dd>{supplier.contact_person ?? '—'}</dd></div>
        <div><dt className="text-[11.5px] text-muted-foreground">Phone</dt><dd>{supplier.phone ?? '—'}</dd></div>
        <div className="col-span-2"><dt className="text-[11.5px] text-muted-foreground">Email</dt><dd>{supplier.email ?? '—'}</dd></div>
        <div className="col-span-2"><dt className="text-[11.5px] text-muted-foreground">Address</dt><dd className="whitespace-pre-line">{supplier.address ?? '—'}</dd></div>
        {supplier.note && <div className="col-span-2"><dt className="text-[11.5px] text-muted-foreground">Note</dt><dd>{supplier.note}</dd></div>}
      </dl>

      {showMoney && balance && (
        <section className={`${card} space-y-1.5 text-[13px]`}>
          <h3 className="mb-1 text-[14px] font-bold">Account</h3>
          {[
            ['Opening balance', balance.openingCents ?? 0, ''],
            ['Goods received (GRN)', balance.purchasesCents, '+'],
            ['Credit returns', balance.creditReturnsCents, '−'],
            ['Payments', balance.paymentsCents, '−'],
          ].map(([label, cents, sign]) => (
            <div key={label as string} className="flex justify-between">
              <span className="text-muted-foreground">{label}</span>
              <span className="tabular-nums">{sign} {formatRupeesFromCents(cents as number)}</span>
            </div>
          ))}
          <div className="flex justify-between border-t border-mint/70 dark:border-border pt-2 text-[15px] font-bold">
            <span>Amount owed</span><span className="tabular-nums">{formatRupeesFromCents(balance.balanceCents)}</span>
          </div>
          {balance.openingCents === null && (
            <p className="text-[11.5px] text-muted-foreground">No opening balance has been entered for this supplier.</p>
          )}
          {balance.pendingCostLines > 0 && (
            <p className="text-[11.5px] font-semibold text-amber-600 dark:text-amber-400">
              {balance.pendingCostLines} GRN line{balance.pendingCostLines === 1 ? ' has' : 's have'} no cost yet, so this figure is understated.
            </p>
          )}
          {balance.cashReturnsCents > 0 && (
            <p className="text-[11.5px] text-muted-foreground">Cash returns ({formatRupeesFromCents(balance.cashReturnsCents)}) were paid back in cash and are not deducted.</p>
          )}
        </section>
      )}

      {error && <ErrorNote message={error} />}
      {!activity && !statement && !error && <p className="py-6 text-center text-sm text-muted-foreground">Loading history…</p>}
      {statement && (
        <HistoryList title="Statement" empty="No transactions yet."
          items={statement.map((row, i) => ({
            id: `${row.reference}-${i}`,
            left: row.reference,
            sub: `${formatDate(row.occurredOn)} · ${row.description}`,
            right: row.debitCents > 0 ? `+ ${formatRupeesFromCents(row.debitCents)}`
              : row.creditCents > 0 ? `− ${formatRupeesFromCents(row.creditCents)}` : '—',
          }))} />
      )}
      {activity && (
        <>
          <HistoryList title="Goods received" empty="No GRNs yet."
            items={activity.grns.map((g) => ({ id: g.id, left: g.grn_number, sub: `${formatDate(g.received_on)} · ${g.total_units} units`, right: '' }))} />
          <HistoryList title="Returns" empty="No returns."
            items={activity.returns.map((r) => ({ id: r.id, left: r.return_number, sub: `${formatDate(r.return_date)} · ${returnTypeLabel(r.return_type)}`, right: '' }))} />
        </>
      )}
    </AdminDrawer>
  )
}

function HistoryList({ title, items, empty }: {
  title: string
  empty: string
  items: { id: string; left: string; sub: string; right: string }[]
}) {
  return (
    <section className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
      <h3 className="mb-2 text-[14px] font-bold">{title}</h3>
      {items.length === 0 ? <p className="text-[12.5px] text-muted-foreground">{empty}</p> : (
        <ul className="space-y-2">
          {items.map((i) => (
            <li key={i.id} className="flex items-baseline justify-between gap-3 text-[13px]">
              <span className="min-w-0"><span className="block font-semibold">{i.left}</span><span className="block text-[11.5px] text-muted-foreground">{i.sub}</span></span>
              <span className="shrink-0 tabular-nums">{i.right}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
