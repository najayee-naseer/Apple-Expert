import { getSupabaseClient } from '@/lib/supabase/client'
import { newRequestId } from './inventory'

/**
 * Customer returns, refunds and quarantine.
 *
 * Goods coming back and money going back are separate facts, recorded separately:
 * a return never implies a refund, and a refund never moves stock. Returned goods
 * always go to quarantine; a person decides whether they are sellable again.
 * Supplier returns are a different flow (purchasing.ts).
 */

export { newRequestId }

export const RETURN_CONDITIONS = [
  { value: 'unverified', label: 'Not checked yet' },
  { value: 'resaleable', label: 'Looks resaleable' },
  { value: 'opened', label: 'Opened / used' },
  { value: 'damaged', label: 'Damaged' },
] as const
export type ReturnCondition = (typeof RETURN_CONDITIONS)[number]['value']

export interface ReturnSourceLine {
  lineId: string
  name: string
  variant: string | null
  quantity: number
  returned: number
  /** Scanned units still counted as sold on this line: choose which came back. */
  units: { id: string; barcode: string; serial: string | null }[]
}

export interface ReturnSource {
  sourceType: 'pos' | 'online'
  sourceId: string
  number: string
  totalCents: number
  refundedCents: number
  lines: ReturnSourceLine[]
}

/** Finds a counter bill (POS-...) or an online order (AE-...) by its number. */
export async function findReturnSource(number: string): Promise<ReturnSource | null> {
  const supabase = getSupabaseClient()
  const value = number.trim().toUpperCase()

  if (value.startsWith('POS-')) {
    const { data: sale, error } = await supabase
      .from('pos_sales').select('id, bill_number, total_cents').eq('bill_number', value).maybeSingle()
    if (error) throw error
    if (!sale) return null
    const [items, units, refunds] = await Promise.all([
      supabase.from('pos_sale_items')
        .select('id, product_name_snapshot, variant_label_snapshot, quantity, returned_quantity, unit_id')
        .eq('pos_sale_id', sale.id),
      supabase.from('inventory_units').select('id, barcode, serial_number').eq('pos_sale_id', sale.id).eq('status', 'sold'),
      supabase.from('customer_refunds').select('amount_cents').eq('pos_sale_id', sale.id),
    ])
    if (items.error) throw items.error
    if (units.error) throw units.error
    if (refunds.error) throw refunds.error
    const unitById = new Map((units.data ?? []).map((u) => [u.id, u]))
    return {
      sourceType: 'pos',
      sourceId: sale.id,
      number: sale.bill_number,
      totalCents: Number(sale.total_cents),
      refundedCents: (refunds.data ?? []).reduce((sum, r) => sum + Number(r.amount_cents), 0),
      lines: (items.data ?? []).map((i) => {
        const unit = i.unit_id ? unitById.get(i.unit_id) : undefined
        return {
          lineId: i.id,
          name: i.product_name_snapshot,
          variant: i.variant_label_snapshot,
          quantity: i.quantity,
          returned: i.returned_quantity,
          units: unit ? [{ id: unit.id, barcode: unit.barcode, serial: unit.serial_number }] : [],
        }
      }),
    }
  }

  const { data: order, error } = await supabase
    .from('orders').select('id, order_number, total_cents').eq('order_number', value).maybeSingle()
  if (error) throw error
  if (!order) return null
  const [items, units, refunds] = await Promise.all([
    supabase.from('order_items')
      .select('id, product_name_snapshot, variant_label_snapshot, quantity, returned_quantity')
      .eq('order_id', order.id),
    supabase.from('inventory_units').select('id, barcode, serial_number, order_item_id').eq('order_id', order.id).eq('status', 'sold'),
    supabase.from('customer_refunds').select('amount_cents').eq('order_id', order.id),
  ])
  if (items.error) throw items.error
  if (units.error) throw units.error
  if (refunds.error) throw refunds.error
  return {
    sourceType: 'online',
    sourceId: order.id,
    number: order.order_number,
    totalCents: Number(order.total_cents),
    refundedCents: (refunds.data ?? []).reduce((sum, r) => sum + Number(r.amount_cents), 0),
    lines: (items.data ?? []).map((i) => ({
      lineId: i.id,
      name: i.product_name_snapshot,
      variant: i.variant_label_snapshot,
      quantity: i.quantity,
      returned: i.returned_quantity,
      units: (units.data ?? [])
        .filter((u) => u.order_item_id === i.id)
        .map((u) => ({ id: u.id, barcode: u.barcode, serial: u.serial_number })),
    })),
  }
}

export interface ReturnItemInput {
  lineId: string
  unitId: string | null
  quantity: number
  condition: ReturnCondition
}

export async function recordCustomerReturn(input: {
  source: ReturnSource
  items: ReturnItemInput[]
  note: string
  requestId: string
}): Promise<{ id: string; return_number: string; replayed: boolean }> {
  const { data, error } = await getSupabaseClient().rpc('admin_record_customer_return', {
    p_source_type: input.source.sourceType,
    p_source_id: input.source.sourceId,
    p_items: input.items.map((i) => ({
      line_id: i.lineId, unit_id: i.unitId, quantity: i.quantity, condition: i.condition,
    })),
    p_note: input.note,
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as { id: string; return_number: string; replayed: boolean }
}

export async function recordCustomerRefund(input: {
  source: ReturnSource
  customerReturnId: string | null
  amountCents: number
  method: string
  reference: string
  note: string
  requestId: string
}): Promise<{ id: string; refund_number: string; replayed: boolean }> {
  const { data, error } = await getSupabaseClient().rpc('admin_record_customer_refund', {
    p_source_type: input.source.sourceType,
    p_source_id: input.source.sourceId,
    p_customer_return_id: input.customerReturnId,
    p_amount_cents: input.amountCents,
    p_method: input.method,
    p_reference: input.reference,
    p_note: input.note,
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as { id: string; refund_number: string; replayed: boolean }
}

export interface RecentReturn {
  id: string
  returnNumber: string
  sourceType: string
  createdAt: string
  note: string | null
  items: { name: string; quantity: number; condition: string }[]
}

export async function listCustomerReturns(): Promise<RecentReturn[]> {
  const supabase = getSupabaseClient()
  const { data, error } = await supabase
    .from('customer_returns')
    .select('id, return_number, source_type, created_at, note')
    .order('created_at', { ascending: false })
    .limit(100)
  if (error) throw error
  const ids = (data ?? []).map((r) => r.id)
  if (ids.length === 0) return []
  const { data: items, error: itemsError } = await supabase
    .from('customer_return_items')
    .select('customer_return_id, product_name_snapshot, quantity, condition')
    .in('customer_return_id', ids)
  if (itemsError) throw itemsError
  return (data ?? []).map((r) => ({
    id: r.id,
    returnNumber: r.return_number,
    sourceType: r.source_type,
    createdAt: r.created_at,
    note: r.note,
    items: (items ?? [])
      .filter((i) => i.customer_return_id === r.id)
      .map((i) => ({ name: i.product_name_snapshot, quantity: i.quantity, condition: i.condition })),
  }))
}

export interface RecentRefund {
  id: string
  refundNumber: string
  amountCents: number
  method: string
  reference: string | null
  createdAt: string
}

export async function listCustomerRefunds(): Promise<RecentRefund[]> {
  const { data, error } = await getSupabaseClient()
    .from('customer_refunds')
    .select('id, refund_number, amount_cents, method, reference, created_at')
    .order('created_at', { ascending: false })
    .limit(100)
  if (error) throw error
  return (data ?? []).map((r) => ({
    id: r.id,
    refundNumber: r.refund_number,
    amountCents: Number(r.amount_cents),
    method: r.method,
    reference: r.reference,
    createdAt: r.created_at,
  }))
}

// ---------------------------------------------------------------------------
// Quarantined quantity
// ---------------------------------------------------------------------------

export interface QuarantineLot {
  id: string
  productName: string
  variantName: string | null
  openQuantity: number
  note: string | null
  createdAt: string
}

export async function listQuarantineLots(): Promise<QuarantineLot[]> {
  const { data, error } = await getSupabaseClient()
    .from('quarantine_lots')
    .select('id, open_quantity, note, created_at, products(name), product_variants(name)')
    .gt('open_quantity', 0)
    .order('created_at', { ascending: true })
    .limit(200)
  if (error) throw error
  return ((data ?? []) as unknown as {
    id: string
    open_quantity: number
    note: string | null
    created_at: string
    products: { name: string } | null
    product_variants: { name: string } | null
  }[]).map((l) => ({
    id: l.id,
    productName: l.products?.name ?? '—',
    variantName: l.product_variants?.name ?? null,
    openQuantity: l.open_quantity,
    note: l.note,
    createdAt: l.created_at,
  }))
}

export async function resolveQuarantineLot(lotId: string, expectedOpen: number, release: number, writeOff: number, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_resolve_quarantine_lot', {
    p_lot_id: lotId,
    p_expected_open: expectedOpen,
    p_release: release,
    p_write_off: writeOff,
    p_note: note,
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// Pre-rollout orders that shipped when stock could not cover them
// ---------------------------------------------------------------------------

export interface ReconciliationFlag {
  id: string
  orderId: string
  productId: string | null
  quantity: number
  reason: string
  createdAt: string
}

export async function listOpenStockFlags(): Promise<ReconciliationFlag[]> {
  const { data, error } = await getSupabaseClient()
    .from('stock_reconciliation_flags')
    .select('id, order_id, product_id, quantity, reason, created_at')
    .is('resolved_at', null)
    .order('created_at', { ascending: false })
    .limit(200)
  if (error) throw error
  return (data ?? []).map((f) => ({
    id: f.id, orderId: f.order_id, productId: f.product_id, quantity: f.quantity, reason: f.reason, createdAt: f.created_at,
  }))
}

export async function resolveStockFlag(flagId: string, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_resolve_stock_flag', { p_flag_id: flagId, p_note: note })
  if (error) throw error
}
