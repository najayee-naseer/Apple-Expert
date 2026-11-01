"use client"

import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react'
import { Camera, Check, LoaderCircle, Minus, Plus, Printer, ScanBarcode, Trash2, ReceiptText, RotateCcw, UserRound, X } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { CameraScanner, cameraScanSupported } from '@/components/admin/inventory/CameraScanner'
import { ErrorNote, SuccessNote, TH, TABLE_CARD, SELECT_CLASS, parseRupees } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { useStoreSettings } from '@/lib/store/settings'
import { buildBillPdf } from '@/lib/admin/bill'
import { openPdf } from '@/lib/admin/labels'
import { InterruptedSalePanel, PriceChangesPanel, type InterruptedStep } from '@/components/admin/inventory/PosSalePanels'
import {
  addQuantity, addUnit, applyPriceChanges, changeQuantity, classifySaleError, createTaskQueue, expectedPrices, isCodeOnBill, lineCents, parsePriceChanges,
  type CartChange, type CartLine, type PriceChange, type TaskQueue,
} from '@/lib/admin/posCart'
import {
  posScan, quoteProduct, posCheckout, checkPosPrices, findSaleByRequest, loadPosSale, listPosSales, listProductsForGrn, canSell, canReceiveStock, newRequestId, normalizeCode,
  findCounterCustomer, loadInventoryPolicy, requestDiscountApproval, loadDiscountApproval, listPendingDiscountApprovals, decideDiscountApproval,
  describeUnitError, formatDateTime, paymentLabel, trackingModeOf, PAYMENT_METHODS,
  type PaymentMethod, type PosSaleListItem, type PosSaleResult,
  type CounterCustomer, type DiscountApproval, type GrnProductOption, type PosItemInput, type PosSaleInput,
} from '@/lib/admin/units'

const INPUT =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

const noop = () => () => {}

const INTERRUPTED_KEY = 'apple-expert.pos.interrupted-sale'

/** Everything needed to put an unresolved bill back after a reload, request id included. */
interface InterruptedSale {
  input: PosSaleInput
  cart: CartLine[]
  customer: CounterCustomer | null
  discount: string
}

function rememberInterrupted(sale: InterruptedSale | null) {
  try {
    if (sale) window.localStorage.setItem(INTERRUPTED_KEY, JSON.stringify(sale))
    else window.localStorage.removeItem(INTERRUPTED_KEY)
  } catch { /* the panel still works until the page is reloaded */ }
}

function recallInterrupted(): InterruptedSale | null {
  try {
    const saved = window.localStorage.getItem(INTERRUPTED_KEY)
    return saved ? JSON.parse(saved) as InterruptedSale : null
  } catch {
    return null
  }
}

/** Short beep: the cashier hears a scan land without looking at the screen. */
function beep(ok: boolean) {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!Ctx) return
    const ctx = new Ctx()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = ok ? 1200 : 220
    gain.gain.value = 0.08
    osc.connect(gain).connect(ctx.destination)
    osc.start()
    osc.stop(ctx.currentTime + (ok ? 0.08 : 0.25))
    osc.onended = () => void ctx.close()
  } catch { /* sound is a nicety */ }
}

/**
 * Shop counter (POS). Scan each item's barcode label — or its box IMEI — and
 * those exact units are sold when the bill is completed; scanning a product barcode
 * adds one more of that item, and quantity-tracked items can also be picked from
 * the product list. Prices come from the database at the served
 * customer's tier, and the database enforces the discount limit: this screen only
 * explains it.
 */
export default function AdminPosPage() {
  const { role } = useAdminAuth()
  const { settings } = useStoreSettings()
  const allowed = canSell(role)
  const isAdmin = canReceiveStock(role)
  const cameraOk = useSyncExternalStore(noop, cameraScanSupported, () => false)

  const [requestId, setRequestId] = useState(newRequestId)
  const [cart, setCart] = useState<CartLine[]>([])
  const [code, setCode] = useState('')
  const [scanning, setScanning] = useState(false)
  const [scanErrors, setScanErrors] = useState<string[]>([])
  const [camera, setCamera] = useState(false)

  const [products, setProducts] = useState<GrnProductOption[]>([])
  const [pickProduct, setPickProduct] = useState('')
  const [pickVariant, setPickVariant] = useState('')
  const [pickQty, setPickQty] = useState('1')

  const [customerQuery, setCustomerQuery] = useState('')
  const [customer, setCustomer] = useState<CounterCustomer | null>(null)
  const [customerMatches, setCustomerMatches] = useState<CounterCustomer[] | null>(null)

  const [staffMaxBps, setStaffMaxBps] = useState<number>(0)
  const [approval, setApproval] = useState<DiscountApproval | null>(null)
  const [approvalReason, setApprovalReason] = useState('')
  const [pending, setPending] = useState<DiscountApproval[]>([])

  const [discount, setDiscount] = useState('')
  const [payment, setPayment] = useState<PaymentMethod>('cash')
  const [paymentReference, setPaymentReference] = useState('')
  const [customerName, setCustomerName] = useState('')
  const [customerPhone, setCustomerPhone] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [saleError, setSaleError] = useState<string | null>(null)
  const [done, setDone] = useState<PosSaleResult | null>(null)
  const [priceChanges, setPriceChanges] = useState<PriceChange[]>([])
  const [pricesUpdated, setPricesUpdated] = useState(false)
  const [interrupted, setInterrupted] = useState<InterruptedSale | null>(null)
  const [interruptedStep, setInterruptedStep] = useState<InterruptedStep>('interrupted')

  const [sales, setSales] = useState<PosSaleListItem[] | null>(null)
  const [salesError, setSalesError] = useState<string | null>(null)
  const [printing, setPrinting] = useState<string | null>(null)

  const scanRef = useRef<HTMLInputElement>(null)
  // Always the latest bill: a scan must see what the one before it left.
  const cartRef = useRef(cart)
  const cameraRef = useRef(false)
  const queueRef = useRef<TaskQueue | null>(null)
  const customerRef = useRef<string | null>(null)
  useEffect(() => { customerRef.current = customer?.profileId ?? null }, [customer])

  const scanningRef = useRef(false)
  useEffect(() => {
    queueRef.current = createTaskQueue((value) => { scanningRef.current = value; setScanning(value) })
  }, [])
  useEffect(() => { cameraRef.current = camera }, [camera])

  // A bill stays frozen until its outcome is known or the new prices are accepted.
  const billLocked = interrupted !== null || priceChanges.length > 0
  const lockedRef = useRef(false)
  useEffect(() => { lockedRef.current = billLocked }, [billLocked])

  const commitCart = useCallback((next: CartLine[]) => {
    cartRef.current = next
    setCart(next)
  }, [])

  // Kept until the next scan after a quiet moment, so a burst cannot hide a refusal.
  const addScanError = useCallback((message: string) => {
    setScanErrors((prev) => [...prev, message].slice(-5))
  }, [])

  /** Applies a change to the bill. Any change invalidates a discount approval. */
  const applyChange = useCallback((change: CartChange): boolean => {
    if (change.error) {
      addScanError(change.error)
      beep(false)
      return false
    }
    commitCart(change.cart)
    setApproval(null)
    setSaleError(null)
    setPricesUpdated(false)
    beep(true)
    return true
  }, [addScanError, commitCart])

  /** Back to the scan box, unless someone is typing elsewhere or using the camera. */
  const refocusScan = useCallback(() => {
    if (cameraRef.current) return
    const active = document.activeElement
    if (!active || active === document.body || active.tagName === 'BUTTON') scanRef.current?.focus()
  }, [])

  const refreshSales = useCallback(() => {
    listPosSales()
      .then((rows) => { setSales(rows); setSalesError(null) })
      .catch((err) => setSalesError(describeUnitError(err, 'Could not load recent bills.')))
  }, [])

  useEffect(() => {
    let cancelled = false
    listPosSales()
      .then((rows) => { if (!cancelled) setSales(rows) })
      .catch((err) => { if (!cancelled) setSalesError(describeUnitError(err, 'Could not load recent bills.')) })
    listProductsForGrn().then((p) => { if (!cancelled) setProducts(p.filter((x) => x.isActive)) }).catch(() => {})
    loadInventoryPolicy().then((p) => { if (!cancelled) setStaffMaxBps(p.staffMaxDiscountBps) }).catch(() => {})
    return () => { cancelled = true }
  }, [])

  // Owner/admin: discount requests waiting for a decision.
  const refreshPending = useCallback(() => {
    listPendingDiscountApprovals().then(setPending).catch(() => {})
  }, [])
  useEffect(() => {
    if (!isAdmin) return
    let cancelled = false
    const tick = () => { listPendingDiscountApprovals().then((rows) => { if (!cancelled) setPending(rows) }).catch(() => {}) }
    tick()
    const timer = window.setInterval(tick, 15_000)
    return () => { cancelled = true; window.clearInterval(timer) }
  }, [isAdmin])

  // Cashier: waits for the decision on this bill's request.
  const approvalId = approval?.status === 'pending' ? approval.id : null
  useEffect(() => {
    if (!approvalId) return
    const timer = window.setInterval(() => {
      loadDiscountApproval(approvalId).then(setApproval).catch(() => {})
    }, 5_000)
    return () => window.clearInterval(timer)
  }, [approvalId])

  const subtotal = cart.reduce((sum, l) => sum + lineCents(l), 0)
  const discountCents = parseRupees(discount)
  const total = subtotal - (discountCents ?? 0)
  const items: PosItemInput[] = cart.map((l) => (l.kind === 'unit'
    ? { code: l.unit.barcode }
    : { product_id: l.item.product_id, variant_id: l.item.variant_id, quantity: l.quantity }))
  const customerId = customer?.profileId ?? null
  // Mirrors the check inside pos_create_sale so the cashier can ask before trying.
  const needsApproval = !isAdmin && (discountCents ?? 0) > 0 && (discountCents ?? 0) * 10000 > subtotal * staffMaxBps
  const approvalUsable = approval?.status === 'approved' && approval.requestedCents >= (discountCents ?? 0) && approval.subtotalCents === subtotal

  /** Any change to the bill invalidates an approval, which is bound to that bill. */
  function billChanged() {
    setApproval(null)
    setSaleError(null)
    setPricesUpdated(false)
  }

  async function findCustomer() {
    setSaleError(null)
    try {
      const matches = await findCounterCustomer(customerQuery)
      setCustomerMatches(matches)
    } catch (err) {
      setSaleError(describeUnitError(err, 'That customer could not be looked up.'))
    }
  }

  // A bill left unresolved by a reload comes back with its original request id.
  useEffect(() => {
    const saved = recallInterrupted()
    if (!saved) return
    const timer = window.setTimeout(() => {
      commitCart(saved.cart)
      setCustomer(saved.customer)
      setDiscount(saved.discount)
      setPayment(saved.input.paymentMethod)
      setPaymentReference(saved.input.paymentReference)
      setCustomerName(saved.input.customerName)
      setCustomerPhone(saved.input.customerPhone)
      setNote(saved.input.note)
      setRequestId(saved.input.requestId)
      setInterrupted(saved)
    }, 0)
    return () => window.clearTimeout(timer)
  }, [commitCart])

  const pickedProduct = products.find((p) => p.id === pickProduct)

  function addQuantityItem() {
    if (!pickedProduct) { setScanErrors(['Choose a product.']); return }
    if (pickedProduct.variants.length > 0 && !pickVariant) { setScanErrors(['Choose the variant.']); return }
    const qty = Number(pickQty)
    if (!Number.isInteger(qty) || qty < 1) { setScanErrors(['Quantity must be a whole number.']); return }
    setScanErrors([])
    setDone(null)
    const productId = pickProduct
    const variantId = pickVariant || null
    void queueRef.current?.run(async () => {
      try {
        const item = await quoteProduct(productId, variantId, customerRef.current)
        if (applyChange(addQuantity(cartRef.current, item, qty))) {
          setPickProduct('')
          setPickVariant('')
          setPickQty('1')
        }
      } catch (err) {
        addScanError(describeUnitError(err, 'That item could not be priced.'))
        beep(false)
      }
    })
  }

  async function askForApproval() {
    if (discountCents === null || discountCents <= 0) return
    if (approvalReason.trim().length < 3) { setSaleError('Give a reason for the discount.'); return }
    setSaleError(null)
    try {
      // An approval given on prices the screen does not show could never match this bill.
      const changed = await checkPosPrices(items, expectedPrices(cart), customerId)
      if (changed.length > 0) { setPriceChanges(changed); return }
      const id = await requestDiscountApproval({
        saleRequestId: requestId, items, customerProfileId: customerId, discountCents, reason: approvalReason.trim(),
      })
      setApproval(await loadDiscountApproval(id))
    } catch (err) {
      setSaleError(describeUnitError(err, 'The request could not be sent.'))
    }
  }

  async function decide(id: string, approve: boolean) {
    try {
      await decideDiscountApproval(id, approve, '')
    } catch (err) {
      setSaleError(describeUnitError(err, 'The decision was not saved.'))
    }
    refreshPending()
  }

  // Returns at once: the next scan can arrive before this one has been answered.
  const addCode = useCallback((raw: string) => {
    const value = normalizeCode(raw)
    if (!value) return
    if (lockedRef.current) {
      setScanErrors(['Deal with the notice on this bill before scanning more items.'])
      beep(false)
      return
    }
    setDone(null)
    if (!scanningRef.current) setScanErrors([])
    void queueRef.current?.run(async () => {
      try {
        if (isCodeOnBill(cartRef.current, value)) {
          addScanError(`${value} is already on this bill.`)
          beep(false)
          return
        }
        const scan = await posScan(value, customerRef.current)
        applyChange(scan.kind === 'unit'
          ? addUnit(cartRef.current, scan, scan.reentered_as)
          : addQuantity(cartRef.current, scan, 1))
      } catch (err) {
        addScanError(describeUnitError(err, 'That code could not be looked up.'))
        beep(false)
      } finally {
        refocusScan()
      }
    })
  }, [addScanError, applyChange, refocusScan])

  function changeLine(key: string, delta: number) {
    applyChange(changeQuantity(cartRef.current, key, delta))
    refocusScan()
  }

  function newSale() {
    commitCart([])
    setDiscount('')
    setPayment('cash')
    setPaymentReference('')
    setCustomer(null)
    setCustomerQuery('')
    setCustomerMatches(null)
    setApproval(null)
    setApprovalReason('')
    setCustomerName('')
    setCustomerPhone('')
    setNote('')
    setSaleError(null)
    setScanErrors([])
    setPriceChanges([])
    setPricesUpdated(false)
    setInterrupted(null)
    setInterruptedStep('interrupted')
    rememberInterrupted(null)
    setRequestId(newRequestId())
    scanRef.current?.focus()
  }

  async function completeSale() {
    if (cart.length === 0) { setSaleError('Scan at least one item.'); return }
    if (discountCents === null) { setSaleError('The discount must be an amount in rupees.'); return }
    if (discountCents > subtotal) { setSaleError('The discount cannot be more than the subtotal.'); return }
    if (needsApproval && !approvalUsable) { setSaleError('This discount needs an owner or admin to approve it first.'); return }
    setBusy(true)
    setSaleError(null)
    // In the queue, so a scan arriving now waits and lands on the next bill.
    await queueRef.current?.run(async () => {
      try {
        // The button is disabled while scanning, but a scan can land in the same tick.
        if (cartRef.current !== cart) { setSaleError('The bill just changed. Check it and complete the sale again.'); return }
        await submitSale({
          items,
          expectedPrices: expectedPrices(cart),
          paymentMethod: payment,
          paymentReference: paymentReference.trim(),
          discountCents,
          customerName: customerName.trim() || (customer?.fullName ?? ''),
          customerPhone: customerPhone.trim() || (customer?.phone ?? ''),
          customerProfileId: customerId,
          discountApprovalId: needsApproval ? approval?.id ?? null : null,
          note: note.trim(),
          requestId,
        })
      } finally {
        setBusy(false)
      }
    })
  }

  function finishSale(result: PosSaleResult) {
    setDone(result)
    newSale()
    refreshSales()
    void printBill(result.id)
  }

  /** Sends a bill. A sale is only ever called failed if the server said so. */
  async function submitSale(input: PosSaleInput) {
    try {
      finishSale(await posCheckout(input))
    } catch (err) {
      const outcome = classifySaleError(err)
      if (outcome === 'unknown') {
        const sale: InterruptedSale = { input, cart: cartRef.current, customer, discount }
        setInterrupted(sale)
        setInterruptedStep('interrupted')
        rememberInterrupted(sale)
        return
      }
      // The server answered and rolled back, so this bill can be edited again.
      setInterrupted(null)
      rememberInterrupted(null)
      if (outcome === 'price_changed') {
        setPriceChanges(parsePriceChanges(err))
        return
      }
      setSaleError(describeUnitError(err, 'The sale could not be completed.'))
      if ((err as { message?: string }).message?.startsWith('discount_approval')) setApproval(null)
    }
  }

  function acceptNewPrices() {
    commitCart(applyPriceChanges(cartRef.current, priceChanges))
    setPriceChanges([])
    setApproval(null)
    setSaleError(null)
    setPricesUpdated(true)
    refocusScan()
  }

  async function checkInterrupted() {
    if (!interrupted) return
    setInterruptedStep('working')
    try {
      const saved = await findSaleByRequest(interrupted.input.requestId)
      if (saved) finishSale(saved)
      else setInterruptedStep('not_saved')
    } catch {
      setInterruptedStep('still_offline')
    }
  }

  async function retryInterrupted() {
    if (!interrupted) return
    setInterruptedStep('working')
    // The same input, so the same request id: the database can only sell it once.
    await queueRef.current?.run(() => submitSale(interrupted.input))
  }

  async function printBill(saleId: string) {
    setPrinting(saleId)
    try {
      const detail = await loadPosSale(saleId)
      const blob = await buildBillPdf(detail, {
        name: settings.store_name || 'Apple Expert',
        phone: settings.contact_phone,
        address: settings.address,
      })
      await openPdf(blob, `${detail.sale.bill_number}.pdf`)
    } catch (err) {
      setSalesError(describeUnitError(err, 'The bill could not be printed.'))
    } finally {
      setPrinting(null)
    }
  }

  if (!allowed) {
    return (
      <>
        <AdminPageHeading title="Shop counter (POS)" />
        <ErrorNote message="Your role cannot bill at the counter." />
      </>
    )
  }

  return (
    <>
      <AdminPageHeading title="Shop counter (POS)"
        subtitle="Scan each item's barcode label, box IMEI or product barcode, or pick quantity items below. Completing the bill sells exactly those items and lowers stock." />

      {isAdmin && pending.length > 0 && (
        <section className="mb-4 space-y-2.5 rounded-[22px] border border-amber-500/30 bg-amber-500/8 p-4">
          <h2 className="text-[14px] font-bold text-foreground">Discount requests</h2>
          {pending.map((a) => (
            <div key={a.id} className="flex flex-wrap items-center justify-between gap-2 text-[13px]">
              <span className="min-w-0">
                <span className="block font-semibold tabular-nums">
                  {formatPrice(centsToRupees(a.requestedCents))} off {formatPrice(centsToRupees(a.subtotalCents))}
                  {a.requestedByName ? ` · ${a.requestedByName}` : ''}
                </span>
                <span className="block text-[11.5px] text-muted-foreground">{a.reason}</span>
              </span>
              <span className="flex gap-1.5">
                <Button size="sm" variant="secondary" onClick={() => void decide(a.id, false)}><X size={14} className="mr-1" /> Reject</Button>
                <Button size="sm" onClick={() => void decide(a.id, true)}><Check size={14} className="mr-1" /> Approve</Button>
              </span>
            </div>
          ))}
        </section>
      )}

      <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
        {/* Scan + cart */}
        <div className="space-y-4">
          <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); addCode(code); setCode('') }}>
            <div className="relative flex-1">
              <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-muted-foreground">
                {scanning ? <LoaderCircle size={17} className="animate-spin motion-reduce:animate-none" /> : <ScanBarcode size={17} />}
              </span>
              <input ref={scanRef} autoFocus value={code} onChange={(e) => setCode(e.target.value)}
                aria-label="Scan barcode or IMEI" placeholder="Scan barcode or type AE… / AP… / IMEI and press Enter"
                className="focus-ring h-12 w-full rounded-xl border border-mint-deep dark:border-border bg-card pl-11 pr-3 font-mono text-[15px] text-foreground placeholder:font-sans placeholder:text-muted-foreground focus:outline-none focus:border-primary/45" />
            </div>
            <Button type="submit" disabled={!code.trim()}>Add</Button>
            {cameraOk && (
              <Button type="button" variant="secondary" size="icon" aria-label="Scan with camera" onClick={() => setCamera((c) => !c)}>
                <Camera size={17} />
              </Button>
            )}
          </form>

          {camera && <CameraScanner onCode={addCode} onClose={() => setCamera(false)} />}

          {/* For quantity-tracked items without a barcode or label to hand. */}
          <div className="rounded-[22px] border border-mint/80 dark:border-border bg-surface p-3.5 shadow-card space-y-2.5">
            <p className="text-[13px] font-semibold">Add by product</p>
            <div className="grid gap-2 sm:grid-cols-[1fr_1fr_90px_auto]">
              <select aria-label="Product" className={cn(SELECT_CLASS, 'w-full')} value={pickProduct} disabled={busy}
                onChange={(e) => { setPickProduct(e.target.value); setPickVariant('') }}>
                <option value="">Choose a product…</option>
                {products.filter((p) => p.variants.length > 0 ? p.variants.some((v) => trackingModeOf(p, v.id) === 'quantity') : p.trackingMode === 'quantity')
                  .map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
              <select aria-label="Variant" className={cn(SELECT_CLASS, 'w-full')} value={pickVariant} disabled={busy || !pickedProduct?.variants.length}
                onChange={(e) => setPickVariant(e.target.value)}>
                <option value="">{pickedProduct?.variants.length ? 'Choose a variant…' : 'No variants'}</option>
                {pickedProduct?.variants.filter((v) => v.trackingMode === 'quantity').map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
              </select>
              <input type="number" inputMode="numeric" min={1} aria-label="Quantity" className={cn(INPUT, 'tabular-nums')} value={pickQty} disabled={busy}
                onChange={(e) => setPickQty(e.target.value)} />
              <Button type="button" variant="secondary" disabled={busy || scanning || billLocked || !pickProduct} onClick={addQuantityItem}>
                <Plus size={15} className="mr-1" /> Add
              </Button>
            </div>
          </div>

          {interrupted && (
            <InterruptedSalePanel step={interruptedStep} onCheck={() => void checkInterrupted()} onRetry={() => void retryInterrupted()} onDiscard={newSale} />
          )}
          {priceChanges.length > 0 && <PriceChangesPanel changes={priceChanges} onAccept={acceptNewPrices} />}
          {pricesUpdated && <SuccessNote message="Bill updated to current prices. Check the new total with the customer, then complete the sale." />}
          {scanErrors.map((message, i) => <ErrorNote key={i} message={message} />)}
          {done && (
            <SuccessNote message={done.replayed
              ? `Bill ${done.bill_number} had already been saved — nothing was sold twice.`
              : `Bill ${done.bill_number} completed · ${formatPrice(centsToRupees(done.total_cents))}. The bill is opening for printing.`} />
          )}

          <div className={TABLE_CARD}>
            {cart.length === 0 ? (
              <p className="px-6 py-12 text-center text-sm text-muted-foreground">No items yet — scan the first one.</p>
            ) : (
              <ul className="divide-y divide-mint/50 dark:divide-border/70">
                {cart.map((l, i) => {
                  const name = l.kind === 'unit' ? l.unit.product_name : l.item.product_name
                  const detail = l.kind === 'unit'
                    ? [l.unit.variant_name, l.unit.barcode, l.unit.serial_number].filter(Boolean).join(' · ')
                    : [l.item.variant_name, `${l.quantity} × ${formatPrice(centsToRupees(l.item.price_cents ?? 0))}`].filter(Boolean).join(' · ')
                  return (
                    <li key={l.key} className="flex items-center gap-3 px-4 py-3">
                      <span className="w-6 shrink-0 text-[12px] text-muted-foreground tabular-nums">{i + 1}</span>
                      <span className="min-w-0 flex-1">
                        <span className="block font-semibold text-foreground truncate">{name}</span>
                        <span className="block text-[11.5px] text-muted-foreground truncate">{detail}</span>
                      </span>
                      {l.kind === 'quantity' && (
                        <span className="flex shrink-0 items-center gap-1">
                          <button type="button" aria-label={`One fewer ${name}`} disabled={busy || billLocked || l.quantity <= 1}
                            onClick={() => changeLine(l.key, -1)}
                            className="focus-ring flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft/60 disabled:opacity-40">
                            <Minus size={15} />
                          </button>
                          <span className="w-6 text-center text-[13px] font-semibold tabular-nums">{l.quantity}</span>
                          <button type="button" aria-label={`One more ${name}`} disabled={busy || billLocked}
                            onClick={() => changeLine(l.key, 1)}
                            className="focus-ring flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft/60">
                            <Plus size={15} />
                          </button>
                        </span>
                      )}
                      <span className="shrink-0 font-semibold tabular-nums">{formatPrice(centsToRupees(lineCents(l)))}</span>
                      <button type="button" aria-label={`Remove ${name}`} disabled={busy || billLocked}
                        onClick={() => { commitCart(cartRef.current.filter((x) => x.key !== l.key)); billChanged(); refocusScan() }}
                        className="focus-ring flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-red-500/10 hover:text-red-500">
                        <Trash2 size={15} />
                      </button>
                    </li>
                  )
                })}
              </ul>
            )}
          </div>
        </div>

        {/* Payment */}
        <aside className="h-fit space-y-3 rounded-[26px] border border-mint/80 dark:border-border bg-surface p-5 shadow-card lg:sticky lg:top-4">
          {/* The price tier is decided by the account: it must be chosen before scanning. */}
          <div className="space-y-2 border-b border-mint/70 dark:border-border pb-3">
            <span className="flex items-center gap-1.5 text-[13px] font-semibold"><UserRound size={14} /> Customer account</span>
            {customer ? (
              <div className="flex items-center justify-between gap-2 text-[13px]">
                <span className="min-w-0">
                  <span className="block truncate font-semibold">{customer.fullName ?? customer.phone}</span>
                  <span className="block text-[11.5px] text-muted-foreground">{customer.tierCode === 'wholesale_vip' ? 'Wholesale prices' : 'Retail prices'}</span>
                </span>
                {cart.length === 0 && <Button size="sm" variant="ghost" onClick={() => { setCustomer(null); setCustomerMatches(null) }}>Remove</Button>}
              </div>
            ) : cart.length > 0 ? (
              <p className="text-[12px] text-muted-foreground">Walk-in, retail prices. Clear the bill to serve an account.</p>
            ) : (
              <>
                <div className="flex gap-2">
                  <input className={INPUT} inputMode="tel" placeholder="Phone (optional)" aria-label="Find customer by phone" value={customerQuery}
                    onChange={(e) => { setCustomerQuery(e.target.value); setCustomerMatches(null) }} />
                  <Button type="button" variant="secondary" disabled={scanning || customerQuery.trim().length < 9} onClick={() => void findCustomer()}>Find</Button>
                </div>
                {customerMatches?.length === 0 && <p className="text-[12px] text-muted-foreground">No account with that phone. The sale stays at retail prices.</p>}
                {customerMatches?.map((m) => (
                  <button key={m.profileId} type="button" onClick={() => { setCustomer(m); setCustomerMatches(null) }}
                    className="focus-ring block w-full rounded-xl border border-mint-deep dark:border-border px-3 py-2 text-left text-[13px] hover:bg-primary-soft/60">
                    <span className="block font-semibold">{m.fullName ?? m.phone}</span>
                    <span className="block text-[11.5px] text-muted-foreground">{m.tierCode === 'wholesale_vip' ? 'Wholesale prices' : 'Retail prices'}</span>
                  </button>
                ))}
              </>
            )}
          </div>
          <div className="flex justify-between text-sm"><span className="text-muted-foreground">Subtotal ({cart.length})</span><span className="tabular-nums">{formatPrice(centsToRupees(subtotal))}</span></div>
          <label className="block">
            <span className="mb-1.5 block text-[13px] font-semibold">Discount (Rs.)</span>
            <input inputMode="decimal" className={cn(INPUT, 'tabular-nums')} placeholder="0" value={discount} disabled={busy || billLocked}
              onChange={(e) => { setDiscount(e.target.value); billChanged() }} />
          </label>
          {needsApproval && !approvalUsable && (
            <div className="space-y-2 rounded-2xl border border-amber-500/30 bg-amber-500/8 p-3">
              <p className="text-[12.5px]">
                {approval?.status === 'pending' ? 'Waiting for an owner or admin to decide…'
                  : approval?.status === 'rejected' ? `Rejected${approval.decisionNote ? `: ${approval.decisionNote}` : ''}. Change the discount or ask again.`
                  : staffMaxBps > 0 ? `Above your limit of ${staffMaxBps / 100}%. An owner or admin must approve this discount for this bill.`
                  : 'An owner or admin must approve this discount for this bill.'}
              </p>
              {approval?.status !== 'pending' && (
                <>
                  <input className={INPUT} placeholder="Reason" aria-label="Reason for the discount" value={approvalReason} onChange={(e) => setApprovalReason(e.target.value)} />
                  <Button fullWidth size="sm" variant="secondary" disabled={cart.length === 0} onClick={() => void askForApproval()}>Request approval</Button>
                </>
              )}
            </div>
          )}
          {needsApproval && approvalUsable && <p className="text-[12.5px] font-semibold text-primary">Discount approved for this bill.</p>}
          <div className="flex items-baseline justify-between border-t border-mint/70 dark:border-border pt-3">
            <span className="font-bold">Total</span>
            <span className="text-2xl font-bold tabular-nums">{formatPrice(centsToRupees(Math.max(total, 0)))}</span>
          </div>
          <label className="block">
            <span className="mb-1.5 block text-[13px] font-semibold">Payment</span>
            <select className={cn(SELECT_CLASS, 'w-full')} value={payment} disabled={busy} onChange={(e) => setPayment(e.target.value as PaymentMethod)}>
              {PAYMENT_METHODS.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
            </select>
          </label>
          {payment !== 'cash' && (
            <input className={INPUT} placeholder="Payment reference (optional)" value={paymentReference} disabled={busy} onChange={(e) => setPaymentReference(e.target.value)} />
          )}
          <input className={INPUT} placeholder="Customer name (optional)" value={customerName} disabled={busy} onChange={(e) => setCustomerName(e.target.value)} />
          <input className={INPUT} inputMode="tel" placeholder="Customer phone (optional)" value={customerPhone} disabled={busy} onChange={(e) => setCustomerPhone(e.target.value)} />
          <input className={INPUT} placeholder="Note (optional)" value={note} disabled={busy} onChange={(e) => setNote(e.target.value)} />
          {saleError && <ErrorNote message={saleError} />}
          <Button fullWidth size="lg" onClick={() => void completeSale()} disabled={busy || scanning || billLocked || cart.length === 0}>
            {busy ? <><LoaderCircle size={16} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Saving…</> : 'Complete sale & print bill'}
          </Button>
          {cart.length > 0 && (
            <Button fullWidth variant="ghost" onClick={newSale} disabled={busy || scanning || interrupted !== null}><RotateCcw size={15} className="mr-1.5" /> Clear bill</Button>
          )}
        </aside>
      </div>

      {/* Recent bills */}
      <h2 className="mt-8 mb-3 flex items-center gap-2 text-lg font-bold tracking-tight"><ReceiptText size={18} /> Recent counter bills</h2>
      {salesError && <ErrorNote message={salesError} className="mb-3" />}
      {sales === null && !salesError && <p className="text-sm text-muted-foreground">Loading…</p>}
      {sales && sales.length === 0 && <p className="text-sm text-muted-foreground">No counter sales yet.</p>}
      {sales && sales.length > 0 && (
        <div className={TABLE_CARD}>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-mint/70 dark:border-border bg-muted/60">
                  <th scope="col" className={TH}>Bill</th>
                  <th scope="col" className={TH}>Customer</th>
                  <th scope="col" className={`${TH} text-right`}>Items</th>
                  <th scope="col" className={`${TH} text-right`}>Total</th>
                  <th scope="col" className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {sales.map((s) => (
                  <tr key={s.id} className="border-b border-mint/50 dark:border-border/70 last:border-0">
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span className="block font-semibold">{s.bill_number}</span>
                      <span className="block text-[11px] text-muted-foreground">{formatDateTime(s.created_at)}{s.cashierName ? ` · ${s.cashierName}` : ''}</span>
                    </td>
                    <td className="px-4 py-3 min-w-[140px] text-muted-foreground">{s.customer_name || s.customer_phone || '—'}</td>
                    <td className="px-4 py-3 text-right tabular-nums">{s.itemCount}</td>
                    <td className="px-4 py-3 text-right whitespace-nowrap">
                      <span className="block font-semibold tabular-nums">{formatPrice(centsToRupees(s.total_cents))}</span>
                      <span className="block text-[11px] text-muted-foreground">{paymentLabel(s.payment_method)}{s.tier_code === 'wholesale_vip' ? ' · Wholesale' : ''}</span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="secondary" disabled={printing === s.id} onClick={() => void printBill(s.id)}>
                        {printing === s.id ? <LoaderCircle size={14} className="animate-spin motion-reduce:animate-none" /> : <Printer size={14} className="mr-1" />} Bill
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </>
  )
}
