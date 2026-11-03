"use client"

import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { AlertCircle, LoaderCircle, RotateCw, X } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { PhoneField } from '@/components/account/PhoneField'
import { useDialogFocus } from '@/components/ui/useDialogFocus'
import { DEFAULT_COUNTRY_ISO } from '@/lib/auth/phone'
import {
  ADDRESS_LABELS, loadDeliveryRegions, saveAddress, splitPhone, validateAddress,
  type AddressErrors, type AddressInput, type DeliveryProvince, type SavedAddress,
} from '@/lib/customer/addresses'

const INPUT = 'focus-ring h-12 w-full rounded-2xl border border-mint-deep dark:border-border bg-card px-4 text-sm text-foreground transition-colors placeholder:text-muted-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60'

function initialInput(address: SavedAddress | null, prefill: { name: string; phone: string }): AddressInput {
  const phone = address?.phone || prefill.phone
  const split = phone ? splitPhone(phone) : { iso: DEFAULT_COUNTRY_ISO, national: '' }
  return {
    label: address?.label || 'Home',
    recipientName: address?.recipientName || prefill.name,
    phoneIso: split.iso,
    phoneNational: split.national,
    province: address?.province ?? '',
    district: address?.district ?? '',
    city: address?.city ?? '',
    line1: address?.line1 ?? '',
    line2: address?.line2 ?? '',
    landmark: address?.landmark ?? '',
    postalCode: address?.postalCode ?? '',
    deliveryInstructions: address?.deliveryInstructions ?? '',
    makeDefault: false,
  }
}

function Field({ label, optional, error, children }: {
  label: string
  optional?: boolean
  error?: string
  children: (props: { id: string; 'aria-invalid': boolean; 'aria-describedby'?: string }) => React.ReactNode
}) {
  const id = useId()
  const errorId = `${id}-error`
  return (
    <div data-field>
      <label htmlFor={id} className="mb-1.5 block text-[13px] font-semibold text-foreground">
        {label}{optional && <span className="ml-1 font-normal text-muted-foreground">(optional)</span>}
      </label>
      {children({ id, 'aria-invalid': Boolean(error), 'aria-describedby': error ? errorId : undefined })}
      {error && <p id={errorId} className="mt-1.5 text-[12px] text-red-500">{error}</p>}
    </div>
  )
}

/** Asks before a close would throw away what the customer typed. */
function DiscardChanges({ onKeep, onDiscard }: { onKeep: () => void; onDiscard: () => void }) {
  const ref = useRef<HTMLDivElement>(null)
  useDialogFocus(ref, onKeep)
  return (
    <div className="absolute inset-0 z-10 flex items-center justify-center rounded-t-[26px] sm:rounded-[26px] bg-black/35 px-5">
      <div ref={ref} tabIndex={-1} role="alertdialog" aria-modal="true" aria-labelledby="discard-address-title"
        aria-describedby="discard-address-text"
        className="w-full max-w-sm rounded-[22px] border border-mint/80 dark:border-border bg-surface p-5 shadow-float focus:outline-none">
        <h3 id="discard-address-title" className="mb-1.5 text-[16px] font-bold tracking-tight text-foreground">Discard your changes?</h3>
        <p id="discard-address-text" className="mb-4 text-[13px] leading-relaxed text-muted-foreground">
          What you have typed in this address will not be saved.
        </p>
        {/* Stacked on the narrowest phones, where "Keep editing" would wrap. */}
        <div className="flex flex-col gap-2.5 min-[360px]:flex-row">
          <Button type="button" variant="ghost" fullWidth autoFocus onClick={onKeep}>Keep editing</Button>
          <Button type="button" fullWidth className="bg-none bg-red-500 hover:bg-red-600 shadow-none" onClick={onDiscard}>Discard</Button>
        </div>
      </div>
    </div>
  )
}

/**
 * Add or edit one saved address, as a sheet over whichever screen opened it, so a
 * customer in checkout keeps their place. Province chooses the districts on offer,
 * from the same list the database enforces.
 *
 * On a phone the keyboard shrinks the screen (Capacitor Keyboard resize "native"
 * on iOS, SystemBars insets on Android), so the sheet fits above it with Save in
 * view; the focused field, with its error, is scrolled back into view each time.
 */
export function AddressForm({ address, prefill, isFirst, onSaved, onClose }: {
  address: SavedAddress | null
  prefill: { name: string; phone: string }
  isFirst: boolean
  onSaved: (id: string, message: string) => void
  onClose: () => void
}) {
  const [initial] = useState<AddressInput>(() => initialInput(address, prefill))
  const [input, setInput] = useState<AddressInput>(initial)
  const [confirmDiscard, setConfirmDiscard] = useState(false)
  const [errors, setErrors] = useState<AddressErrors>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [regions, setRegions] = useState<DeliveryProvince[] | null>(null)
  const [regionsFailed, setRegionsFailed] = useState(false)
  const [regionsAttempt, setRegionsAttempt] = useState(0)
  const panelRef = useRef<HTMLDivElement>(null)
  const phoneErrorId = useId()

  useEffect(() => {
    let cancelled = false
    loadDeliveryRegions()
      .then((rows) => { if (!cancelled) { setRegions(rows); setRegionsFailed(false) } })
      .catch(() => { if (!cancelled) setRegionsFailed(true) })
    return () => { cancelled = true }
  }, [regionsAttempt])

  const dirty = (Object.keys(initial) as (keyof AddressInput)[]).some((key) => initial[key] !== input[key])

  // Close button, Cancel, the backdrop and Escape all come here. Nothing typed is
  // lost without the customer saying so, and nothing closes mid-save.
  const requestClose = useCallback(() => {
    if (saving) return
    if (dirty) setConfirmDiscard(true)
    else onClose()
  }, [saving, dirty, onClose])

  useDialogFocus(panelRef, requestClose)

  // The keyboard opening resizes the screen after focus has already moved, so the
  // field is revealed again on every resize, not just on focus.
  useEffect(() => {
    const panel = panelRef.current
    if (!panel) return
    let frame = 0
    function reveal() {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        const active = document.activeElement
        if (!(active instanceof HTMLElement) || !panel!.contains(active) || !active.matches('input, select, textarea')) return
        ;(active.closest('[data-field]') ?? active).scrollIntoView({ block: 'nearest' })
      })
    }
    panel.addEventListener('focusin', reveal)
    window.addEventListener('resize', reveal)
    window.visualViewport?.addEventListener('resize', reveal)
    return () => {
      cancelAnimationFrame(frame)
      panel.removeEventListener('focusin', reveal)
      window.removeEventListener('resize', reveal)
      window.visualViewport?.removeEventListener('resize', reveal)
    }
  }, [])

  function set<K extends keyof AddressInput>(key: K, value: AddressInput[K]) {
    setInput((current) => ({ ...current, [key]: value }))
    setErrors((current) => ({ ...current, [key]: undefined }))
  }

  const districts = regions?.find((p) => p.name === input.province)?.districts ?? []

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    const found = validateAddress(input)
    setErrors(found)
    setFormError(null)
    if (Object.keys(found).length > 0) {
      requestAnimationFrame(() => panelRef.current?.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus())
      return
    }
    setSaving(true)
    try {
      const id = await saveAddress(address?.id ?? null, input)
      onSaved(id, address ? 'Address updated.' : 'Address saved.')
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Your address could not be saved. Please try again.')
      setSaving(false)
    }
  }

  // On the body, above the bottom navigation, which would otherwise cover the buttons.
  return createPortal(
    <div className="fixed inset-0 z-[60] flex items-end justify-center sm:items-center">
      <button type="button" aria-label="Close" tabIndex={-1} onClick={requestClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />
      <div ref={panelRef} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="address-form-title"
        className="relative flex max-h-[92vh] supports-[height:100dvh]:max-h-[92dvh] w-full max-w-[480px] flex-col rounded-t-[26px] sm:rounded-[26px] border border-mint/80 dark:border-border bg-surface shadow-float focus:outline-none">
        <header className="flex items-center justify-between gap-3 border-b border-mint/70 dark:border-border px-5 py-4">
          <h2 id="address-form-title" className="text-[17px] font-bold tracking-tight text-foreground">
            {address ? 'Edit address' : 'Add a delivery address'}
          </h2>
          <button type="button" onClick={requestClose} aria-label="Close"
            className="focus-ring flex h-11 w-11 -mr-2 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <form onSubmit={(event) => void submit(event)} noValidate className="flex min-h-0 flex-1 flex-col">
          <div className="flex-1 space-y-4 overflow-y-auto px-5 py-4">
            <fieldset>
              <legend className="mb-1.5 text-[13px] font-semibold text-foreground">Save as</legend>
              <div className="flex gap-2">
                {ADDRESS_LABELS.map((option) => (
                  <label key={option}
                    className={`flex h-11 flex-1 cursor-pointer items-center justify-center rounded-full border text-[13px] font-semibold transition-colors has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-primary/40 ${
                      input.label === option ? 'border-primary/45 bg-primary-soft text-primary' : 'border-mint-deep dark:border-border bg-card text-muted-foreground'
                    }`}>
                    <input type="radio" name="address-label" value={option} checked={input.label === option}
                      onChange={() => set('label', option)} disabled={saving} className="sr-only" />
                    {option}
                  </label>
                ))}
              </div>
            </fieldset>

            <Field label="Recipient name" error={errors.recipientName}>
              {(props) => (
                <input {...props} type="text" autoComplete="name" value={input.recipientName} disabled={saving}
                  onChange={(e) => set('recipientName', e.target.value)} className={INPUT} />
              )}
            </Field>

            <div data-field>
              <PhoneField
                label="Contact number"
                hint="The courier calls this number. It can belong to someone else."
                iso={input.phoneIso}
                onIsoChange={(iso) => set('phoneIso', iso)}
                national={input.phoneNational}
                onNationalChange={(national) => set('phoneNational', national)}
                invalid={Boolean(errors.phoneNational)}
                describedBy={errors.phoneNational ? phoneErrorId : undefined}
                disabled={saving}
              />
              {errors.phoneNational && <p id={phoneErrorId} className="mt-1.5 text-[12px] text-red-500">{errors.phoneNational}</p>}
            </div>

            {regionsFailed ? (
              <div role="alert" className="flex items-center justify-between gap-3 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
                <p className="text-[13px] text-foreground">Provinces could not be loaded.</p>
                <button type="button" onClick={() => { setRegionsFailed(false); setRegionsAttempt((n) => n + 1) }}
                  className="focus-ring inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full px-3 text-[13px] font-semibold text-primary">
                  <RotateCw size={14} /> Retry
                </button>
              </div>
            ) : (
              <>
                <Field label="Province" error={errors.province}>
                  {(props) => (
                    <select {...props} value={input.province} disabled={saving || !regions}
                      onChange={(e) => { set('province', e.target.value); set('district', '') }} className={INPUT}>
                      <option value="">{regions ? 'Choose a province' : 'Loading…'}</option>
                      {regions?.map((p) => <option key={p.name} value={p.name}>{p.name}</option>)}
                    </select>
                  )}
                </Field>
                <Field label="District" error={errors.district}>
                  {(props) => (
                    <select {...props} value={input.district} disabled={saving || !input.province}
                      onChange={(e) => set('district', e.target.value)} className={INPUT}>
                      <option value="">{input.province ? 'Choose a district' : 'Choose a province first'}</option>
                      {districts.map((d) => <option key={d} value={d}>{d}</option>)}
                    </select>
                  )}
                </Field>
              </>
            )}

            <Field label="City / Town" error={errors.city}>
              {(props) => (
                <input {...props} type="text" autoComplete="address-level2" value={input.city} disabled={saving}
                  onChange={(e) => set('city', e.target.value)} className={INPUT} />
              )}
            </Field>
            <Field label="Street address" error={errors.line1}>
              {(props) => (
                <input {...props} type="text" autoComplete="address-line1" placeholder="No. 25, Main Street" value={input.line1} disabled={saving}
                  onChange={(e) => set('line1', e.target.value)} className={INPUT} />
              )}
            </Field>
            <Field label="Apartment, floor or area" optional error={errors.line2}>
              {(props) => (
                <input {...props} type="text" autoComplete="address-line2" value={input.line2} disabled={saving}
                  onChange={(e) => set('line2', e.target.value)} className={INPUT} />
              )}
            </Field>
            <Field label="Landmark" optional error={errors.landmark}>
              {(props) => (
                <input {...props} type="text" placeholder="Near Main Junction" value={input.landmark} disabled={saving}
                  onChange={(e) => set('landmark', e.target.value)} className={INPUT} />
              )}
            </Field>
            <Field label="Postal code" optional error={errors.postalCode}>
              {(props) => (
                <input {...props} type="text" inputMode="numeric" autoComplete="postal-code" maxLength={5} value={input.postalCode} disabled={saving}
                  onChange={(e) => set('postalCode', e.target.value)} className={INPUT} />
              )}
            </Field>
            <Field label="Delivery instructions" optional error={errors.deliveryInstructions}>
              {(props) => (
                <textarea {...props} rows={2} placeholder="Please call before delivery" value={input.deliveryInstructions} disabled={saving}
                  onChange={(e) => set('deliveryInstructions', e.target.value)}
                  className="focus-ring w-full rounded-2xl border border-mint-deep dark:border-border bg-card px-4 py-3 text-sm text-foreground transition-colors placeholder:text-muted-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60" />
              )}
            </Field>

            {isFirst ? (
              <p className="text-[12.5px] text-muted-foreground">Your first address becomes your default.</p>
            ) : !address?.isDefault && (
              <label className="flex min-h-11 cursor-pointer items-center gap-3 text-[13px] font-medium text-foreground">
                <input type="checkbox" checked={input.makeDefault} disabled={saving}
                  onChange={(e) => set('makeDefault', e.target.checked)}
                  className="h-5 w-5 shrink-0 accent-[var(--primary)]" />
                Use as my default address
              </label>
            )}

            {formError && (
              <div role="alert" className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
                <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
                <p className="text-[13px] text-foreground">{formError}</p>
              </div>
            )}
          </div>

          <footer className="flex gap-2.5 border-t border-mint/70 dark:border-border px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
            <Button type="button" variant="ghost" fullWidth disabled={saving} onClick={requestClose}>Cancel</Button>
            <Button type="submit" fullWidth disabled={saving}>
              {saving ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</> : 'Save address'}
            </Button>
          </footer>
        </form>

        {confirmDiscard && (
          <DiscardChanges onKeep={() => setConfirmDiscard(false)} onDiscard={onClose} />
        )}
      </div>
    </div>,
    document.body,
  )
}
