import { getSupabaseClient } from '@/lib/supabase/client'
import type { Database } from '@/lib/supabase/database.types'
import { newRequestId } from './inventory'
import type { AdminRole } from './roles'
import { describeUnitError } from './units'

/**
 * Purchase & Returns — suppliers, purchase orders, supplier returns and
 * supplier payments. Every write goes through a SECURITY DEFINER function from
 * migration 20261028160000; the tables are read-only for browser sessions.
 *
 * What the shop owes a supplier:
 *   opening balance + accepted goods at stated cost - corrections
 *   - credit returns - payments
 * A cash return is money handed back; it is listed but does not change it. Lines
 * whose cost is pending are not in the figure and are counted separately.
 *
 * Money columns are not granted to browser sessions, so selects name their
 * columns. Owner/admin read money through loadCosts() in units.ts and the supplier
 * functions here; the database refuses staff.
 */

type Tables = Database['public']['Tables']
export type SupplierRow = Omit<Tables['suppliers']['Row'], 'opening_balance_cents'>
export type PurchaseOrderRow = Omit<Tables['purchase_orders']['Row'], 'total_cents' | 'request_fingerprint'>
export type PurchaseOrderLineRow = Omit<Tables['purchase_order_lines']['Row'], 'unit_cost_cents' | 'cost_pending'>
export type SupplierReturnRow = Omit<Tables['supplier_returns']['Row'], 'total_cents' | 'request_fingerprint'>
export type SupplierReturnItemRow = Omit<Tables['supplier_return_items']['Row'], 'unit_cost_cents'>
export type SupplierPaymentRow = Tables['supplier_payments']['Row']

const SUPPLIER_COLUMNS = 'id, supplier_code, name, contact_person, phone, email, address, note, is_active, created_by, created_at, updated_at'
const PO_COLUMNS = 'id, po_number, supplier_id, order_date, expected_date, status, note, close_note, closed_at, created_by, request_id, created_at'
const PO_LINE_COLUMNS = 'id, purchase_order_id, line_no, product_id, variant_id, product_name_snapshot, variant_label_snapshot, quantity, received_quantity, rejected_quantity, returned_quantity'
const RETURN_COLUMNS = 'id, return_number, supplier_id, return_date, return_type, total_units, note, created_by, request_id, reversed_at, reversed_by, reversal_note, created_at'
const RETURN_ITEM_COLUMNS = 'id, supplier_return_id, unit_id, product_id, variant_id, product_name_snapshot, variant_label_snapshot, barcode_snapshot, serial_snapshot, grn_id, grn_line_id, quantity, from_status, reversed_at'

export { newRequestId }

/** Admin and owner write here; staff can view suppliers, POs and returns. */
export function canManagePurchasing(role: AdminRole | null): boolean {
  return role === 'owner' || role === 'admin'
}

// ---------------------------------------------------------------------------
// Suppliers
// ---------------------------------------------------------------------------

export async function listSuppliers(): Promise<SupplierRow[]> {
  const { data, error } = await getSupabaseClient()
    .from('suppliers')
    .select(SUPPLIER_COLUMNS)
    .order('name', { ascending: true })
    .limit(2000)
  if (error) throw error
  return (data ?? []) as unknown as SupplierRow[]
}

export interface SupplierInput {
  id: string | null
  name: string
  contactPerson: string
  phone: string
  email: string
  address: string
  note: string
  /** null = none entered yet. Never assumed to be zero. */
  openingBalanceCents: number | null
  /** Required when the opening balance changes: it is kept in the audit trail. */
  openingBalanceNote: string
  isActive: boolean
}

export async function saveSupplier(input: SupplierInput): Promise<{ id: string; supplier_code: string; name: string }> {
  const { data, error } = await getSupabaseClient().rpc('admin_save_supplier', {
    p_id: input.id,
    p_name: input.name,
    p_contact_person: input.contactPerson,
    p_phone: input.phone,
    p_email: input.email,
    p_address: input.address,
    p_note: input.note,
    p_opening_balance_cents: input.openingBalanceCents,
    p_opening_balance_note: input.openingBalanceNote,
    p_is_active: input.isActive,
  })
  if (error) throw error
  return data as unknown as { id: string; supplier_code: string; name: string }
}

export interface SupplierBalance {
  supplierId: string
  /** null = none entered yet. */
  openingCents: number | null
  purchasesCents: number
  creditReturnsCents: number
  cashReturnsCents: number
  paymentsCents: number
  balanceCents: number
  /** GRN lines with no cost yet: the balance is understated until they are stated. */
  pendingCostLines: number
}

/** Admin/owner only — the database refuses everyone else. */
export async function loadSupplierBalances(): Promise<Map<string, SupplierBalance>> {
  const { data, error } = await getSupabaseClient().rpc('admin_supplier_balances')
  if (error) throw error
  return new Map((data ?? []).map((r) => [r.supplier_id, {
    supplierId: r.supplier_id,
    openingCents: r.opening_cents === null ? null : Number(r.opening_cents),
    purchasesCents: Number(r.purchases_cents),
    creditReturnsCents: Number(r.credit_returns_cents),
    cashReturnsCents: Number(r.cash_returns_cents),
    paymentsCents: Number(r.payments_cents),
    balanceCents: Number(r.balance_cents),
    pendingCostLines: r.pending_cost_lines,
  }]))
}

export interface StatementRow {
  occurredOn: string
  kind: string
  reference: string
  description: string
  debitCents: number
  creditCents: number
}

export async function loadSupplierStatement(supplierId: string): Promise<StatementRow[]> {
  const { data, error } = await getSupabaseClient().rpc('admin_supplier_statement', { p_supplier_id: supplierId })
  if (error) throw error
  return (data ?? []).map((r) => ({
    occurredOn: r.occurred_on,
    kind: r.kind,
    reference: r.reference,
    description: r.description,
    debitCents: Number(r.debit_cents ?? 0),
    creditCents: Number(r.credit_cents ?? 0),
  }))
}

export interface OpenGrn {
  grnId: string
  grnNumber: string
  receivedOn: string
  supplierInvoice: string | null
  outstandingCents: number
}

export async function loadOpenGrns(supplierId: string): Promise<OpenGrn[]> {
  const { data, error } = await getSupabaseClient().rpc('admin_supplier_open_grns', { p_supplier_id: supplierId })
  if (error) throw error
  return (data ?? []).map((r) => ({
    grnId: r.grn_id,
    grnNumber: r.grn_number,
    receivedOn: r.received_on,
    supplierInvoice: r.supplier_invoice,
    outstandingCents: Number(r.outstanding_cents),
  }))
}

// ---------------------------------------------------------------------------
// Receiving goods (GRN) from a supplier, optionally against a PO
// ---------------------------------------------------------------------------

export interface GrnLineInput {
  productId: string
  variantId: string | null
  purchaseOrderLineId: string | null
  /** What physically arrived. */
  receivedQuantity: number
  /** Refused on arrival: never stocked, never owed. */
  rejectedQuantity: number
  rejectionReason: string
  /** null only together with costPending: a blank cost is never zero. */
  unitCostCents: number | null
  costPending: boolean
  /** Required when the cost differs from the PO's. */
  costNote: string
  /** One per accepted unit, or empty when optional. */
  serials: string[]
  /** Required when an IMEI was recorded before and has legitimately come back. */
  serialReentryReason: string
}

export type GrnSourceType = 'supplier' | 'opening' | 'buyback'

export const GRN_SOURCES: { value: GrnSourceType; label: string; hint: string }[] = [
  { value: 'supplier', label: 'Supplier delivery', hint: 'Adds to what you owe that supplier.' },
  { value: 'opening', label: 'Opening stock (counted)', hint: 'Physically counted stock at cutover. Nothing is owed.' },
  { value: 'buyback', label: 'Buy-back from a person', hint: 'A device bought from a customer. Nothing is owed to a supplier.' },
]

export interface ReceiveInput {
  sourceType: GrnSourceType
  supplierId: string | null
  sourceName: string
  purchaseOrderId: string | null
  supplierInvoice: string
  confirmDuplicateInvoice: boolean
  duplicateInvoiceNote: string
  receivedOn: string
  note: string
  lines: GrnLineInput[]
  requestId: string
}

export interface GrnResult {
  id: string
  grn_number: string
  total_units: number
  rejected_units: number
  replayed: boolean
}

export async function receiveGoods(input: ReceiveInput): Promise<GrnResult> {
  const { data, error } = await getSupabaseClient().rpc('admin_receive_goods', {
    p_source_type: input.sourceType,
    p_supplier_id: input.supplierId,
    p_source_name: input.sourceName,
    p_purchase_order_id: input.purchaseOrderId,
    p_supplier_invoice: input.supplierInvoice,
    p_confirm_duplicate_invoice: input.confirmDuplicateInvoice,
    p_duplicate_invoice_note: input.duplicateInvoiceNote,
    p_received_on: input.receivedOn,
    p_note: input.note,
    p_lines: input.lines.map((l) => ({
      product_id: l.productId,
      variant_id: l.variantId,
      purchase_order_line_id: l.purchaseOrderLineId,
      received_quantity: l.receivedQuantity,
      rejected_quantity: l.rejectedQuantity,
      rejection_reason: l.rejectionReason,
      unit_cost_cents: l.unitCostCents,
      cost_pending: l.costPending,
      cost_note: l.costNote,
      serials: l.serials,
      serial_reentry_reason: l.serialReentryReason,
    })),
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as GrnResult
}

/** States a pending cost, or corrects a stated one. Audited; needs a note. */
export async function setGrnLineCost(lineId: string, unitCostCents: number, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_set_grn_line_cost', {
    p_grn_line_id: lineId, p_unit_cost_cents: unitCostCents, p_note: note,
  })
  if (error) throw error
}

/** Takes goods recorded by mistake back out of stock, the PO and what is owed. */
export async function correctGrnLine(input: {
  lineId: string
  unitIds: string[] | null
  quantity: number | null
  note: string
  requestId: string
}): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_correct_grn_line', {
    p_grn_line_id: input.lineId,
    p_unit_ids: input.unitIds,
    p_quantity: input.quantity,
    p_note: input.note,
    p_request_id: input.requestId,
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// Purchase orders
// ---------------------------------------------------------------------------

export const PO_STATUSES = ['open', 'partially_received', 'received', 'closed', 'cancelled'] as const
export type PoStatus = (typeof PO_STATUSES)[number]

export const PO_STATUS_LABEL: Record<PoStatus, string> = {
  open: 'Open',
  partially_received: 'Partly received',
  received: 'Received',
  closed: 'Closed',
  cancelled: 'Cancelled',
}

export function isPoReceivable(status: string): boolean {
  return status === 'open' || status === 'partially_received'
}

export interface PurchaseOrderListItem extends PurchaseOrderRow {
  supplierName: string
}

export async function listPurchaseOrders(): Promise<PurchaseOrderListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('purchase_orders')
    .select(`${PO_COLUMNS}, suppliers(name)`)
    .order('order_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(1000)
  if (error) throw error
  return ((data ?? []) as unknown as (PurchaseOrderRow & { suppliers: { name: string } | null })[]).map(({ suppliers, ...row }) => ({
    ...row,
    supplierName: suppliers?.name ?? '—',
  }))
}

export interface PurchaseOrderDetail {
  po: PurchaseOrderListItem
  lines: PurchaseOrderLineRow[]
  grns: { id: string; grn_number: string; received_on: string; total_units: number }[]
}

export async function loadPurchaseOrder(id: string): Promise<PurchaseOrderDetail> {
  const supabase = getSupabaseClient()
  const [po, lines, grns] = await Promise.all([
    supabase.from('purchase_orders').select(`${PO_COLUMNS}, suppliers(name)`).eq('id', id).single(),
    supabase.from('purchase_order_lines').select(PO_LINE_COLUMNS).eq('purchase_order_id', id).order('line_no'),
    supabase.from('grns').select('id, grn_number, received_on, total_units').eq('purchase_order_id', id).order('created_at'),
  ])
  if (po.error) throw po.error
  if (lines.error) throw lines.error
  if (grns.error) throw grns.error
  const { suppliers, ...row } = po.data as unknown as PurchaseOrderRow & { suppliers: { name: string } | null }
  return {
    po: { ...row, supplierName: suppliers?.name ?? '—' },
    lines: (lines.data ?? []) as unknown as PurchaseOrderLineRow[],
    grns: grns.data ?? [],
  }
}

export interface PoLineInput {
  productId: string
  variantId: string | null
  quantity: number
  /** null = not known yet: the line is marked cost pending, never zero. */
  unitCostCents: number | null
}

export async function createPurchaseOrder(input: {
  supplierId: string
  orderDate: string
  expectedDate: string | null
  note: string
  lines: PoLineInput[]
  requestId: string
}): Promise<{ id: string; po_number: string; replayed: boolean }> {
  const { data, error } = await getSupabaseClient().rpc('admin_create_purchase_order', {
    p_supplier_id: input.supplierId,
    p_order_date: input.orderDate,
    p_expected_date: input.expectedDate,
    p_note: input.note,
    p_lines: input.lines.map((l) => ({
      product_id: l.productId,
      variant_id: l.variantId,
      quantity: l.quantity,
      unit_cost_cents: l.unitCostCents,
      cost_pending: l.unitCostCents === null,
    })),
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as { id: string; po_number: string; replayed: boolean }
}

export async function closePurchaseOrder(id: string, note: string): Promise<{ status: PoStatus }> {
  const { data, error } = await getSupabaseClient().rpc('admin_close_purchase_order', {
    p_purchase_order_id: id,
    p_note: note,
  })
  if (error) throw error
  return data as unknown as { status: PoStatus }
}

// ---------------------------------------------------------------------------
// Supplier returns
// ---------------------------------------------------------------------------

export const RETURN_TYPES = [
  { value: 'credit', label: 'Credit', hint: 'Deducted from what you owe the supplier' },
  { value: 'cash', label: 'Cash', hint: 'The supplier paid the money back' },
] as const
export type ReturnType = (typeof RETURN_TYPES)[number]['value']

export function returnTypeLabel(value: string): string {
  return RETURN_TYPES.find((t) => t.value === value)?.label ?? value
}

export interface SupplierReturnListItem extends SupplierReturnRow {
  supplierName: string
}

export async function listSupplierReturns(): Promise<SupplierReturnListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('supplier_returns')
    .select(`${RETURN_COLUMNS}, suppliers(name)`)
    .order('return_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(1000)
  if (error) throw error
  return ((data ?? []) as unknown as (SupplierReturnRow & { suppliers: { name: string } | null })[]).map(({ suppliers, ...row }) => ({
    ...row,
    supplierName: suppliers?.name ?? '—',
  }))
}

export async function loadSupplierReturnItems(returnId: string): Promise<SupplierReturnItemRow[]> {
  const { data, error } = await getSupabaseClient()
    .from('supplier_return_items')
    .select(RETURN_ITEM_COLUMNS)
    .eq('supplier_return_id', returnId)
    .order('product_name_snapshot')
  if (error) throw error
  return (data ?? []) as unknown as SupplierReturnItemRow[]
}

export async function createSupplierReturn(input: {
  supplierId: string
  returnDate: string
  returnType: ReturnType
  codes: string[]
  /** Quantity-tracked goods, valued at the delivery they came from. */
  quantityLines: { grnLineId: string; quantity: number }[]
  note: string
  requestId: string
}): Promise<{ id: string; return_number: string; total_cents: number; total_units: number; replayed: boolean }> {
  const { data, error } = await getSupabaseClient().rpc('admin_create_supplier_return', {
    p_supplier_id: input.supplierId,
    p_return_date: input.returnDate,
    p_return_type: input.returnType,
    p_codes: input.codes,
    p_quantity_lines: input.quantityLines.map((l) => ({ grn_line_id: l.grnLineId, quantity: l.quantity })),
    p_note: input.note,
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as { id: string; return_number: string; total_cents: number; total_units: number; replayed: boolean }
}

/** A return recorded by mistake: its effect on stock and on what is owed is undone. */
export async function reverseSupplierReturn(returnId: string, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_reverse_supplier_return', { p_return_id: returnId, p_note: note })
  if (error) throw error
}

/** GRN lines of quantity-tracked goods from one supplier that can still be returned. */
export interface ReturnableLine {
  id: string
  grnNumber: string
  productName: string
  variantName: string | null
  returnable: number
}

export async function listReturnableLines(supplierId: string): Promise<ReturnableLine[]> {
  const { data, error } = await getSupabaseClient()
    .from('grn_lines')
    .select('id, product_name_snapshot, variant_label_snapshot, accepted_quantity, corrected_quantity, returned_quantity, grns!inner(grn_number, supplier_id)')
    .eq('tracking_mode_snapshot', 'quantity')
    .eq('grns.supplier_id', supplierId)
    .limit(500)
  if (error) throw error
  return ((data ?? []) as unknown as {
    id: string
    product_name_snapshot: string
    variant_label_snapshot: string | null
    accepted_quantity: number
    corrected_quantity: number
    returned_quantity: number
    grns: { grn_number: string }
  }[])
    .map((l) => ({
      id: l.id,
      grnNumber: l.grns.grn_number,
      productName: l.product_name_snapshot,
      variantName: l.variant_label_snapshot,
      returnable: l.accepted_quantity - l.corrected_quantity - l.returned_quantity,
    }))
    .filter((l) => l.returnable > 0)
}

// ---------------------------------------------------------------------------
// Supplier payments
// ---------------------------------------------------------------------------

export const SUPPLIER_PAYMENT_METHODS = [
  { value: 'cash', label: 'Cash' },
  { value: 'bank_transfer', label: 'Bank transfer' },
  { value: 'cheque', label: 'Cheque' },
  { value: 'card', label: 'Card' },
  { value: 'other', label: 'Other' },
] as const
export type SupplierPaymentMethod = (typeof SUPPLIER_PAYMENT_METHODS)[number]['value']

export function supplierPaymentMethodLabel(value: string): string {
  return SUPPLIER_PAYMENT_METHODS.find((m) => m.value === value)?.label ?? value
}

export interface SupplierPaymentListItem extends SupplierPaymentRow {
  supplierName: string
}

export async function listSupplierPayments(): Promise<SupplierPaymentListItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('supplier_payments')
    .select('*, suppliers(name)')
    .order('paid_on', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(1000)
  if (error) throw error
  return (data ?? []).map(({ suppliers, ...row }) => ({
    ...(row as SupplierPaymentRow),
    supplierName: (suppliers as { name: string } | null)?.name ?? '—',
  }))
}

export async function recordSupplierPayment(input: {
  supplierId: string
  paidOn: string
  amountCents: number
  method: SupplierPaymentMethod
  reference: string
  note: string
  /** Optional: which GRNs this settles. */
  allocations: { grnId: string; amountCents: number }[]
  requestId: string
}): Promise<{ id: string; payment_number: string; replayed: boolean }> {
  const { data, error } = await getSupabaseClient().rpc('admin_record_supplier_payment', {
    p_supplier_id: input.supplierId,
    p_paid_on: input.paidOn,
    p_amount_cents: input.amountCents,
    p_method: input.method,
    p_reference: input.reference,
    p_note: input.note,
    p_allocations: input.allocations.map((a) => ({ grn_id: a.grnId, amount_cents: a.amountCents })),
    p_request_id: input.requestId,
  })
  if (error) throw error
  return data as unknown as { id: string; payment_number: string; replayed: boolean }
}

export async function voidSupplierPayment(id: string, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_void_supplier_payment', { p_payment_id: id, p_note: note })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/** A sentence the shop can act on. The database raises '<code>: <detail>'. */
export function describePurchasingError(err: unknown, fallback: string): string {
  const e = (err ?? {}) as { code?: unknown; message?: unknown }
  if (e.code === 'PGRST202' || e.code === 'PGRST205' || (typeof e.message === 'string' && e.message.includes('Could not find the'))) {
    return 'This screen needs the latest database update. Nothing was changed.'
  }
  return describeUnitError(err, fallback)
}

export function formatRupeesFromCents(cents: number): string {
  return `Rs. ${(cents / 100).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

// ---------------------------------------------------------------------------
// Scanning a unit for a supplier return
// ---------------------------------------------------------------------------

export interface ReturnUnit {
  id: string
  barcode: string
  serial: string | null
  status: string
  productName: string
  variantName: string | null
  grnNumber: string | null
  grnSupplierId: string | null
  grnSupplierName: string | null
}

interface ReturnUnitRow {
  id: string
  barcode: string
  serial_number: string | null
  status: string
  created_at: string
  products: { name: string } | null
  product_variants: { name: string } | null
  grns: { grn_number: string; supplier_id: string | null; supplier_name: string } | null
}

/**
 * Finds one unit by its barcode label or IMEI / serial. An IMEI can have older
 * history rows, so the one physically here wins, like private.find_unit_by_code().
 */
export async function findUnitForReturn(code: string): Promise<ReturnUnit | null> {
  const value = code.replace(/\s+/g, '').toUpperCase()
  if (!/^[A-Z0-9-]{4,40}$/.test(value)) return null
  const { data, error } = await getSupabaseClient()
    .from('inventory_units')
    .select('id, barcode, serial_number, status, created_at, products(name), product_variants(name), grns(grn_number, supplier_id, supplier_name)')
    .or(`barcode.eq.${value},serial_number.eq.${value}`)
    .order('created_at', { ascending: false })
    .limit(10)
  if (error) throw error
  const rows = (data ?? []) as unknown as ReturnUnitRow[]
  const row = rows.find((r) => r.barcode === value)
    ?? rows.find((r) => ['in_stock', 'reserved', 'quarantined'].includes(r.status))
    ?? rows[0]
  if (!row) return null
  return {
    id: row.id,
    barcode: row.barcode,
    serial: row.serial_number,
    status: row.status,
    productName: row.products?.name ?? '—',
    variantName: row.product_variants?.name ?? null,
    grnNumber: row.grns?.grn_number ?? null,
    grnSupplierId: row.grns?.supplier_id ?? null,
    grnSupplierName: row.grns?.supplier_name ?? null,
  }
}
