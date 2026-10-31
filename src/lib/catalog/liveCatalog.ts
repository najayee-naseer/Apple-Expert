import type {
  Product, ProductVariant, ProductCategory, ProductSubcategory, WarrantyInfo,
  ProductCondition, PreOwnedDetails, ProductWarranty, WarrantyType,
} from '@/types'
import { getSupabaseClient, isSupabaseConfigured } from '@/lib/supabase/client'
import { resolveCustomerType } from '@/lib/customer/profile'
import type { ResolvedTier } from './types'

/**
 * Live catalog overlay.
 *
 * Reads the fields an admin can change from Supabase and lays them over the
 * bundled catalog: name, description, model, subcategory, warranty, lifecycle
 * status, specifications, image references, variant details, stock, price and
 * whether the product is still published.
 *
 * Prices come exclusively from product_prices via the my_effective_prices view,
 * which is `security_invoker`, so RLS applies to the caller and a retail
 * customer's query physically cannot return a wholesale_vip row. There is no
 * price column on products and none is introduced here.
 *
 * Image FILES are not fetched. A product_images row either holds a bundled
 * /images/... path (storage_bucket NULL — every image that predates uploads) or
 * an object in the `product-images` Storage bucket, which is resolved to its
 * public URL here. Uploaded images never ship in the APK.
 *
 * SINCE THE ADMIN CATALOG PHASE this module no longer only overlays. A product
 * that exists in the database but not in the bundled catalog — anything an
 * administrator created after this build was made — is BUILT from its database
 * rows and appended to the list. That is what lets "Apple released the iPhone
 * 18 Pro" be a data change rather than a release.
 */

/** Money crosses the wire as bigint minor units. Rupees = cents / 100. */
export function centsToRupees(cents: number): number {
  return cents / 100
}

interface LivePriceRow {
  product_id: string
  variant_id: string | null
  tier_code: string
  price_cents: number
}

/**
 * Both tiers for one product or variant, kept apart so the resolver can choose.
 *
 * Previously the fetch collapsed every returned row into a single number and
 * trusted my_effective_prices to have handed back exactly one row per
 * product/variant. That trust holds only for a caller whose RLS limits them to
 * one tier. A staff, admin or owner account reads EVERY tier through the
 * "product_prices staff read all" policy, and the view's
 * `order by (tier_code = 'wholesale_vip') desc` then deliberately prefers the
 * VIP row — so anyone with a role saw VIP prices on the storefront regardless
 * of their own customer_type. Keeping the tiers separate is what makes the
 * choice explicit instead of incidental.
 */
export interface TierPrices {
  retail?: number
  wholesale_vip?: number
}

/**
 * THE customer-facing price rule. Every price the storefront shows comes
 * through here.
 *
 *   wholesale_vip -> the VIP price, falling back to retail when none is set
 *   retail        -> the retail price, never the VIP one
 *
 * The tier argument is the customer's own profiles.customer_type. It is never
 * inferred from which rows came back, from the /wholesale route, or from the
 * localStorage experience preference.
 */
export function resolveTierPrice(
  prices: TierPrices | undefined,
  tier: ResolvedTier,
): number | undefined {
  if (!prices) return undefined
  if (tier === 'wholesale_vip') return prices.wholesale_vip ?? prices.retail
  return prices.retail
}

/**
 * True when resolveTierPrice() would answer from the VIP row itself rather
 * than the retail fallback. Feeds Product.isVipPrice — a label only.
 */
function isVipTierPrice(prices: TierPrices | undefined, tier: ResolvedTier): boolean {
  return tier === 'wholesale_vip' && prices?.wholesale_vip !== undefined
}

/** Editable product fields, as stored. */
interface ProductOverlay {
  name: string
  description: string
  model: string | null
  subcategory: string
  /** Resolved to a display name through the categories table. */
  category_id: string
  sort_order: number
  lifecycle_status: string | null
  is_new: boolean
  warranty_text: string | null
  warranty_status: string | null
  warranty_duration: string | null
  warranty_months: number | null
  warranty_coverage: string | null
  rating: number | null
  reviews_count: number
  stock: number
}

interface VariantOverlay {
  legacyKey: string
  name: string
  color: string | null
  colorCode: string | null
  storage: string | null
  sortOrder: number
  /** What can be bought of this exact variant. undefined on a database without it. */
  available?: number
}

/** One product_conditions row, mapped for the storefront. */
export interface ItemConditionData {
  condition: ProductCondition
  preOwned?: PreOwnedDetails
}

/**
 * Condition and warranty data, keyed like product_prices: `product_id` for the
 * product-level row/plan (variant_id NULL), `${product_id}:${legacy_key}` for a
 * variant's. Read separately from the core catalog (see fetchProductExtras).
 */
export interface CatalogExtras {
  /** False when the query failed — products then carry no condition/warranty. */
  loaded: boolean
  conditions: Map<string, ItemConditionData>
  plans: Map<string, ProductWarranty>
}

const EMPTY_EXTRAS: CatalogExtras = { loaded: false, conditions: new Map(), plans: new Map() }

export interface LiveCatalogData {
  activeIds: Set<string>
  product: Map<string, ProductOverlay>
  variants: Map<string, VariantOverlay[]>
  specs: Map<string, Record<string, string>>
  /** product_id -> images shared by all variants (variant_id NULL), primary first. */
  images: Map<string, string[]>
  /** `${product_id}:${legacy_key}` -> images assigned to that variant only. */
  variantImages: Map<string, string[]>
  /** product_id -> compatibility labels, in stored order. */
  compatibility: Map<string, string[]>
  /** category_id -> display name, for products this build has never seen. */
  categoryName: Map<string, string>
  /** product_id -> both tiers, in rupees. Resolved by resolveTierPrice(). */
  productPrice: Map<string, TierPrices>
  /** `${product_id}:${legacy_key}` -> both tiers, in rupees */
  variantPrice: Map<string, TierPrices>
  /**
   * Curated featured ids in display order, or null when the merchandising
   * query failed or returned nothing — in which case the bundled selection is
   * used. Featured is deliberately non-fatal: a merchandising hiccup must not
   * cost the customer live prices.
   */
  featuredIds: string[] | null
  /**
   * Conditions and warranty plans (product-level and per variant). Not loaded
   * when that query failed, in which case products simply carry no
   * condition/warranty data — never a broken store.
   */
  extras: CatalogExtras
  /**
   * The tier this catalog was resolved AT, read from the caller's own profile —
   * not guessed from the price rows that happened to come back.
   */
  tier: ResolvedTier
}

function isTier(value: string): value is ResolvedTier {
  return value === 'retail' || value === 'wholesale_vip'
}

/**
 * The caller's own pricing tier, read from public.profiles.
 *
 * profiles.customer_type is the single authority for pricing, so it is asked
 * directly rather than inferred from the price rows. An anonymous visitor has
 * no profile and resolves to retail, exactly as
 * private.current_customer_type() does inside the database.
 *
 * Fails CLOSED: if the session or the profile cannot be read, the caller is
 * treated as retail. Showing a VIP price to someone we could not confirm is a
 * worse failure than showing a retail price to a VIP, who will see the correct
 * price on the next load.
 */
async function fetchCallerTier(): Promise<ResolvedTier> {
  const supabase = getSupabaseClient()

  const { data: { session } } = await supabase.auth.getSession()
  const userId = session?.user?.id
  if (!userId) return 'retail'

  const { data, error } = await supabase
    .from('profiles')
    .select('customer_type, vip_expires_at')
    .eq('id', userId)
    .maybeSingle()

  if (error || !data) return 'retail'

  // Same rule the profile page and the auth context use — written once.
  return resolveCustomerType(data)
}

function isCondition(value: string): value is ProductCondition {
  return value === 'brand_new' || value === 'pre_owned' || value === 'refurbished'
}

function isWarrantyType(value: string): value is WarrantyType {
  return value === 'none' || value === 'included' || value === 'optional_paid'
}

/**
 * Conditions (product_conditions), warranty plans (product_warranty_plans) and
 * their options, keyed by product or by variant legacy_key.
 *
 * Deliberately NON-FATAL, like featured products: a failure here must not cost
 * the customer live prices, so it yields "not loaded" instead of throwing.
 *
 * RLS returns rows of active products only, enabled options only, and active
 * grades only.
 */
async function fetchProductExtras(
  variantKeyById: Map<string, { productId: string; legacyKey: string }>,
): Promise<CatalogExtras> {
  const supabase = getSupabaseClient()

  const [conditionsResult, plansResult, optionsResult, gradesResult] = await Promise.all([
    supabase
      .from('product_conditions')
      .select('product_id, variant_id, condition, condition_grade_id, battery_health, cycle_count, physical_condition, accessories_included, device_notes'),
    supabase
      .from('product_warranty_plans')
      .select('id, product_id, variant_id, warranty_type, warranty_duration, warranty_months, warranty_title, warranty_description, warranty_covered, warranty_excluded'),
    supabase
      .from('product_warranty_options')
      .select('id, plan_id, duration_months, additional_price_cents, is_default, display_order')
      .order('display_order', { ascending: true }),
    supabase.from('condition_grades').select('id, code, label, description'),
  ])

  const failure = conditionsResult.error ?? plansResult.error ?? optionsResult.error ?? gradesResult.error
  if (failure) {
    if (process.env.NODE_ENV !== 'production') {
      console.info('[catalog] condition/warranty data unavailable:', failure.message)
    }
    return EMPTY_EXTRAS
  }

  /** The key a row is stored under, or null for a variant the catalog does not know. */
  function keyFor(productId: string, variantId: string | null): string | null {
    if (variantId === null) return productId
    const mapped = variantKeyById.get(variantId)
    return mapped ? `${productId}:${mapped.legacyKey}` : null
  }

  const grades = new Map(
    (gradesResult.data ?? []).map((g) => [g.id, { code: g.code, label: g.label, description: g.description ?? undefined }]),
  )

  const conditions = new Map<string, ItemConditionData>()
  for (const row of conditionsResult.data ?? []) {
    const key = keyFor(row.product_id, row.variant_id)
    if (!key || !isCondition(row.condition)) continue
    conditions.set(key, {
      condition: row.condition,
      preOwned: row.condition === 'pre_owned'
        ? {
            grade: row.condition_grade_id ? grades.get(row.condition_grade_id) : undefined,
            batteryHealth: row.battery_health ?? undefined,
            cycleCount: row.cycle_count ?? undefined,
            physicalCondition: row.physical_condition ?? undefined,
            accessoriesIncluded: row.accessories_included ?? undefined,
            deviceNotes: row.device_notes ?? undefined,
          }
        : undefined,
    })
  }

  const optionsByPlan = new Map<string, ProductWarranty['options']>()
  for (const row of optionsResult.data ?? []) {
    const list = optionsByPlan.get(row.plan_id) ?? []
    list.push({
      id: row.id,
      months: row.duration_months,
      addOn: centsToRupees(row.additional_price_cents),
      isDefault: row.is_default,
    })
    optionsByPlan.set(row.plan_id, list)
  }

  const plans = new Map<string, ProductWarranty>()
  for (const row of plansResult.data ?? []) {
    const key = keyFor(row.product_id, row.variant_id)
    if (!key) continue
    plans.set(key, {
      type: isWarrantyType(row.warranty_type) ? row.warranty_type : 'none',
      duration: row.warranty_duration ?? undefined,
      months: row.warranty_months ?? undefined,
      title: row.warranty_title ?? undefined,
      description: row.warranty_description ?? undefined,
      covered: row.warranty_covered ?? [],
      excluded: row.warranty_excluded ?? [],
      options: optionsByPlan.get(row.id) ?? [],
    })
  }

  return { loaded: true, conditions, plans }
}

/**
 * The URL a product_images row is served from: its bundled path, or the public
 * URL of its object in Supabase Storage.
 */
export function productImageUrl(row: { path: string; storage_bucket: string | null }): string {
  if (!row.storage_bucket) return row.path
  return getSupabaseClient().storage.from(row.storage_bucket).getPublicUrl(row.path).data.publicUrl
}

/**
 * Resolves order_items.image_path_snapshot, which place_order() copies straight
 * from product_images.path: a bundled '/images/...' path or an https URL is used
 * as-is; anything else can only be an object key in the `product-images` bucket
 * (the product_images_bucket_known constraint allows no other bucket).
 */
export function snapshotImageUrl(path: string): string {
  if (path.startsWith('/') || /^https?:\/\//.test(path)) return path
  return productImageUrl({ path, storage_bucket: 'product-images' })
}

/**
 * Reads the live catalog. Throws on failure so the caller can fall back to the
 * bundled catalog rather than rendering a half-empty store.
 */
export async function fetchLiveCatalog(): Promise<LiveCatalogData> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase is not configured for this build.')
  }

  const supabase = getSupabaseClient()

  const [
    tier, productsResult, variantsResult, specsResult, imagesResult,
    compatibilityResult, categoriesResult, pricesResult, featuredResult, availabilityResult,
  ] =
    await Promise.all([
      fetchCallerTier(),
      supabase
        .from('products')
        .select(
          'id, name, description, model, subcategory, category_id, sort_order, lifecycle_status, is_new, stock, rating, reviews_count, warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage',
        )
        .eq('is_active', true),
      supabase
        .from('product_variants')
        .select('id, product_id, legacy_key, name, color, color_code, storage, sort_order')
        .order('sort_order', { ascending: true }),
      supabase.from('product_specs').select('product_id, label, value, position').order('position', { ascending: true }),
      supabase.from('product_images').select('product_id, variant_id, path, storage_bucket, position, is_primary').order('position', { ascending: true }),
      supabase.from('product_compatibility').select('product_id, label, position').order('position', { ascending: true }),
      supabase.from('categories').select('id, name').eq('is_active', true),
      supabase.from('my_effective_prices').select('product_id, variant_id, tier_code, price_cents'),
      supabase
        .from('featured_products')
        .select('product_id, position')
        .eq('slot', 'home')
        .eq('is_active', true)
        .order('position', { ascending: true }),
      // Non-fatal like featured: a database without it falls back to products.stock.
      supabase.rpc('catalog_availability'),
    ])

  if (productsResult.error) throw productsResult.error
  if (variantsResult.error) throw variantsResult.error
  if (specsResult.error) throw specsResult.error
  if (imagesResult.error) throw imagesResult.error
  if (compatibilityResult.error) throw compatibilityResult.error
  if (categoriesResult.error) throw categoriesResult.error
  if (pricesResult.error) throw pricesResult.error
  // featuredResult is intentionally NOT thrown on — see featuredIds above.

  // Availability = stock minus online holds, per exact option. products.stock
  // alone would ignore holds and hide an empty variant behind a shared pool.
  const productAvailable = new Map<string, number>()
  const variantAvailable = new Map<string, number>()
  for (const row of (availabilityResult.error ? null : availabilityResult.data) ?? []) {
    if (row.variant_id === null) productAvailable.set(row.product_id, row.available)
    else if (row.legacy_key) variantAvailable.set(`${row.product_id}:${row.legacy_key}`, row.available)
  }

  const activeIds = new Set<string>()
  const product = new Map<string, ProductOverlay>()
  for (const row of productsResult.data ?? []) {
    activeIds.add(row.id)
    product.set(row.id, { ...(row as ProductOverlay), stock: productAvailable.get(row.id) ?? row.stock })
  }

  // Variant ids are UUIDs in the database but 'v1', 'v2' … in the bundled data.
  // legacy_key is what bridges the two, which is also what keeps already-saved
  // cart lines resolvable.
  const variantKeyById = new Map<string, { productId: string; legacyKey: string }>()
  const variants = new Map<string, VariantOverlay[]>()
  for (const row of variantsResult.data ?? []) {
    if (!row.legacy_key) continue
    variantKeyById.set(row.id, { productId: row.product_id, legacyKey: row.legacy_key })

    const list = variants.get(row.product_id) ?? []
    list.push({
      legacyKey: row.legacy_key,
      name: row.name,
      color: row.color,
      colorCode: row.color_code,
      storage: row.storage,
      sortOrder: row.sort_order,
      available: variantAvailable.get(`${row.product_id}:${row.legacy_key}`),
    })
    variants.set(row.product_id, list)
  }
  for (const list of variants.values()) list.sort((a, b) => a.sortOrder - b.sortOrder)

  // Specification order is data: the UI renders them in the stored order.
  const specs = new Map<string, Record<string, string>>()
  for (const row of specsResult.data ?? []) {
    const record = specs.get(row.product_id) ?? {}
    record[row.label] = row.value
    specs.set(row.product_id, record)
  }

  // Ordered by position already; a row flagged is_primary is moved to the
  // front, because the storefront treats images[0] as the card image. Shared
  // images (variant_id NULL) and variant-only images are kept apart.
  const images = new Map<string, string[]>()
  const variantImages = new Map<string, string[]>()
  for (const row of imagesResult.data ?? []) {
    const url = productImageUrl(row)
    let target = images
    let key = row.product_id
    if (row.variant_id) {
      const mapped = variantKeyById.get(row.variant_id)
      if (!mapped) continue
      target = variantImages
      key = `${row.product_id}:${mapped.legacyKey}`
    }
    const list = target.get(key) ?? []
    if (row.is_primary) list.unshift(url)
    else list.push(url)
    target.set(key, list)
  }

  // Needs the variant uuid -> legacy_key map built above.
  const extras = await fetchProductExtras(variantKeyById)

  const compatibility = new Map<string, string[]>()
  for (const row of compatibilityResult.data ?? []) {
    const list = compatibility.get(row.product_id) ?? []
    list.push(row.label)
    compatibility.set(row.product_id, list)
  }

  const categoryName = new Map<string, string>()
  for (const row of categoriesResult.data ?? []) categoryName.set(row.id, row.name)

  const productPrice = new Map<string, TierPrices>()
  const variantPrice = new Map<string, TierPrices>()

  /** Records a row under its OWN tier, so neither tier can overwrite the other. */
  function record(map: Map<string, TierPrices>, key: string, row: LivePriceRow) {
    if (!isTier(row.tier_code)) return
    const entry = map.get(key) ?? {}
    entry[row.tier_code] = centsToRupees(row.price_cents)
    map.set(key, entry)
  }

  for (const row of (pricesResult.data ?? []) as LivePriceRow[]) {
    if (row.variant_id === null) {
      record(productPrice, row.product_id, row)
      continue
    }

    const mapped = variantKeyById.get(row.variant_id)
    if (mapped) {
      record(variantPrice, `${mapped.productId}:${mapped.legacyKey}`, row)
    }
  }

  if (process.env.NODE_ENV !== 'production') {
    // Diagnostic only, and never in the shipped APK: shows which tier the
    // storefront resolved and whether VIP rows were even visible to this caller.
    const vipRows = (pricesResult.data ?? []).filter(
      (row) => (row as LivePriceRow).tier_code === 'wholesale_vip',
    ).length
    console.info(
      `[catalog] tier=${tier} priceRows=${pricesResult.data?.length ?? 0} vipRowsVisible=${vipRows}`,
    )
  }

  // Only a FAILED query falls back to the bundled selection. A successful query
  // with no active rows means an administrator disabled or removed every
  // featured product in /admin/settings, and that choice must be respected.
  const featuredRows = featuredResult.error ? null : featuredResult.data
  const featuredIds = featuredRows ? featuredRows.map((row) => row.product_id) : null

  return {
    activeIds, product, variants, specs, images, variantImages, compatibility, categoryName,
    productPrice, variantPrice, featuredIds, extras, tier,
  }
}

function buildWarrantyInfo(overlay: ProductOverlay, fallback?: WarrantyInfo): WarrantyInfo | undefined {
  if (!overlay.warranty_status) return fallback
  return {
    status: overlay.warranty_status === 'none' ? 'none' : 'active',
    duration: overlay.warranty_duration ?? fallback?.duration ?? '',
    months: overlay.warranty_months ?? fallback?.months ?? 0,
    coverage: overlay.warranty_coverage ?? fallback?.coverage ?? '',
  }
}

/**
 * Builds the variant list for a product that exists only in the database.
 *
 * legacy_key is what the rest of the app calls a variant id — the cart composes
 * `${product.id}-${variant.id}` from it — so a variant with no legacy_key is
 * skipped here exactly as it is skipped when the price map is built. The admin
 * creator always assigns one.
 */
function buildLiveVariants(
  productId: string,
  live: LiveCatalogData,
  productPrice: number,
  productPriceIsVip: boolean,
): ProductVariant[] | undefined {
  const rows = live.variants.get(productId)
  if (!rows || rows.length === 0) return undefined

  return rows.map((row) => {
    const prices = live.variantPrice.get(`${productId}:${row.legacyKey}`)
    const own = resolveTierPrice(prices, live.tier)
    return {
      id: row.legacyKey,
      name: row.name,
      price: own ?? productPrice,
      isVipPrice: own !== undefined ? isVipTierPrice(prices, live.tier) : productPriceIsVip,
      color: row.color ?? undefined,
      colorCode: row.colorCode ?? undefined,
      storage: row.storage ?? undefined,
      available: row.available,
    }
  })
}

/**
 * Builds a complete Product from database rows alone.
 *
 * Used for every active product the bundled catalog has never heard of — which
 * is to say, everything an administrator creates from now on. Nothing is
 * invented: each field is either a stored value or an explicit empty default,
 * and a product with no price at all is refused by the caller rather than being
 * shown at Rs. 0.
 */
function buildProductFromLive(
  id: string,
  overlay: ProductOverlay,
  live: LiveCatalogData,
  price: number,
  priceIsVip: boolean,
): Product {
  return {
    id,
    name: overlay.name,
    // An active product whose category row is not visible (deactivated, say)
    // still belongs in search and on its own page; it simply matches no
    // category listing until the category is published again.
    category: live.categoryName.get(overlay.category_id) ?? 'Uncategorised',
    subcategory: overlay.subcategory as ProductSubcategory,
    model: overlay.model ?? undefined,
    price,
    images: live.images.get(id) ?? [],
    description: overlay.description,
    specifications: live.specs.get(id) ?? {},
    compatibility: live.compatibility.get(id),
    stock: overlay.stock,
    rating: overlay.rating ?? 0,
    reviewsCount: overlay.reviews_count,
    warranty: overlay.warranty_text ?? '',
    warrantyInfo: buildWarrantyInfo(overlay),
    isNew: overlay.is_new,
    status: (overlay.lifecycle_status as Product['status']) ?? undefined,
    isVipPrice: priceIsVip,
    variants: buildLiveVariants(id, live, price, priceIsVip),
  }
}

/**
 * Applies live data to the bundled catalog.
 *
 * Merges onto the bundled objects rather than rebuilding them, so any field the
 * overlay does not supply (`featured`, compatibility, category) survives
 * untouched and the UI cannot regress.
 *
 * A product with no live price keeps its bundled price. That is a last-known
 * value shipped in the APK, not a fabricated one — nothing here ever invents a
 * number, and the unpriced replacement parts are not in this list at all.
 */
export function applyLiveCatalog(
  staticProducts: readonly Product[],
  live: LiveCatalogData,
): Product[] {
  const merged: Product[] = []

  for (const product of staticProducts) {
    // Unpublished in the database: hide it from the storefront.
    if (!live.activeIds.has(product.id)) continue

    const overlay = live.product.get(product.id)
    // Resolved against the customer's OWN tier, never against whichever row
    // the database happened to return first.
    const livePrice = resolveTierPrice(live.productPrice.get(product.id), live.tier)
    const livePriceIsVip = isVipTierPrice(live.productPrice.get(product.id), live.tier)

    // Variants come from the database when it has them, keyed back to the
    // bundled 'v1'/'v2' ids via legacy_key so cart lines stay resolvable.
    let variants: ProductVariant[] | undefined = product.variants
    const liveVariants = live.variants.get(product.id)

    if (liveVariants && liveVariants.length > 0) {
      const bundledByKey = new Map((product.variants ?? []).map((v) => [v.id, v]))
      variants = liveVariants.map((lv) => {
        const bundled = bundledByKey.get(lv.legacyKey)
        // Precedence matters: the live product-level price must beat the
        // BUNDLED variant price, otherwise a variant with no price row of its
        // own keeps showing a stale number shipped in the APK even though the
        // database has a newer one. Bundled values are the last resort only.
        const prices = live.variantPrice.get(`${product.id}:${lv.legacyKey}`)
        const own = resolveTierPrice(prices, live.tier)
        const price = own ?? livePrice ?? bundled?.price ?? product.price
        return {
          id: lv.legacyKey,
          name: lv.name,
          price,
          isVipPrice:
            own !== undefined ? isVipTierPrice(prices, live.tier)
            : livePrice !== undefined && livePriceIsVip,
          color: lv.color ?? undefined,
          colorCode: lv.colorCode ?? undefined,
          storage: lv.storage ?? undefined,
          available: lv.available,
        }
      })
    } else if (product.variants && product.variants.length > 0) {
      variants = product.variants.map((variant) => {
        const prices = live.variantPrice.get(`${product.id}:${variant.id}`)
        const price = resolveTierPrice(prices, live.tier)
        return price === undefined ? variant : { ...variant, price, isVipPrice: isVipTierPrice(prices, live.tier) }
      })
    }

    const liveSpecs = live.specs.get(product.id)
    const liveImages = live.images.get(product.id)

    merged.push({
      ...product,
      name: overlay?.name ?? product.name,
      description: overlay?.description ?? product.description,
      model: overlay?.model ?? product.model,
      subcategory: (overlay?.subcategory as ProductSubcategory | undefined) ?? product.subcategory,
      category: product.category as ProductCategory,
      status: (overlay?.lifecycle_status as Product['status']) ?? product.status,
      isNew: overlay?.is_new ?? product.isNew,
      rating: overlay?.rating ?? product.rating,
      reviewsCount: overlay?.reviews_count ?? product.reviewsCount,
      warranty: overlay?.warranty_text ?? product.warranty,
      warrantyInfo: overlay ? buildWarrantyInfo(overlay, product.warrantyInfo) : product.warrantyInfo,
      specifications: liveSpecs && Object.keys(liveSpecs).length > 0 ? liveSpecs : product.specifications,
      images: liveImages && liveImages.length > 0 ? liveImages : product.images,
      price: livePrice ?? product.price,
      isVipPrice: livePrice !== undefined && livePriceIsVip,
      stock: overlay?.stock ?? product.stock,
      variants,
    })
  }

  // ---------------------------------------------------------------------------
  // Products that exist ONLY in the database.
  // ---------------------------------------------------------------------------
  // This is the half that makes the admin panel's "Add Product" real: without
  // it the loop above could only ever emit things that were compiled into the
  // app, so a product created after the build was invisible no matter how
  // complete its rows were.
  //
  // A product is included when it is active AND a price resolves for it. The
  // price condition is the existing house rule, not a new one — the 54 unpriced
  // replacement parts are seeded inactive for the same reason. Showing a
  // customer "Rs. 0" because an administrator saved a product before setting
  // its price would be worse than not listing it yet, and the admin Products
  // screen flags exactly which rows are held back for this reason.
  // ---------------------------------------------------------------------------
  const bundledIds = new Set(staticProducts.map((p) => p.id))
  const fromDatabase: { product: Product; sortOrder: number }[] = []

  for (const [id, overlay] of live.product) {
    if (bundledIds.has(id)) continue

    const productPrice = resolveTierPrice(live.productPrice.get(id), live.tier)
    const variantPrices = (live.variants.get(id) ?? [])
      .map((v) => live.variantPrice.get(`${id}:${v.legacyKey}`))
      .map((prices) => ({ price: resolveTierPrice(prices, live.tier), isVip: isVipTierPrice(prices, live.tier) }))
      .filter((entry): entry is { price: number; isVip: boolean } => entry.price !== undefined)

    // Cheapest variant price stands in as the product price when only variants
    // are priced, which mirrors displayPrice() on the storefront.
    const cheapest = variantPrices.reduce<{ price: number; isVip: boolean } | undefined>(
      (min, entry) => (min === undefined || entry.price < min.price ? entry : min),
      undefined,
    )
    const price = productPrice ?? cheapest?.price
    if (price === undefined) continue
    const priceIsVip = productPrice !== undefined
      ? isVipTierPrice(live.productPrice.get(id), live.tier)
      : Boolean(cheapest?.isVip)

    fromDatabase.push({ product: buildProductFromLive(id, overlay, live, price, priceIsVip), sortOrder: overlay.sort_order })
  }

  fromDatabase.sort((a, b) => a.sortOrder - b.sortOrder || a.product.name.localeCompare(b.product.name))
  for (const entry of fromDatabase) merged.push(entry.product)

  return merged.map((p) => withItemData(p, live))
}

/**
 * Attaches condition, warranty plans and variant photos — the per-item data —
 * to a built product, following the same rules as place_order():
 *
 *   - each variant gets ITS OWN condition row (none = Brand New), its own
 *     warranty override if any, and its own photos;
 *   - only a product WITHOUT variants gets a product-level condition; a product
 *     with variants never does, so nothing can present one variant's condition
 *     as the product's;
 *   - the product carries its default warranty plan.
 *
 * Until the extras have loaded, no condition or plan is attached at all.
 */
function withItemData(product: Product, live: LiveCatalogData): Product {
  const { extras } = live
  const hasVariants = (product.variants?.length ?? 0) > 0

  const variants = product.variants?.map((variant): ProductVariant => {
    const key = `${product.id}:${variant.id}`
    const own = live.variantImages.get(key)
    const item = extras.conditions.get(key)
    return {
      ...variant,
      ...(own && own.length > 0 && { images: own }),
      ...(extras.loaded && {
        condition: item?.condition ?? 'brand_new',
        preOwned: item?.preOwned,
        warrantyPlan: extras.plans.get(key),
      }),
    }
  })

  const productItem = extras.conditions.get(product.id)
  // A card needs an image: when nothing is shared, show a variant's own photo.
  const fallback = product.images.length === 0 ? variants?.find((v) => v.images?.length)?.images : undefined

  return {
    ...product,
    variants,
    sharedImages: product.images,
    images: fallback ?? product.images,
    ...(extras.loaded && { warrantyPlan: extras.plans.get(product.id) }),
    ...(extras.loaded && !hasVariants && {
      condition: productItem?.condition ?? 'brand_new',
      preOwned: productItem?.preOwned,
    }),
  }
}

/**
 * Resolves featured ids to products, in curated order.
 *
 * Ids are resolved against the catalog, so the two duplicated ids
 * (iphone-17-pro-max, macbook-pro-16) yield the authoritative deviceData
 * definitions. An id that no longer resolves — unpublished, or removed from the
 * bundle — is skipped rather than rendering a gap.
 */
export function resolveFeatured(
  products: readonly Product[],
  featuredIds: readonly string[],
): Product[] {
  const byId = new Map(products.map((p) => [p.id, p]))
  const resolved: Product[] = []
  for (const id of featuredIds) {
    const product = byId.get(id)
    if (product) resolved.push(product)
  }
  return resolved
}
