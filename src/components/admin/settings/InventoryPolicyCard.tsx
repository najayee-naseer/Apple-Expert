"use client"

import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/Button'
import { TextField } from '@/components/admin/products/fields'
import { loadInventoryPolicy, saveInventoryPolicy, describeUnitError, type InventoryPolicy } from '@/lib/admin/units'

/** Blank means no limit. */
function parseLimit(text: string): number | null | 'invalid' {
  const value = text.trim()
  if (value === '') return null
  return /^[1-9]\d*$/.test(value) ? Number(value) : 'invalid'
}

/**
 * Rules the business decides, enforced by the database. Nothing here has a
 * business-approved default: customer limits start blank (no limit) and the staff
 * discount limit starts at 0%, so every staff discount needs approval until the
 * shop chooses otherwise. Changes are kept in the audit trail.
 */
export function InventoryPolicyCard({ canEdit }: { canEdit: boolean }) {
  const [policy, setPolicy] = useState<InventoryPolicy | null>(null)
  const [units, setUnits] = useState('')
  const [orders, setOrders] = useState('')
  const [discount, setDiscount] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)

  useEffect(() => {
    let cancelled = false
    loadInventoryPolicy()
      .then((p) => {
        if (cancelled) return
        setPolicy(p)
        setUnits(p.maxReservedUnitsPerCustomer?.toString() ?? '')
        setOrders(p.maxActiveOrdersPerCustomer?.toString() ?? '')
        setDiscount(String(p.staffMaxDiscountBps / 100))
      })
      .catch((err) => { if (!cancelled) setMessage({ ok: false, text: describeUnitError(err, 'Could not load the policy.') }) })
    return () => { cancelled = true }
  }, [])

  async function save() {
    const maxUnits = parseLimit(units)
    const maxOrders = parseLimit(orders)
    const percent = Number(discount)
    if (maxUnits === 'invalid' || maxOrders === 'invalid') { setMessage({ ok: false, text: 'A limit must be a whole number, or blank for no limit.' }); return }
    if (discount.trim() === '' || !Number.isFinite(percent) || percent < 0 || percent > 100) { setMessage({ ok: false, text: 'The staff discount limit must be from 0 to 100%.' }); return }
    if (note.trim().length < 3) { setMessage({ ok: false, text: 'Add a note: it is kept with the change.' }); return }
    const next: InventoryPolicy = {
      maxReservedUnitsPerCustomer: maxUnits,
      maxActiveOrdersPerCustomer: maxOrders,
      staffMaxDiscountBps: Math.round(percent * 100),
    }
    setBusy(true)
    setMessage(null)
    try {
      await saveInventoryPolicy(next, note.trim())
      setPolicy(next)
      setNote('')
      setMessage({ ok: true, text: 'Saved.' })
    } catch (err) {
      setMessage({ ok: false, text: describeUnitError(err, 'The policy could not be saved.') })
    } finally {
      setBusy(false)
    }
  }

  const disabled = !canEdit || busy || !policy

  return (
    <section className="space-y-3.5 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-5 shadow-card">
      <div>
        <h2 className="text-[15px] font-bold tracking-tight text-foreground">Stock and discount rules</h2>
        <p className="mt-1 text-[12.5px] leading-snug text-muted-foreground">Enforced by the database. Unconfirmed online orders always release their stock after 48 hours.</p>
      </div>
      <div className="grid gap-3.5 sm:grid-cols-3">
        <TextField id="pol-units" label="Items one customer may hold" hint="blank = no limit" value={units} disabled={disabled} onChange={setUnits} />
        <TextField id="pol-orders" label="Open orders per customer" hint="blank = no limit" value={orders} disabled={disabled} onChange={setOrders} />
        <TextField id="pol-discount" label="Staff discount without approval" hint="% of the bill" value={discount} disabled={disabled} onChange={setDiscount} />
      </div>
      {canEdit && (
        <>
          <TextField id="pol-note" label="Why is this changing?" value={note} disabled={disabled} onChange={setNote} />
          <Button onClick={() => void save()} disabled={disabled}>{busy ? 'Saving…' : 'Save rules'}</Button>
        </>
      )}
      {message && <p role={message.ok ? 'status' : 'alert'} className={message.ok ? 'text-[12.5px] text-primary' : 'text-[12.5px] text-red-600 dark:text-red-400'}>{message.text}</p>}
    </section>
  )
}
