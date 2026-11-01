import { getSupabaseClient } from '@/lib/supabase/client'
import type { Database } from '@/lib/supabase/database.types'
import { describeAdminError } from './errors'
import { newRequestId } from './inventory'
import { isConnectionError, type PriceChange } from './posCart'
import type { AdminRole } from './roles'

/**
 * Barcode units, the inventory dashboard and the shop counter — data access.
 *
 * Every write goes through a SECURITY DEFINER function. The tables are read-only
 * for every browser session and only staff can read them at all; customers never
 * see a barcode or an IMEI. Purchase cost columns are not granted to browser
 * sessions at all (migration 20261101130000), so every select here names its
 * columns: `*` would be refused. Owner/admin read money through loadCosts().
 *
 * How a unit moves:
 *   GRN          -> in_stock (one barcode per physical item)
 *   online order -> reserved (oldest unit first, FIFO) -> sold on first shipment
 *                   -> back to in_stock if the order is cancelled or expires first
 *   counter scan -> sold
 *   customer return -> quarantined -> in_stock (verified) or written_off
 *   write-off    -> written_off
 *   supplier return -> returned_to_supplier
 */

type Tables = Database['public']['Tables']

const GRN_COLUMNS = 'id, grn_number, supplier_name, supplier_id, purchase_order_id, source_type, supplier_invoice, received_on, note, total_units, rejected_units, duplicate_invoice_note, created_by, request_id, created_at'
const GRN_LINE_COLUMNS = 'id, grn_id, line_no, product_id, variant_id, product_name_snapshot, variant_label_snapshot, ordered_quantity, received_quantity, accepted_quantity, rejected_quantity, rejection_reason, purchase_order_line_id, corrected_quantity, returned_quantity, tracking_mode_snapshot'
const UNIT_COLUMNS = 'id, barcode, serial_number, product_id, variant_id, grn_id, grn_line_id, received_on, fifo_seq, status, location_code, order_id, order_item_id, pos_sale_id, supplier_return_id, reentry_of_unit_id, status_changed_at, status_note, created_at'

export type GrnRow = Omit<Tables['grns']['Row'], 'total_cost_cents' | 'corrected_cost_cents' | 'pending_cost_lines' | 'request_fingerprint'>
export type GrnLineRow = Omit<Tables['grn_lines']['Row'], 'unit_cost_cents' | 'po_unit_cost_cents' | 'cost_pending' | 'cost_note'>
export type UnitRow = Omit<Tables['inventory_units']['Row'], 'unit_cost_cents'>
export type PosSaleRow = Tables['pos_sales']['Row']
export type PosSaleItemRow = Tables['pos_sale_items']['Row']

export const UNIT_STATUSES = ['in_stock', 'reserved', 'sold', 'quarantined', 'written_off', 'returned_to_supplier'] as const
export type UnitStatus = (typeof UNIT_STATUSES)[number]

export const UNIT_STATUS_LABEL: Record<UnitStatus, string> = {
  in_stock: 'In stock',
  reserved: 'Reserved (online order)',
  sold: 'Sold',
  quarantined: 'Quarantine',
  written_off: 'Written off',
  returned_to_supplier: 'Returned to supplier',
}

export const PAYMENT_METHODS = [
  { value: 'cash', label: 'Cash' },
  { value: 'card', label: 'Card' },
  { value: 'bank_transfer', label: 'Bank transfer' },
  { value: 'other', label: 'Other' },
] as const
export type PaymentMethod = (typeof PAYMENT_METHODS)[number]['value']

export function paymentLabel(value: string): string {
  return PAYMENT_METHODS.find((m) => m.value === value)?.label ?? value
}

/** GRN and write-off are admin/owner, like Adjust stock. */
export function canReceiveStock(role: AdminRole | null): boolean {
  return role === 'owner' || role === 'admin'
}

/** Anyone in the admin panel can bill at the counter. */
export function canSell(role: AdminRole | null): boolean {
  return role === 'owner' || role === 'admin' || role === 'staff'
}

/** Mirrors private.normalize_serial(): upper case, no spaces. */
export function normalizeCode(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase()
}

/** Luhn check, the same rule the database applies to a 15-digit IMEI. */
export function isValidImei(value: string): boolean {
  if (!/^[0-9]{15}$/.test(value)) return false
  let sum = 0
  for (let i = 0; i < 15; i++) {
    let d = Number(value[i])
    if (i % 2 === 1) {
      d *= 2
      if (d > 9) d -= 9
    }
    sum += d
  }
  return sum % 10 === 0
}

/** Same pattern as the inventory_units.serial_number CHECK. */
export function isValidSerial(value: string): boolean {
  return /^[A-Z0-9][A-Z0-9-]{3,29}$/.test(value)
}

/** Splits a pasted / scanned block into codes: one per line (or comma). */
export function splitCodes(text: string): string[] {
  return text.split(/[\n,;\t]+/).map(normalizeCode).filter((s) => s.length > 0)
}

export { newRequestId }

// ---------------------------------------------------------------------------
// Products for GRN, PO and counter forms
// ---------------------------------------------------------------------------

export type TrackingMode = 'quantity' | 'unit'

export interface ProductOptionVariant {
  id: string
  name: string
  /** null = shares the product's stock. */
  stock: number | null
  trackingMode: TrackingMode
}

export interface GrnProductOption {
  id: string
  name: string
  isActive: boolean
  categoryName: string | null
  requiresSerial: boolean
  /** The product's own number (or the pool its shared variants draw on). */
  stock: number
  trackingMode: TrackingMode
  /** What its category tracks by. 'unit' means these items must be individually tracked. */
  categoryTrackingMode: TrackingMode
  variants: ProductOptionVariant[]
}

interface ProductEmbedRow {
  id: string
  name: string
  is_active: boolean
  stock: number
  sort_order: number
  tracking_mode: string
  categories: { name: string; requires_serial: boolean; default_tracking_mode: string } | null
  product_variants: { id: string; name: string; stock: number | null; sort_order: number; tracking_mode: string | null }[]
}

export async function listProductsForGrn(): Promise<GrnProductOption[]> {
  const { data, error } = await getSupabaseClient()
    .from('products')
    .select('id, name, is_active, stock, sort_order, tracking_mode, categories(name, requires_serial, default_tracking_mode), product_variants(id, name, stock, sort_order, tracking_mode)')
    .order('name', { ascending: true })
    .limit(2000)

  if (error) throw error
  return ((data ?? []) as unknown as ProductEmbedRow[]).map((p) => {
    const trackingMode = p.tracking_mode === 'unit' ? 'unit' : 'quantity'
    return {
      id: p.id,
      name: p.name,
      isActive: p.is_active,
      categoryName: p.categories?.name ?? null,
      requiresSerial: p.categories?.requires_serial ?? false,
      stock: p.stock,
      trackingMode,
      categoryTrackingMode: p.categories?.default_tracking_mode === 'unit' ? 'unit' : 'quantity',
      variants: [...(p.product_variants ?? [])]
        .sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name))
        .map((v) => ({
          id: v.id,
          name: v.name,
          stock: v.stock,
          // Mirrors private.tracking_mode_of(): only an own-stock variant can differ.
          trackingMode: v.stock !== null && (v.tracking_mode === 'unit' || v.tracking_mode === 'quantity') ? v.tracking_mode : trackingMode,
        })),
    }
  })
}

/** The mode that applies to one product + variant. */
export function trackingModeOf(product: GrnProductOption, variantId: string | null): TrackingMode {
  return product.variants.find((v) => v.id === variantId)?.trackingMode ?? product.trackingMode
}

// ---------------------------------------------------------------------------
// GRN (posting lives in purchasing.ts, with suppliers and purchase orders)
// ---------------------------------------------------------------------------

export interface GrnListItem extends GrnRow {
  createdByName: string | null
  /** Barcoded units this GRN created. 0 = there are no barcode labels to print. */
  unitCount: number
}

export async function listGrns(): Promise<GrnListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('grns')
    .select(`${GRN_COLUMNS}, profiles(full_name, email), grn_lines(accepted_quantity, tracking_mode_snapshot)`)
    .order('received_on', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(200)

  if (error) throw error
  return ((data ?? []) as unknown as (GrnRow & {
    profiles: { full_name: string | null; email: string | null } | null
    grn_lines: { accepted_quantity: number; tracking_mode_snapshot: string }[] | null
  })[])
    .map(({ profiles, grn_lines, ...row }) => ({
      ...row,
      createdByName: profiles?.full_name ?? profiles?.email ?? null,
      // Every accepted item on a unit-tracked line got a unit. Not an embedded
      // count: inventory_units is column-restricted, and PostgREST's count needs
      // the whole table, so it would be refused.
      unitCount: (grn_lines ?? []).reduce((n, l) => n + (l.tracking_mode_snapshot === 'unit' ? l.accepted_quantity : 0), 0),
    }))
}

/** A unit with the names a label and a list need. */
export interface UnitView extends UnitRow {
  productName: string
  variantName: string | null
  grnNumber: string | null
  supplierName: string | null
}

const UNIT_SELECT = `${UNIT_COLUMNS}, products(name), product_variants(name), grns(grn_number, supplier_name)`

interface UnitEmbedRow extends UnitRow {
  products: { name: string } | null
  product_variants: { name: string } | null
  grns: { grn_number: string; supplier_name: string } | null
}

function toUnitView(row: UnitEmbedRow): UnitView {
  const { products, product_variants, grns, ...unit } = row
  return {
    ...unit,
    productName: products?.name ?? unit.product_id,
    variantName: product_variants?.name ?? null,
    grnNumber: grns?.grn_number ?? null,
    supplierName: grns?.supplier_name ?? null,
  }
}

export interface GrnDetail {
  grn: GrnRow
  lines: GrnLineRow[]
  units: UnitView[]
}

export async function loadGrn(grnId: string): Promise<GrnDetail> {
  const supabase = getSupabaseClient()
  const [grn, lines, units] = await Promise.all([
    supabase.from('grns').select(GRN_COLUMNS).eq('id', grnId).single(),
    supabase.from('grn_lines').select(GRN_LINE_COLUMNS).eq('grn_id', grnId).order('line_no'),
    supabase.from('inventory_units').select(UNIT_SELECT).eq('grn_id', grnId).order('fifo_seq').limit(2000),
  ])
  if (grn.error) throw grn.error
  if (lines.error) throw lines.error
  if (units.error) throw units.error
  return {
    grn: grn.data as unknown as GrnRow,
    lines: (lines.data ?? []) as unknown as GrnLineRow[],
    units: ((units.data ?? []) as unknown as UnitEmbedRow[]).map(toUnitView),
  }
}

// ---------------------------------------------------------------------------
// Purchase money: owner/admin only, enforced by the database
// ---------------------------------------------------------------------------

export type CostKind = 'grn' | 'grn_line' | 'po' | 'po_line' | 'supplier_return' | 'supplier_return_item' | 'unit'

export interface CostRow {
  id: string
  parentId: string | null
  /** null while the cost is pending. Never treated as zero. */
  cents: number | null
  pending: boolean
  extra: Record<string, unknown> | null
}

/** Staff calling this are refused by the database, so screens ask only for owner/admin. */
export async function loadCosts(kind: CostKind, ids: string[]): Promise<Map<string, CostRow>> {
  if (ids.length === 0) return new Map()
  const { data, error } = await getSupabaseClient().rpc('admin_purchase_costs', { p_kind: kind, p_ids: ids })
  if (error) throw error
  return new Map((data ?? []).map((r) => [r.id, {
    id: r.id,
    parentId: r.parent_id,
    cents: r.cents === null ? null : Number(r.cents),
    pending: r.pending,
    extra: (r.extra ?? null) as Record<string, unknown> | null,
  }]))
}

// ---------------------------------------------------------------------------
// Units
// ---------------------------------------------------------------------------

export const UNIT_FETCH_LIMIT = 500

export interface UnitFilter {
  status: UnitStatus | 'all'
  productId: string | null
  /** Barcode or IMEI fragment. */
  code: string
}

export async function listUnits(filter: UnitFilter): Promise<UnitView[]> {
  let query = getSupabaseClient()
    .from('inventory_units')
    .select(UNIT_SELECT)
    .order('received_on', { ascending: true })
    .order('fifo_seq', { ascending: true })
    .limit(UNIT_FETCH_LIMIT)

  if (filter.status !== 'all') query = query.eq('status', filter.status)
  if (filter.productId) query = query.eq('product_id', filter.productId)
  const code = normalizeCode(filter.code).replace(/[^A-Z0-9-]/g, '')
  if (code) query = query.or(`barcode.ilike.%${code}%,serial_number.ilike.%${code}%`)

  const { data, error } = await query
  if (error) throw error
  return ((data ?? []) as unknown as UnitEmbedRow[]).map(toUnitView)
}

// ---------------------------------------------------------------------------
// Dashboard: every figure comes from admin_inventory_dashboard()
// ---------------------------------------------------------------------------

export interface DashboardRow {
  productId: string
  variantId: string | null
  productName: string
  variantName: string | null
  categoryName: string | null
  isActive: boolean
  trackingMode: TrackingMode
  /** product: no variants. shared: draws on the product's pool. own: its own number. */
  stockScope: 'product' | 'shared' | 'own'
  onHand: number
  reserved: number
  available: number
  sold: number
  quarantined: number
  returnedToSupplier: number
  writtenOff: number
  serialisedUnits: number
  oldestReceivedOn: string | null
  stockStatus: 'out' | 'low' | 'in'
}

export async function loadInventoryDashboard(): Promise<DashboardRow[]> {
  const { data, error } = await getSupabaseClient().rpc('admin_inventory_dashboard')
  if (error) throw error
  return (data ?? []).map((r) => ({
    productId: r.product_id,
    variantId: r.variant_id,
    productName: r.product_name,
    variantName: r.variant_name,
    categoryName: r.category_name,
    isActive: r.is_active,
    trackingMode: r.tracking_mode === 'unit' ? 'unit' : 'quantity',
    stockScope: r.stock_scope as DashboardRow['stockScope'],
    onHand: r.on_hand,
    reserved: r.reserved,
    available: r.available,
    sold: r.sold,
    quarantined: r.quarantined,
    returnedToSupplier: r.returned_to_supplier,
    writtenOff: r.written_off,
    serialisedUnits: r.serialised_units,
    oldestReceivedOn: r.oldest_received_on,
    stockStatus: r.stock_status as DashboardRow['stockStatus'],
  }))
}

/** Releases overdue online holds. Safe to call repeatedly. */
export async function expirePendingOrders(): Promise<number> {
  const { data, error } = await getSupabaseClient().rpc('expire_pending_orders', {})
  if (error) throw error
  return (data as unknown as { expired: number }).expired
}

export async function writeOffUnits(unitIds: string[], reason: 'damage' | 'correction', note: string): Promise<number> {
  const { data, error } = await getSupabaseClient().rpc('admin_write_off_units', {
    p_unit_ids: unitIds,
    p_reason: reason,
    p_note: note,
  })
  if (error) throw error
  return (data as unknown as { written_off: number }).written_off
}

export async function quarantineUnits(unitIds: string[], note: string): Promise<number> {
  const { data, error } = await getSupabaseClient().rpc('admin_quarantine_units', { p_unit_ids: unitIds, p_note: note })
  if (error) throw error
  return (data as unknown as { quarantined: number }).quarantined
}

export async function releaseQuarantineUnits(unitIds: string[], note: string): Promise<number> {
  const { data, error } = await getSupabaseClient().rpc('admin_release_quarantine_units', { p_unit_ids: unitIds, p_note: note })
  if (error) throw error
  return (data as unknown as { released: number }).released
}

/** Units an online order holds — what staff pick and pack. */
export async function listOrderUnits(orderId: string): Promise<UnitView[]> {
  const { data, error } = await getSupabaseClient()
    .from('inventory_units')
    .select(UNIT_SELECT)
    .eq('order_id', orderId)
    .order('received_on')
    .order('fifo_seq')
  if (error) throw error
  return ((data ?? []) as unknown as UnitEmbedRow[]).map(toUnitView)
}

// ---------------------------------------------------------------------------
// POS
// ---------------------------------------------------------------------------

export interface ScannedUnit {
  kind: 'unit'
  unit_id: string
  barcode: string
  serial_number: string | null
  status: UnitStatus
  product_id: string
  variant_id: string | null
  product_name: string
  variant_name: string | null
  /** Live price at the served customer's tier; null when there is none (it cannot be sold). */
  price_cents: number | null
  tier_code: string | null
}

export interface QuotedProduct {
  kind: 'product'
  product_id: string
  variant_id: string | null
  product_name: string
  variant_name: string | null
  tracking_mode: TrackingMode
  available: number
  price_cents: number | null
  tier_code: string | null
}

export async function lookupUnit(code: string, customerProfileId: string | null): Promise<ScannedUnit> {
  const { data, error } = await getSupabaseClient().rpc('pos_lookup_unit', {
    p_code: code,
    p_customer_profile_id: customerProfileId,
  })
  if (error) throw error
  return data as unknown as ScannedUnit
}

/** What a scanned code means: one exact unit, or one exact product/variant. */
export type PosScanResult =
  | (ScannedUnit & { reentered_as?: string })
  | (QuotedProduct & { barcode: string })

export async function posScan(code: string, customerProfileId: string | null): Promise<PosScanResult> {
  const { data, error } = await getSupabaseClient().rpc('pos_scan', {
    p_code: code,
    p_customer_profile_id: customerProfileId,
  })
  if (error) throw error
  return data as unknown as PosScanResult
}

export async function quoteProduct(productId: string, variantId: string | null, customerProfileId: string | null): Promise<QuotedProduct> {
  const { data, error } = await getSupabaseClient().rpc('pos_quote_product', {
    p_product_id: productId,
    p_variant_id: variantId,
    p_customer_profile_id: customerProfileId,
  })
  if (error) throw error
  return data as unknown as QuotedProduct
}

export interface CounterCustomer {
  profileId: string
  fullName: string | null
  phone: string | null
  tierCode: string
}

export async function findCounterCustomer(phone: string): Promise<CounterCustomer[]> {
  const { data, error } = await getSupabaseClient().rpc('pos_find_customer', { p_phone: phone })
  if (error) throw error
  return (data ?? []).map((c) => ({ profileId: c.profile_id, fullName: c.full_name, phone: c.phone, tierCode: c.tier_code }))
}

/** One bill line as sent to the database: never a price. */
export type PosItemInput =
  | { code: string }
  | { product_id: string; variant_id: string | null; quantity: number }

export interface PosSaleInput {
  items: PosItemInput[]
  /** What the screen showed, line for line. The server compares it and never charges it. */
  expectedPrices: { price_cents: number; tier_code: string | null }[]
  paymentMethod: PaymentMethod
  paymentReference: string
  discountCents: number
  customerName: string
  customerPhone: string
  customerProfileId: string | null
  discountApprovalId: string | null
  note: string
  requestId: string
}

export interface PosSaleResult {
  id: string
  bill_number: string
  total_cents: number
  replayed: boolean
}

/** No answer in this long counts as an interrupted connection. */
const CHECKOUT_TIMEOUT_MS = 30_000

export async function posCheckout(input: PosSaleInput): Promise<PosSaleResult> {
  const { data, error } = await getSupabaseClient().rpc('pos_checkout', {
    p_items: input.items,
    p_expected_prices: input.expectedPrices,
    p_payment_method: input.paymentMethod,
    p_payment_reference: input.paymentReference,
    p_discount_cents: input.discountCents,
    p_customer_name: input.customerName,
    p_customer_phone: input.customerPhone,
    p_customer_profile_id: input.customerProfileId,
    p_note: input.note,
    p_discount_approval_id: input.discountApprovalId,
    p_request_id: input.requestId,
  }).abortSignal(AbortSignal.timeout(CHECKOUT_TIMEOUT_MS))
  if (error) throw error
  return data as unknown as PosSaleResult
}

/** Which prices on a bill are out of date. Changes nothing. */
export async function checkPosPrices(items: PosItemInput[], expected: PosSaleInput['expectedPrices'], customerProfileId: string | null): Promise<PriceChange[]> {
  const { data, error } = await getSupabaseClient().rpc('pos_check_prices', {
    p_items: items,
    p_expected_prices: expected,
    p_customer_profile_id: customerProfileId,
  })
  if (error) throw error
  return data as unknown as PriceChange[]
}

/** The bill saved under this request id, if the database has one. */
export async function findSaleByRequest(requestId: string): Promise<PosSaleResult | null> {
  const { data, error } = await getSupabaseClient()
    .from('pos_sales').select('id, bill_number, total_cents').eq('request_id', requestId).maybeSingle()
  if (error) throw error
  return data ? { ...data, replayed: true } : null
}

// Discount policy and approval

export interface InventoryPolicy {
  maxReservedUnitsPerCustomer: number | null
  maxActiveOrdersPerCustomer: number | null
  staffMaxDiscountBps: number
}

export async function loadInventoryPolicy(): Promise<InventoryPolicy> {
  const { data, error } = await getSupabaseClient()
    .from('inventory_policy')
    .select('max_reserved_units_per_customer, max_active_orders_per_customer, staff_max_discount_bps')
    .eq('id', true)
    .single()
  if (error) throw error
  return {
    maxReservedUnitsPerCustomer: data.max_reserved_units_per_customer,
    maxActiveOrdersPerCustomer: data.max_active_orders_per_customer,
    staffMaxDiscountBps: data.staff_max_discount_bps,
  }
}

export async function saveInventoryPolicy(policy: InventoryPolicy, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_save_inventory_policy', {
    p_max_reserved_units_per_customer: policy.maxReservedUnitsPerCustomer,
    p_max_active_orders_per_customer: policy.maxActiveOrdersPerCustomer,
    p_staff_max_discount_bps: policy.staffMaxDiscountBps,
    p_note: note,
  })
  if (error) throw error
}

export interface DiscountApproval {
  id: string
  status: 'pending' | 'approved' | 'rejected' | 'used'
  requestedCents: number
  subtotalCents: number
  reason: string
  requestedByName: string | null
  decisionNote: string | null
  expiresAt: string
  createdAt: string
}

const APPROVAL_SELECT = 'id, status, requested_cents, subtotal_cents, reason, decision_note, expires_at, created_at, profiles!pos_discount_approvals_requested_by_fkey(full_name, email)'

interface ApprovalEmbedRow {
  id: string
  status: string
  requested_cents: number
  subtotal_cents: number
  reason: string
  decision_note: string | null
  expires_at: string
  created_at: string
  profiles: { full_name: string | null; email: string | null } | null
}

function toApproval(r: ApprovalEmbedRow): DiscountApproval {
  return {
    id: r.id,
    status: r.status as DiscountApproval['status'],
    requestedCents: r.requested_cents,
    subtotalCents: r.subtotal_cents,
    reason: r.reason,
    requestedByName: r.profiles?.full_name ?? r.profiles?.email ?? null,
    decisionNote: r.decision_note,
    expiresAt: r.expires_at,
    createdAt: r.created_at,
  }
}

export async function requestDiscountApproval(input: {
  saleRequestId: string
  items: PosItemInput[]
  customerProfileId: string | null
  discountCents: number
  reason: string
}): Promise<string> {
  const { data, error } = await getSupabaseClient().rpc('pos_request_discount_approval', {
    p_sale_request_id: input.saleRequestId,
    p_items: input.items,
    p_customer_profile_id: input.customerProfileId,
    p_discount_cents: input.discountCents,
    p_reason: input.reason,
  })
  if (error) throw error
  return (data as unknown as { id: string }).id
}

export async function loadDiscountApproval(id: string): Promise<DiscountApproval> {
  const { data, error } = await getSupabaseClient()
    .from('pos_discount_approvals').select(APPROVAL_SELECT).eq('id', id).single()
  if (error) throw error
  return toApproval(data as unknown as ApprovalEmbedRow)
}

/** What is waiting for an owner/admin. RLS gives staff only their own. */
export async function listPendingDiscountApprovals(): Promise<DiscountApproval[]> {
  const { data, error } = await getSupabaseClient()
    .from('pos_discount_approvals')
    .select(APPROVAL_SELECT)
    .eq('status', 'pending')
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  return ((data ?? []) as unknown as ApprovalEmbedRow[]).map(toApproval)
}

export async function decideDiscountApproval(id: string, approve: boolean, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_decide_discount_approval', {
    p_approval_id: id, p_approve: approve, p_note: note,
  })
  if (error) throw error
}

export interface PosSaleListItem extends PosSaleRow {
  cashierName: string | null
  itemCount: number
}

export async function listPosSales(): Promise<PosSaleListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('pos_sales')
    .select('*, profiles!pos_sales_cashier_id_fkey(full_name, email), pos_sale_items(count)')
    .order('created_at', { ascending: false })
    .limit(200)
  if (error) throw error
  return ((data ?? []) as unknown as (PosSaleRow & {
    profiles: { full_name: string | null; email: string | null } | null
    pos_sale_items: { count: number }[] | null
  })[]).map(({ profiles, pos_sale_items, ...row }) => ({
    ...row,
    cashierName: profiles?.full_name ?? profiles?.email ?? null,
    itemCount: pos_sale_items?.[0]?.count ?? 0,
  }))
}

export interface PosSaleDetail {
  sale: PosSaleRow
  items: PosSaleItemRow[]
  cashierName: string | null
  refundedCents: number
}

export async function loadPosSale(saleId: string): Promise<PosSaleDetail> {
  const supabase = getSupabaseClient()
  const [sale, items, refunds] = await Promise.all([
    supabase.from('pos_sales').select('*, profiles!pos_sales_cashier_id_fkey(full_name, email)').eq('id', saleId).single(),
    supabase.from('pos_sale_items').select('*').eq('pos_sale_id', saleId).order('product_name_snapshot'),
    supabase.from('customer_refunds').select('amount_cents').eq('pos_sale_id', saleId),
  ])
  if (sale.error) throw sale.error
  if (items.error) throw items.error
  if (refunds.error) throw refunds.error
  const { profiles, ...row } = sale.data as unknown as PosSaleRow & { profiles: { full_name: string | null; email: string | null } | null }
  return {
    sale: row,
    items: items.data ?? [],
    cashierName: profiles?.full_name ?? profiles?.email ?? null,
    refundedCents: (refunds.data ?? []).reduce((sum, r) => sum + Number(r.amount_cents), 0),
  }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * A sentence the shop can act on. The database raises '<code>: <detail>'; the
 * detail already names the item, barcode or IMEI concerned, so it is what a person
 * reads. Anything not in that shape falls back to the full PostgREST detail.
 */
export function describeUnitError(err: unknown, fallback: string): string {
  if (isConnectionError(err)) return 'The connection was interrupted. Check it and try again.'
  const message = typeof (err as { message?: unknown })?.message === 'string' ? (err as { message: string }).message : ''
  const match = message.match(/^([a-z_]+):\s*([\s\S]+)$/)
  if (match) {
    if (match[1] === 'not_authenticated' || match[1] === 'insufficient_privilege') {
      return 'Your role cannot do this. It needs an owner or admin.'
    }
    return capitalise(match[2])
  }
  if (isFunctionMissing(err)) return 'This feature becomes available after the next server update. Nothing was changed.'
  return describeAdminError(err, fallback)
}

function capitalise(text: string): string {
  return text ? text[0].toUpperCase() + text.slice(1) + (text.endsWith('.') ? '' : '.') : text
}

function isFunctionMissing(err: unknown): boolean {
  const e = (err ?? {}) as { code?: unknown; message?: unknown }
  return e.code === 'PGRST202' || (typeof e.message === 'string' && e.message.includes('Could not find the function'))
}

/** yyyy-mm-dd in Sri Lanka time — the GRN date default. */
export function todayInColombo(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Colombo', year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(new Date())
}

export function formatDate(isoDate: string): string {
  const [y, m, d] = isoDate.slice(0, 10).split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' })
}

export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
