import { getSupabaseClient } from '@/lib/supabase/client'
import type { Database } from '@/lib/supabase/database.types'
import type { AdminRole } from './roles'

/**
 * Admin orders data access.
 *
 * Everything here rides the policies that already exist:
 *
 *   orders          staff read / staff update status / admin all
 *   order_items     staff read / admin all   - UPDATE and DELETE are revoked
 *                                              from `authenticated`, so purchase
 *                                              snapshots cannot be rewritten
 *                                              from any browser session
 *   order_events    staff all                - status history is recorded here
 *   payments        admin read only          - no client write path exists
 *
 * No schema change, no new RPC, no service-role key.
 */

type Tables = Database['public']['Tables']
export type OrderRow = Tables['orders']['Row']
export type OrderItemRow = Tables['order_items']['Row']
export type OrderEventRow = Tables['order_events']['Row']
export type PaymentRow = Tables['payments']['Row']

/** Exactly the values the orders.status CHECK constraint permits. */
export const ORDER_STATUSES = [
  'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded',
] as const
export type OrderStatus = (typeof ORDER_STATUSES)[number]

export const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  pending: 'Pending',
  confirmed: 'Confirmed',
  processing: 'Processing',
  shipped: 'Shipped',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
  refunded: 'Refunded',
}

/** Transitions worth a second look before they are applied. */
export const SENSITIVE_STATUSES: readonly OrderStatus[] = ['cancelled', 'refunded']

/** Exactly the values the payments.status CHECK constraint permits. */
export const PAYMENT_STATUS_LABEL: Record<string, string> = {
  initiated: 'Initiated',
  authorized: 'Authorised',
  captured: 'Captured',
  failed: 'Failed',
  refunded: 'Refunded',
}

export function isOrderStatus(value: string): value is OrderStatus {
  return (ORDER_STATUSES as readonly string[]).includes(value)
}

/** Staff, admin and owner may all change status — this mirrors the existing policy. */
export function canManageOrders(role: AdminRole | null): boolean {
  return role === 'owner' || role === 'admin' || role === 'staff'
}

/** Only admin and owner can read payments — "payments admin read". */
export function canViewPayments(role: AdminRole | null): boolean {
  return role === 'owner' || role === 'admin'
}

/**
 * Bounded fetch. Order volume is currently zero and the storefront has no
 * checkout yet, so a capped list plus client-side filtering is far cheaper than
 * a round trip per keystroke. `orders_status_idx` and `orders_profile_idx`
 * already back the ordering, and this is the single place to add pagination
 * when volume justifies it.
 */
export const ORDER_FETCH_LIMIT = 200

export interface AdminOrderListItem {
  id: string
  order_number: string
  status: string
  customer_type_at_purchase: string
  total_cents: number
  currency: string
  placed_at: string
  customerName: string | null
  customerEmail: string | null
  customerPhone: string | null
  itemCount: number
}

interface EmbeddedOrderRow {
  id: string
  order_number: string
  status: string
  customer_type_at_purchase: string
  total_cents: number
  currency: string
  placed_at: string
  profiles: { full_name: string | null; email: string | null; phone: string | null } | null
  order_items: { count: number }[]
}

export async function listOrders(): Promise<AdminOrderListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('orders')
    .select(
      'id, order_number, status, customer_type_at_purchase, total_cents, currency, placed_at, profiles(full_name, email, phone), order_items(count)',
    )
    .order('placed_at', { ascending: false })
    .limit(ORDER_FETCH_LIMIT)

  if (error) throw error

  return ((data ?? []) as unknown as EmbeddedOrderRow[]).map((row) => ({
    id: row.id,
    order_number: row.order_number,
    status: row.status,
    customer_type_at_purchase: row.customer_type_at_purchase,
    total_cents: row.total_cents,
    currency: row.currency,
    placed_at: row.placed_at,
    customerName: row.profiles?.full_name ?? null,
    customerEmail: row.profiles?.email ?? null,
    customerPhone: row.profiles?.phone ?? null,
    itemCount: row.order_items?.[0]?.count ?? 0,
  }))
}

export interface AdminOrderDetail {
  order: OrderRow
  items: OrderItemRow[]
  events: OrderEventRow[]
  payments: PaymentRow[]
  customer: { full_name: string | null; email: string | null; phone: string | null } | null
}

/**
 * Loads one order with its immutable line snapshots, its history and its
 * payments.
 *
 * Nothing here joins to `products` or `product_prices`: the line snapshot IS
 * the record. Re-reading the live catalog would let a later price change
 * rewrite what a customer was charged.
 */
export async function loadOrderDetail(
  orderId: string,
  includePayments: boolean,
): Promise<AdminOrderDetail> {
  const supabase = getSupabaseClient()

  const [orderResult, itemsResult, eventsResult, paymentsResult] = await Promise.all([
    supabase.from('orders').select('*, profiles(full_name, email, phone)').eq('id', orderId).single(),
    supabase.from('order_items').select('*').eq('order_id', orderId).order('created_at', { ascending: true }),
    supabase.from('order_events').select('*').eq('order_id', orderId).order('created_at', { ascending: false }),
    // Staff cannot read payments at all; asking would only produce a noisy error.
    includePayments
      ? supabase.from('payments').select('*').eq('order_id', orderId).order('created_at', { ascending: false })
      : Promise.resolve({ data: [] as PaymentRow[], error: null }),
  ])

  if (orderResult.error) throw orderResult.error
  if (itemsResult.error) throw itemsResult.error
  if (eventsResult.error) throw eventsResult.error
  if (paymentsResult.error) throw paymentsResult.error

  const { profiles, ...order } = orderResult.data as OrderRow & {
    profiles: { full_name: string | null; email: string | null; phone: string | null } | null
  }

  return {
    order: order as OrderRow,
    items: itemsResult.data ?? [],
    events: eventsResult.data ?? [],
    payments: paymentsResult.data ?? [],
    customer: profiles ?? null,
  }
}

/**
 * Changes an order's status and records the transition in order_events.
 *
 * Only `status` is written — totals and line snapshots are never touched, so a
 * status change can never alter what the customer was charged.
 *
 * The two statements are not wrapped in a single transaction: PostgREST has no
 * client transaction, and adding one would require a database function this
 * phase was asked not to introduce. The status update is applied first and the
 * event is written second, so the worst case is a recorded status with a
 * missing history line, which the caller surfaces rather than hides.
 */
export async function updateOrderStatus(
  orderId: string,
  fromStatus: string,
  toStatus: OrderStatus,
  note?: string,
): Promise<{ order: OrderRow; eventRecorded: boolean; eventError: string | null }> {
  const supabase = getSupabaseClient()

  const { data, error } = await supabase
    .from('orders')
    .update({ status: toStatus })
    .eq('id', orderId)
    .select()
    .single()

  if (error) throw error

  const { error: eventError } = await supabase.from('order_events').insert({
    order_id: orderId,
    from_status: fromStatus,
    to_status: toStatus,
    note: note?.trim() ? note.trim() : null,
  })

  return {
    order: data,
    eventRecorded: !eventError,
    eventError: eventError ? eventError.message : null,
  }
}

/** Staff-facing meaning of orders.stock_state. */
export const STOCK_STATE_LABEL: Record<string, string> = {
  reserved: 'Stock held for this order',
  released: 'Hold released',
  expired: 'Hold expired after 48 hours',
  consumed: 'Stock deducted on shipment',
  legacy_open: 'Placed before reservations: stock is deducted on first shipment',
  legacy_closed: 'Placed before reservations: closed',
  legacy_done: 'Shipped before reservations: stock not changed',
  needs_reconciliation: 'Needs reconciliation: stock could not cover a line when it shipped',
}

/** Case-insensitive match across the fields the schema actually provides. */
export function matchesOrderQuery(order: AdminOrderListItem, query: string): boolean {
  const q = query.trim().toLowerCase()
  if (!q) return true
  return (
    order.order_number.toLowerCase().includes(q) ||
    (order.customerName?.toLowerCase().includes(q) ?? false) ||
    (order.customerEmail?.toLowerCase().includes(q) ?? false) ||
    (order.customerPhone?.toLowerCase().includes(q) ?? false)
  )
}
