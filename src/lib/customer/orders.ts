import { getSupabaseClient } from '@/lib/supabase/client'
import type { CartItem } from '@/types'

/**
 * Customer orders.
 *
 * Placing an order goes through public.place_order(), never a table insert —
 * customers have no INSERT policy on orders. The RPC receives only WHAT is
 * being bought (product, variant key, warranty option, quantity). Every amount
 * — product price at the caller's own tier and the warranty add-on — is
 * resolved inside PostgreSQL, so nothing this device sends can change a price.
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
 * requestId stays the same across retries of one basket, so a retry after a lost
 * response returns the first order instead of placing a second one and holding
 * its stock twice. Falls back to place_order() on a database that has not been
 * updated yet, where a request id does not exist.
 */
export async function placeOrder(cart: CartItem[], requestId: string, notes?: string): Promise<PlacedOrder> {
  const lines = cart.map((item) => ({
    product_id: item.product.id,
    variant_key: item.variant?.id ?? null,
    warranty_option_id: item.warrantyOptionId ?? null,
    quantity: item.quantity,
  }))

  const supabase = getSupabaseClient()
  let { data, error } = await supabase.rpc('place_order_v2', {
    p_lines: lines,
    p_notes: notes?.trim() ? notes.trim() : null,
    p_request_id: requestId,
  })
  if (error && (error.code === 'PGRST202' || error.message.includes('Could not find the function'))) {
    ({ data, error } = await supabase.rpc('place_order', {
      p_lines: lines,
      ...(notes?.trim() ? { p_notes: notes.trim() } : {}),
    }))
  }
  if (error) throw new Error(describeOrderError(error.message))

  const result = data as { id: string; order_number: string; total_cents: number }
  return { id: result.id, orderNumber: result.order_number, totalCents: result.total_cents }
}

/**
 * place_order() raises '<code>: <detail>'. The code is mapped to a sentence a
 * customer can act on; anything unrecognised is shown as the database said it.
 */
export function describeOrderError(message: string): string {
  // PostgREST's answer when place_order() has not been deployed to this project yet.
  if (message.includes('Could not find the function')) {
    return 'Online ordering is not available yet. Please contact us to place your order.'
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
    case 'request_id_reused': return 'Your bag changed while the order was being sent. Please try again.'
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
  lines: MyOrderLine[]
}

/** The signed-in customer's own orders, newest first. Snapshots only — never re-priced. */
export async function listMyOrders(): Promise<MyOrder[]> {
  const { data, error } = await getSupabaseClient()
    .from('orders')
    .select(
      'id, order_number, status, customer_type_at_purchase, total_cents, placed_at, order_items(id, product_name_snapshot, variant_label_snapshot, quantity, unit_price_cents, line_total_cents, base_unit_price_cents, condition_snapshot, condition_grade_snapshot, warranty_label_snapshot, warranty_months_snapshot, warranty_price_cents_snapshot, created_at)',
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
