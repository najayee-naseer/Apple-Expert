import { getSupabaseClient } from '@/lib/supabase/client'
import type { Database } from '@/lib/supabase/database.types'
import { describeAdminError } from './errors'

/**
 * Admin stock data access.
 *
 * Admin adjustments go ONLY through admin_set_stock() (migration 20261023120000);
 * goods received, sales and returns have their own database functions.
 * The products.stock / product_variants.stock columns are guarded by a trigger
 * that refuses any change without a matching inventory_movements row in the
 * same transaction, and clients cannot write that table — so there is no
 * direct-write fallback here, even when the function is missing on an older
 * database. A missing function is reported, never worked around.
 *
 * Reads use the "inventory_movements staff read" policy.
 */

type Tables = Database['public']['Tables']
export type MovementRow = Tables['inventory_movements']['Row']

/** Same ceiling as the database CHECK in admin_set_stock(). */
export const MAX_STOCK = 100_000

/** Reasons an admin can pick in the Adjust stock dialog. */
export const ADJUST_REASONS = [
  { value: 'stock_count', label: 'Stock count', direction: 'any' },
  { value: 'restock', label: 'Stock received', direction: 'up' },
  { value: 'return', label: 'Customer return', direction: 'up' },
  { value: 'damage', label: 'Damaged / written off', direction: 'down' },
  { value: 'correction', label: 'Correction', direction: 'any' },
  { value: 'adjustment', label: 'Other adjustment', direction: 'any' },
] as const

export type AdjustReason = (typeof ADJUST_REASONS)[number]['value'] | 'opening_balance'

const REASON_LABEL: Record<string, string> = {
  ...Object.fromEntries(ADJUST_REASONS.map((r) => [r.value, r.label])),
  opening_balance: 'Opening stock',
  seed: 'Initial data',
  sale: 'Sale',
  transfer: 'Transfer',
  supplier_return: 'Returned to supplier',
  supplier_return_reversal: 'Supplier return reversed',
  quarantine: 'Moved to quarantine',
  quarantine_release: 'Released from quarantine',
}

export function reasonLabel(reason: string): string {
  return REASON_LABEL[reason] ?? reason
}

/**
 * A request id for one adjustment. The same id is sent again on a retry, so a
 * request whose response was lost is applied once and replayed afterwards.
 */
export function newRequestId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID()
  const bytes = new Uint8Array(16)
  crypto.getRandomValues(bytes)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

export interface StockAdjustment {
  productId: string
  /** null = the product's own stock (and every variant that shares it). */
  variantId: string | null
  /** The value the admin was looking at; a different current value is refused. */
  expected: number
  next: number
  reason: AdjustReason
  note: string
  requestId: string
}

export interface StockResult {
  movement_id: string
  quantity_before: number
  quantity_after: number
  delta: number
  current_quantity: number
  /** true when this request id had already been applied and was replayed. */
  replayed: boolean
}

export async function setStock(input: StockAdjustment): Promise<StockResult> {
  const { data, error } = await getSupabaseClient().rpc('admin_set_stock', {
    p_product_id: input.productId,
    // The generated Args type marks this uuid as a string; null is how the
    // product-level adjustment is expressed and PostgreSQL accepts it.
    p_variant_id: input.variantId as string,
    p_expected_quantity: input.expected,
    p_new_quantity: input.next,
    p_reason: input.reason,
    p_note: input.note,
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as StockResult
}

/**
 * Switches one stock holder between a number and individually barcoded units. The
 * database refuses while any stock, hold or unit exists, so nothing can be lost.
 */
export async function setTrackingMode(productId: string, variantId: string | null, mode: 'quantity' | 'unit', note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_set_tracking_mode', {
    p_product_id: productId,
    p_variant_id: variantId,
    p_mode: mode,
    p_note: note,
  })
  if (error) throw error
}

/** How many ledger rows the editor loads per product. */
export const MOVEMENT_LIMIT = 200

/**
 * Ledger rows for one product, newest first, with the actor's name.
 *
 * Rows written in one transaction share created_at, so ties are broken by
 * entry_seq (write order), newest first. That is done here rather than in the
 * query because an older database has no entry_seq column, and the editor must
 * still load there.
 */
export async function listMovements(productId: string): Promise<(MovementRow & { actorName: string | null })[]> {
  const { data, error } = await getSupabaseClient()
    .from('inventory_movements')
    .select('*, profiles(full_name, email)')
    .eq('product_id', productId)
    .order('created_at', { ascending: false })
    .limit(MOVEMENT_LIMIT)

  if (error) throw error
  return (data ?? [])
    .map(({ profiles, ...row }) => ({
      ...(row as MovementRow),
      actorName: profiles?.full_name ?? profiles?.email ?? null,
    }))
    .sort((a, b) => b.created_at.localeCompare(a.created_at) || (b.entry_seq ?? 0) - (a.entry_seq ?? 0))
}

/**
 * Whether one exact request id is in the ledger — used after a stock request
 * whose response was lost. Reads through the existing "staff read" policy;
 * nothing beyond what an admin can already see is exposed. Throws on any
 * failure, which callers treat as "cannot tell".
 */
export async function wasStockRequestRecorded(requestId: string): Promise<boolean> {
  const { data, error } = await getSupabaseClient()
    .from('inventory_movements')
    .select('id')
    .eq('request_id', requestId)
    .limit(1)

  if (error) throw error
  return (data ?? []).length > 0
}

/** True when the database has no admin_set_stock() yet (migration not pushed). */
export function isStockFunctionMissing(err: unknown): boolean {
  const e = (err ?? {}) as { code?: unknown; message?: unknown }
  return e.code === 'PGRST202' || (typeof e.message === 'string' && e.message.includes('Could not find the function'))
}

/**
 * A sentence an administrator can act on. Codes are the '<code>: <detail>'
 * prefixes raised by admin_set_stock() and the stock guard; anything else falls
 * back to the full PostgREST detail.
 */
export function describeStockError(err: unknown): string {
  if (isStockFunctionMissing(err)) {
    return 'Stock adjustments become available after the next server update. Nothing was changed.'
  }
  const message = typeof (err as { message?: unknown })?.message === 'string' ? (err as { message: string }).message : ''
  const code = message.split(':')[0]?.trim()
  const detail = message.slice(message.indexOf(':') + 1).trim()
  switch (code) {
    case 'stale_quantity': return `Someone changed this stock since you opened it (${detail}). Close and reopen to see the current value.`
    case 'no_change': return 'That is already the current stock. Nothing was changed.'
    case 'request_id_reused': return 'This adjustment was already submitted with different details. Close and reopen to start a new one.'
    case 'variant_inherits_product_stock': return 'This variant shares its product’s stock. Adjust the product’s stock instead.'
    case 'insufficient_privilege':
    case 'not_authenticated': return 'Only an owner or admin can adjust stock.'
    case 'invalid_quantity': return `Stock must be a whole number from 0 to ${MAX_STOCK.toLocaleString('en-US')}.`
    case 'invalid_note': return 'Add a note of 3 to 500 characters explaining the change.'
    case 'invalid_reason': return `That reason does not fit this change: ${detail}.`
    // The detail may start with a product id: shown exactly as stored.
    case 'stock_on_hand': return `Cannot delete — ${detail}. Set its stock to 0 first.`
    case 'inventory_history_exists': return `Cannot delete — ${detail}. Unpublish it instead.`
    case 'stock_locked':
    case 'stock_mode_locked': return 'Stock can only be changed with Adjust stock.'
    case 'unit_tracked': return 'This item is tracked by barcode. Add stock with a GRN, and remove it by selling or writing off units (Inventory).'
    case 'stock_reserved': return `${detail}`
    case 'tracking_mode_locked': return detail ? detail[0].toUpperCase() + detail.slice(1) : 'The tracking mode cannot be changed right now.'
    default: return describeAdminError(err, 'The database refused the stock change.')
  }
}
