import { getSupabaseClient } from '@/lib/supabase/client'
import { parseDeliverySnapshot, type DeliverySnapshot } from '@/lib/customer/addresses'
import type { CartItem } from '@/types'

/**
 * Customer orders.
 *
 * Placing an order goes through public.place_order_v3(), never a table insert —
 * customers have no INSERT policy on orders. The RPC receives only WHAT is
 * being bought (product, variant key, warranty option, quantity) and the id of
 * the chosen saved address. Every amount — product price at the caller's own tier
 * and the warranty add-on — is resolved inside PostgreSQL, so nothing this device
 * sends can change a price, and the delivery details are copied there too.
 *
 * Reading orders rides "orders read own" / "order_items read own".
 */

export interface PlacedOrder {
  id: string
  orderNumber: string
  totalCents: number
}

/** crypto.randomUUID exists only in secure contexts: a dev server over LAN is not one. */
export function newOrderRequestId(): string {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID()
  const b = crypto.getRandomValues(new Uint8Array(16))
  b[6] = (b[6] & 0x0f) | 0x40
  b[8] = (b[8] & 0x3f) | 0x80
  const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
}

/** What identifies a basket: the same content retries under the same request id. */
export function cartOrderKey(cart: CartItem[]): string {
  return JSON.stringify(cart.map((item) => [item.product.id, item.variant?.id ?? null, item.warrantyOptionId ?? null, item.quantity]))
}

/**
 * The one line that says which option of a product this is. Built only from fields
 * that exist on the item: a chosen variant's storage and colour, or, for a
 * replacement part, the model it fits. Nothing here is invented.
 */
export function describeCartSelection(item: CartItem): string | null {
  if (item.variant) {
    const parts = [item.variant.storage, item.variant.color].filter(Boolean)
    return parts.length > 0 ? parts.join(' · ') : item.variant.name
  }
  const fits = item.product.model ?? item.product.compatibility?.[0]
  if (fits) return `For ${fits}`
  if (item.product.subcategory && item.product.subcategory !== 'Devices') {
    return item.product.subcategory
  }
  return null
}

/** A customer-facing sentence, plus the database's code for the caller to act on. */
export class OrderError extends Error {
  constructor(message: string, readonly code: string) {
    super(message)
  }
}

/** supabase-js reports a request that never got an answer as '<ErrorName>: <browser message>'. */
function isNetworkFailure(message: string): boolean {
  return /failed to fetch|load failed|networkerror|network request failed|fetch failed/i.test(message)
}

/**
 * requestId stays the same across retries until the outcome is known, so a retry
 * after a lost response returns the first order instead of placing a second one
 * and holding its stock twice. There is deliberately no fallback to an older
 * function: an order must not be placed without its delivery address.
 *
 * A request that got no answer throws an OrderError with code 'network': the order
 * may or may not exist, and only a retry with the same requestId can tell.
 */
export async function placeOrder(cart: CartItem[], addressId: string, requestId: string, notes?: string): Promise<PlacedOrder> {
  const lines = cart.map((item) => ({
    product_id: item.product.id,
    variant_key: item.variant?.id ?? null,
    warranty_option_id: item.warrantyOptionId ?? null,
    quantity: item.quantity,
  }))

  const { data, error } = await getSupabaseClient().rpc('place_order_v3', {
    p_lines: lines,
    p_address_id: addressId,
    p_notes: notes?.trim() ? notes.trim() : null,
    p_request_id: requestId,
  })
  if (error) {
    const code = isNetworkFailure(error.message) ? 'network' : error.message.split(':')[0]?.trim() ?? ''
    throw new OrderError(describeOrderError(error.message), code)
  }

  const result = data as { id: string; order_number: string; total_cents: number }
  return { id: result.id, orderNumber: result.order_number, totalCents: result.total_cents }
}

export interface EarlierOrder extends PlacedOrder {
  delivery: DeliverySnapshot | null
}

/**
 * The customer's own order placed under this request id, or null if none was.
 * Resolves a lost response: orders.request_id is unique per customer, so at most
 * one order can match. profileId narrows the read for a staff account, whose
 * "orders staff read" would otherwise reach every customer's orders.
 */
export async function findMyOrderByRequest(requestId: string, profileId: string): Promise<EarlierOrder | null> {
  const { data, error } = await getSupabaseClient()
    .from('orders')
    .select('id, order_number, total_cents, shipping_address')
    .eq('profile_id', profileId)
    .eq('request_id', requestId)
    .maybeSingle()
  if (error) throw error
  if (!data) return null
  return {
    id: data.id,
    orderNumber: data.order_number,
    totalCents: data.total_cents,
    delivery: parseDeliverySnapshot(data.shipping_address),
  }
}

/**
 * place_order_v3() raises '<code>: <detail>'. The code is mapped to a sentence a
 * customer can act on; anything unrecognised is shown as the database said it.
 */
export function describeOrderError(message: string): string {
  // PostgREST's answer when place_order_v3() has not been deployed to this project yet.
  if (message.includes('Could not find the function')) {
    return 'Online ordering is not available yet. Please contact us to place your order.'
  }
  if (isNetworkFailure(message)) {
    return 'We could not confirm your order because the connection dropped. Check your connection and tap Confirm order again. It will not be ordered twice.'
  }
  const code = message.split(':')[0]?.trim()
  switch (code) {
    case 'not_authenticated': return 'Please sign in again to place your order.'
    case 'product_unavailable': return 'An item in your bag is no longer available. Remove it and try again.'
    case 'variant_unavailable':
    case 'variant_required': return 'An option in your bag is no longer available. Remove that item and add it again.'
    case 'price_unavailable': return 'An item in your bag does not have a price yet. Remove it or contact us.'
    case 'insufficient_stock': return 'We do not have enough stock of one of your selected options. Lower the quantity, or choose another colour or storage.'
    case 'reservation_limit_reached': return 'This account already holds as much as it can at one time. Please wait for your open orders to be confirmed, or contact us.'
    case 'request_id_reused': return 'An earlier attempt may already have gone through. Please check My Orders before trying again.'
    case 'address_required': return 'Please choose a delivery address.'
    case 'address_not_found': return 'That address is no longer in your account. Please choose another.'
    case 'address_incomplete': return 'That address is missing some details. Please edit it or choose another.'
    case 'warranty_option_invalid':
    case 'warranty_not_applicable': return 'A warranty you chose is no longer offered. Remove that item and choose again.'
    case 'store_unavailable': return 'Ordering is unavailable right now. Please try again later.'
    case 'invalid_lines':
    case 'invalid_quantity': return 'Your bag could not be read. Remove and re-add the items, then try again.'
    default: return message || 'Your order could not be placed. Please try again.'
  }
}

export interface MyOrderLine {
  id: string
  productName: string
  variantLabel: string | null
  quantity: number
  unitPriceCents: number
  lineTotalCents: number
  basePriceCents: number | null
  condition: string | null
  conditionGrade: string | null
  warrantyLabel: string | null
  warrantyMonths: number | null
  warrantyPriceCents: number
}

export interface MyOrder {
  id: string
  orderNumber: string
  status: string
  customerType: string
  totalCents: number
  placedAt: string
  /** The copy taken at placement. Null for orders placed before addresses were recorded. */
  delivery: DeliverySnapshot | null
  lines: MyOrderLine[]
}

/** The signed-in customer's own orders, newest first. Snapshots only — never re-priced. */
export async function listMyOrders(): Promise<MyOrder[]> {
  const { data, error } = await getSupabaseClient()
    .from('orders')
    .select(
      'id, order_number, status, customer_type_at_purchase, total_cents, placed_at, shipping_address, order_items(id, product_name_snapshot, variant_label_snapshot, quantity, unit_price_cents, line_total_cents, base_unit_price_cents, condition_snapshot, condition_grade_snapshot, warranty_label_snapshot, warranty_months_snapshot, warranty_price_cents_snapshot, created_at)',
    )
    .order('placed_at', { ascending: false })
    .limit(50)

  if (error) throw error

  return (data ?? []).map((row) => ({
    id: row.id,
    orderNumber: row.order_number,
    status: row.status,
    customerType: row.customer_type_at_purchase,
    totalCents: row.total_cents,
    placedAt: row.placed_at,
    delivery: parseDeliverySnapshot(row.shipping_address),
    lines: [...(row.order_items ?? [])]
      .sort((a, b) => a.created_at.localeCompare(b.created_at))
      .map((item) => ({
        id: item.id,
        productName: item.product_name_snapshot,
        variantLabel: item.variant_label_snapshot,
        quantity: item.quantity,
        unitPriceCents: item.unit_price_cents,
        lineTotalCents: item.line_total_cents,
        basePriceCents: item.base_unit_price_cents,
        condition: item.condition_snapshot,
        conditionGrade: item.condition_grade_snapshot,
        warrantyLabel: item.warranty_label_snapshot,
        warrantyMonths: item.warranty_months_snapshot,
        warrantyPriceCents: item.warranty_price_cents_snapshot,
      })),
  }))
}
