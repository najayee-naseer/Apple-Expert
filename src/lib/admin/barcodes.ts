import { getSupabaseClient } from '@/lib/supabase/client'

/**
 * Shared barcodes of quantity-tracked accessories and parts: a shop AP… code, a
 * manufacturer's UPC / EAN, or both, all meaning one product or variant. Devices
 * use unit barcodes (units.ts). Staff can read these; only owner/admin can change
 * them, always through the database functions, which enforce every rule here.
 */

export interface ProductBarcode {
  id: string
  productId: string
  variantId: string | null
  value: string
  source: 'shop' | 'manufacturer'
  status: 'active' | 'retired'
}

function fromRow(row: { id: string; product_id: string; variant_id: string | null; value: string; source: string; status: string }): ProductBarcode {
  return {
    id: row.id,
    productId: row.product_id,
    variantId: row.variant_id,
    value: row.value,
    source: row.source as ProductBarcode['source'],
    status: row.status as ProductBarcode['status'],
  }
}

export async function listProductBarcodes(productIds: string[]): Promise<ProductBarcode[]> {
  if (productIds.length === 0) return []
  const { data, error } = await getSupabaseClient()
    .from('product_barcodes')
    .select('id, product_id, variant_id, value, source, status')
    .in('product_id', productIds)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []).map(fromRow)
}

/** Which of these products sit in a category that may have shared barcodes. */
export async function productsAllowingSharedBarcode(productIds: string[]): Promise<Set<string>> {
  if (productIds.length === 0) return new Set()
  const { data, error } = await getSupabaseClient()
    .from('products')
    .select('id, categories!inner(allows_shared_barcode)')
    .in('id', productIds)
    .eq('categories.allows_shared_barcode', true)
  if (error) throw error
  return new Set((data ?? []).map((p) => p.id))
}

export async function issueProductBarcode(productId: string, variantId: string | null): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_issue_product_barcode', { p_product_id: productId, p_variant_id: variantId })
  if (error) throw error
}

export async function registerManufacturerBarcode(productId: string, variantId: string | null, value: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_register_manufacturer_barcode', { p_product_id: productId, p_variant_id: variantId, p_value: value })
  if (error) throw error
}

export async function retireProductBarcode(barcodeId: string, note: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('admin_retire_product_barcode', { p_barcode_id: barcodeId, p_note: note })
  if (error) throw error
}
