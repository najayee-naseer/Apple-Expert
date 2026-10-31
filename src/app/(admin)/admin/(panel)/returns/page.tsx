"use client"

import { useCallback, useEffect, useState } from 'react'
import { LoaderCircle, RotateCcw, Search } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { ErrorNote, SuccessNote, parseRupees, SELECT_CLASS } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { canReceiveStock, describeUnitError, formatDateTime, paymentLabel, PAYMENT_METHODS } from '@/lib/admin/units'
import {
  findReturnSource, recordCustomerReturn, recordCustomerRefund, listCustomerReturns, listCustomerRefunds, newRequestId,
  RETURN_CONDITIONS,
  type RecentRefund, type RecentReturn, type ReturnCondition, type ReturnSource,
} from '@/lib/admin/returns'

const INPUT =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'
const CARD = 'rounded-[22px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card'

/** One thing that can come back: a scanned unit, or some quantity of a line. */
interface Pick {
  key: string
  lineId: string
  unitId: string | null
  label: string
  max: number
}

function picksFrom(source: ReturnSource): Pick[] {
  return source.lines.flatMap((l): Pick[] => {
    const label = `${l.name}${l.variant ? ` · ${l.variant}` : ''}`
    if (l.units.length > 0) {
      return l.units.map((u) => ({
        key: u.id, lineId: l.lineId, unitId: u.id, max: 1,
        label: `${label} · ${u.barcode}${u.serial ? ` · ${u.serial}` : ''}`,
      }))
    }
    const left = l.quantity - l.returned
    return left > 0 ? [{ key: l.lineId, lineId: l.lineId, unitId: null, label, max: left }] : []
  })
}

/**
 * Customer returns and refunds, kept apart on purpose: goods coming back go to
 * quarantine and move no money; money going back moves no stock. Supplier returns
 * have their own screen under Purchase & Returns.
 */
export default function CustomerReturnsPage() {
  const { role } = useAdminAuth()
  const canManage = canReceiveStock(role)

  const [number, setNumber] = useState('')
  const [searching, setSearching] = useState(false)
  const [source, setSource] = useState<ReturnSource | null>(null)
  const [findError, setFindError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [returns, setReturns] = useState<RecentReturn[] | null>(null)
  const [refunds, setRefunds] = useState<RecentRefund[]>([])
  const [listError, setListError] = useState<string | null>(null)

  const load = useCallback(() => Promise.all([listCustomerReturns(), listCustomerRefunds()]), [])
  const refresh = useCallback(() => {
    load().then(([a, b]) => { setReturns(a); setRefunds(b); setListError(null) })
      .catch((err) => setListError(describeUnitError(err, 'Could not load returns.')))
  }, [load])

  useEffect(() => {
    let cancelled = false
    load()
      .then(([a, b]) => { if (!cancelled) { setReturns(a); setRefunds(b) } })
      .catch((err) => { if (!cancelled) setListError(describeUnitError(err, 'Could not load returns.')) })
    return () => { cancelled = true }
  }, [load])

  async function find(value: string) {
    if (!value.trim()) return
    setSearching(true)
    setFindError(null)
    try {
      const found = await findReturnSource(value)
      setSource(found)
      if (!found) setFindError(`No counter bill or online order numbered ${value.trim().toUpperCase()}.`)
    } catch (err) {
      setFindError(describeUnitError(err, 'That number could not be looked up.'))
    } finally {
      setSearching(false)
    }
  }

  function changed(message: string) {
    setNotice(message)
    refresh()
    if (source) void find(source.number)
  }

  return (
    <>
      <AdminPageHeading title="Customer returns"
        subtitle="Goods that come back go to quarantine until someone checks them. Money that goes back is recorded separately." />

      {!canManage && <p className="mb-4 text-[12.5px] text-muted-foreground">You can view returns and refunds. Recording them needs an owner or admin.</p>}
      {notice && <SuccessNote message={notice} className="mb-4" />}

      {canManage && (
        <form className="mb-4 flex gap-2" onSubmit={(e) => { e.preventDefault(); setNotice(null); void find(number) }}>
          <div className="relative flex-1">
            <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-muted-foreground">
              {searching ? <LoaderCircle size={16} className="animate-spin motion-reduce:animate-none" /> : <Search size={16} />}
            </span>
            <input value={number} onChange={(e) => setNumber(e.target.value)} aria-label="Bill or order number"
              placeholder="Bill number (POS-…) or order number (AE-…)"
              className="focus-ring h-11 w-full rounded-xl border border-mint-deep dark:border-border bg-card pl-11 pr-3 font-mono text-sm placeholder:font-sans placeholder:text-muted-foreground focus:outline-none focus:border-primary/45" />
          </div>
          <Button type="submit" disabled={searching || !number.trim()}>Find</Button>
        </form>
      )}
      {findError && <ErrorNote message={findError} className="mb-4" />}

      {source && canManage && (
        <div className="mb-6 grid gap-4 lg:grid-cols-2">
          <ReturnForm key={`r-${source.sourceId}-${source.lines.map((l) => l.returned).join()}`} source={source}
            onDone={(n) => changed(`${n} recorded. The goods are in quarantine; no money has moved.`)} />
          <RefundForm key={`m-${source.sourceId}-${source.refundedCents}`} source={source}
            onDone={(n) => changed(`${n} recorded. No stock has moved.`)} />
        </div>
      )}

      {listError && <ErrorNote message={listError} className="mb-3" />}
      {returns === null && !listError && <p className="text-sm text-muted-foreground">Loading…</p>}
      {returns && (
        <div className="grid gap-4 lg:grid-cols-2">
          <section className={CARD}>
            <h2 className="mb-2 flex items-center gap-2 text-[15px] font-bold"><RotateCcw size={16} /> Recent returns</h2>
            {returns.length === 0 && <p className="text-[13px] text-muted-foreground">None yet.</p>}
            <ul className="space-y-2.5">
              {returns.map((r) => (
                <li key={r.id} className="text-[13px]">
                  <span className="block font-semibold">{r.returnNumber} <span className="font-normal text-muted-foreground">· {formatDateTime(r.createdAt)}</span></span>
                  <span className="block text-[11.5px] text-muted-foreground">{r.items.map((i) => `${i.name} × ${i.quantity} (${i.condition})`).join(', ')}</span>
                </li>
              ))}
            </ul>
          </section>
          <section className={CARD}>
            <h2 className="mb-2 text-[15px] font-bold">Recent refunds</h2>
            {refunds.length === 0 && <p className="text-[13px] text-muted-foreground">None yet.</p>}
            <ul className="space-y-2.5">
              {refunds.map((r) => (
                <li key={r.id} className="flex items-baseline justify-between gap-3 text-[13px]">
                  <span className="min-w-0">
                    <span className="block font-semibold">{r.refundNumber}</span>
                    <span className="block text-[11.5px] text-muted-foreground">{formatDateTime(r.createdAt)} · {paymentLabel(r.method)}{r.reference ? ` · ${r.reference}` : ''}</span>
                  </span>
                  <span className="shrink-0 font-semibold tabular-nums">{formatPrice(centsToRupees(r.amountCents))}</span>
                </li>
              ))}
            </ul>
          </section>
        </div>
      )}
    </>
  )
}

function ReturnForm({ source, onDone }: { source: ReturnSource; onDone: (number: string) => void }) {
  const [requestId] = useState(newRequestId)
  const picks = picksFrom(source)
  const [quantities, setQuantities] = useState<Record<string, string>>({})
  const [conditions, setConditions] = useState<Record<string, ReturnCondition>>({})
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    const items = []
    for (const p of picks) {
      const text = (quantities[p.key] ?? '').trim()
      if (!text || text === '0') continue
      const qty = Number(text)
      if (!Number.isInteger(qty) || qty < 1 || qty > p.max) { setError(`${p.label}: enter 1 to ${p.max}.`); return }
      items.push({ lineId: p.lineId, unitId: p.unitId, quantity: qty, condition: conditions[p.key] ?? 'unverified' })
    }
    if (items.length === 0) { setError('Enter what came back.'); return }
    setBusy(true)
    setError(null)
    try {
      const r = await recordCustomerReturn({ source, items, note: note.trim(), requestId })
      onDone(r.return_number)
    } catch (err) {
      setError(describeUnitError(err, 'The return could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <section className={`${CARD} space-y-3`}>
      <h2 className="text-[15px] font-bold">Goods back · {source.number}</h2>
      {picks.length === 0 && <p className="text-[13px] text-muted-foreground">Everything on this {source.sourceType === 'pos' ? 'bill' : 'order'} has already been returned.</p>}
      {picks.map((p) => (
        <div key={p.key} className="space-y-1.5 border-b border-mint/50 dark:border-border/70 pb-3 last:border-0">
          <p className="text-[13px] font-semibold">{p.label}</p>
          <div className="grid grid-cols-2 gap-2">
            <input type="number" inputMode="numeric" min={0} max={p.max} aria-label={`Quantity returned of ${p.label}`} placeholder={`Returned (max ${p.max})`}
              className={INPUT} value={quantities[p.key] ?? ''} disabled={busy}
              onChange={(e) => setQuantities((prev) => ({ ...prev, [p.key]: e.target.value }))} />
            <select aria-label={`Condition of ${p.label}`} className={SELECT_CLASS} value={conditions[p.key] ?? 'unverified'} disabled={busy}
              onChange={(e) => setConditions((prev) => ({ ...prev, [p.key]: e.target.value as ReturnCondition }))}>
              {RETURN_CONDITIONS.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>
        </div>
      ))}
      {picks.length > 0 && (
        <>
          <input className={INPUT} placeholder="Note (optional)" value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} />
          {error && <ErrorNote message={error} />}
          <Button fullWidth onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Record return to quarantine'}</Button>
        </>
      )}
    </section>
  )
}

function RefundForm({ source, onDone }: { source: ReturnSource; onDone: (number: string) => void }) {
  const [requestId] = useState(newRequestId)
  const left = source.totalCents - source.refundedCents
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<string>('cash')
  const [reference, setReference] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    const cents = amount.trim() === '' ? null : parseRupees(amount)
    if (cents === null || cents <= 0) { setError('Enter the amount refunded.'); return }
    if (cents > left) { setError(`Only ${formatPrice(centsToRupees(left))} can still be refunded.`); return }
    setBusy(true)
    setError(null)
    try {
      const r = await recordCustomerRefund({ source, customerReturnId: null, amountCents: cents, method, reference: reference.trim(), note: note.trim(), requestId })
      onDone(r.refund_number)
    } catch (err) {
      setError(describeUnitError(err, 'The refund could not be saved.'))
      setBusy(false)
    }
  }

  return (
    <section className={`${CARD} space-y-3`}>
      <h2 className="text-[15px] font-bold">Money back · {source.number}</h2>
      <p className="text-[13px] tabular-nums text-muted-foreground">
        Charged {formatPrice(centsToRupees(source.totalCents))} · refunded {formatPrice(centsToRupees(source.refundedCents))}
      </p>
      {left <= 0 ? <p className="text-[13px] text-muted-foreground">This has been refunded in full.</p> : (
        <>
          <div className="grid grid-cols-2 gap-2">
            <input inputMode="decimal" aria-label="Amount refunded" placeholder="Rs." className={INPUT} value={amount} disabled={busy} onChange={(e) => setAmount(e.target.value)} />
            <select aria-label="Refund method" className={SELECT_CLASS} value={method} disabled={busy} onChange={(e) => setMethod(e.target.value)}>
              {PAYMENT_METHODS.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
            </select>
          </div>
          <input className={INPUT} placeholder="Reference (optional)" value={reference} disabled={busy} onChange={(e) => setReference(e.target.value)} />
          <input className={INPUT} placeholder="Note (optional)" value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} />
          {error && <ErrorNote message={error} />}
          <Button fullWidth onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Record refund'}</Button>
        </>
      )}
    </section>
  )
}
