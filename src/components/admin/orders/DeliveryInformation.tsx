"use client"

import { useEffect, useState } from 'react'
import { AlertCircle, Check, Copy, LoaderCircle } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { formatE164 } from '@/lib/auth/phone'
import { addOrderDeliveryNote, listOrderDeliveryNotes, type OrderDeliveryNote } from '@/lib/admin/orders'
import { formatDeliveryForCopy, parseDeliverySnapshot } from '@/lib/customer/addresses'
import type { Json } from '@/lib/supabase/database.types'
import { copyText } from '@/utils/copyText'

/**
 * Where this order goes: the copy taken when it was placed, never the customer's
 * saved address, which may have changed or gone since.
 */
export function DeliveryInformation({ shippingAddress }: { shippingAddress: Json | null }) {
  const snapshot = parseDeliverySnapshot(shippingAddress)
  const [copy, setCopy] = useState<'idle' | 'copied' | 'failed'>('idle')

  if (!snapshot) {
    return <p className="text-[13px] text-muted-foreground">No delivery address was recorded for this order.</p>
  }

  const rows: [string, string][] = [
    ['Recipient', snapshot.recipientName],
    ['Contact number', snapshot.contactNumber ? formatE164(snapshot.contactNumber) : ''],
    ['Province', snapshot.province],
    ['District', snapshot.district],
    ['City / Town', snapshot.city],
    ['Address', [snapshot.addressLine1, snapshot.addressLine2].filter(Boolean).join(', ')],
    ['Landmark', snapshot.landmark],
    ['Postal code', snapshot.postalCode],
    ['Instructions', snapshot.deliveryInstructions],
  ]

  async function copyAddress() {
    setCopy((await copyText(formatDeliveryForCopy(snapshot!))) ? 'copied' : 'failed')
  }

  return (
    <>
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-[13px]">
        {rows.map(([label, value]) => (
          <div key={label} className="contents">
            <dt className="text-muted-foreground">{label}</dt>
            <dd className={value ? 'min-w-0 break-words text-foreground' : 'text-muted-foreground'}>{value || 'Not given'}</dd>
          </div>
        ))}
      </dl>
      <div className="mt-3.5 flex items-center gap-3">
        <Button type="button" variant="secondary" size="sm" className="min-h-11" onClick={() => void copyAddress()}>
          {copy === 'copied' ? <Check size={14} className="mr-1.5" /> : <Copy size={14} className="mr-1.5" />}
          {copy === 'copied' ? 'Copied' : 'Copy address'}
        </Button>
        {copy === 'failed' && <p role="alert" className="text-[12px] text-red-500">Could not copy. Select the text above instead.</p>}
      </div>
    </>
  )
}

/** Staff-only, append-only, and read from a table customers have no policy on. */
export function OrderDeliveryNotes({ orderId, canAdd }: { orderId: string; canAdd: boolean }) {
  const [notes, setNotes] = useState<OrderDeliveryNote[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [draft, setDraft] = useState('')
  const [saving, setSaving] = useState(false)
  const [version, setVersion] = useState(0)

  useEffect(() => {
    let cancelled = false
    listOrderDeliveryNotes(orderId)
      .then((rows) => { if (!cancelled) { setNotes(rows); setError(null) } })
      .catch((err) => { if (!cancelled) setError(err instanceof Error ? err.message : 'Could not load the notes.') })
    return () => { cancelled = true }
  }, [orderId, version])

  async function add() {
    setSaving(true)
    setError(null)
    try {
      await addOrderDeliveryNote(orderId, draft.trim())
      setDraft('')
      setVersion((n) => n + 1)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The note was not saved.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      {!notes && !error && (
        <p className="flex items-center gap-2 text-[13px] text-muted-foreground">
          <LoaderCircle size={14} className="animate-spin motion-reduce:animate-none" /> Loading notes…
        </p>
      )}
      {notes?.length === 0 && <p className="text-[13px] text-muted-foreground">No internal notes yet.</p>}
      {notes && notes.length > 0 && (
        <ol className="space-y-2">
          {notes.map((note) => (
            <li key={note.id} className="rounded-xl border border-mint/70 dark:border-border bg-card px-3 py-2.5">
              <p className="whitespace-pre-wrap break-words text-[13px] text-foreground">{note.note}</p>
              <p className="mt-0.5 text-[11px] text-muted-foreground">
                {[note.authorName, new Date(note.createdAt).toLocaleString('en-GB', {
                  day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
                })].filter(Boolean).join(' · ')}
              </p>
            </li>
          ))}
        </ol>
      )}
      {error && (
        <p role="alert" className="mt-2 flex items-start gap-1.5 text-[12.5px] text-red-500">
          <AlertCircle size={14} className="mt-0.5 shrink-0" /> {error}
        </p>
      )}
      {canAdd && (
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <textarea
            rows={2} value={draft} maxLength={1000} disabled={saving} aria-label="New internal delivery note"
            placeholder="Add a note for staff" onChange={(e) => setDraft(e.target.value)}
            className="focus-ring min-w-0 flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
          <Button type="button" className="shrink-0" disabled={saving || !draft.trim()} onClick={() => void add()}>
            {saving ? 'Saving…' : 'Add note'}
          </Button>
        </div>
      )}
    </>
  )
}
