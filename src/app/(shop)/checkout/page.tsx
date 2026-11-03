"use client"

import { useCallback, useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import {
  AlertCircle, ArrowLeft, ArrowRight, Check, CheckCircle2, LoaderCircle, LogIn, MapPin, Pencil, Plus, RotateCw, ShoppingBag,
} from 'lucide-react'
import { Header } from '@/components/ui/Header'
import { Button } from '@/components/ui/Button'
import { VipBadge } from '@/components/account/VipBadge'
import { AddressForm } from '@/components/account/AddressForm'
import { AddressHeading, IncompleteNote, SavedAddressLines } from '@/components/account/AddressCard'
import { useCart } from '@/context/CartContext'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { centsToRupees } from '@/lib/catalog'
import {
  deliveryPlace, isAddressComplete, listMyAddresses, type SavedAddress,
} from '@/lib/customer/addresses'
import {
  cartOrderKey, describeCartSelection, findMyOrderByRequest, newOrderRequestId, OrderError, placeOrder,
  type EarlierOrder, type PlacedOrder,
} from '@/lib/customer/orders'
import { formatPrice } from '@/utils/formatPrice'

/**
 * Checkout: choose where it goes, review, confirm. One screen for Retail and
 * Wholesale VIP; the database prices the order for the caller's own tier.
 *
 * The device sends only the id of the chosen address. place_order_v3() checks that
 * it belongs to this account and copies it onto the order.
 */

type Step = 'delivery' | 'review'

const SELECTED_KEY = 'apple-expert-checkout-address'

/** The choice survives a trip back to the bag. A convenience: the database decides ownership. */
function readSelected(userId: string | null): string | null {
  try {
    return userId ? sessionStorage.getItem(`${SELECTED_KEY}:${userId}`) : null
  } catch {
    return null
  }
}

function writeSelected(userId: string | null, addressId: string) {
  try {
    if (userId) sessionStorage.setItem(`${SELECTED_KEY}:${userId}`, addressId)
  } catch {
    // Blocked storage only loses the convenience.
  }
}

function clearSelected(userId: string | null) {
  try {
    if (userId) sessionStorage.removeItem(`${SELECTED_KEY}:${userId}`)
  } catch {
    // As above.
  }
}

/**
 * The request id of the order this customer is placing, and every basket sent
 * under it. It is kept until the outcome is known — the order confirmed, or found
 * after a lost response — and survives a reload, so no retry can order twice:
 * orders.request_id is unique per customer. The same id is used even if the
 * basket changes, so the database can say an earlier attempt went through.
 */
interface PendingRequest {
  id: string
  baskets: string[]
}

const REQUEST_KEY = 'apple-expert-checkout-request'

function readPending(userId: string): PendingRequest | null {
  try {
    const value = JSON.parse(sessionStorage.getItem(`${REQUEST_KEY}:${userId}`) ?? 'null') as PendingRequest | null
    return value && typeof value.id === 'string' && Array.isArray(value.baskets) ? value : null
  } catch {
    return null
  }
}

function writePending(userId: string, pending: PendingRequest) {
  try {
    sessionStorage.setItem(`${REQUEST_KEY}:${userId}`, JSON.stringify(pending))
  } catch {
    // Blocked storage: the in-memory copy still covers retries on this screen.
  }
}

function clearPending(userId: string) {
  try {
    sessionStorage.removeItem(`${REQUEST_KEY}:${userId}`)
  } catch {
    // As above.
  }
}

function Steps({ step }: { step: Step }) {
  const items: { key: Step; label: string }[] = [{ key: 'delivery', label: 'Delivery' }, { key: 'review', label: 'Review' }]
  return (
    <ol className="mb-5 flex items-center gap-2 text-[12.5px] font-semibold">
      {items.map((item, index) => {
        const active = item.key === step
        const done = step === 'review' && item.key === 'delivery'
        return (
          <li key={item.key} aria-current={active ? 'step' : undefined} className="flex items-center gap-2">
            {index > 0 && <span aria-hidden className="h-px w-6 bg-mint-deep dark:bg-border" />}
            <span className={`flex h-6 w-6 items-center justify-center rounded-full text-[11px] ${active || done ? 'bg-gradient-cta text-white' : 'border border-mint-deep bg-card text-muted-foreground'}`}>
              {done ? <Check size={13} strokeWidth={3} /> : index + 1}
            </span>
            <span className={active ? 'text-foreground' : 'text-muted-foreground'}>{item.label}</span>
          </li>
        )
      })}
    </ol>
  )
}

export default function CheckoutPage() {
  const { cart, cartTotal, cartCount, clearCart, unitPrice, warrantyFor } = useCart()
  const { status, userId, profile, phone, isWholesaleVip } = useCustomerAuth()

  const [step, setStep] = useState<Step>('delivery')
  const [addresses, setAddresses] = useState<SavedAddress[] | null>(null)
  const [loadError, setLoadError] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [editing, setEditing] = useState<SavedAddress | 'new' | null>(null)
  const [saved, setSaved] = useState<string | null>(null)
  const [placing, setPlacing] = useState(false)
  const [orderError, setOrderError] = useState<string | null>(null)
  const [placed, setPlaced] = useState<{
    order: PlacedOrder
    place: string
    /** Found after a lost response rather than confirmed by this attempt. */
    earlier?: boolean
    /** The bag differs from what that order held, so it was kept. */
    bagKept?: boolean
  } | null>(null)

  // Mirrors sessionStorage, for when storage is blocked.
  const pendingRef = useRef<PendingRequest | null>(null)
  // The cart as of the last render: a lookup that returns later compares against it.
  const cartRef = useRef(cart)
  // clearCart is a new function on every render; the lookup must not depend on it.
  const clearCartRef = useRef(clearCart)
  const reloadCheckedFor = useRef<string | null>(null)

  useEffect(() => {
    cartRef.current = cart
    clearCartRef.current = clearCart
  })

  const hasSession = status === 'signed-in' || status === 'error'
  const selected = addresses?.find((a) => a.id === selectedId) ?? null
  const blocked = cart.some((item) => warrantyFor(item)?.unavailable)
  const closeForm = useCallback(() => setEditing(null), [])

  useEffect(() => {
    if (!hasSession) return
    let cancelled = false
    listMyAddresses()
      .then((rows) => {
        if (cancelled) return
        setAddresses(rows)
        setLoadError(false)
        // Keep the current or remembered choice while it can still be delivered to,
        // otherwise fall to the default, then to any address that is complete.
        setSelectedId((current) => {
          const usable = rows.filter(isAddressComplete)
          const wanted = current ?? readSelected(userId)
          return usable.find((a) => a.id === wanted)?.id ?? usable.find((a) => a.isDefault)?.id ?? usable[0]?.id ?? null
        })
        // A customer with nothing saved has to add one, so open the form for them.
        if (rows.length === 0) setEditing('new')
      })
      .catch(() => { if (!cancelled) setLoadError(true) })
    return () => { cancelled = true }
  }, [attempt, hasSession, userId])

  useEffect(() => {
    if (selectedId) writeSelected(userId, selectedId)
  }, [selectedId, userId])

  const currentPending = useCallback((): PendingRequest | null => {
    if (!userId) return null
    const stored = readPending(userId)
    if (stored) pendingRef.current = stored
    return pendingRef.current
  }, [userId])

  /**
   * Shows the order an earlier attempt placed under this request id, if there is
   * one. The bag is emptied only if every basket sent under the id was this one;
   * otherwise it is kept, because that order may not hold what is in it now.
   * Throws if the lookup itself fails, leaving the request id in place.
   */
  const resolveEarlierAttempt = useCallback(async (pending: PendingRequest): Promise<boolean> => {
    if (!userId) return false
    const existing: EarlierOrder | null = await findMyOrderByRequest(pending.id, userId)
    if (!existing) return false
    const key = cartOrderKey(cartRef.current)
    const sameBasket = pending.baskets.every((basket) => basket === key)
    clearPending(userId)
    pendingRef.current = null
    clearSelected(userId)
    if (sameBasket) clearCartRef.current()
    setPlaced({
      order: existing,
      place: existing.delivery ? deliveryPlace(existing.delivery) : '',
      earlier: true,
      bagKept: !sameBasket,
    })
    return true
  }, [userId])

  // A reload after a lost response: if that attempt went through, say so now
  // rather than waiting for the customer to confirm again. Once per account.
  useEffect(() => {
    if (!hasSession || !userId || reloadCheckedFor.current === userId) return
    reloadCheckedFor.current = userId
    const pending = currentPending()
    if (!pending || pending.baskets.length === 0) return
    resolveEarlierAttempt(pending).catch(() => {
      // Unreachable now; confirming again replays the same request id safely.
    })
  }, [hasSession, userId, currentPending, resolveEarlierAttempt])

  async function confirmOrder() {
    if (!selected || !isAddressComplete(selected) || !userId) {
      setStep('delivery')
      return
    }
    setPlacing(true)
    setOrderError(null)
    const key = cartOrderKey(cart)
    const pending = currentPending() ?? { id: newOrderRequestId(), baskets: [] }
    if (!pending.baskets.includes(key)) pending.baskets = [...pending.baskets, key]
    // Stored before sending, so a reload while it is in flight keeps the id.
    pendingRef.current = pending
    writePending(userId, pending)
    try {
      const order = await placeOrder(cart, selected.id, pending.id)
      clearPending(userId)
      pendingRef.current = null
      clearSelected(userId)
      clearCart()
      setPlaced({ order, place: deliveryPlace(selected) })
    } catch (err) {
      const code = err instanceof OrderError ? err.code : null
      // An order already exists under this id, for another basket or address.
      // Show it rather than let a fresh id place a second one.
      if (code === 'request_id_reused') {
        try {
          if (await resolveEarlierAttempt(pending)) return
        } catch {
          // The lookup failed too: keep the id, so the next tap asks again.
        }
      }
      if (code === 'address_not_found' || code === 'address_incomplete' || code === 'address_required') {
        setSelectedId(null)
        setAttempt((n) => n + 1)
        setStep('delivery')
      }
      setOrderError(err instanceof Error ? err.message : 'Your order could not be placed. Please try again.')
    } finally {
      setPlacing(false)
    }
  }

  if (placed) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <div className="w-24 h-24 rounded-full bg-well-cool border border-mint-deep shadow-card flex items-center justify-center mb-6">
            <CheckCircle2 size={40} strokeWidth={1.6} className="text-primary" />
          </div>
          <h1 className="text-[22px] font-bold tracking-tight mb-1.5">Order placed</h1>
          <p className="text-sm text-muted-foreground mb-1">Order {placed.order.orderNumber}</p>
          <p className="text-lg font-bold tracking-tight mb-1">{formatPrice(centsToRupees(placed.order.totalCents))}</p>
          {placed.place && (
            <p className="flex items-center gap-1.5 text-[13px] text-muted-foreground mb-2">
              <MapPin size={13} className="text-primary" /> Delivering to {placed.place}
            </p>
          )}
          {placed.earlier && (
            <p role="status" className="text-[13px] font-medium text-foreground mb-2 max-w-xs leading-relaxed">
              {placed.bagKept
                ? 'This order went through on an earlier attempt, so nothing new was ordered. Your bag has changed since, so we kept it. Review it before ordering again.'
                : 'This order went through on an earlier attempt, so nothing new was ordered.'}
            </p>
          )}
          <p className="text-[13px] text-muted-foreground mb-8 max-w-xs leading-relaxed">
            We are holding your items and will contact you to confirm delivery and payment. Orders not confirmed within 48 hours are released.
          </p>
          <div className="flex w-full max-w-xs flex-col gap-2.5">
            <Link href="/orders"><Button fullWidth size="lg">View my orders</Button></Link>
            {placed.bagKept
              ? <Link href="/cart"><Button fullWidth variant="secondary">Review my bag</Button></Link>
              : <Link href="/categories"><Button fullWidth variant="secondary">Continue shopping</Button></Link>}
          </div>
        </main>
      </div>
    )
  }

  if (cart.length === 0) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <div className="w-24 h-24 rounded-full bg-well-cool border border-mint-deep shadow-card flex items-center justify-center mb-6">
            <ShoppingBag size={36} strokeWidth={1.5} className="text-primary" />
          </div>
          <h1 className="text-[22px] font-bold tracking-tight mb-2">Your cart is empty</h1>
          <p className="text-sm text-muted-foreground mb-8 max-w-xs leading-relaxed">Add something to your bag, then come back to check out.</p>
          <Link href="/categories" className="w-full max-w-xs"><Button fullWidth size="lg">Continue Shopping</Button></Link>
        </main>
      </div>
    )
  }

  if (status !== 'loading' && !hasSession) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <span className="mb-4 flex h-13 w-13 items-center justify-center rounded-full bg-well-strong border border-mint-deep text-primary">
            <LogIn size={23} strokeWidth={1.8} />
          </span>
          <h1 className="text-lg font-bold tracking-tight mb-1.5">Sign in to check out</h1>
          <p className="mb-6 max-w-xs text-[13px] leading-relaxed text-muted-foreground">Orders and saved addresses need a verified account.</p>
          <Link href="/account/sign-in" className="w-full max-w-xs"><Button fullWidth>Sign in with your phone</Button></Link>
        </main>
      </div>
    )
  }

  return (
    <div className="flex flex-col min-h-screen pb-36">
      <Header />

      <main className="px-4 py-6">
        <h1 className="mb-3 text-[28px] font-bold leading-tight tracking-tight text-foreground">
          {step === 'delivery' ? 'Where should it go?' : 'Review your order.'}
        </h1>
        <Steps step={step} />

        {saved && (
          <div role="status" className="mb-4 flex items-start gap-2.5 rounded-2xl border border-mint-deep bg-primary-soft px-4 py-3">
            <Check size={16} className="mt-0.5 shrink-0 text-primary" />
            <p className="text-[13px] font-medium text-primary">{saved}</p>
          </div>
        )}

        {orderError && (
          <div role="alert" className="mb-4 flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
            <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
            <p className="text-[13px] text-foreground">{orderError}</p>
          </div>
        )}

        {step === 'delivery' && (
          <section aria-label="Delivery address">
            {loadError && (
              <div className="flex items-center justify-between gap-3 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
                <p className="flex items-center gap-2 text-[13px] text-foreground">
                  <AlertCircle size={15} className="shrink-0 text-red-500" /> Your addresses could not be loaded.
                </p>
                <button type="button" onClick={() => { setLoadError(false); setAttempt((n) => n + 1) }}
                  className="focus-ring inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full px-3 text-[13px] font-semibold text-primary">
                  <RotateCw size={14} /> Retry
                </button>
              </div>
            )}

            {!addresses && !loadError && (
              <div className="flex items-center justify-center gap-2.5 py-14 text-sm text-muted-foreground">
                <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading your addresses…
              </div>
            )}

            {addresses?.length === 0 && (
              <div className="flex flex-col items-center rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 text-center shadow-card">
                <span className="mb-3 flex h-13 w-13 items-center justify-center rounded-full border border-mint-deep bg-well-cool text-primary">
                  <MapPin size={22} strokeWidth={1.7} />
                </span>
                <p className="mb-1 font-semibold">Add a delivery address</p>
                <p className="max-w-xs text-[13px] text-muted-foreground">We need to know where to deliver before you can place this order.</p>
              </div>
            )}

            {addresses && addresses.length > 0 && (
              <div role="radiogroup" aria-label="Choose a delivery address" className="space-y-3">
                {addresses.map((address) => {
                  const usable = isAddressComplete(address)
                  const isSelected = address.id === selectedId
                  return (
                    <div key={address.id}
                      className={`rounded-[26px] border bg-surface shadow-card transition-colors ${isSelected ? 'border-primary/60 ring-1 ring-primary/30' : 'border-mint/80 dark:border-border'}`}>
                      <label className={`flex items-start gap-3 p-4 pb-2 ${usable ? 'cursor-pointer' : 'opacity-70'}`}>
                        <input type="radio" name="delivery-address" checked={isSelected} disabled={!usable}
                          onChange={() => { setSelectedId(address.id); setOrderError(null) }}
                          className="mt-0.5 h-5 w-5 shrink-0 accent-[var(--primary)]" />
                        <span className="min-w-0 flex-1">
                          <AddressHeading address={address} />
                          <SavedAddressLines address={address} />
                          <IncompleteNote address={address} />
                        </span>
                      </label>
                      <div className="flex justify-end px-3 pb-2">
                        <button type="button" onClick={() => setEditing(address)} aria-label={`Edit ${address.line1}`}
                          className="focus-ring inline-flex min-h-11 items-center gap-1.5 rounded-full px-3 text-[13px] font-semibold text-primary hover:bg-primary-soft">
                          <Pencil size={14} /> Edit
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}

            {addresses && (
              <Button variant="secondary" fullWidth className="mt-3.5" onClick={() => setEditing('new')}>
                <Plus size={16} className="mr-1.5" /> Add a new address
              </Button>
            )}
          </section>
        )}

        {step === 'review' && selected && (
          <div className="space-y-3.5">
            <section aria-label="Delivery address" className="rounded-[26px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="mb-1.5 text-[13px] font-bold text-foreground">Delivering to</p>
                  <AddressHeading address={selected} />
                  <SavedAddressLines address={selected} />
                </div>
                <button type="button" onClick={() => { setStep('delivery'); setOrderError(null) }}
                  className="focus-ring -mr-1 -mt-1 inline-flex min-h-11 shrink-0 items-center rounded-full px-3 text-[13px] font-semibold text-primary hover:bg-primary-soft">
                  Change
                </button>
              </div>
            </section>

            <section aria-label="Items" className="rounded-[26px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
              <div className="mb-2 flex items-center justify-between gap-2">
                <p className="text-[13px] font-bold text-foreground">{cartCount} {cartCount === 1 ? 'item' : 'items'}</p>
                <Link href="/cart" className="focus-ring inline-flex min-h-11 items-center rounded-full px-3 -mr-1 text-[13px] font-semibold text-primary hover:bg-primary-soft">Edit bag</Link>
              </div>
              <ul className="divide-y divide-mint/70 dark:divide-border">
                {cart.map((item) => {
                  const warranty = warrantyFor(item)
                  const selection = describeCartSelection(item)
                  return (
                    <li key={item.id} className="flex items-start justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                      <div className="min-w-0">
                        <p className="text-[14px] font-semibold leading-tight">{item.product.name}</p>
                        <p className="mt-0.5 text-[12px] text-muted-foreground">
                          {[selection, `Qty ${item.quantity}`].filter(Boolean).join(' · ')}
                        </p>
                        {warranty && (
                          <p className={`mt-0.5 text-[12px] ${warranty.unavailable ? 'text-red-500' : 'text-muted-foreground'}`}>
                            {warranty.unavailable ? `${warranty.label} is no longer offered` : warranty.label}
                          </p>
                        )}
                      </div>
                      <span className="shrink-0 text-[14px] font-bold">{formatPrice(unitPrice(item) * item.quantity)}</span>
                    </li>
                  )
                })}
              </ul>
            </section>

            <section aria-label="Order summary" className="rounded-[26px] border border-mint/80 dark:border-border bg-surface p-5 shadow-card">
              {isWholesaleVip && (
                <div className="flex flex-wrap items-center gap-2 mb-4 pb-4 border-b border-mint/70 dark:border-border">
                  <VipBadge />
                  <span className="text-[12px] text-muted-foreground">Wholesale VIP pricing applied where set</span>
                </div>
              )}
              <div className="flex justify-between items-center mb-3 text-sm text-muted-foreground">
                <span>Subtotal</span>
                <span className="font-semibold text-foreground">{formatPrice(cartTotal)}</span>
              </div>
              <div className="flex justify-between items-center mb-4 text-sm text-muted-foreground">
                <span>Delivery</span>
                <span className="font-semibold text-primary">Free</span>
              </div>
              <div className="flex justify-between items-center text-lg font-bold pt-4 border-t border-mint-deep">
                <span>Total</span>
                <span>{formatPrice(cartTotal)}</span>
              </div>
              <p className="mt-3 text-[11.5px] leading-relaxed text-muted-foreground">
                Prices and warranty add-ons are confirmed by our system when you place the order.
              </p>
            </section>
          </div>
        )}
      </main>

      {/* The same floating panel as the bag, above the bottom navigation. */}
      <div className="fixed left-3 right-3 z-40 mx-auto w-auto max-w-[456px]" style={{ bottom: 'calc(var(--nav-offset) + 0.5rem)' }}>
        <div className="rounded-[26px] border border-primary/25 dark:border-primary/15 bg-purchase shadow-purchase p-3">
          <div className="flex items-center gap-2">
            {step === 'review' ? (
              <button type="button" onClick={() => setStep('delivery')} aria-label="Back to delivery address" disabled={placing}
                className="focus-ring shrink-0 w-11 h-11 min-[360px]:w-12 min-[360px]:h-12 rounded-2xl bg-card border border-mint-deep dark:border-border text-foreground flex items-center justify-center active:scale-95 transition-transform disabled:opacity-50">
                <ArrowLeft size={19} />
              </button>
            ) : (
              <Link href="/cart" aria-label="Back to bag"
                className="focus-ring shrink-0 w-11 h-11 min-[360px]:w-12 min-[360px]:h-12 rounded-2xl bg-card border border-mint-deep dark:border-border text-foreground flex items-center justify-center active:scale-95 transition-transform">
                <ArrowLeft size={19} />
              </Link>
            )}
            <div className="min-w-0 flex-1">
              <span className="block text-[11px] font-medium text-foreground/70 dark:text-muted-foreground leading-none mb-1">Total</span>
              <span className="block text-[17px] min-[360px]:text-[19px] font-bold tracking-tight text-[var(--purchase-price)] dark:text-foreground truncate">
                {formatPrice(cartTotal)}
              </span>
            </div>
            {step === 'delivery' ? (
              <Button size="lg" disabled={!selected}
                onClick={() => { setStep('review'); setOrderError(null); setSaved(null); window.scrollTo(0, 0) }}
                className="shrink-0 h-11 min-[360px]:h-12 px-5 text-[15px] bg-gradient-cta-deep hover:bg-gradient-cta-deep-hover shadow-purchase-cta hover:shadow-purchase-cta-hover">
                Continue <ArrowRight size={16} className="ml-1.5" />
              </Button>
            ) : (
              <Button size="lg" disabled={placing || blocked || !selected} onClick={() => void confirmOrder()}
                className="shrink-0 h-11 min-[360px]:h-12 px-5 text-[15px] bg-gradient-cta-deep hover:bg-gradient-cta-deep-hover shadow-purchase-cta hover:shadow-purchase-cta-hover">
                {placing
                  ? <><LoaderCircle size={16} className="mr-1.5 animate-spin motion-reduce:animate-none" />Placing…</>
                  : 'Confirm order'}
              </Button>
            )}
          </div>
        </div>
      </div>

      {editing && (
        <AddressForm
          address={editing === 'new' ? null : editing}
          prefill={{ name: profile?.full_name ?? '', phone: phone ?? '' }}
          isFirst={addresses?.length === 0}
          onClose={closeForm}
          onSaved={(id, message) => {
            setEditing(null)
            setSaved(message)
            setSelectedId(id)
            setAttempt((n) => n + 1)
          }}
        />
      )}
    </div>
  )
}
