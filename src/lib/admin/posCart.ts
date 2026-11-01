import type { QuotedProduct, ScannedUnit, UnitStatus } from './units'

/**
 * What a scan does to a counter bill. Pure, so the rules run without a browser
 * (scripts/test-pos-cart.mjs); the page only adds the network and the screen.
 *
 * Prices here are for display. pos_create_sale re-prices and re-checks every line.
 */

/** A bill line: one scanned unit, or a quantity of a quantity-tracked item. */
export type CartLine =
  | { kind: 'unit'; key: string; unit: ScannedUnit }
  | { kind: 'quantity'; key: string; item: QuotedProduct; quantity: number }

export interface CartChange {
  cart: CartLine[]
  /** Why nothing changed; the cart is returned as it was. */
  error: string | null
}

export function lineCents(line: CartLine): number {
  return line.kind === 'unit' ? line.unit.price_cents ?? 0 : (line.item.price_cents ?? 0) * line.quantity
}

export function quantityLineKey(productId: string, variantId: string | null): string {
  return `${productId}|${variantId ?? ''}`
}

/** Why this unit cannot go on a bill; null when it can. */
export function unitRefusal(unit: ScannedUnit, reenteredAs?: string): string | null {
  const name = `${unit.barcode} (${unit.product_name})`
  const reasons: Record<Exclude<UnitStatus, 'in_stock'>, string> = {
    reserved: `${name} is held for an online order. It cannot be sold at the counter.`,
    sold: reenteredAs
      ? `${name} was sold and later came back as ${reenteredAs}. Scan that label instead.`
      : `${name} has already been sold.`,
    quarantined: `${name} is in quarantine. Release it before selling.`,
    written_off: `${name} was written off. It cannot be sold.`,
    returned_to_supplier: `${name} was returned to the supplier. It cannot be sold.`,
  }
  if (unit.status !== 'in_stock') return reasons[unit.status] ?? `${name} cannot be sold.`
  if (unit.price_cents === null) return `${unit.product_name} has no price. Set a price in Pricing first.`
  return null
}

/** A code on the bill already, recognisable without asking the database. */
export function isCodeOnBill(cart: CartLine[], code: string): boolean {
  return cart.some((l) => l.kind === 'unit' && (l.unit.barcode === code || l.unit.serial_number === code))
}

export function addUnit(cart: CartLine[], unit: ScannedUnit, reenteredAs?: string): CartChange {
  if (cart.some((l) => l.kind === 'unit' && l.unit.unit_id === unit.unit_id)) {
    return { cart, error: `${unit.barcode} is already on this bill.` }
  }
  const refusal = unitRefusal(unit, reenteredAs)
  if (refusal) return { cart, error: refusal }
  return { cart: [...cart, { kind: 'unit', key: unit.unit_id, unit }], error: null }
}

/**
 * Adds to the item's line, or starts one. The new total is capped by the availability
 * in `item`, a fresh quote. An existing line keeps the price the cashier was shown:
 * if that price is out of date, checkout stops and asks.
 */
export function addQuantity(cart: CartLine[], item: QuotedProduct, quantity: number): CartChange {
  if (item.tracking_mode === 'unit') {
    return { cart, error: `${item.product_name} is tracked individually. Scan its barcode or IMEI.` }
  }
  if (item.price_cents === null) {
    return { cart, error: `${item.product_name} has no price. Set one in Pricing first.` }
  }
  const key = quantityLineKey(item.product_id, item.variant_id)
  const line = cart.find((l) => l.key === key)
  const total = (line?.kind === 'quantity' ? line.quantity : 0) + quantity
  if (total > item.available) {
    return { cart, error: `Only ${item.available} of ${item.product_name} available.` }
  }
  if (!line) return { cart: [...cart, { kind: 'quantity', key, item, quantity }], error: null }
  const shown = line.kind === 'quantity' ? line.item : item
  const merged = { ...item, price_cents: shown.price_cents, tier_code: shown.tier_code }
  return { cart: cart.map((l) => (l.key === key ? { kind: 'quantity', key, item: merged, quantity: total } : l)), error: null }
}

/** The + and − on a quantity line. Availability is as of the last quote. */
export function changeQuantity(cart: CartLine[], key: string, delta: number): CartChange {
  const line = cart.find((l) => l.key === key)
  if (line?.kind !== 'quantity') return { cart, error: null }
  const total = line.quantity + delta
  if (total < 1) return { cart, error: null }
  if (total > line.item.available) {
    return { cart, error: `Only ${line.item.available} of ${line.item.product_name} available.` }
  }
  return { cart: cart.map((l) => (l.key === key ? { ...line, quantity: total } : l)), error: null }
}

export interface TaskQueue {
  /** Runs after everything already queued; settles when the task has finished. */
  run(task: () => Promise<void>): Promise<void>
}

/**
 * One at a time, in order. A USB scanner can fire the next code before the last
 * lookup has answered, and each scan has to see the bill the previous one left.
 * A failed task does not stop the ones behind it.
 */
export function createTaskQueue(onBusyChange: (busy: boolean) => void = () => {}): TaskQueue {
  let tail: Promise<void> = Promise.resolve()
  let pending = 0
  return {
    run(task) {
      if (pending++ === 0) onBusyChange(true)
      const result = tail.then(task).catch(() => {}).then(() => {
        if (--pending === 0) onBusyChange(false)
      })
      tail = result
      return result
    },
  }
}

// ---------------------------------------------------------------------------
// Prices the cashier was shown
// ---------------------------------------------------------------------------

/** What the screen showed for each line, in bill order. Compared, never charged. */
export function expectedPrices(cart: CartLine[]): { price_cents: number; tier_code: string | null }[] {
  return cart.map((l) => {
    const shown = l.kind === 'unit' ? l.unit : l.item
    return { price_cents: shown.price_cents ?? 0, tier_code: shown.tier_code }
  })
}

export interface PriceChange {
  code: string | null
  product_id: string
  variant_id: string | null
  product_name: string
  variant_name: string | null
  previous_cents: number
  current_cents: number | null
  current_tier: string | null
  reason: 'price_changed' | 'tier_changed' | 'price_removed'
}

export function priceChangeReason(change: PriceChange): string {
  if (change.reason === 'price_removed') return 'No longer has a price, so it will be removed from the bill.'
  if (change.reason === 'tier_changed') return "The customer's price tier changed."
  return 'The price was changed.'
}

/** The changes a price_changed refusal carries; empty for any other error. */
export function parsePriceChanges(err: unknown): PriceChange[] {
  const e = (err ?? {}) as { message?: unknown; details?: unknown }
  if (typeof e.message !== 'string' || !e.message.startsWith('price_changed:') || typeof e.details !== 'string') return []
  try {
    const parsed: unknown = JSON.parse(e.details)
    return Array.isArray(parsed) ? parsed as PriceChange[] : []
  } catch {
    return []
  }
}

/**
 * The cashier accepted the new prices: the bill takes them, and an item with no
 * price left comes off it. Checkout then compares these prices all over again.
 */
export function applyPriceChanges(cart: CartLine[], changes: PriceChange[]): CartLine[] {
  const next: CartLine[] = []
  for (const line of cart) {
    const change = changes.find((c) => (line.kind === 'unit'
      ? c.code === line.unit.barcode
      : c.code === null && line.key === quantityLineKey(c.product_id, c.variant_id)))
    if (!change) next.push(line)
    else if (change.current_cents === null) continue
    else if (line.kind === 'unit') next.push({ ...line, unit: { ...line.unit, price_cents: change.current_cents, tier_code: change.current_tier } })
    else next.push({ ...line, item: { ...line.item, price_cents: change.current_cents, tier_code: change.current_tier } })
  }
  return next
}

// ---------------------------------------------------------------------------
// What a failed checkout means
// ---------------------------------------------------------------------------

/**
 * 'unknown': no answer from the database, so the sale may or may not be saved and
 * must not be reported as failed. 'refused': the database answered and rolled back.
 *
 * A duplicate-key error counts as unknown because it means another request with
 * this id got there first. PGRST000 to 003 mean PostgREST lost the database.
 */
export function classifySaleError(err: unknown): 'unknown' | 'price_changed' | 'refused' {
  const e = (err ?? {}) as { message?: unknown; code?: unknown }
  const message = typeof e.message === 'string' ? e.message : ''
  const code = typeof e.code === 'string' ? e.code : ''
  if (message.startsWith('price_changed:')) return 'price_changed'
  if (code === '23505' || /^PGRST00[0-3]$/.test(code)) return 'unknown'
  if (code || /^[a-z_]+:\s/.test(message)) return 'refused'
  return 'unknown'
}

/** The request never got an answer: the browser's own words, not the server's. */
export function isConnectionError(err: unknown): boolean {
  const e = (err ?? {}) as { message?: unknown; code?: unknown }
  const message = typeof e.message === 'string' ? e.message : ''
  return !e.code && /failed to fetch|networkerror|load failed|network request failed|aborterror|timed? ?out/i.test(message)
}
