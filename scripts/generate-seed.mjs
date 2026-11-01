#!/usr/bin/env node
/**
 * Apple Expert - reproducible catalog seed generator.
 *
 *   node scripts/generate-seed.mjs
 *
 * Compiles the existing static catalog modules to plain JS in a temp directory,
 * imports them, and writes supabase/seed.sql. The catalog is never retyped by
 * hand, so the seeded rows are provably identical to what the app ships today.
 *
 * Rules enforced here (all of them business decisions already approved):
 *
 *   - deviceData.ts is authoritative for the two duplicate ids
 *     (iphone-17-pro-max, macbook-pro-16). The mockData definitions are dropped.
 *   - The 54 generated replacement parts are seeded is_active = false with NO
 *     price rows, because their source values (379 / 119 / 69 ...) are almost
 *     certainly USD and are awaiting business confirmation. Nothing is converted.
 *   - Prices are bigint minor units: rupees * 100.
 *   - Only the retail tier is seeded. wholesale_vip rows are left for the owner
 *     to set through the admin panel; until then VIP falls back to retail.
 *   - Every seeded price uses min_qty = 1.
 *   - The seed is re-runnable: catalog rows upsert, and a price row is only
 *     inserted when no live price already exists, so an admin's price change is
 *     never clobbered by re-seeding.
 */

import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, '..');
const outDir = mkdtempSync(path.join(tmpdir(), 'apple-expert-seed-'));

// ---------------------------------------------------------------------------
// 1. Compile the catalog modules. Type-only imports ('@/types') are elided by
//    TypeScript, so the emitted JS has no unresolvable requires at runtime.
// ---------------------------------------------------------------------------
console.log('Compiling catalog modules ->', outDir);
execFileSync(
  process.execPath,
  [
    path.join(projectRoot, 'node_modules', 'typescript', 'bin', 'tsc'),
    '-p', path.join(scriptDir, 'tsconfig.seed.json'),
    '--outDir', outDir,
  ],
  { stdio: 'inherit', cwd: projectRoot },
);

const require = createRequire(import.meta.url);
const { allDevices } = require(path.join(outDir, 'data', 'deviceData.js'));
const { products: mockProducts } = require(path.join(outDir, 'data', 'mockData.js'));
const { iphoneModels } = require(path.join(outDir, 'data', 'iphoneModels.js'));
const categoryMeta = require(path.join(outDir, 'data', 'categoryMeta.js'));
const { buildPartProduct } = require(path.join(outDir, 'lib', 'partProduct.js'));

const { categorySlugToName, categorySubtitle, categoryHeroCopy, categorySlugFromName } = categoryMeta;

// ---------------------------------------------------------------------------
// 2. SQL helpers
// ---------------------------------------------------------------------------
const lit = (v) => (v === null || v === undefined || v === '' ? 'null' : `'${String(v).replace(/'/g, "''")}'`);
const litReq = (v) => `'${String(v ?? '').replace(/'/g, "''")}'`;
const num = (v) => (v === null || v === undefined || Number.isNaN(v) ? 'null' : String(v));
const bool = (v) => (v ? 'true' : 'false');
/** Rupees -> bigint minor units. Integer arithmetic only; never a float. */
const toCents = (rupees) => {
  if (typeof rupees !== 'number' || !Number.isFinite(rupees)) {
    throw new Error(`Non-numeric price: ${rupees}`);
  }
  return Math.round(rupees * 100);
};

const out = [];
const S = (s) => out.push(s);

// ---------------------------------------------------------------------------
// 3. Assemble the catalog exactly as the app does today
// ---------------------------------------------------------------------------
// deviceData first, mockData only where it does not collide. This is the same
// precedence the running app uses in product/[id], search and wishlist.
const deviceIds = new Set(allDevices.map((p) => p.id));
const shadowed = mockProducts.filter((p) => deviceIds.has(p.id)).map((p) => p.id);
const catalogProducts = [...allDevices, ...mockProducts.filter((p) => !deviceIds.has(p.id))];

// The 54 generated replacement parts - identity and specs only, no prices.
const generatedParts = [];
for (const model of iphoneModels) {
  for (const kind of ['display', 'battery']) {
    generatedParts.push({ product: buildPartProduct(model, kind), modelId: model.id, kind });
  }
}

const PENDING_PRICE = new Set(generatedParts.map((g) => g.product.id));
const allProducts = [...catalogProducts, ...generatedParts.map((g) => g.product)];

// ---------------------------------------------------------------------------
// 4. Header
// ---------------------------------------------------------------------------
S(`-- ===========================================================================
-- Apple Expert - catalog seed
-- GENERATED FILE - do not edit by hand.
-- Regenerate with:  node scripts/generate-seed.mjs
--
-- Source of truth: src/data/deviceData.ts, src/data/mockData.ts,
--                  src/data/iphoneModels.ts, src/data/categoryMeta.ts
--
-- Money is bigint minor units (rupees * 100).
-- Only the retail tier is seeded; wholesale_vip is set by the owner in the
-- admin panel and falls back to retail until then.
-- ===========================================================================

begin;
`);

// ---------------------------------------------------------------------------
// 5. categories - preserve the existing route slugs
// ---------------------------------------------------------------------------
const categoryImages = {
  iphone: '/images/categories/iphone.jpg',
  ipad: '/images/categories/ipad.jpg',
  mac: '/images/categories/mac.jpg',
  watch: '/images/categories/apple-watch.jpg',
  airpods: '/images/categories/airpods.jpg',
  parts: '/images/categories/replacement-parts.jpg',
  accessories: '/images/categories/accessories.jpg',
  displays: '/images/categories/replacement-parts.jpg',
  batteries: '/images/categories/replacement-parts.jpg',
};
const topLevelSlugs = Object.keys(categorySlugToName);   // iphone..accessories
const childSlugs = [
  { slug: 'displays', name: 'Displays', parent: 'parts' },
  { slug: 'batteries', name: 'Batteries', parent: 'parts' },
];

S('-- ---------- categories ----------');
topLevelSlugs.forEach((slug, i) => {
  const hero = categoryHeroCopy[slug] || {};
  S(`insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values (${litReq(slug)}, ${litReq(categorySlugToName[slug])}, ${lit(categorySubtitle[slug])}, ${lit(hero.eyebrow)}, ${lit(hero.headline)}, ${lit(hero.blurb)}, ${lit(categoryImages[slug])}, ${i + 1}, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;`);
});
childSlugs.forEach((c, i) => {
  const hero = categoryHeroCopy[c.slug] || {};
  S(`insert into public.categories (slug, name, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
select ${litReq(c.slug)}, ${litReq(c.name)}, ${lit(hero.eyebrow)}, ${lit(hero.headline)}, ${lit(hero.blurb)}, ${lit(categoryImages[c.slug])}, ${100 + i}, p.id
from public.categories p where p.slug = ${litReq(c.parent)}
on conflict (slug) do update set
  name = excluded.name, hero_eyebrow = excluded.hero_eyebrow,
  hero_headline = excluded.hero_headline, hero_blurb = excluded.hero_blurb,
  image_path = excluded.image_path, sort_order = excluded.sort_order,
  parent_id = excluded.parent_id;`);
});
S('');

// ---------------------------------------------------------------------------
// 6. device_models
// ---------------------------------------------------------------------------
S('-- ---------- device_models ----------');
iphoneModels.forEach((m, i) => {
  const series = (m.name.match(/iPhone\s+(\d+)/) || [])[1];
  S(`insert into public.device_models (id, name, series, image_path, sort_order)
values (${litReq(m.id)}, ${litReq(m.name)}, ${lit(series ? `iPhone ${series}` : null)}, ${lit(m.image)}, ${i + 1})
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;`);
});
S('');

// ---------------------------------------------------------------------------
// 7. products
// ---------------------------------------------------------------------------
S('-- ---------- products ----------');
allProducts.forEach((p, i) => {
  const slug = categorySlugFromName(p.category);
  const w = p.warrantyInfo || {};
  const isActive = !PENDING_PRICE.has(p.id);
  S(`insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select ${litReq(p.id)}, ${litReq(p.name)}, c.id, ${litReq(p.subcategory)}, ${lit(p.model)},
  ${litReq(p.description)}, ${num(p.stock ?? 0)}, ${num(p.rating)}, ${num(p.reviewsCount ?? 0)},
  ${lit(p.warranty)}, ${lit(w.status)}, ${lit(w.duration)}, ${num(w.months)}, ${lit(w.coverage)},
  ${lit(p.status)}, ${bool(p.isNew)}, ${bool(isActive)}, ${i + 1}
from public.categories c where c.slug = ${litReq(slug)}
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;`);
});
S('');

// ---------------------------------------------------------------------------
// 8. product_variants
// ---------------------------------------------------------------------------
S('-- ---------- product_variants ----------');
let variantCount = 0;
allProducts.forEach((p) => {
  (p.variants || []).forEach((v, i) => {
    variantCount++;
    S(`insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values (${litReq(p.id)}, ${litReq(v.id)}, ${litReq(v.name)}, ${lit(v.color)}, ${lit(v.colorCode)}, ${lit(v.storage)}, ${i + 1})
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;`);
  });
});
S('');

// ---------------------------------------------------------------------------
// 9. product_images / product_specs / product_compatibility
//    Derived from source data, so they are replaced wholesale on re-seed.
// ---------------------------------------------------------------------------
const seededIds = allProducts.map((p) => litReq(p.id)).join(', ');
S('-- ---------- product_images / specs / compatibility (replaced on re-seed) ----------');
S(`delete from public.product_images        where product_id in (${seededIds});`);
S(`delete from public.product_specs         where product_id in (${seededIds});`);
S(`delete from public.product_compatibility where product_id in (${seededIds});`);
S('');

let imageCount = 0, specCount = 0, compatCount = 0;
allProducts.forEach((p) => {
  (p.images || []).forEach((src, i) => {
    imageCount++;
    S(`insert into public.product_images (product_id, path, alt, position, is_primary)
values (${litReq(p.id)}, ${litReq(src)}, ${litReq(p.name)}, ${i}, ${bool(i === 0)});`);
  });
  // Object key order is the render order the UI relies on, so position records it.
  Object.entries(p.specifications || {}).forEach(([label, value], i) => {
    specCount++;
    S(`insert into public.product_specs (product_id, label, value, position)
values (${litReq(p.id)}, ${litReq(label)}, ${litReq(value)}, ${i});`);
  });
});

// Compatibility: generated parts resolve to a real device_model; free-text
// entries keep their label with device_model_id left NULL.
const partById = new Map(generatedParts.map((g) => [g.product.id, g]));
allProducts.forEach((p) => {
  (p.compatibility || []).forEach((label, i) => {
    compatCount++;
    const g = partById.get(p.id);
    if (g) {
      S(`insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values (${litReq(p.id)}, ${litReq(g.modelId)}, ${litReq(label)}, ${litReq(g.kind)}, ${i});`);
    } else {
      S(`insert into public.product_compatibility (product_id, device_model_id, label, position)
values (${litReq(p.id)}, null, ${litReq(label)}, ${i});`);
    }
  });
});
S('');

// ---------------------------------------------------------------------------
// 10. product_prices - retail only, min_qty = 1
// ---------------------------------------------------------------------------
// The `not exists` guard means re-running the seed never overwrites a price an
// admin has since changed through admin_set_price().
// ---------------------------------------------------------------------------
S('-- ---------- product_prices (retail, min_qty = 1) ----------');
let productPriceRows = 0, variantPriceRows = 0;
const pendingProducts = [];

allProducts.forEach((p) => {
  if (PENDING_PRICE.has(p.id)) { pendingProducts.push(p.id); return; }

  productPriceRows++;
  S(`insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select ${litReq(p.id)}, null, 'retail', ${toCents(p.price)}, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = ${litReq(p.id)} and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);`);

  (p.variants || []).forEach((v) => {
    variantPriceRows++;
    S(`insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select ${litReq(p.id)}, v.id, 'retail', ${toCents(v.price)}, 1
from public.product_variants v
where v.product_id = ${litReq(p.id)} and v.legacy_key = ${litReq(v.id)}
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);`);
  });
});
S('');

// ---------------------------------------------------------------------------
// 11. featured_products - preserve the current homepage selection
// ---------------------------------------------------------------------------
// The homepage carousel reads mockData's `featured` flag today, so that list is
// the selection to preserve. The two duplicate ids resolve to the authoritative
// deviceData product, which is automatic here because ids are shared.
// ---------------------------------------------------------------------------
const featuredIds = mockProducts.filter((p) => p.featured).map((p) => p.id);
S('-- ---------- featured_products (slot: home) ----------');
featuredIds.forEach((id, i) => {
  S(`insert into public.featured_products (slot, product_id, position)
values ('home', ${litReq(id)}, ${i + 1})
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;`);
});
S('');

// ---------------------------------------------------------------------------
// 11b. Derived condition / warranty rows
// ---------------------------------------------------------------------------
// Migrations 20261002120000 and 20261003120000 derive these from the products
// that exist when they run. In production the products were already there; in
// a fresh local database the migrations run BEFORE this seed, against an empty
// catalog, so the same derivations are applied here. Each statement mirrors its
// migration exactly and is idempotent, so re-seeding never duplicates a row.
// Products WITH variants get no condition rows: a variant with no row is Brand
// New, which is what every bundled variant is.
// ---------------------------------------------------------------------------
// Same trap as below: these two migration updates find no categories locally.
S('-- ---------- category tracking rules (mirror migrations 20261028120000, 20261101100000 + 20261101140000) ----------');
S(`update public.categories set requires_serial = true where slug = 'iphone';`);
S(`update public.categories set default_tracking_mode = 'unit' where slug in ('iphone', 'ipad', 'mac', 'watch', 'airpods');`);
S(`update public.categories set allows_shared_barcode = true where slug in ('accessories', 'parts', 'batteries', 'displays');`);
S('-- ---------- derived condition / warranty rows (mirror migrations 20261002120000 + 20261003120000) ----------');
S(`update public.products
   set warranty_type = case when warranty_status = 'active' then 'included' else 'none' end
 where warranty_type is distinct from case when warranty_status = 'active' then 'included' else 'none' end;`);
S(`insert into public.product_warranty_plans
  (product_id, variant_id, warranty_type, warranty_duration, warranty_months,
   warranty_title, warranty_description, warranty_covered, warranty_excluded)
select p.id, null, p.warranty_type, p.warranty_duration, p.warranty_months,
       p.warranty_title, p.warranty_description, p.warranty_covered, p.warranty_excluded
from public.products p
on conflict (product_id, variant_id) do nothing;`);
S(`insert into public.product_conditions
  (product_id, variant_id, condition, condition_grade_id, battery_health, cycle_count,
   physical_condition, accessories_included, device_notes)
select p.id, null, p.condition, p.condition_grade_id, p.battery_health, p.cycle_count,
       p.physical_condition, p.accessories_included, p.device_notes
from public.products p
where not exists (select 1 from public.product_variants v where v.product_id = p.id)
on conflict (product_id, variant_id) do nothing;`);
S('');
S('commit;');
S('');

// ---------------------------------------------------------------------------
// 12. Write + summary
// ---------------------------------------------------------------------------
mkdirSync(path.join(projectRoot, 'supabase'), { recursive: true });
const target = path.join(projectRoot, 'supabase', 'seed.sql');
writeFileSync(target, out.join('\n'));
rmSync(outDir, { recursive: true, force: true });

const summary = {
  categories: topLevelSlugs.length + childSlugs.length,
  device_models: iphoneModels.length,
  products_total: allProducts.length,
  products_from_deviceData: allDevices.length,
  products_from_mockData: catalogProducts.length - allDevices.length,
  products_generated_parts: generatedParts.length,
  duplicate_ids_dropped_from_mockData: shadowed,
  product_variants: variantCount,
  product_images: imageCount,
  product_specs: specCount,
  product_compatibility: compatCount,
  price_rows_retail_product_level: productPriceRows,
  price_rows_retail_variant_level: variantPriceRows,
  price_rows_total: productPriceRows + variantPriceRows,
  price_rows_wholesale_vip: 0,
  products_pending_price: pendingProducts.length,
  featured_products: featuredIds.length,
};

console.log('\nWrote', path.relative(projectRoot, target));
console.log(JSON.stringify(summary, null, 2));
writeFileSync(
  path.join(projectRoot, 'supabase', 'seed-summary.json'),
  JSON.stringify({ generatedAt: new Date().toISOString(), ...summary, pendingProducts }, null, 2),
);
