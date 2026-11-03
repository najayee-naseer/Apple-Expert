"use client"

import { useState } from 'react'
import {
  X, LoaderCircle, AlertCircle, Crown, LifeBuoy, Mail, Phone, User, StickyNote, Lock, Save,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { describeAdminError, logAdminError } from '@/lib/admin/errors'
import {
  APPLICATION_FIELDS, missingFields, fieldSource, customerValue, isDecidable,
  updateRequest, reviewRequest, REQUEST_STATUS_LABEL,
  type AdminWholesaleRequest, type ApplicationField, type FieldSource, type ReviewDecision,
} from '@/lib/admin/wholesaleRequests'
import {
  BUSINESS_TYPES, MONTHLY_VOLUMES, inputFromRequest, type WholesaleRequestInput,
} from '@/lib/customer/wholesale'

/**
 * One wholesale application, opened from the admin queue.
 *
 * An admin/owner can complete or correct the fields on the customer's behalf
 * (admin_update_wholesale_request), keep an internal note, and approve or
 * reject (admin_review_wholesale_request → admin_set_customer_type on
 * approval). Staff see the same screen read-only; the database refuses their
 * writes regardless of what this component renders.
 */

const INPUT =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 transition-colors disabled:opacity-70'

function dateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

const SOURCE_BADGE: Record<FieldSource, { label: string; className: string } | null> = {
  customer: { label: 'Customer-provided', className: 'border-border bg-muted text-muted-foreground' },
  'admin-entered': { label: 'Admin-entered', className: 'border-mint-deep bg-primary-soft text-primary' },
  'admin-corrected': { label: 'Corrected by admin', className: 'border-mint-deep bg-primary-soft text-primary' },
  empty: { label: 'Missing', className: 'border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-400' },
}

function SourceBadge({ source }: { source: FieldSource }) {
  const badge = SOURCE_BADGE[source]
  if (!badge) return null
  return (
    <span className={cn('inline-flex items-center rounded-full border px-2 py-0.5 text-[10.5px] font-semibold whitespace-nowrap', badge.className)}>
      {badge.label}
    </span>
  )
}

function optionsWith(list: readonly string[], current: string): string[] {
  return current && !list.includes(current) ? [current, ...list] : [...list]
}

export function WholesaleApplicationEditor({
  request, canReview, onClose, onChanged,
}: {
  request: AdminWholesaleRequest
  canReview: boolean
  onClose: () => void
  /** Called after any successful write, with a message for the toast. Re-read the queue. */
  onChanged: (message: string) => Promise<void>
}) {
  const open = isDecidable(request.status)
  const editable = canReview && open

  const [input, setInput] = useState<WholesaleRequestInput>(() => inputFromRequest(request))
  const [notes, setNotes] = useState(request.adminNotes ?? '')
  const [reason, setReason] = useState('')
  const [confirm, setConfirm] = useState<ReviewDecision | null>(null)
  const [busy, setBusy] = useState<'save' | ReviewDecision | null>(null)
  const [error, setError] = useState<string | null>(null)

  const saved = inputFromRequest(request)
  const fieldsDirty = APPLICATION_FIELDS.some((f) => input[f.key].trim() !== saved[f.key].trim())
  const notesDirty = notes.trim() !== (request.adminNotes ?? '').trim()
  const missing = missingFields(request)
  const who = request.customerName || request.customerEmail || request.business_name || 'This customer'

  function set(key: keyof WholesaleRequestInput, value: string) {
    setInput((prev) => ({ ...prev, [key]: value }))
  }

  /** Writes pending edits. Returns false (with the error shown) when the database refused. */
  async function persist(): Promise<boolean> {
    if (!fieldsDirty && !notesDirty) return true
    try {
      await updateRequest(request.id, editable && fieldsDirty ? input : null, notesDirty ? notes : null)
      return true
    } catch (err) {
      logAdminError('wholesale-requests:update', err)
      setError(describeAdminError(err, 'The database refused the changes.'))
      return false
    }
  }

  async function handleSave() {
    setError(null)
    setBusy('save')
    if (await persist()) {
      await onChanged(fieldsDirty ? `Application for ${who} saved and marked under review.` : 'Internal note saved.')
    }
    setBusy(null)
  }

  async function handleDecision(decision: ReviewDecision) {
    setError(null)
    if (decision === 'approved' && !input.businessName.trim()) {
      setError('Add the business name before approving.')
      setConfirm(null)
      return
    }
    if (decision === 'rejected' && !reason.trim()) {
      setError('Give the customer a reason so they know what to change.')
      return
    }
    setBusy(decision)
    // The decision is made on what is SAVED, so unsaved edits go first.
    if (!(await persist())) { setBusy(null); setConfirm(null); return }
    try {
      await reviewRequest(request.id, decision, decision === 'rejected' ? reason : '')
      await onChanged(decision === 'approved'
        ? `${who} is now a Wholesale VIP customer.`
        : `${who}'s application was returned for changes.`)
    } catch (err) {
      // Never claim success when the RPC refused.
      logAdminError('wholesale-requests:review', err)
      setError(describeAdminError(err, 'The database refused the decision.'))
      setConfirm(null)
    } finally {
      setBusy(null)
    }
  }

  function renderField(field: ApplicationField) {
    const value = input[field.key]
    const source = fieldSource(request, field)
    const original = source === 'admin-corrected' ? customerValue(request, field) : ''
    const id = `wa-${field.key}`
    const control =
      field.key === 'businessType' || field.key === 'monthlyVolume' ? (
        <select id={id} value={value} disabled={!editable || busy !== null}
          onChange={(e) => set(field.key, e.target.value)} className={cn(INPUT, 'h-11')}>
          <option value="">Not provided</option>
          {optionsWith(field.key === 'businessType' ? BUSINESS_TYPES : MONTHLY_VOLUMES, value).map((o) => (
            <option key={o} value={o}>{o}</option>
          ))}
        </select>
      ) : field.key === 'message' ? (
        <textarea id={id} rows={3} value={value} disabled={!editable || busy !== null}
          onChange={(e) => set(field.key, e.target.value)} placeholder="Not provided"
          className={cn(INPUT, 'resize-none py-2.5')} />
      ) : (
        <input id={id} type={field.key === 'contactPhone' ? 'tel' : 'text'} value={value}
          disabled={!editable || busy !== null} onChange={(e) => set(field.key, e.target.value)}
          placeholder="Not provided" className={cn(INPUT, 'h-11')} />
      )

    return (
      <div key={field.key}>
        <div className="mb-1.5 flex flex-wrap items-center justify-between gap-2">
          <label htmlFor={id} className="text-[12.5px] font-semibold text-foreground">{field.label}</label>
          <SourceBadge source={source} />
        </div>
        {control}
        {original && (
          <p className="mt-1 text-[11.5px] text-muted-foreground">Customer entered: {original}</p>
        )}
      </div>
    )
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:px-5">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />
      <div role="dialog" aria-modal="true" aria-labelledby="wa-title"
        className="relative flex max-h-[92vh] w-full max-w-2xl flex-col pb-[var(--safe-bottom)] rounded-t-[26px] sm:rounded-[26px] border border-mint/80 dark:border-border bg-surface shadow-float">

        <header className="flex items-start justify-between gap-3 border-b border-mint/70 dark:border-border px-5 py-4">
          <div className="min-w-0">
            <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">Wholesale Application</p>
            <h2 id="wa-title" className="mt-0.5 truncate text-[17px] font-bold tracking-tight text-foreground">
              {request.business_name.trim() || 'Business name not provided'}
            </h2>
            <p className="mt-1 text-[12px] text-muted-foreground">
              Status: <span className="font-semibold text-foreground">{REQUEST_STATUS_LABEL[request.status] ?? request.status}</span>
              {' · '}Applied {dateTime(request.submitted_at ?? request.created_at)}
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground">
            <X size={17} />
          </button>
        </header>

        <div className="flex-1 space-y-5 overflow-y-auto px-5 py-5">
          {request.status === 'assistance_requested' && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-4 py-3">
              <LifeBuoy size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">
                Customer requested assistance with wholesale application
                {request.assistance_requested_at ? ` on ${dateTime(request.assistance_requested_at)}` : ''}.
                Complete the missing details below, save, then approve.
              </p>
            </div>
          )}

          {/* Customer account */}
          <section className="rounded-2xl border border-mint/70 dark:border-border bg-card px-4 py-3">
            <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">Customer</p>
            <div className="flex flex-col gap-1.5 text-[13px] text-foreground">
              <span className="flex items-center gap-2"><User size={13} className="shrink-0 text-muted-foreground" />{request.customerName || 'No name on file'}</span>
              {request.customerEmail && <span className="flex items-center gap-2 min-w-0"><Mail size={13} className="shrink-0 text-muted-foreground" /><span className="truncate">{request.customerEmail}</span></span>}
              {request.customerPhone && <span className="flex items-center gap-2"><Phone size={13} className="shrink-0 text-muted-foreground" />{request.customerPhone} <span className="text-muted-foreground">(account)</span></span>}
              {request.customerType === 'wholesale_vip' && (
                <span className="flex items-center gap-2 text-primary"><Crown size={13} className="shrink-0" />On Wholesale VIP pricing</span>
              )}
            </div>
          </section>

          {/* Missing information */}
          {missing.length > 0 && (
            <section className="rounded-2xl border border-amber-500/25 bg-amber-500/8 px-4 py-3">
              <p className="text-[12.5px] font-semibold text-foreground">Missing information</p>
              <p className="mt-1 text-[12.5px] text-muted-foreground">{missing.map((f) => f.label).join(' · ')}</p>
              <p className="mt-1.5 text-[11.5px] text-muted-foreground">Only the business name is required to approve.</p>
            </section>
          )}

          {/* Application fields */}
          <section className="space-y-4">
            {APPLICATION_FIELDS.map(renderField)}
            {request.admin_updated_at && (
              <p className="text-[11.5px] text-muted-foreground">Last edited by an admin {dateTime(request.admin_updated_at)}.</p>
            )}
            {!canReview && (
              <p className="flex items-center gap-1.5 text-[12px] text-muted-foreground">
                <Lock size={12} /> Read-only — only an admin or owner can edit or decide applications.
              </p>
            )}
          </section>

          {/* Internal note */}
          <section>
            <label htmlFor="wa-notes" className="mb-1.5 flex items-center gap-1.5 text-[12.5px] font-semibold text-foreground">
              <StickyNote size={13} className="text-muted-foreground" /> Internal admin notes
              <span className="font-normal text-muted-foreground">(never shown to the customer)</span>
            </label>
            <textarea id="wa-notes" rows={2} value={notes} disabled={!canReview || busy !== null}
              onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Called the customer, registration certificate seen."
              className={cn(INPUT, 'resize-none py-2.5')} />
          </section>

          {/* Decision record for closed applications */}
          {!open && request.status !== 'draft' && (
            <section className="rounded-2xl border border-mint/70 dark:border-border bg-card px-4 py-3">
              <p className="text-[12px] text-muted-foreground">
                {REQUEST_STATUS_LABEL[request.status]} {request.reviewed_at ? dateTime(request.reviewed_at) : ''}
              </p>
              {request.review_note && <p className="mt-1.5 text-[13px] leading-relaxed text-foreground">{request.review_note}</p>}
            </section>
          )}

          {confirm === 'rejected' && (
            <section>
              <label htmlFor="wa-reason" className="mb-1.5 block text-[12.5px] font-semibold text-foreground">
                Reason for the customer
              </label>
              <textarea id="wa-reason" rows={2} value={reason} disabled={busy !== null}
                onChange={(e) => setReason(e.target.value)}
                placeholder="Your wholesale application needs additional information."
                className={cn(INPUT, 'resize-none py-2.5')} />
              <p className="mt-1 text-[11.5px] text-muted-foreground">The customer sees this and can update and resubmit.</p>
            </section>
          )}

          {confirm === 'approved' && (
            <p className="rounded-2xl border border-mint-deep bg-primary-soft px-4 py-3 text-[13px] leading-relaxed text-foreground">
              Approving makes this customer a Wholesale VIP immediately: they get the Wholesale Portal and
              VIP pricing on every product that has one.{fieldsDirty || notesDirty ? ' Your unsaved changes are saved first.' : ''}
            </p>
          )}

          {error && (
            <div role="alert" className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[13px] leading-snug text-foreground">{error}</p>
            </div>
          )}
        </div>

        {canReview && (
          <footer className="flex flex-col-reverse sm:flex-row sm:justify-end gap-2.5 border-t border-mint/70 dark:border-border px-5 py-4">
            {confirm ? (
              <>
                <Button variant="ghost" disabled={busy !== null} onClick={() => setConfirm(null)}>Cancel</Button>
                <Button disabled={busy !== null} onClick={() => void handleDecision(confirm)}>
                  {busy === confirm
                    ? <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" />
                    : confirm === 'approved' ? 'Confirm approval' : 'Reject application'}
                </Button>
              </>
            ) : (
              <>
                {(fieldsDirty || notesDirty) && (
                  <Button variant="secondary" disabled={busy !== null} onClick={() => void handleSave()}>
                    {busy === 'save'
                      ? <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" />
                      : <><Save size={14} className="mr-1.5" />Save</>}
                  </Button>
                )}
                {open && (
                  <>
                    <Button variant="ghost" disabled={busy !== null} onClick={() => { setError(null); setConfirm('rejected') }}>
                      Reject
                    </Button>
                    <Button disabled={busy !== null} onClick={() => { setError(null); setConfirm('approved') }}>
                      Approve Wholesale
                    </Button>
                  </>
                )}
              </>
            )}
          </footer>
        )}
      </div>
    </div>
  )
}
