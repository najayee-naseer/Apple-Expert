"use client"

import { useCallback, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import Link from 'next/link'
import { AlertCircle, Check, LoaderCircle, LogIn, MapPin, Pencil, Plus, RotateCw, Star, Trash2 } from 'lucide-react'
import { Header } from '@/components/ui/Header'
import { Button } from '@/components/ui/Button'
import { AddressForm } from '@/components/account/AddressForm'
import { useDialogFocus } from '@/components/ui/useDialogFocus'
import { AddressHeading, IncompleteNote, SavedAddressLines } from '@/components/account/AddressCard'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import {
  deleteAddress, listMyAddresses, setDefaultAddress, type SavedAddress,
} from '@/lib/customer/addresses'

/** The customer's address book. One page for Retail and Wholesale VIP alike. */

type Notice = { kind: 'success' | 'error'; message: string }

const ACTION = 'focus-ring inline-flex min-h-11 items-center gap-1.5 rounded-full px-3 text-[13px] font-semibold disabled:opacity-50 transition-colors'

/** Escape and the backdrop cancel; focus stays inside until it closes. */
function DeleteAddressDialog({ address, onCancel, onConfirm }: {
  address: SavedAddress
  onCancel: () => void
  onConfirm: () => void
}) {
  const ref = useRef<HTMLDivElement>(null)
  useDialogFocus(ref, onCancel)
  return createPortal(
    <div className="fixed inset-0 z-[60] flex items-center justify-center px-5">
      <button type="button" aria-label="Cancel" tabIndex={-1} onClick={onCancel}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />
      <div ref={ref} tabIndex={-1} role="alertdialog" aria-modal="true" aria-labelledby="delete-address-title"
        aria-describedby="delete-address-text"
        className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float focus:outline-none">
        <h2 id="delete-address-title" className="mb-2 text-lg font-bold tracking-tight text-foreground">Delete this address?</h2>
        <p id="delete-address-text" className="mb-5 break-words text-sm leading-relaxed text-muted-foreground">
          {address.line1}, {address.city} will be removed from your saved addresses. Orders you have already placed keep their delivery details.
        </p>
        <div className="flex gap-2.5">
          <Button variant="ghost" fullWidth autoFocus onClick={onCancel}>Keep it</Button>
          <Button fullWidth className="bg-none bg-red-500 hover:bg-red-600 shadow-none" onClick={onConfirm}>
            Delete
          </Button>
        </div>
      </div>
    </div>,
    document.body,
  )
}

export default function SavedAddressesPage() {
  const { status, userId, profile, phone } = useCustomerAuth()
  // Tagged with the account it was read for, so another account never sees it.
  const [loaded, setLoaded] = useState<{ owner: string; rows: SavedAddress[] } | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [notice, setNotice] = useState<Notice | null>(null)
  const [editing, setEditing] = useState<SavedAddress | 'new' | null>(null)
  const [deleting, setDeleting] = useState<SavedAddress | null>(null)
  const [busyId, setBusyId] = useState<string | null>(null)

  /** 'error' is still a session — only the profile read failed. */
  const hasSession = status === 'signed-in' || status === 'error'

  const addresses = hasSession && loaded && loaded.owner === userId ? loaded.rows : null

  useEffect(() => {
    // Signed out, the read would only be refused.
    if (!hasSession || !userId) return
    let cancelled = false
    listMyAddresses()
      .then((rows) => { if (!cancelled) { setLoaded({ owner: userId, rows }); setLoadError(null) } })
      .catch(() => { if (!cancelled) setLoadError('Your addresses could not be loaded.') })
    return () => { cancelled = true }
  }, [attempt, hasSession, userId])

  const reload = useCallback(() => setAttempt((n) => n + 1), [])
  const closeForm = useCallback(() => setEditing(null), [])

  if (status !== 'loading' && !hasSession) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <span className="mb-4 flex h-13 w-13 items-center justify-center rounded-full bg-well-strong border border-mint-deep text-primary">
            <LogIn size={23} strokeWidth={1.8} />
          </span>
          <h1 className="text-lg font-bold tracking-tight mb-1.5">Sign in to see your addresses</h1>
          <p className="mb-6 max-w-xs text-[13px] leading-relaxed text-muted-foreground">Saved addresses belong to a verified account.</p>
          <Link href="/account/sign-in" className="w-full max-w-xs"><Button fullWidth>Sign in with your phone</Button></Link>
        </main>
      </div>
    )
  }

  async function run(id: string, action: () => Promise<void>, success: string) {
    setBusyId(id)
    setNotice(null)
    try {
      await action()
      setNotice({ kind: 'success', message: success })
      reload()
    } catch (err) {
      setNotice({ kind: 'error', message: err instanceof Error ? err.message : 'That did not work. Please try again.' })
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="flex flex-col min-h-screen pb-10">
      <Header />
      <main className="px-4 py-6">
        <h1 className="mb-1 text-[28px] font-bold leading-tight tracking-tight">Saved Addresses</h1>
        <p className="mb-5 text-sm text-muted-foreground">
          Changing an address here never changes an order you have already placed.
        </p>

        {notice && (
          <div role={notice.kind === 'error' ? 'alert' : 'status'}
            className={`mb-4 flex items-start gap-2.5 rounded-2xl border px-4 py-3 ${notice.kind === 'error' ? 'border-red-500/25 bg-red-500/8' : 'border-mint-deep bg-primary-soft'}`}>
            {notice.kind === 'error'
              ? <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
              : <Check size={16} className="mt-0.5 shrink-0 text-primary" />}
            <p className={`text-[13px] ${notice.kind === 'error' ? 'text-foreground' : 'font-medium text-primary'}`}>{notice.message}</p>
          </div>
        )}

        {loadError && (
          <div className="flex items-center justify-between gap-3 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
            <p className="flex items-center gap-2 text-[13px] text-foreground">
              <AlertCircle size={15} className="shrink-0 text-red-500" /> {loadError}
            </p>
            <button type="button" onClick={() => { setLoadError(null); reload() }} className={`${ACTION} shrink-0 text-primary`}>
              <RotateCw size={14} /> Retry
            </button>
          </div>
        )}

        {!addresses && !loadError && (
          <div className="flex items-center justify-center gap-2.5 py-16 text-sm text-muted-foreground">
            <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading your addresses…
          </div>
        )}

        {addresses?.length === 0 && (
          <div className="flex flex-col items-center py-12 text-center">
            <span className="mb-4 flex h-16 w-16 items-center justify-center rounded-full border border-mint-deep bg-well-cool text-primary shadow-card">
              <MapPin size={26} strokeWidth={1.6} />
            </span>
            <p className="mb-1 font-semibold">No saved addresses yet</p>
            <p className="mb-6 max-w-xs text-sm text-muted-foreground">Add one now and checkout will be quicker next time.</p>
            <Button onClick={() => setEditing('new')}><Plus size={16} className="mr-1.5" /> Add an address</Button>
          </div>
        )}

        {addresses && addresses.length > 0 && (
          <>
            <div className="space-y-3.5">
              {addresses.map((address) => (
                <article key={address.id} className="rounded-[26px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
                  <AddressHeading address={address} />
                  <SavedAddressLines address={address} />
                  <IncompleteNote address={address} />
                  <div className="-mx-1 mt-2 flex flex-wrap items-center gap-1 border-t border-mint/70 dark:border-border pt-2">
                    <button type="button" disabled={busyId !== null} onClick={() => setEditing(address)}
                      aria-label={`Edit ${address.label || 'address'} at ${address.line1}`} className={`${ACTION} text-primary hover:bg-primary-soft`}>
                      <Pencil size={14} /> Edit
                    </button>
                    <button type="button" disabled={busyId !== null} onClick={() => setDeleting(address)}
                      aria-label={`Delete ${address.label || 'address'} at ${address.line1}`} className={`${ACTION} text-red-500 hover:bg-red-500/8`}>
                      <Trash2 size={14} /> Delete
                    </button>
                    {!address.isDefault && (
                      <button type="button" disabled={busyId !== null}
                        onClick={() => void run(address.id, () => setDefaultAddress(address.id), 'Default address updated.')}
                        aria-label={`Set ${address.line1} as default`} className={`${ACTION} ml-auto text-foreground hover:bg-primary-soft`}>
                        {busyId === address.id
                          ? <LoaderCircle size={14} className="animate-spin motion-reduce:animate-none" />
                          : <Star size={14} />} Set as Default
                      </button>
                    )}
                  </div>
                </article>
              ))}
            </div>
            <Button variant="secondary" fullWidth className="mt-4" onClick={() => setEditing('new')}>
              <Plus size={16} className="mr-1.5" /> Add another address
            </Button>
          </>
        )}

        <p className="mt-6 text-center text-[12.5px] text-muted-foreground">
          <Link href="/profile" className="focus-ring rounded-full px-2 py-1 font-semibold text-primary">Back to profile</Link>
        </p>
      </main>

      {editing && (
        <AddressForm
          address={editing === 'new' ? null : editing}
          prefill={{ name: profile?.full_name ?? '', phone: phone ?? '' }}
          isFirst={addresses?.length === 0}
          onClose={closeForm}
          onSaved={(_id, message) => { setEditing(null); setNotice({ kind: 'success', message }); reload() }}
        />
      )}

      {deleting && (
        <DeleteAddressDialog
          address={deleting}
          onCancel={() => setDeleting(null)}
          onConfirm={() => {
            const target = deleting
            setDeleting(null)
            void run(target.id, () => deleteAddress(target.id), 'Address deleted.')
          }}
        />
      )}
    </div>
  )
}
