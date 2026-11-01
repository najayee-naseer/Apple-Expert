-- ===========================================================================
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

-- ---------- categories ----------
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('iphone', 'iPhone', 'All iPhone models', 'Apple iPhone', 'Discover the iPhone', 'The complete iPhone lineup, from everyday performance to Pro power.', '/images/categories/iphone.jpg', 1, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('ipad', 'iPad', 'All iPad models', 'Apple iPad', 'Discover iPad', 'Powerful, portable, and ready for anything you create.', '/images/categories/ipad.jpg', 2, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('mac', 'Mac', 'All Mac models', 'Apple Mac', 'Discover Mac', 'Laptops and desktops built for speed, power and everyday work.', '/images/categories/mac.jpg', 3, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('watch', 'Apple Watch', 'Apple Watch collection', 'Apple Watch', 'Discover Apple Watch', 'Your health, fitness and connectivity — right on your wrist.', '/images/categories/apple-watch.jpg', 4, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('airpods', 'AirPods', 'AirPods collection', 'Apple AirPods', 'Discover AirPods', 'Immersive sound and a seamless connection to every Apple device.', '/images/categories/airpods.jpg', 5, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('parts', 'Replacement Parts', 'Genuine Apple replacement parts', 'Genuine Parts', 'Replacement Parts', 'Quality displays, batteries and components for every repair.', '/images/categories/replacement-parts.jpg', 6, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, subtitle, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
values ('accessories', 'Accessories', 'Apple accessories & cables', 'Apple Expert', 'Accessories', 'Cases, chargers, cables and everything else you need.', '/images/categories/accessories.jpg', 7, null)
on conflict (slug) do update set
  name = excluded.name, subtitle = excluded.subtitle,
  hero_eyebrow = excluded.hero_eyebrow, hero_headline = excluded.hero_headline,
  hero_blurb = excluded.hero_blurb, image_path = excluded.image_path,
  sort_order = excluded.sort_order;
insert into public.categories (slug, name, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
select 'displays', 'Displays', 'Genuine Displays', 'iPhone Displays', 'Sharp, true-to-life replacement screens for every iPhone.', '/images/categories/replacement-parts.jpg', 100, p.id
from public.categories p where p.slug = 'parts'
on conflict (slug) do update set
  name = excluded.name, hero_eyebrow = excluded.hero_eyebrow,
  hero_headline = excluded.hero_headline, hero_blurb = excluded.hero_blurb,
  image_path = excluded.image_path, sort_order = excluded.sort_order,
  parent_id = excluded.parent_id;
insert into public.categories (slug, name, hero_eyebrow, hero_headline, hero_blurb, image_path, sort_order, parent_id)
select 'batteries', 'Batteries', 'Genuine Batteries', 'iPhone Batteries', 'Restore full-day battery life with a genuine replacement.', '/images/categories/replacement-parts.jpg', 101, p.id
from public.categories p where p.slug = 'parts'
on conflict (slug) do update set
  name = excluded.name, hero_eyebrow = excluded.hero_eyebrow,
  hero_headline = excluded.hero_headline, hero_blurb = excluded.hero_blurb,
  image_path = excluded.image_path, sort_order = excluded.sort_order,
  parent_id = excluded.parent_id;

-- ---------- device_models ----------
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-17-pro-max', 'iPhone 17 Pro Max', 'iPhone 17', '/images/products/iphone/iphone-17-pro-max.jpg', 1)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-17-pro', 'iPhone 17 Pro', 'iPhone 17', '/images/products/iphone/iphone-17-pro.jpg', 2)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-air', 'iPhone Air', null, '/images/products/iphone/iphone-air.jpg', 3)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-17', 'iPhone 17', 'iPhone 17', '/images/products/iphone/iphone-17.jpg', 4)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-16-pro-max', 'iPhone 16 Pro Max', 'iPhone 16', '/images/products/iphone/iphone-16-pro-max.jpg', 5)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-16-pro', 'iPhone 16 Pro', 'iPhone 16', '/images/products/iphone/iphone-16-pro.jpg', 6)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-16-plus', 'iPhone 16 Plus', 'iPhone 16', '/images/products/iphone/iphone-16-plus.jpg', 7)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-16', 'iPhone 16', 'iPhone 16', '/images/products/iphone/iphone-16.jpg', 8)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-15-pro-max', 'iPhone 15 Pro Max', 'iPhone 15', '/images/products/iphone/iphone-15-pro-max.jpg', 9)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-15-pro', 'iPhone 15 Pro', 'iPhone 15', '/images/products/iphone/iphone-15-pro.jpg', 10)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-15-plus', 'iPhone 15 Plus', 'iPhone 15', '/images/products/iphone/iphone-15-plus.jpg', 11)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-15', 'iPhone 15', 'iPhone 15', '/images/products/iphone/iphone-15.jpg', 12)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-14-pro-max', 'iPhone 14 Pro Max', 'iPhone 14', '/images/products/iphone/iphone-14-pro-max.jpg', 13)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-14-pro', 'iPhone 14 Pro', 'iPhone 14', '/images/products/iphone/iphone-14-pro.jpg', 14)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-14-plus', 'iPhone 14 Plus', 'iPhone 14', '/images/products/iphone/iphone-14-plus.jpg', 15)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-14', 'iPhone 14', 'iPhone 14', '/images/products/iphone/iphone-14.jpg', 16)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-13-pro-max', 'iPhone 13 Pro Max', 'iPhone 13', '/images/products/iphone/iphone-13-pro-max.jpg', 17)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-13-pro', 'iPhone 13 Pro', 'iPhone 13', '/images/products/iphone/iphone-13-pro.jpg', 18)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-13', 'iPhone 13', 'iPhone 13', '/images/products/iphone/iphone-13.jpg', 19)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-13-mini', 'iPhone 13 mini', 'iPhone 13', '/images/products/iphone/iphone-13-mini.jpg', 20)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-12-pro-max', 'iPhone 12 Pro Max', 'iPhone 12', '/images/products/iphone/iphone-12-pro-max.jpg', 21)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-12-pro', 'iPhone 12 Pro', 'iPhone 12', '/images/products/iphone/iphone-12-pro.jpg', 22)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-12', 'iPhone 12', 'iPhone 12', '/images/products/iphone/iphone-12.jpg', 23)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-12-mini', 'iPhone 12 mini', 'iPhone 12', '/images/products/iphone/iphone-12-mini.jpg', 24)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-11-pro-max', 'iPhone 11 Pro Max', 'iPhone 11', '/images/products/iphone/iphone-11-pro-max.jpg', 25)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-11-pro', 'iPhone 11 Pro', 'iPhone 11', '/images/products/iphone/iphone-11-pro.jpg', 26)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;
insert into public.device_models (id, name, series, image_path, sort_order)
values ('iphone-11', 'iPhone 11', 'iPhone 11', '/images/products/iphone/iphone-11.jpg', 27)
on conflict (id) do update set
  name = excluded.name, series = excluded.series,
  image_path = excluded.image_path, sort_order = excluded.sort_order;

-- ---------- products ----------
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-17-pro-max', 'iPhone 17 Pro Max', c.id, 'Devices', 'iPhone 17 Pro Max',
  'The most powerful iPhone ever. Forged in titanium with the groundbreaking A19 Pro chip and the most advanced camera system.', 50, 4.9, 1284,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 1
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-17-pro', 'iPhone 17 Pro', c.id, 'Devices', 'iPhone 17 Pro',
  'Titanium. ProMotion. Pro camera. The iPhone 17 Pro is a powerhouse in a refined, lightweight chassis.', 45, 4.9, 876,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 2
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-air', 'iPhone Air', c.id, 'Devices', 'iPhone Air',
  'The thinnest iPhone ever. iPhone Air brings a bold new form factor — impossibly light, remarkably powerful.', 40, 4.8, 412,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 3
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-17', 'iPhone 17', c.id, 'Devices', 'iPhone 17',
  'A new design, updated cameras, and a 48MP camera system. iPhone 17 sets the new standard.', 60, 4.8, 521,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 4
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-17e', 'iPhone 17e', c.id, 'Devices', 'iPhone 17e',
  'Powerful performance at an approachable price. iPhone 17e packs the A16 chip and a serious camera.', 80, 4.7, 328,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 5
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-16-pro-max', 'iPhone 16 Pro Max', c.id, 'Devices', 'iPhone 16 Pro Max',
  'The biggest Pro display. The most powerful chip. iPhone 16 Pro Max with A18 Pro and titanium design.', 30, 4.9, 2341,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 6
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-16-pro', 'iPhone 16 Pro', c.id, 'Devices', 'iPhone 16 Pro',
  'iPhone 16 Pro. Titanium. A18 Pro chip. Camera Control. The most powerful iPhone Pro.', 35, 4.8, 1893,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 7
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-16-plus', 'iPhone 16 Plus', c.id, 'Devices', 'iPhone 16 Plus',
  'Big screen, big battery. iPhone 16 Plus with a 6.7" display and up to 27 hours battery life.', 40, 4.7, 956,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 8
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-16', 'iPhone 16', c.id, 'Devices', 'iPhone 16',
  'Built for Apple Intelligence. iPhone 16 with Camera Control and the powerful A18 chip.', 55, 4.8, 1521,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 9
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-16e', 'iPhone 16e', c.id, 'Devices', 'iPhone 16e',
  'Serious performance, serious value. iPhone 16e with A16 Bionic and Apple Intelligence.', 90, 4.7, 876,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 10
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-15-pro-max', 'iPhone 15 Pro Max', c.id, 'Devices', 'iPhone 15 Pro Max',
  'iPhone 15 Pro Max with titanium design, A17 Pro chip, and the world''s first 5× Telephoto.', 25, 4.9, 4821,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 11
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-15-pro', 'iPhone 15 Pro', c.id, 'Devices', 'iPhone 15 Pro',
  'Titanium frame. A17 Pro chip. iPhone 15 Pro redefined what Pro means.', 20, 4.9, 6234,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 12
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-15-plus', 'iPhone 15 Plus', c.id, 'Devices', 'iPhone 15 Plus',
  'iPhone 15 Plus. Big screen, long-lasting battery and a 48MP camera.', 30, 4.7, 2145,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 13
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-15', 'iPhone 15', c.id, 'Devices', 'iPhone 15',
  'Dynamic Island. 48MP camera. USB-C. iPhone 15 raises the bar.', 40, 4.8, 7821,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 14
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-14-pro-max', 'iPhone 14 Pro Max', c.id, 'Devices', 'iPhone 14 Pro Max',
  'Dynamic Island introduced. A16 Bionic with Always-On display.', 15, 4.8, 9231,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 15
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-14-pro', 'iPhone 14 Pro', c.id, 'Devices', 'iPhone 14 Pro',
  'The Pro that started Dynamic Island. A16 Bionic chip with the best iPhone camera system.', 20, 4.8, 11023,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 16
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-14-plus', 'iPhone 14 Plus', c.id, 'Devices', 'iPhone 14 Plus',
  'Big screen, great battery. iPhone 14 Plus with a 6.7" display.', 25, 4.6, 3412,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 17
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-14', 'iPhone 14', c.id, 'Devices', 'iPhone 14',
  'Crash Detection. Emergency SOS via satellite. 12MP dual camera.', 35, 4.7, 13002,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 18
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-13-pro-max', 'iPhone 13 Pro Max', c.id, 'Devices', 'iPhone 13 Pro Max',
  'ProMotion on a Pro Max for the first time. A15 Bionic with incredible battery life.', 20, 4.8, 8734,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 19
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-13-pro', 'iPhone 13 Pro', c.id, 'Devices', 'iPhone 13 Pro',
  'ProMotion display, 1TB storage, macro photography. iPhone 13 Pro.', 22, 4.8, 9827,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 20
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-13-mini', 'iPhone 13 mini', c.id, 'Devices', 'iPhone 13 mini',
  'All the power of A15 Bionic in the most compact iPhone. Perfect for one-handed use.', 18, 4.7, 5823,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 21
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-13', 'iPhone 13', c.id, 'Devices', 'iPhone 13',
  'A15 Bionic, a 12MP dual camera with bigger sensors, and up to 19 hours battery.', 30, 4.7, 18430,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 22
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-12-pro-max', 'iPhone 12 Pro Max', c.id, 'Devices', 'iPhone 12 Pro Max',
  'The biggest Pro ever at launch. 5G, OLED, and the first Pro Max triple camera.', 15, 4.7, 9231,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 23
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-12-pro', 'iPhone 12 Pro', c.id, 'Devices', 'iPhone 12 Pro',
  'iPhone 12 Pro with 5G, LiDAR Scanner, and a polished surgical-grade stainless steel design.', 18, 4.7, 10823,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 24
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-12-mini', 'iPhone 12 mini', c.id, 'Devices', 'iPhone 12 mini',
  'The smallest 5G iPhone with the A14 Bionic and an OLED display.', 12, 4.6, 4521,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 25
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-12', 'iPhone 12', c.id, 'Devices', 'iPhone 12',
  '5G on iPhone for the first time. OLED display, A14 Bionic, and the Ceramic Shield.', 25, 4.7, 22102,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 26
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-11-pro-max', 'iPhone 11 Pro Max', c.id, 'Devices', 'iPhone 11 Pro Max',
  'iPhone 11 Pro Max with Super Retina XDR OLED and the first triple camera system.', 12, 4.7, 8932,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 27
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-11-pro', 'iPhone 11 Pro', c.id, 'Devices', 'iPhone 11 Pro',
  'The original triple camera Pro. Matte glass back, A13 Bionic, Super Retina XDR.', 14, 4.6, 7123,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 28
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'iphone-11', 'iPhone 11', c.id, 'Devices', 'iPhone 11',
  'Liquid Retina HD display, wide dual camera, A13 Bionic chip. Still a great iPhone.', 20, 4.6, 31204,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'OLDER', false, true, 29
from public.categories c where c.slug = 'iphone'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-pro-13-m5', 'iPad Pro 13-inch (M5)', c.id, 'Devices', 'iPad Pro 13-inch',
  'The ultimate iPad. M5 chip, Ultra Retina XDR OLED display, and Apple Pencil Pro support.', 25, 4.9, 892,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 30
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-pro-11-m5', 'iPad Pro 11-inch (M5)', c.id, 'Devices', 'iPad Pro 11-inch',
  'Thin and light with M5 chip and Ultra Retina XDR OLED display. Pro in every way.', 30, 4.9, 734,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 31
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-air-13-m4', 'iPad Air 13-inch (M4)', c.id, 'Devices', 'iPad Air 13-inch',
  'The biggest Air ever. M4 chip, stunning 13" Liquid Retina display, and Apple Pencil Pro.', 35, 4.8, 512,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 32
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-air-11-m4', 'iPad Air 11-inch (M4)', c.id, 'Devices', 'iPad Air 11-inch',
  'Powerfully capable. Impossibly thin. iPad Air 11" with M4 and a gorgeous Liquid Retina display.', 40, 4.8, 823,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 33
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-a16', 'iPad (A16)', c.id, 'Devices', 'iPad 11-inch',
  'The most popular iPad, now with A16 chip, Apple Intelligence, and a 11-inch Liquid Retina display.', 70, 4.8, 1823,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 34
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'ipad-mini-a17-pro', 'iPad mini (A17 Pro)', c.id, 'Devices', 'iPad mini',
  'Mighty and compact. iPad mini with A17 Pro chip and Apple Intelligence in the palm of your hand.', 45, 4.8, 1012,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 35
from public.categories c where c.slug = 'ipad'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'macbook-neo', 'MacBook Neo', c.id, 'Devices', 'MacBook Neo',
  'The next chapter in Mac portables. MacBook Neo delivers M5 power in a revolutionary new design.', 20, 4.9, 241,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'NEW', true, true, 36
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'macbook-air-15', 'MacBook Air 15-inch', c.id, 'Devices', 'MacBook Air 15-inch',
  'Big screen. Thin design. All-day battery. MacBook Air 15-inch with M4 chip.', 30, 4.8, 1532,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 37
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'macbook-air-13', 'MacBook Air 13-inch', c.id, 'Devices', 'MacBook Air 13-inch',
  'Strikingly thin. Incredibly capable. MacBook Air with M4 and the world''s best 13" laptop display.', 40, 4.8, 3821,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 38
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'macbook-pro-16', 'MacBook Pro 16-inch', c.id, 'Devices', 'MacBook Pro 16-inch',
  'Mind-blowing performance. MacBook Pro 16" with M4 Max and a stunning Liquid Retina XDR display.', 20, 4.9, 2341,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 39
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'macbook-pro-14', 'MacBook Pro 14-inch', c.id, 'Devices', 'MacBook Pro 14-inch',
  'Incredibly powerful. The compact Pro for creators and professionals. M4 Pro chip.', 25, 4.9, 1923,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 40
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'imac-m5', 'iMac', c.id, 'Devices', 'iMac',
  'Stunning all-in-one. The iMac with M5 chip, 24" 4.5K Retina display, and slim colorful design.', 20, 4.8, 1341,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 41
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'mac-mini-m5', 'Mac mini', c.id, 'Devices', 'Mac mini',
  'Small footprint, powerful M5 chip. Mac mini fits anywhere and powers everything.', 35, 4.9, 2123,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 42
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'mac-studio-m5', 'Mac Studio', c.id, 'Devices', 'Mac Studio',
  'Unprecedented power in an impossibly compact design. Mac Studio with M5 Max or M5 Ultra.', 15, 4.9, 892,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 43
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'mac-pro-m5', 'Mac Pro', c.id, 'Devices', 'Mac Pro',
  'For the most demanding workflows. Mac Pro with M5 Ultra and extreme expandability.', 5, 4.9, 412,
  '1 Year Apple Limited Warranty', 'active', '1 Year', 12, 'Hardware defects under normal use.',
  'CURRENT', false, true, 44
from public.categories c where c.slug = 'mac'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'airpods-pro-2', 'AirPods Pro (2nd generation)', c.id, 'Devices', 'AirPods Pro',
  'Reengineered for richer audio, up to 2x more Active Noise Cancellation, and Adaptive Transparency.', 150, 4.9, 4231,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 45
from public.categories c where c.slug = 'airpods'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'apple-watch-ultra-2', 'Apple Watch Ultra 2', c.id, 'Devices', 'Apple Watch Ultra',
  'The most rugged and capable Apple Watch pushes the limits again. Featuring the all-new S9 SiP.', 35, 4.7, 932,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 46
from public.categories c where c.slug = 'watch'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-iphone-15-pro-display', 'OLED Display Assembly', c.id, 'Displays', 'iPhone 15 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 15 Pro. Includes display, digitizer, and front glass.', 12, 5, 24,
  '90 Days Part Warranty', null, null, null, null,
  null, false, true, 47
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-iphone-15-pro-battery', 'Replacement Battery Kit', c.id, 'Batteries', 'iPhone 15 Pro',
  'Genuine replacement battery for iPhone 15 Pro. Restores factory battery life and performance.', 45, 4.8, 112,
  '1 Year Part Warranty', null, null, null, null,
  null, false, true, 48
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'acc-magsafe-charger', 'MagSafe Charger', c.id, 'MagSafe', null,
  'The MagSafe Charger makes wireless charging a snap. The perfectly aligned magnets attach to your iPhone.', 200, 4.6, 840,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 49
from public.categories c where c.slug = 'accessories'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-macbook-pro-14-display', 'Liquid Retina XDR Display Assembly', c.id, 'Displays', 'MacBook Pro 14"',
  'Complete display assembly for the 14-inch MacBook Pro. Includes the aluminum housing, LCD panel, and camera module.', 4, 4.9, 15,
  '90 Days Part Warranty', null, null, null, null,
  null, false, true, 50
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'acc-iphone-15-case', 'iPhone 15 Pro Silicone Case with MagSafe', c.id, 'iPhone Cases', null,
  'Designed by Apple to complement iPhone 15 Pro, the Silicone Case with MagSafe is a delightful way to protect your iPhone.', 120, 4.8, 345,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 51
from public.categories c where c.slug = 'accessories'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'acc-usbc-cable-60w', '60W USB-C Charge Cable (1m)', c.id, 'USB-C Cables', null,
  'This 1-meter charge cable is made with a woven design — with USB-C connectors on both ends.', 500, 4.9, 1289,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 52
from public.categories c where c.slug = 'accessories'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'acc-power-adapter-20w', '20W USB-C Power Adapter', c.id, 'Power Adapters', null,
  'The Apple 20W USB‑C Power Adapter offers fast, efficient charging at home, in the office, or on the go.', 450, 4.9, 3210,
  '1 Year Apple Limited Warranty', null, null, null, null,
  null, false, true, 53
from public.categories c where c.slug = 'accessories'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-17-pro-max', 'iPhone 17 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 17 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 17 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 54
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-17-pro-max', 'iPhone 17 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 17 Pro Max',
  'Genuine replacement battery for iPhone 17 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 55
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-17-pro', 'iPhone 17 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 17 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 17 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 56
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-17-pro', 'iPhone 17 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 17 Pro',
  'Genuine replacement battery for iPhone 17 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 57
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-air', 'iPhone Air OLED Display Assembly', c.id, 'Displays', 'iPhone Air',
  'Genuine Apple OLED Display Assembly replacement for iPhone Air. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 58
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-air', 'iPhone Air Replacement Battery Kit', c.id, 'Batteries', 'iPhone Air',
  'Genuine replacement battery for iPhone Air. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 59
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-17', 'iPhone 17 OLED Display Assembly', c.id, 'Displays', 'iPhone 17',
  'Genuine Apple OLED Display Assembly replacement for iPhone 17. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 60
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-17', 'iPhone 17 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 17',
  'Genuine replacement battery for iPhone 17. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 61
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-16-pro-max', 'iPhone 16 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 16 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 16 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 62
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-16-pro-max', 'iPhone 16 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 16 Pro Max',
  'Genuine replacement battery for iPhone 16 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 63
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-16-pro', 'iPhone 16 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 16 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 16 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 64
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-16-pro', 'iPhone 16 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 16 Pro',
  'Genuine replacement battery for iPhone 16 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 65
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-16-plus', 'iPhone 16 Plus OLED Display Assembly', c.id, 'Displays', 'iPhone 16 Plus',
  'Genuine Apple OLED Display Assembly replacement for iPhone 16 Plus. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 66
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-16-plus', 'iPhone 16 Plus Replacement Battery Kit', c.id, 'Batteries', 'iPhone 16 Plus',
  'Genuine replacement battery for iPhone 16 Plus. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 67
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-16', 'iPhone 16 OLED Display Assembly', c.id, 'Displays', 'iPhone 16',
  'Genuine Apple OLED Display Assembly replacement for iPhone 16. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 68
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-16', 'iPhone 16 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 16',
  'Genuine replacement battery for iPhone 16. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 69
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-15-pro-max', 'iPhone 15 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 15 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 15 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 70
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-15-pro-max', 'iPhone 15 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 15 Pro Max',
  'Genuine replacement battery for iPhone 15 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 71
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-15-pro', 'iPhone 15 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 15 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 15 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 72
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-15-pro', 'iPhone 15 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 15 Pro',
  'Genuine replacement battery for iPhone 15 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 73
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-15-plus', 'iPhone 15 Plus OLED Display Assembly', c.id, 'Displays', 'iPhone 15 Plus',
  'Genuine Apple OLED Display Assembly replacement for iPhone 15 Plus. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 74
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-15-plus', 'iPhone 15 Plus Replacement Battery Kit', c.id, 'Batteries', 'iPhone 15 Plus',
  'Genuine replacement battery for iPhone 15 Plus. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 75
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-15', 'iPhone 15 OLED Display Assembly', c.id, 'Displays', 'iPhone 15',
  'Genuine Apple OLED Display Assembly replacement for iPhone 15. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 76
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-15', 'iPhone 15 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 15',
  'Genuine replacement battery for iPhone 15. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 77
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-14-pro-max', 'iPhone 14 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 14 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 14 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 78
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-14-pro-max', 'iPhone 14 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 14 Pro Max',
  'Genuine replacement battery for iPhone 14 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 79
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-14-pro', 'iPhone 14 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 14 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 14 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 80
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-14-pro', 'iPhone 14 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 14 Pro',
  'Genuine replacement battery for iPhone 14 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 81
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-14-plus', 'iPhone 14 Plus OLED Display Assembly', c.id, 'Displays', 'iPhone 14 Plus',
  'Genuine Apple OLED Display Assembly replacement for iPhone 14 Plus. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 82
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-14-plus', 'iPhone 14 Plus Replacement Battery Kit', c.id, 'Batteries', 'iPhone 14 Plus',
  'Genuine replacement battery for iPhone 14 Plus. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 83
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-14', 'iPhone 14 OLED Display Assembly', c.id, 'Displays', 'iPhone 14',
  'Genuine Apple OLED Display Assembly replacement for iPhone 14. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 84
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-14', 'iPhone 14 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 14',
  'Genuine replacement battery for iPhone 14. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 85
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-13-pro-max', 'iPhone 13 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 13 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 13 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 86
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-13-pro-max', 'iPhone 13 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 13 Pro Max',
  'Genuine replacement battery for iPhone 13 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 87
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-13-pro', 'iPhone 13 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 13 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 13 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 88
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-13-pro', 'iPhone 13 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 13 Pro',
  'Genuine replacement battery for iPhone 13 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 89
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-13', 'iPhone 13 OLED Display Assembly', c.id, 'Displays', 'iPhone 13',
  'Genuine Apple OLED Display Assembly replacement for iPhone 13. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 90
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-13', 'iPhone 13 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 13',
  'Genuine replacement battery for iPhone 13. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 91
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-13-mini', 'iPhone 13 mini OLED Display Assembly', c.id, 'Displays', 'iPhone 13 mini',
  'Genuine Apple OLED Display Assembly replacement for iPhone 13 mini. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 92
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-13-mini', 'iPhone 13 mini Replacement Battery Kit', c.id, 'Batteries', 'iPhone 13 mini',
  'Genuine replacement battery for iPhone 13 mini. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 93
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-12-pro-max', 'iPhone 12 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 12 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 12 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 94
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-12-pro-max', 'iPhone 12 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 12 Pro Max',
  'Genuine replacement battery for iPhone 12 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 95
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-12-pro', 'iPhone 12 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 12 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 12 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 96
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-12-pro', 'iPhone 12 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 12 Pro',
  'Genuine replacement battery for iPhone 12 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 97
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-12', 'iPhone 12 OLED Display Assembly', c.id, 'Displays', 'iPhone 12',
  'Genuine Apple OLED Display Assembly replacement for iPhone 12. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 98
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-12', 'iPhone 12 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 12',
  'Genuine replacement battery for iPhone 12. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 99
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-12-mini', 'iPhone 12 mini OLED Display Assembly', c.id, 'Displays', 'iPhone 12 mini',
  'Genuine Apple OLED Display Assembly replacement for iPhone 12 mini. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 100
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-12-mini', 'iPhone 12 mini Replacement Battery Kit', c.id, 'Batteries', 'iPhone 12 mini',
  'Genuine replacement battery for iPhone 12 mini. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 101
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-11-pro-max', 'iPhone 11 Pro Max OLED Display Assembly', c.id, 'Displays', 'iPhone 11 Pro Max',
  'Genuine Apple OLED Display Assembly replacement for iPhone 11 Pro Max. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 102
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-11-pro-max', 'iPhone 11 Pro Max Replacement Battery Kit', c.id, 'Batteries', 'iPhone 11 Pro Max',
  'Genuine replacement battery for iPhone 11 Pro Max. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 103
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-11-pro', 'iPhone 11 Pro OLED Display Assembly', c.id, 'Displays', 'iPhone 11 Pro',
  'Genuine Apple OLED Display Assembly replacement for iPhone 11 Pro. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 104
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-11-pro', 'iPhone 11 Pro Replacement Battery Kit', c.id, 'Batteries', 'iPhone 11 Pro',
  'Genuine replacement battery for iPhone 11 Pro. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 105
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-display-iphone-11', 'iPhone 11 LCD Display Assembly', c.id, 'Displays', 'iPhone 11',
  'Genuine Apple LCD Display Assembly replacement for iPhone 11. Includes display, digitizer, and front glass.', 10, 4.9, 12,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 106
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;
insert into public.products (
  id, name, category_id, subcategory, model, description, stock, rating, reviews_count,
  warranty_text, warranty_status, warranty_duration, warranty_months, warranty_coverage,
  lifecycle_status, is_new, is_active, sort_order)
select 'part-battery-iphone-11', 'iPhone 11 Replacement Battery Kit', c.id, 'Batteries', 'iPhone 11',
  'Genuine replacement battery for iPhone 11. Restores factory battery life and performance.', 20, 4.8, 24,
  '6-Month Replacement Warranty', null, null, null, null,
  null, false, false, 107
from public.categories c where c.slug = 'parts'
on conflict (id) do update set
  name = excluded.name, category_id = excluded.category_id,
  subcategory = excluded.subcategory, model = excluded.model,
  description = excluded.description, stock = excluded.stock,
  rating = excluded.rating, reviews_count = excluded.reviews_count,
  warranty_text = excluded.warranty_text, warranty_status = excluded.warranty_status,
  warranty_duration = excluded.warranty_duration, warranty_months = excluded.warranty_months,
  warranty_coverage = excluded.warranty_coverage,
  lifecycle_status = excluded.lifecycle_status, is_new = excluded.is_new,
  is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------- product_variants ----------
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro-max', 'v1', 'Natural Titanium 256GB', 'Natural Titanium', '#B8B3A9', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro-max', 'v2', 'Black Titanium 256GB', 'Black Titanium', '#4B4C4F', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro-max', 'v3', 'Natural Titanium 512GB', 'Natural Titanium', '#B8B3A9', '512GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro-max', 'v4', 'Natural Titanium 1TB', 'Natural Titanium', '#B8B3A9', '1TB', 4)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro', 'v1', 'Natural Titanium 256GB', 'Natural Titanium', '#B8B3A9', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro', 'v2', 'Desert Titanium 256GB', 'Desert Titanium', '#C9A882', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17-pro', 'v3', 'Natural Titanium 512GB', 'Natural Titanium', '#B8B3A9', '512GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-air', 'v1', 'Starlight 128GB', 'Starlight', '#F5F4EF', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-air', 'v2', 'Midnight 128GB', 'Midnight', '#2C2C2E', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-air', 'v3', 'Starlight 256GB', 'Starlight', '#F5F4EF', '256GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17', 'v2', 'White 128GB', 'White', '#F5F5F7', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17', 'v3', 'Ultramarine 128GB', 'Ultramarine', '#4B6CB7', '128GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17', 'v4', 'Black 256GB', 'Black', '#1C1C1E', '256GB', 4)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17e', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17e', 'v2', 'Starlight 128GB', 'Starlight', '#F5F4EF', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-17e', 'v3', 'Black 256GB', 'Black', '#1C1C1E', '256GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-pro-max', 'v1', 'Black Titanium 256GB', 'Black Titanium', '#4B4C4F', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-pro-max', 'v2', 'Desert Titanium 256GB', 'Desert Titanium', '#C9A882', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-pro-max', 'v3', 'Black Titanium 512GB', 'Black Titanium', '#4B4C4F', '512GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-pro', 'v1', 'Black Titanium 128GB', 'Black Titanium', '#4B4C4F', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-pro', 'v2', 'White Titanium 128GB', 'White Titanium', '#E8E4DC', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-plus', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16-plus', 'v2', 'Teal 128GB', 'Teal', '#5DA89F', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16', 'v2', 'Ultramarine 128GB', 'Ultramarine', '#4B6CB7', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16', 'v3', 'Teal 128GB', 'Teal', '#5DA89F', '128GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16e', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-16e', 'v2', 'White 128GB', 'White', '#F5F5F7', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-15-pro-max', 'v1', 'Black Titanium 256GB', 'Black Titanium', '#4B4C4F', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-15-pro-max', 'v2', 'Natural Titanium 256GB', 'Natural Titanium', '#B8B3A9', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-15-pro', 'v1', 'Black Titanium 128GB', 'Black Titanium', '#4B4C4F', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-15', 'v1', 'Black 128GB', 'Black', '#1C1C1E', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('iphone-15', 'v2', 'Blue 128GB', 'Blue', '#4B6CB7', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-pro-13-m5', 'v1', 'Space Black 256GB Wi-Fi', 'Space Black', '#2C2C2E', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-pro-13-m5', 'v2', 'Silver 256GB Wi-Fi', 'Silver', '#E3E4E5', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-pro-13-m5', 'v3', 'Space Black 512GB Wi-Fi', 'Space Black', '#2C2C2E', '512GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-pro-11-m5', 'v1', 'Space Black 256GB Wi-Fi', 'Space Black', '#2C2C2E', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-pro-11-m5', 'v2', 'Silver 256GB Wi-Fi', 'Silver', '#E3E4E5', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-air-13-m4', 'v1', 'Blue 128GB Wi-Fi', 'Blue', '#4B6CB7', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-air-13-m4', 'v2', 'Starlight 128GB Wi-Fi', 'Starlight', '#F5F4EF', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-air-11-m4', 'v1', 'Blue 128GB Wi-Fi', 'Blue', '#4B6CB7', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-air-11-m4', 'v2', 'Purple 128GB Wi-Fi', 'Purple', '#7B68B8', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-a16', 'v1', 'Blue 128GB Wi-Fi', 'Blue', '#4B6CB7', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-a16', 'v2', 'Pink 128GB Wi-Fi', 'Pink', '#F2A7B0', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-a16', 'v3', 'Yellow 128GB Wi-Fi', 'Yellow', '#F5D76E', '128GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-mini-a17-pro', 'v1', 'Starlight 128GB Wi-Fi', 'Starlight', '#F5F4EF', '128GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-mini-a17-pro', 'v2', 'Midnight 128GB Wi-Fi', 'Midnight', '#2C2C2E', '128GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('ipad-mini-a17-pro', 'v3', 'Purple 128GB Wi-Fi', 'Purple', '#7B68B8', '128GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-neo', 'v1', 'Midnight M5 16GB 512GB', 'Midnight', '#2C2C2E', '512GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-neo', 'v2', 'Starlight M5 16GB 512GB', 'Starlight', '#F5F4EF', '512GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-neo', 'v3', 'Midnight M5 24GB 1TB', 'Midnight', '#2C2C2E', '1TB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-air-15', 'v1', 'Midnight M4 16GB 256GB', 'Midnight', '#2C2C2E', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-air-15', 'v2', 'Starlight M4 16GB 256GB', 'Starlight', '#F5F4EF', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-air-15', 'v3', 'Sky Blue M4 16GB 256GB', 'Sky Blue', '#87C5E5', '256GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-air-13', 'v1', 'Midnight M4 16GB 256GB', 'Midnight', '#2C2C2E', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-air-13', 'v2', 'Starlight M4 16GB 256GB', 'Starlight', '#F5F4EF', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-pro-16', 'v1', 'Space Black M4 Pro 24GB 512GB', 'Space Black', '#2E2E2E', '512GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-pro-16', 'v2', 'Silver M4 Pro 24GB 512GB', 'Silver', '#E3E4E5', '512GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-pro-14', 'v1', 'Space Black M4 Pro 24GB 512GB', 'Space Black', '#2E2E2E', '512GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('macbook-pro-14', 'v2', 'Silver M4 Pro 24GB 512GB', 'Silver', '#E3E4E5', '512GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('imac-m5', 'v1', 'Blue M5 16GB 256GB', 'Blue', '#4B6CB7', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('imac-m5', 'v2', 'Purple M5 16GB 256GB', 'Purple', '#7B68B8', '256GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('imac-m5', 'v3', 'Green M5 16GB 256GB', 'Green', '#5A9E6F', '256GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-mini-m5', 'v1', 'M5 16GB 256GB', 'Silver', '#E3E4E5', '256GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-mini-m5', 'v2', 'M5 16GB 512GB', 'Silver', '#E3E4E5', '512GB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-mini-m5', 'v3', 'M5 Pro 24GB 512GB', 'Silver', '#E3E4E5', '512GB', 3)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-studio-m5', 'v1', 'M5 Max 36GB 512GB', 'Silver', '#E3E4E5', '512GB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-studio-m5', 'v2', 'M5 Ultra 96GB 1TB', 'Silver', '#E3E4E5', '1TB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-pro-m5', 'v1', 'Tower 192GB 1TB', 'Silver', '#E3E4E5', '1TB', 1)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;
insert into public.product_variants (product_id, legacy_key, name, color, color_code, storage, sort_order)
values ('mac-pro-m5', 'v2', 'Rack 192GB 1TB', 'Silver', '#E3E4E5', '1TB', 2)
on conflict (product_id, legacy_key) do update set
  name = excluded.name, color = excluded.color, color_code = excluded.color_code,
  storage = excluded.storage, sort_order = excluded.sort_order;

-- ---------- product_images / specs / compatibility (replaced on re-seed) ----------
delete from public.product_images        where product_id in ('iphone-17-pro-max', 'iphone-17-pro', 'iphone-air', 'iphone-17', 'iphone-17e', 'iphone-16-pro-max', 'iphone-16-pro', 'iphone-16-plus', 'iphone-16', 'iphone-16e', 'iphone-15-pro-max', 'iphone-15-pro', 'iphone-15-plus', 'iphone-15', 'iphone-14-pro-max', 'iphone-14-pro', 'iphone-14-plus', 'iphone-14', 'iphone-13-pro-max', 'iphone-13-pro', 'iphone-13-mini', 'iphone-13', 'iphone-12-pro-max', 'iphone-12-pro', 'iphone-12-mini', 'iphone-12', 'iphone-11-pro-max', 'iphone-11-pro', 'iphone-11', 'ipad-pro-13-m5', 'ipad-pro-11-m5', 'ipad-air-13-m4', 'ipad-air-11-m4', 'ipad-a16', 'ipad-mini-a17-pro', 'macbook-neo', 'macbook-air-15', 'macbook-air-13', 'macbook-pro-16', 'macbook-pro-14', 'imac-m5', 'mac-mini-m5', 'mac-studio-m5', 'mac-pro-m5', 'airpods-pro-2', 'apple-watch-ultra-2', 'part-iphone-15-pro-display', 'part-iphone-15-pro-battery', 'acc-magsafe-charger', 'part-macbook-pro-14-display', 'acc-iphone-15-case', 'acc-usbc-cable-60w', 'acc-power-adapter-20w', 'part-display-iphone-17-pro-max', 'part-battery-iphone-17-pro-max', 'part-display-iphone-17-pro', 'part-battery-iphone-17-pro', 'part-display-iphone-air', 'part-battery-iphone-air', 'part-display-iphone-17', 'part-battery-iphone-17', 'part-display-iphone-16-pro-max', 'part-battery-iphone-16-pro-max', 'part-display-iphone-16-pro', 'part-battery-iphone-16-pro', 'part-display-iphone-16-plus', 'part-battery-iphone-16-plus', 'part-display-iphone-16', 'part-battery-iphone-16', 'part-display-iphone-15-pro-max', 'part-battery-iphone-15-pro-max', 'part-display-iphone-15-pro', 'part-battery-iphone-15-pro', 'part-display-iphone-15-plus', 'part-battery-iphone-15-plus', 'part-display-iphone-15', 'part-battery-iphone-15', 'part-display-iphone-14-pro-max', 'part-battery-iphone-14-pro-max', 'part-display-iphone-14-pro', 'part-battery-iphone-14-pro', 'part-display-iphone-14-plus', 'part-battery-iphone-14-plus', 'part-display-iphone-14', 'part-battery-iphone-14', 'part-display-iphone-13-pro-max', 'part-battery-iphone-13-pro-max', 'part-display-iphone-13-pro', 'part-battery-iphone-13-pro', 'part-display-iphone-13', 'part-battery-iphone-13', 'part-display-iphone-13-mini', 'part-battery-iphone-13-mini', 'part-display-iphone-12-pro-max', 'part-battery-iphone-12-pro-max', 'part-display-iphone-12-pro', 'part-battery-iphone-12-pro', 'part-display-iphone-12', 'part-battery-iphone-12', 'part-display-iphone-12-mini', 'part-battery-iphone-12-mini', 'part-display-iphone-11-pro-max', 'part-battery-iphone-11-pro-max', 'part-display-iphone-11-pro', 'part-battery-iphone-11-pro', 'part-display-iphone-11', 'part-battery-iphone-11');
delete from public.product_specs         where product_id in ('iphone-17-pro-max', 'iphone-17-pro', 'iphone-air', 'iphone-17', 'iphone-17e', 'iphone-16-pro-max', 'iphone-16-pro', 'iphone-16-plus', 'iphone-16', 'iphone-16e', 'iphone-15-pro-max', 'iphone-15-pro', 'iphone-15-plus', 'iphone-15', 'iphone-14-pro-max', 'iphone-14-pro', 'iphone-14-plus', 'iphone-14', 'iphone-13-pro-max', 'iphone-13-pro', 'iphone-13-mini', 'iphone-13', 'iphone-12-pro-max', 'iphone-12-pro', 'iphone-12-mini', 'iphone-12', 'iphone-11-pro-max', 'iphone-11-pro', 'iphone-11', 'ipad-pro-13-m5', 'ipad-pro-11-m5', 'ipad-air-13-m4', 'ipad-air-11-m4', 'ipad-a16', 'ipad-mini-a17-pro', 'macbook-neo', 'macbook-air-15', 'macbook-air-13', 'macbook-pro-16', 'macbook-pro-14', 'imac-m5', 'mac-mini-m5', 'mac-studio-m5', 'mac-pro-m5', 'airpods-pro-2', 'apple-watch-ultra-2', 'part-iphone-15-pro-display', 'part-iphone-15-pro-battery', 'acc-magsafe-charger', 'part-macbook-pro-14-display', 'acc-iphone-15-case', 'acc-usbc-cable-60w', 'acc-power-adapter-20w', 'part-display-iphone-17-pro-max', 'part-battery-iphone-17-pro-max', 'part-display-iphone-17-pro', 'part-battery-iphone-17-pro', 'part-display-iphone-air', 'part-battery-iphone-air', 'part-display-iphone-17', 'part-battery-iphone-17', 'part-display-iphone-16-pro-max', 'part-battery-iphone-16-pro-max', 'part-display-iphone-16-pro', 'part-battery-iphone-16-pro', 'part-display-iphone-16-plus', 'part-battery-iphone-16-plus', 'part-display-iphone-16', 'part-battery-iphone-16', 'part-display-iphone-15-pro-max', 'part-battery-iphone-15-pro-max', 'part-display-iphone-15-pro', 'part-battery-iphone-15-pro', 'part-display-iphone-15-plus', 'part-battery-iphone-15-plus', 'part-display-iphone-15', 'part-battery-iphone-15', 'part-display-iphone-14-pro-max', 'part-battery-iphone-14-pro-max', 'part-display-iphone-14-pro', 'part-battery-iphone-14-pro', 'part-display-iphone-14-plus', 'part-battery-iphone-14-plus', 'part-display-iphone-14', 'part-battery-iphone-14', 'part-display-iphone-13-pro-max', 'part-battery-iphone-13-pro-max', 'part-display-iphone-13-pro', 'part-battery-iphone-13-pro', 'part-display-iphone-13', 'part-battery-iphone-13', 'part-display-iphone-13-mini', 'part-battery-iphone-13-mini', 'part-display-iphone-12-pro-max', 'part-battery-iphone-12-pro-max', 'part-display-iphone-12-pro', 'part-battery-iphone-12-pro', 'part-display-iphone-12', 'part-battery-iphone-12', 'part-display-iphone-12-mini', 'part-battery-iphone-12-mini', 'part-display-iphone-11-pro-max', 'part-battery-iphone-11-pro-max', 'part-display-iphone-11-pro', 'part-battery-iphone-11-pro', 'part-display-iphone-11', 'part-battery-iphone-11');
delete from public.product_compatibility where product_id in ('iphone-17-pro-max', 'iphone-17-pro', 'iphone-air', 'iphone-17', 'iphone-17e', 'iphone-16-pro-max', 'iphone-16-pro', 'iphone-16-plus', 'iphone-16', 'iphone-16e', 'iphone-15-pro-max', 'iphone-15-pro', 'iphone-15-plus', 'iphone-15', 'iphone-14-pro-max', 'iphone-14-pro', 'iphone-14-plus', 'iphone-14', 'iphone-13-pro-max', 'iphone-13-pro', 'iphone-13-mini', 'iphone-13', 'iphone-12-pro-max', 'iphone-12-pro', 'iphone-12-mini', 'iphone-12', 'iphone-11-pro-max', 'iphone-11-pro', 'iphone-11', 'ipad-pro-13-m5', 'ipad-pro-11-m5', 'ipad-air-13-m4', 'ipad-air-11-m4', 'ipad-a16', 'ipad-mini-a17-pro', 'macbook-neo', 'macbook-air-15', 'macbook-air-13', 'macbook-pro-16', 'macbook-pro-14', 'imac-m5', 'mac-mini-m5', 'mac-studio-m5', 'mac-pro-m5', 'airpods-pro-2', 'apple-watch-ultra-2', 'part-iphone-15-pro-display', 'part-iphone-15-pro-battery', 'acc-magsafe-charger', 'part-macbook-pro-14-display', 'acc-iphone-15-case', 'acc-usbc-cable-60w', 'acc-power-adapter-20w', 'part-display-iphone-17-pro-max', 'part-battery-iphone-17-pro-max', 'part-display-iphone-17-pro', 'part-battery-iphone-17-pro', 'part-display-iphone-air', 'part-battery-iphone-air', 'part-display-iphone-17', 'part-battery-iphone-17', 'part-display-iphone-16-pro-max', 'part-battery-iphone-16-pro-max', 'part-display-iphone-16-pro', 'part-battery-iphone-16-pro', 'part-display-iphone-16-plus', 'part-battery-iphone-16-plus', 'part-display-iphone-16', 'part-battery-iphone-16', 'part-display-iphone-15-pro-max', 'part-battery-iphone-15-pro-max', 'part-display-iphone-15-pro', 'part-battery-iphone-15-pro', 'part-display-iphone-15-plus', 'part-battery-iphone-15-plus', 'part-display-iphone-15', 'part-battery-iphone-15', 'part-display-iphone-14-pro-max', 'part-battery-iphone-14-pro-max', 'part-display-iphone-14-pro', 'part-battery-iphone-14-pro', 'part-display-iphone-14-plus', 'part-battery-iphone-14-plus', 'part-display-iphone-14', 'part-battery-iphone-14', 'part-display-iphone-13-pro-max', 'part-battery-iphone-13-pro-max', 'part-display-iphone-13-pro', 'part-battery-iphone-13-pro', 'part-display-iphone-13', 'part-battery-iphone-13', 'part-display-iphone-13-mini', 'part-battery-iphone-13-mini', 'part-display-iphone-12-pro-max', 'part-battery-iphone-12-pro-max', 'part-display-iphone-12-pro', 'part-battery-iphone-12-pro', 'part-display-iphone-12', 'part-battery-iphone-12', 'part-display-iphone-12-mini', 'part-battery-iphone-12-mini', 'part-display-iphone-11-pro-max', 'part-battery-iphone-11-pro-max', 'part-display-iphone-11-pro', 'part-battery-iphone-11-pro', 'part-display-iphone-11', 'part-battery-iphone-11');

insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-17-pro-max', '/images/products/iphone/iphone-17-pro-max.jpg', 'iPhone 17 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro-max', 'Display', '6.9" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro-max', 'Chip', 'A19 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro-max', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 5× Telephoto', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro-max', 'Battery', 'Up to 33 hours video playback', 3);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro-max', 'Material', 'Titanium frame, matte glass back', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-17-pro', '/images/products/iphone/iphone-17-pro.jpg', 'iPhone 17 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro', 'Display', '6.3" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro', 'Chip', 'A19 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 5× Telephoto', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro', 'Battery', 'Up to 27 hours video playback', 3);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17-pro', 'Material', 'Titanium frame', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-air', '/images/products/iphone/iphone-air.jpg', 'iPhone Air', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-air', 'Display', '6.6" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-air', 'Chip', 'A18 chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-air', 'Camera', '48MP Main + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-air', 'Battery', 'Up to 22 hours video playback', 3);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-air', 'Thickness', '5.5mm — thinnest iPhone ever', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-17', '/images/products/iphone/iphone-17.jpg', 'iPhone 17', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17', 'Chip', 'A18 chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17', 'Camera', '48MP Main + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17', 'Battery', 'Up to 22 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-17e', '/images/products/iphone/iphone-17e.jpg', 'iPhone 17e', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17e', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17e', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17e', 'Camera', '48MP Main', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-17e', 'Battery', 'Up to 20 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-16-pro-max', '/images/products/iphone/iphone-16-pro-max.jpg', 'iPhone 16 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro-max', 'Display', '6.9" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro-max', 'Chip', 'A18 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro-max', 'Camera', '48MP Fusion + 48MP Ultra Wide + 12MP 5× Telephoto', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro-max', 'Battery', 'Up to 33 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-16-pro', '/images/products/iphone/iphone-16-pro.jpg', 'iPhone 16 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro', 'Display', '6.3" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro', 'Chip', 'A18 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro', 'Camera', '48MP Fusion + 48MP Ultra Wide + 12MP 5× Telephoto', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-pro', 'Battery', 'Up to 27 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-16-plus', '/images/products/iphone/iphone-16-plus.jpg', 'iPhone 16 Plus', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-plus', 'Display', '6.7" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-plus', 'Chip', 'A18 chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-plus', 'Camera', '48MP Fusion + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16-plus', 'Battery', 'Up to 27 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-16', '/images/products/iphone/iphone-16.jpg', 'iPhone 16', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16', 'Chip', 'A18 chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16', 'Camera', '48MP Fusion + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16', 'Battery', 'Up to 22 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-16e', '/images/products/iphone/iphone-16e.jpg', 'iPhone 16e', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16e', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16e', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16e', 'Camera', '48MP Main', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-16e', 'Battery', 'Up to 26 hours video playback', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-15-pro-max', '/images/products/iphone/iphone-15-pro-max.jpg', 'iPhone 15 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro-max', 'Display', '6.7" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro-max', 'Chip', 'A17 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro-max', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 5× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-15-pro', '/images/products/iphone/iphone-15-pro.jpg', 'iPhone 15 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro', 'Display', '6.1" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro', 'Chip', 'A17 Pro chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-pro', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 3× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-15-plus', '/images/products/iphone/iphone-15-plus.jpg', 'iPhone 15 Plus', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-plus', 'Display', '6.7" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-plus', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15-plus', 'Camera', '48MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-15', '/images/products/iphone/iphone-15.jpg', 'iPhone 15', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-15', 'Camera', '48MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-14-pro-max', '/images/products/iphone/iphone-14-pro-max.jpg', 'iPhone 14 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro-max', 'Display', '6.7" Super Retina XDR OLED, ProMotion, Always-On', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro-max', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro-max', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 3× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-14-pro', '/images/products/iphone/iphone-14-pro.jpg', 'iPhone 14 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro', 'Display', '6.1" Super Retina XDR OLED, ProMotion, Always-On', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro', 'Chip', 'A16 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-pro', 'Camera', '48MP Main + 12MP Ultra Wide + 12MP 3× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-14-plus', '/images/products/iphone/iphone-14-plus.jpg', 'iPhone 14 Plus', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-plus', 'Display', '6.7" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-plus', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14-plus', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-14', '/images/products/iphone/iphone-14.jpg', 'iPhone 14', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-14', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-13-pro-max', '/images/products/iphone/iphone-13-pro-max.jpg', 'iPhone 13 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro-max', 'Display', '6.7" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro-max', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro-max', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 3× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-13-pro', '/images/products/iphone/iphone-13-pro.jpg', 'iPhone 13 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro', 'Display', '6.1" Super Retina XDR OLED, ProMotion', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-pro', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 3× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-13-mini', '/images/products/iphone/iphone-13-mini.jpg', 'iPhone 13 mini', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-mini', 'Display', '5.4" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-mini', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13-mini', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-13', '/images/products/iphone/iphone-13.jpg', 'iPhone 13', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13', 'Chip', 'A15 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-13', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-12-pro-max', '/images/products/iphone/iphone-12-pro-max.jpg', 'iPhone 12 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro-max', 'Display', '6.7" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro-max', 'Chip', 'A14 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro-max', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 2.5× Telephoto', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro-max', 'Connectivity', '5G', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-12-pro', '/images/products/iphone/iphone-12-pro.jpg', 'iPhone 12 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro', 'Chip', 'A14 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-pro', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 2× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-12-mini', '/images/products/iphone/iphone-12-mini.jpg', 'iPhone 12 mini', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-mini', 'Display', '5.4" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-mini', 'Chip', 'A14 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-mini', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12-mini', 'Connectivity', '5G', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-12', '/images/products/iphone/iphone-12.jpg', 'iPhone 12', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12', 'Display', '6.1" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12', 'Chip', 'A14 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-12', 'Connectivity', '5G', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-11-pro-max', '/images/products/iphone/iphone-11-pro-max.jpg', 'iPhone 11 Pro Max', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro-max', 'Display', '6.5" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro-max', 'Chip', 'A13 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro-max', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 2× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-11-pro', '/images/products/iphone/iphone-11-pro.jpg', 'iPhone 11 Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro', 'Display', '5.8" Super Retina XDR OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro', 'Chip', 'A13 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11-pro', 'Camera', '12MP Main + 12MP Ultra Wide + 12MP 2× Telephoto', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('iphone-11', '/images/products/iphone/iphone-11.jpg', 'iPhone 11', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11', 'Display', '6.1" Liquid Retina HD LCD', 0);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11', 'Chip', 'A13 Bionic', 1);
insert into public.product_specs (product_id, label, value, position)
values ('iphone-11', 'Camera', '12MP Main + 12MP Ultra Wide', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-pro-13-m5', '/images/products/ipad/ipad-pro-13.jpg', 'iPad Pro 13-inch (M5)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Display', '13" Ultra Retina XDR Tandem OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Chip', 'Apple M5', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Camera', '12MP Wide, 10MP Ultra Wide, LiDAR Scanner', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Storage', '256GB, 512GB, 1TB, 2TB', 3);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Apple Pencil', 'Apple Pencil Pro (USB-C)', 4);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-13-m5', 'Keyboard', 'Magic Keyboard for iPad Pro', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-pro-11-m5', '/images/products/ipad/ipad-pro-11.jpg', 'iPad Pro 11-inch (M5)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-11-m5', 'Display', '11" Ultra Retina XDR Tandem OLED', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-11-m5', 'Chip', 'Apple M5', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-11-m5', 'Camera', '12MP Wide, 10MP Ultra Wide, LiDAR Scanner', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-11-m5', 'Storage', '256GB, 512GB, 1TB, 2TB', 3);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-pro-11-m5', 'Apple Pencil', 'Apple Pencil Pro (USB-C)', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-air-13-m4', '/images/products/ipad/ipad-air-13.jpg', 'iPad Air 13-inch (M4)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-13-m4', 'Display', '13" Liquid Retina IPS', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-13-m4', 'Chip', 'Apple M4', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-13-m4', 'Camera', '12MP Wide, 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-13-m4', 'Storage', '128GB, 256GB, 512GB, 1TB', 3);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-13-m4', 'Apple Pencil', 'Apple Pencil Pro', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-air-11-m4', '/images/products/ipad/ipad-air-11.jpg', 'iPad Air 11-inch (M4)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-11-m4', 'Display', '11" Liquid Retina IPS', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-11-m4', 'Chip', 'Apple M4', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-11-m4', 'Camera', '12MP Wide, 12MP Ultra Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-11-m4', 'Storage', '128GB, 256GB, 512GB', 3);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-air-11-m4', 'Apple Pencil', 'Apple Pencil Pro', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-a16', '/images/products/ipad/ipad-11.jpg', 'iPad (A16)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-a16', 'Display', '11" Liquid Retina IPS', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-a16', 'Chip', 'Apple A16', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-a16', 'Camera', '12MP Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-a16', 'Apple Pencil', 'Apple Pencil (USB-C)', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('ipad-mini-a17-pro', '/images/products/ipad/ipad-mini.jpg', 'iPad mini (A17 Pro)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-mini-a17-pro', 'Display', '8.3" Liquid Retina IPS', 0);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-mini-a17-pro', 'Chip', 'Apple A17 Pro', 1);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-mini-a17-pro', 'Camera', '12MP Wide', 2);
insert into public.product_specs (product_id, label, value, position)
values ('ipad-mini-a17-pro', 'Apple Pencil', 'Apple Pencil Pro', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('macbook-neo', '/images/products/mac/macbook-neo.jpg', 'MacBook Neo', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Display', '14.5" Liquid Retina display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Chip', 'Apple M5', 1);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Memory', '16GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Storage', '512GB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Battery', 'Up to 24 hours', 4);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-neo', 'Ports', '3× Thunderbolt 4, MagSafe 3, HDMI, SD', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('macbook-air-15', '/images/products/mac/macbook-air-15.jpg', 'MacBook Air 15-inch', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Display', '15.3" Liquid Retina display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Chip', 'Apple M4', 1);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Memory', '16GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Storage', '256GB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Battery', 'Up to 18 hours', 4);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-15', 'Ports', '2× Thunderbolt 4, MagSafe 3, 3.5mm jack', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('macbook-air-13', '/images/products/mac/macbook-air-13.jpg', 'MacBook Air 13-inch', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-13', 'Display', '13.6" Liquid Retina display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-13', 'Chip', 'Apple M4', 1);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-13', 'Memory', '16GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-13', 'Storage', '256GB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-air-13', 'Battery', 'Up to 18 hours', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('macbook-pro-16', '/images/products/mac/macbook-pro-16.jpg', 'MacBook Pro 16-inch', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-16', 'Display', '16.2" Liquid Retina XDR display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-16', 'Chip', 'Apple M4 Pro or M4 Max', 1);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-16', 'Memory', '24GB–128GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-16', 'Storage', 'Up to 8TB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-16', 'Battery', 'Up to 24 hours', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('macbook-pro-14', '/images/products/mac/macbook-pro-14.jpg', 'MacBook Pro 14-inch', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-14', 'Display', '14.2" Liquid Retina XDR display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-14', 'Chip', 'Apple M4 Pro or M4 Max', 1);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-14', 'Memory', '24GB–96GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-14', 'Storage', 'Up to 4TB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('macbook-pro-14', 'Battery', 'Up to 22 hours', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('imac-m5', '/images/products/mac/imac.jpg', 'iMac', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('imac-m5', 'Display', '24" 4.5K Retina display', 0);
insert into public.product_specs (product_id, label, value, position)
values ('imac-m5', 'Chip', 'Apple M5', 1);
insert into public.product_specs (product_id, label, value, position)
values ('imac-m5', 'Memory', '16GB–32GB unified memory', 2);
insert into public.product_specs (product_id, label, value, position)
values ('imac-m5', 'Storage', '256GB–2TB SSD', 3);
insert into public.product_specs (product_id, label, value, position)
values ('imac-m5', 'Camera', '12MP Center Stage', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('mac-mini-m5', '/images/products/mac/mac-mini.jpg', 'Mac mini', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('mac-mini-m5', 'Chip', 'Apple M5 or M5 Pro', 0);
insert into public.product_specs (product_id, label, value, position)
values ('mac-mini-m5', 'Memory', '16GB–64GB unified memory', 1);
insert into public.product_specs (product_id, label, value, position)
values ('mac-mini-m5', 'Storage', '256GB–2TB SSD', 2);
insert into public.product_specs (product_id, label, value, position)
values ('mac-mini-m5', 'Ports', '3× Thunderbolt 4, 2× USB-A, HDMI, Ethernet', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('mac-studio-m5', '/images/products/mac/mac-studio.jpg', 'Mac Studio', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('mac-studio-m5', 'Chip', 'Apple M5 Max or M5 Ultra', 0);
insert into public.product_specs (product_id, label, value, position)
values ('mac-studio-m5', 'Memory', '36GB–192GB unified memory', 1);
insert into public.product_specs (product_id, label, value, position)
values ('mac-studio-m5', 'Storage', '512GB–8TB SSD', 2);
insert into public.product_specs (product_id, label, value, position)
values ('mac-studio-m5', 'Ports', '6× Thunderbolt 5, 4× USB-A, HDMI, SD card', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('mac-pro-m5', '/images/products/mac/mac-pro.jpg', 'Mac Pro', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('mac-pro-m5', 'Chip', 'Apple M5 Ultra', 0);
insert into public.product_specs (product_id, label, value, position)
values ('mac-pro-m5', 'Memory', '192GB–512GB unified memory', 1);
insert into public.product_specs (product_id, label, value, position)
values ('mac-pro-m5', 'Storage', '1TB–8TB SSD', 2);
insert into public.product_specs (product_id, label, value, position)
values ('mac-pro-m5', 'Expansion', '6 PCIe expansion slots', 3);
insert into public.product_specs (product_id, label, value, position)
values ('mac-pro-m5', 'Ports', 'Thunderbolt 5, USB-A, HDMI 2.1, 10Gb Ethernet', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('airpods-pro-2', 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&q=80&w=800', 'AirPods Pro (2nd generation)', 0, true);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('airpods-pro-2', 'https://images.unsplash.com/photo-1608231387042-66d1773070a5?auto=format&fit=crop&q=80&w=800', 'AirPods Pro (2nd generation)', 1, false);
insert into public.product_specs (product_id, label, value, position)
values ('airpods-pro-2', 'Audio', 'Active Noise Cancellation, Adaptive Transparency', 0);
insert into public.product_specs (product_id, label, value, position)
values ('airpods-pro-2', 'Chip', 'H2 headphone chip', 1);
insert into public.product_specs (product_id, label, value, position)
values ('airpods-pro-2', 'Battery', 'Up to 6 hours of listening time', 2);
insert into public.product_specs (product_id, label, value, position)
values ('airpods-pro-2', 'Charging', 'MagSafe Charging Case (USB-C)', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('apple-watch-ultra-2', 'https://images.unsplash.com/photo-1664478546384-d57ffe74a78c?auto=format&fit=crop&q=80&w=800', 'Apple Watch Ultra 2', 0, true);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('apple-watch-ultra-2', 'https://images.unsplash.com/photo-1696446700622-48ec59a7ee1d?auto=format&fit=crop&q=80&w=800', 'Apple Watch Ultra 2', 1, false);
insert into public.product_specs (product_id, label, value, position)
values ('apple-watch-ultra-2', 'Display', 'Always-On Retina LTPO OLED, up to 3000 nits', 0);
insert into public.product_specs (product_id, label, value, position)
values ('apple-watch-ultra-2', 'Material', 'Aerospace-grade titanium', 1);
insert into public.product_specs (product_id, label, value, position)
values ('apple-watch-ultra-2', 'Water Resistance', '100m water resistant', 2);
insert into public.product_specs (product_id, label, value, position)
values ('apple-watch-ultra-2', 'Battery', 'Up to 36 hours', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-iphone-15-pro-display', '/images/products/iphone/iphone-15-pro.jpg', 'OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-display', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-display', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-display', 'Resolution', '2556x1179-pixel resolution at 460 ppi', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-display', 'Features', 'Dynamic Island, ProMotion, True Tone', 3);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-iphone-15-pro-battery', '/images/categories/replacement-parts.jpg', 'Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-battery', 'Capacity', '3274 mAh', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-battery', 'Type', 'Lithium-ion polymer', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-iphone-15-pro-battery', 'Condition', 'New (Genuine Apple)', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('acc-magsafe-charger', '/images/categories/accessories.jpg', 'MagSafe Charger', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('acc-magsafe-charger', 'Connector', 'USB-C', 0);
insert into public.product_specs (product_id, label, value, position)
values ('acc-magsafe-charger', 'Output', 'Up to 15W wireless charging', 1);
insert into public.product_specs (product_id, label, value, position)
values ('acc-magsafe-charger', 'Cable Length', '1m', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-macbook-pro-14-display', '/images/categories/mac.jpg', 'Liquid Retina XDR Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-macbook-pro-14-display', 'Part Type', 'Complete Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-macbook-pro-14-display', 'Color', 'Space Gray', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-macbook-pro-14-display', 'Resolution', '3024-by-1964 native resolution at 254 pixels per inch', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('acc-iphone-15-case', '/images/categories/accessories.jpg', 'iPhone 15 Pro Silicone Case with MagSafe', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('acc-iphone-15-case', 'Material', 'Silicone', 0);
insert into public.product_specs (product_id, label, value, position)
values ('acc-iphone-15-case', 'Features', 'MagSafe compatible, soft microfiber lining', 1);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('acc-usbc-cable-60w', '/images/categories/accessories.jpg', '60W USB-C Charge Cable (1m)', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('acc-usbc-cable-60w', 'Connector', 'USB-C to USB-C', 0);
insert into public.product_specs (product_id, label, value, position)
values ('acc-usbc-cable-60w', 'Length', '1 meter', 1);
insert into public.product_specs (product_id, label, value, position)
values ('acc-usbc-cable-60w', 'Power', 'Up to 60W', 2);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('acc-power-adapter-20w', '/images/categories/accessories.jpg', '20W USB-C Power Adapter', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('acc-power-adapter-20w', 'Port', 'USB-C', 0);
insert into public.product_specs (product_id, label, value, position)
values ('acc-power-adapter-20w', 'Power', '20W Fast Charging', 1);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-17-pro-max', '/images/products/iphone/iphone-17-pro-max.jpg', 'iPhone 17 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Compatibility', 'iPhone 17 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Size', '6.9-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Resolution', '2868 × 1320 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro-max', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-17-pro-max', '/images/products/iphone/iphone-17-pro-max.jpg', 'iPhone 17 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro-max', 'Compatibility', 'iPhone 17 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro-max', 'Capacity', '4676 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-17-pro', '/images/products/iphone/iphone-17-pro.jpg', 'iPhone 17 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Compatibility', 'iPhone 17 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Size', '6.3-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Resolution', '2622 × 1206 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17-pro', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-17-pro', '/images/products/iphone/iphone-17-pro.jpg', 'iPhone 17 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro', 'Compatibility', 'iPhone 17 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro', 'Capacity', '3577 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-air', '/images/products/iphone/iphone-air.jpg', 'iPhone Air OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Compatibility', 'iPhone Air', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Size', '6.6-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Resolution', '2740 × 1260 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-air', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-air', '/images/products/iphone/iphone-air.jpg', 'iPhone Air Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-air', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-air', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-air', 'Compatibility', 'iPhone Air', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-air', 'Capacity', '4000 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-air', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-17', '/images/products/iphone/iphone-17.jpg', 'iPhone 17 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Compatibility', 'iPhone 17', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Resolution', '2556 × 1179 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-17', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-17', '/images/products/iphone/iphone-17.jpg', 'iPhone 17 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17', 'Compatibility', 'iPhone 17', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17', 'Capacity', '3274 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-17', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-16-pro-max', '/images/products/iphone/iphone-16-pro-max.jpg', 'iPhone 16 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Compatibility', 'iPhone 16 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Size', '6.9-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Resolution', '2868 × 1320 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro-max', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-16-pro-max', '/images/products/iphone/iphone-16-pro-max.jpg', 'iPhone 16 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro-max', 'Compatibility', 'iPhone 16 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro-max', 'Capacity', '4676 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-16-pro', '/images/products/iphone/iphone-16-pro.jpg', 'iPhone 16 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Compatibility', 'iPhone 16 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Size', '6.3-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Resolution', '2622 × 1206 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-pro', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-16-pro', '/images/products/iphone/iphone-16-pro.jpg', 'iPhone 16 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro', 'Compatibility', 'iPhone 16 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro', 'Capacity', '3577 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-16-plus', '/images/products/iphone/iphone-16-plus.jpg', 'iPhone 16 Plus OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Compatibility', 'iPhone 16 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Resolution', '2796 × 1290 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16-plus', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-16-plus', '/images/products/iphone/iphone-16-plus.jpg', 'iPhone 16 Plus Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-plus', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-plus', 'Compatibility', 'iPhone 16 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-plus', 'Capacity', '4383 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16-plus', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-16', '/images/products/iphone/iphone-16.jpg', 'iPhone 16 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Compatibility', 'iPhone 16', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Resolution', '2556 × 1179 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-16', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-16', '/images/products/iphone/iphone-16.jpg', 'iPhone 16 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16', 'Compatibility', 'iPhone 16', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16', 'Capacity', '3561 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-16', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-15-pro-max', '/images/products/iphone/iphone-15-pro-max.jpg', 'iPhone 15 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Compatibility', 'iPhone 15 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Resolution', '2796 × 1290 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro-max', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-15-pro-max', '/images/products/iphone/iphone-15-pro-max.jpg', 'iPhone 15 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro-max', 'Compatibility', 'iPhone 15 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro-max', 'Capacity', '4422 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-15-pro', '/images/products/iphone/iphone-15-pro.jpg', 'iPhone 15 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Compatibility', 'iPhone 15 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Resolution', '2556 × 1179 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-pro', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-15-pro', '/images/products/iphone/iphone-15-pro.jpg', 'iPhone 15 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro', 'Compatibility', 'iPhone 15 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro', 'Capacity', '3274 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-15-plus', '/images/products/iphone/iphone-15-plus.jpg', 'iPhone 15 Plus OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Compatibility', 'iPhone 15 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Resolution', '2796 × 1290 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15-plus', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-15-plus', '/images/products/iphone/iphone-15-plus.jpg', 'iPhone 15 Plus Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-plus', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-plus', 'Compatibility', 'iPhone 15 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-plus', 'Capacity', '4383 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15-plus', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-15', '/images/products/iphone/iphone-15.jpg', 'iPhone 15 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Compatibility', 'iPhone 15', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Resolution', '2556 × 1179 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-15', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-15', '/images/products/iphone/iphone-15.jpg', 'iPhone 15 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15', 'Compatibility', 'iPhone 15', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15', 'Capacity', '3349 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-15', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-14-pro-max', '/images/products/iphone/iphone-14-pro-max.jpg', 'iPhone 14 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Compatibility', 'iPhone 14 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Resolution', '2796 × 1290 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro-max', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-14-pro-max', '/images/products/iphone/iphone-14-pro-max.jpg', 'iPhone 14 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro-max', 'Compatibility', 'iPhone 14 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro-max', 'Capacity', '4323 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-14-pro', '/images/products/iphone/iphone-14-pro.jpg', 'iPhone 14 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Compatibility', 'iPhone 14 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Resolution', '2556 × 1179 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-pro', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-14-pro', '/images/products/iphone/iphone-14-pro.jpg', 'iPhone 14 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro', 'Compatibility', 'iPhone 14 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro', 'Capacity', '3200 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-14-plus', '/images/products/iphone/iphone-14-plus.jpg', 'iPhone 14 Plus OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Compatibility', 'iPhone 14 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Resolution', '2778 × 1284 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14-plus', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-14-plus', '/images/products/iphone/iphone-14-plus.jpg', 'iPhone 14 Plus Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-plus', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-plus', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-plus', 'Compatibility', 'iPhone 14 Plus', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-plus', 'Capacity', '4325 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14-plus', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-14', '/images/products/iphone/iphone-14.jpg', 'iPhone 14 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Compatibility', 'iPhone 14', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Resolution', '2532 × 1170 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-14', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-14', '/images/products/iphone/iphone-14.jpg', 'iPhone 14 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14', 'Compatibility', 'iPhone 14', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14', 'Capacity', '3279 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-14', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-13-pro-max', '/images/products/iphone/iphone-13-pro-max.jpg', 'iPhone 13 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Compatibility', 'iPhone 13 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Resolution', '2778 × 1284 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro-max', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-13-pro-max', '/images/products/iphone/iphone-13-pro-max.jpg', 'iPhone 13 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro-max', 'Compatibility', 'iPhone 13 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro-max', 'Capacity', '4352 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-13-pro', '/images/products/iphone/iphone-13-pro.jpg', 'iPhone 13 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Compatibility', 'iPhone 13 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Resolution', '2532 × 1170 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-pro', 'Technology', 'OLED / ProMotion', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-13-pro', '/images/products/iphone/iphone-13-pro.jpg', 'iPhone 13 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro', 'Compatibility', 'iPhone 13 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro', 'Capacity', '3095 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-13', '/images/products/iphone/iphone-13.jpg', 'iPhone 13 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Compatibility', 'iPhone 13', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Resolution', '2532 × 1170 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-13', '/images/products/iphone/iphone-13.jpg', 'iPhone 13 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13', 'Compatibility', 'iPhone 13', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13', 'Capacity', '3227 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-13-mini', '/images/products/iphone/iphone-13-mini.jpg', 'iPhone 13 mini OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Compatibility', 'iPhone 13 mini', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Size', '5.4-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Resolution', '2340 × 1080 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-13-mini', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-13-mini', '/images/products/iphone/iphone-13-mini.jpg', 'iPhone 13 mini Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-mini', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-mini', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-mini', 'Compatibility', 'iPhone 13 mini', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-mini', 'Capacity', '2406 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-13-mini', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-12-pro-max', '/images/products/iphone/iphone-12-pro-max.jpg', 'iPhone 12 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Compatibility', 'iPhone 12 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Size', '6.7-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Resolution', '2778 × 1284 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro-max', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-12-pro-max', '/images/products/iphone/iphone-12-pro-max.jpg', 'iPhone 12 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro-max', 'Compatibility', 'iPhone 12 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro-max', 'Capacity', '3687 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-12-pro', '/images/products/iphone/iphone-12-pro.jpg', 'iPhone 12 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Compatibility', 'iPhone 12 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Resolution', '2532 × 1170 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-pro', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-12-pro', '/images/products/iphone/iphone-12-pro.jpg', 'iPhone 12 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro', 'Compatibility', 'iPhone 12 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro', 'Capacity', '2815 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-12', '/images/products/iphone/iphone-12.jpg', 'iPhone 12 OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Compatibility', 'iPhone 12', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Resolution', '2532 × 1170 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-12', '/images/products/iphone/iphone-12.jpg', 'iPhone 12 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12', 'Compatibility', 'iPhone 12', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12', 'Capacity', '2815 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-12-mini', '/images/products/iphone/iphone-12-mini.jpg', 'iPhone 12 mini OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Compatibility', 'iPhone 12 mini', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Size', '5.4-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Resolution', '2340 × 1080 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-12-mini', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-12-mini', '/images/products/iphone/iphone-12-mini.jpg', 'iPhone 12 mini Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-mini', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-mini', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-mini', 'Compatibility', 'iPhone 12 mini', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-mini', 'Capacity', '2227 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-12-mini', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-11-pro-max', '/images/products/iphone/iphone-11-pro-max.jpg', 'iPhone 11 Pro Max OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Compatibility', 'iPhone 11 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Size', '6.5-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Resolution', '2688 × 1242 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro-max', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-11-pro-max', '/images/products/iphone/iphone-11-pro-max.jpg', 'iPhone 11 Pro Max Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro-max', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro-max', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro-max', 'Compatibility', 'iPhone 11 Pro Max', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro-max', 'Capacity', '3969 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro-max', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-11-pro', '/images/products/iphone/iphone-11-pro.jpg', 'iPhone 11 Pro OLED Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Part Type', 'OLED Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Compatibility', 'iPhone 11 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Size', '5.8-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Resolution', '2436 × 1125 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11-pro', 'Technology', 'OLED', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-11-pro', '/images/products/iphone/iphone-11-pro.jpg', 'iPhone 11 Pro Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro', 'Compatibility', 'iPhone 11 Pro', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro', 'Capacity', '3046 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11-pro', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-display-iphone-11', '/images/products/iphone/iphone-11.jpg', 'iPhone 11 LCD Display Assembly', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Part Type', 'LCD Display Assembly', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Compatibility', 'iPhone 11', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Size', '6.1-inch', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Resolution', '1792 × 828 pixels', 4);
insert into public.product_specs (product_id, label, value, position)
values ('part-display-iphone-11', 'Technology', 'LCD', 5);
insert into public.product_images (product_id, path, alt, position, is_primary)
values ('part-battery-iphone-11', '/images/products/iphone/iphone-11.jpg', 'iPhone 11 Replacement Battery Kit', 0, true);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11', 'Part Type', 'Replacement Battery Kit', 0);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11', 'Condition', 'New (Genuine Apple)', 1);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11', 'Compatibility', 'iPhone 11', 2);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11', 'Capacity', '3110 mAh', 3);
insert into public.product_specs (product_id, label, value, position)
values ('part-battery-iphone-11', 'Chemistry', 'Lithium-ion polymer', 4);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('part-iphone-15-pro-display', null, 'iPhone 15 Pro', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('part-iphone-15-pro-battery', null, 'iPhone 15 Pro', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-magsafe-charger', null, 'iPhone 15', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-magsafe-charger', null, 'iPhone 15 Pro', 1);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-magsafe-charger', null, 'iPhone 14', 2);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-magsafe-charger', null, 'iPhone 13', 3);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-magsafe-charger', null, 'iPhone 12 Series', 4);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('part-macbook-pro-14-display', null, 'MacBook Pro 14" (2021)', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('part-macbook-pro-14-display', null, 'MacBook Pro 14" (2023)', 1);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-iphone-15-case', null, 'iPhone 15 Pro', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-usbc-cable-60w', null, 'Mac', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-usbc-cable-60w', null, 'iPad', 1);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-usbc-cable-60w', null, 'iPhone 15 Series', 2);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-power-adapter-20w', null, 'iPhone', 0);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-power-adapter-20w', null, 'iPad', 1);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-power-adapter-20w', null, 'Apple Watch', 2);
insert into public.product_compatibility (product_id, device_model_id, label, position)
values ('acc-power-adapter-20w', null, 'AirPods', 3);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-17-pro-max', 'iphone-17-pro-max', 'iPhone 17 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-17-pro-max', 'iphone-17-pro-max', 'iPhone 17 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-17-pro', 'iphone-17-pro', 'iPhone 17 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-17-pro', 'iphone-17-pro', 'iPhone 17 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-air', 'iphone-air', 'iPhone Air', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-air', 'iphone-air', 'iPhone Air', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-17', 'iphone-17', 'iPhone 17', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-17', 'iphone-17', 'iPhone 17', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-16-pro-max', 'iphone-16-pro-max', 'iPhone 16 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-16-pro-max', 'iphone-16-pro-max', 'iPhone 16 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-16-pro', 'iphone-16-pro', 'iPhone 16 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-16-pro', 'iphone-16-pro', 'iPhone 16 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-16-plus', 'iphone-16-plus', 'iPhone 16 Plus', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-16-plus', 'iphone-16-plus', 'iPhone 16 Plus', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-16', 'iphone-16', 'iPhone 16', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-16', 'iphone-16', 'iPhone 16', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-15-pro-max', 'iphone-15-pro-max', 'iPhone 15 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-15-pro-max', 'iphone-15-pro-max', 'iPhone 15 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-15-pro', 'iphone-15-pro', 'iPhone 15 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-15-pro', 'iphone-15-pro', 'iPhone 15 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-15-plus', 'iphone-15-plus', 'iPhone 15 Plus', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-15-plus', 'iphone-15-plus', 'iPhone 15 Plus', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-15', 'iphone-15', 'iPhone 15', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-15', 'iphone-15', 'iPhone 15', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-14-pro-max', 'iphone-14-pro-max', 'iPhone 14 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-14-pro-max', 'iphone-14-pro-max', 'iPhone 14 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-14-pro', 'iphone-14-pro', 'iPhone 14 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-14-pro', 'iphone-14-pro', 'iPhone 14 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-14-plus', 'iphone-14-plus', 'iPhone 14 Plus', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-14-plus', 'iphone-14-plus', 'iPhone 14 Plus', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-14', 'iphone-14', 'iPhone 14', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-14', 'iphone-14', 'iPhone 14', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-13-pro-max', 'iphone-13-pro-max', 'iPhone 13 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-13-pro-max', 'iphone-13-pro-max', 'iPhone 13 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-13-pro', 'iphone-13-pro', 'iPhone 13 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-13-pro', 'iphone-13-pro', 'iPhone 13 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-13', 'iphone-13', 'iPhone 13', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-13', 'iphone-13', 'iPhone 13', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-13-mini', 'iphone-13-mini', 'iPhone 13 mini', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-13-mini', 'iphone-13-mini', 'iPhone 13 mini', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-12-pro-max', 'iphone-12-pro-max', 'iPhone 12 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-12-pro-max', 'iphone-12-pro-max', 'iPhone 12 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-12-pro', 'iphone-12-pro', 'iPhone 12 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-12-pro', 'iphone-12-pro', 'iPhone 12 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-12', 'iphone-12', 'iPhone 12', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-12', 'iphone-12', 'iPhone 12', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-12-mini', 'iphone-12-mini', 'iPhone 12 mini', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-12-mini', 'iphone-12-mini', 'iPhone 12 mini', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-11-pro-max', 'iphone-11-pro-max', 'iPhone 11 Pro Max', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-11-pro-max', 'iphone-11-pro-max', 'iPhone 11 Pro Max', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-11-pro', 'iphone-11-pro', 'iPhone 11 Pro', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-11-pro', 'iphone-11-pro', 'iPhone 11 Pro', 'battery', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-display-iphone-11', 'iphone-11', 'iPhone 11', 'display', 0);
insert into public.product_compatibility (product_id, device_model_id, label, part_kind, position)
values ('part-battery-iphone-11', 'iphone-11', 'iPhone 11', 'battery', 0);

-- ---------- product_prices (retail, min_qty = 1) ----------
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', null, 'retail', 35900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-17-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'retail', 35900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'retail', 35900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'retail', 41900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro-max', v.id, 'retail', 47900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro-max' and v.legacy_key = 'v4'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro', null, 'retail', 29900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-17-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17-pro', v.id, 'retail', 35900000, 1
from public.product_variants v
where v.product_id = 'iphone-17-pro' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-air', null, 'retail', 26900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-air' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-air', v.id, 'retail', 26900000, 1
from public.product_variants v
where v.product_id = 'iphone-air' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-air', v.id, 'retail', 26900000, 1
from public.product_variants v
where v.product_id = 'iphone-air' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-air', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-air' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-17' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-17' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-17' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-17' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17', v.id, 'retail', 26900000, 1
from public.product_variants v
where v.product_id = 'iphone-17' and v.legacy_key = 'v4'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17e', null, 'retail', 17900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-17e' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17e', v.id, 'retail', 17900000, 1
from public.product_variants v
where v.product_id = 'iphone-17e' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17e', v.id, 'retail', 17900000, 1
from public.product_variants v
where v.product_id = 'iphone-17e' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-17e', v.id, 'retail', 20900000, 1
from public.product_variants v
where v.product_id = 'iphone-17e' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro-max', null, 'retail', 35900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-16-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro-max', v.id, 'retail', 35900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-pro-max' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro-max', v.id, 'retail', 35900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-pro-max' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro-max', v.id, 'retail', 41900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-pro-max' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro', null, 'retail', 29900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-16-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-pro' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-pro', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-pro' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-plus', null, 'retail', 26900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-16-plus' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-plus', v.id, 'retail', 26900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-plus' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16-plus', v.id, 'retail', 26900000, 1
from public.product_variants v
where v.product_id = 'iphone-16-plus' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-16' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-16' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-16' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'iphone-16' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16e', null, 'retail', 17900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-16e' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16e', v.id, 'retail', 17900000, 1
from public.product_variants v
where v.product_id = 'iphone-16e' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-16e', v.id, 'retail', 17900000, 1
from public.product_variants v
where v.product_id = 'iphone-16e' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-pro-max', null, 'retail', 32900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-15-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-pro-max', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'iphone-15-pro-max' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-pro-max', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'iphone-15-pro-max' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-pro', null, 'retail', 29900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-15-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-pro', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'iphone-15-pro' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15-plus', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-15-plus' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15', null, 'retail', 20900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-15' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15', v.id, 'retail', 20900000, 1
from public.product_variants v
where v.product_id = 'iphone-15' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-15', v.id, 'retail', 20900000, 1
from public.product_variants v
where v.product_id = 'iphone-15' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-14-pro-max', null, 'retail', 29900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-14-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-14-pro', null, 'retail', 26900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-14-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-14-plus', null, 'retail', 20900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-14-plus' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-14', null, 'retail', 17900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-14' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-13-pro-max', null, 'retail', 20900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-13-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-13-pro', null, 'retail', 17900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-13-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-13-mini', null, 'retail', 13400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-13-mini' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-13', null, 'retail', 14900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-13' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-12-pro-max', null, 'retail', 16400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-12-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-12-pro', null, 'retail', 14900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-12-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-12-mini', null, 'retail', 10400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-12-mini' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-12', null, 'retail', 11900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-12' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-11-pro-max', null, 'retail', 10400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-11-pro-max' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-11-pro', null, 'retail', 8900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-11-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'iphone-11', null, 'retail', 7400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'iphone-11' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-13-m5', null, 'retail', 38900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-pro-13-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-13-m5', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'ipad-pro-13-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-13-m5', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'ipad-pro-13-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-13-m5', v.id, 'retail', 44900000, 1
from public.product_variants v
where v.product_id = 'ipad-pro-13-m5' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-11-m5', null, 'retail', 29900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-pro-11-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-11-m5', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'ipad-pro-11-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-pro-11-m5', v.id, 'retail', 29900000, 1
from public.product_variants v
where v.product_id = 'ipad-pro-11-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-13-m4', null, 'retail', 32900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-air-13-m4' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-13-m4', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'ipad-air-13-m4' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-13-m4', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'ipad-air-13-m4' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-11-m4', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-air-11-m4' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-11-m4', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'ipad-air-11-m4' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-air-11-m4', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'ipad-air-11-m4' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-a16', null, 'retail', 10400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-a16' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-a16', v.id, 'retail', 10400000, 1
from public.product_variants v
where v.product_id = 'ipad-a16' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-a16', v.id, 'retail', 10400000, 1
from public.product_variants v
where v.product_id = 'ipad-a16' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-a16', v.id, 'retail', 10400000, 1
from public.product_variants v
where v.product_id = 'ipad-a16' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-mini-a17-pro', null, 'retail', 14900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'ipad-mini-a17-pro' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-mini-a17-pro', v.id, 'retail', 14900000, 1
from public.product_variants v
where v.product_id = 'ipad-mini-a17-pro' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-mini-a17-pro', v.id, 'retail', 14900000, 1
from public.product_variants v
where v.product_id = 'ipad-mini-a17-pro' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'ipad-mini-a17-pro', v.id, 'retail', 14900000, 1
from public.product_variants v
where v.product_id = 'ipad-mini-a17-pro' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-neo', null, 'retail', 44900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'macbook-neo' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-neo', v.id, 'retail', 44900000, 1
from public.product_variants v
where v.product_id = 'macbook-neo' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-neo', v.id, 'retail', 44900000, 1
from public.product_variants v
where v.product_id = 'macbook-neo' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-neo', v.id, 'retail', 53900000, 1
from public.product_variants v
where v.product_id = 'macbook-neo' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-15', null, 'retail', 38900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'macbook-air-15' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-15', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'macbook-air-15' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-15', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'macbook-air-15' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-15', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'macbook-air-15' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-13', null, 'retail', 32900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'macbook-air-13' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-13', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'macbook-air-13' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-air-13', v.id, 'retail', 32900000, 1
from public.product_variants v
where v.product_id = 'macbook-air-13' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-16', null, 'retail', 74900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'macbook-pro-16' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-16', v.id, 'retail', 74900000, 1
from public.product_variants v
where v.product_id = 'macbook-pro-16' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-16', v.id, 'retail', 74900000, 1
from public.product_variants v
where v.product_id = 'macbook-pro-16' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-14', null, 'retail', 59900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'macbook-pro-14' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-14', v.id, 'retail', 59900000, 1
from public.product_variants v
where v.product_id = 'macbook-pro-14' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'macbook-pro-14', v.id, 'retail', 59900000, 1
from public.product_variants v
where v.product_id = 'macbook-pro-14' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'imac-m5', null, 'retail', 38900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'imac-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'imac-m5', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'imac-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'imac-m5', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'imac-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'imac-m5', v.id, 'retail', 38900000, 1
from public.product_variants v
where v.product_id = 'imac-m5' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-mini-m5', null, 'retail', 17900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'mac-mini-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-mini-m5', v.id, 'retail', 17900000, 1
from public.product_variants v
where v.product_id = 'mac-mini-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-mini-m5', v.id, 'retail', 23900000, 1
from public.product_variants v
where v.product_id = 'mac-mini-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-mini-m5', v.id, 'retail', 41900000, 1
from public.product_variants v
where v.product_id = 'mac-mini-m5' and v.legacy_key = 'v3'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-studio-m5', null, 'retail', 59900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'mac-studio-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-studio-m5', v.id, 'retail', 59900000, 1
from public.product_variants v
where v.product_id = 'mac-studio-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-studio-m5', v.id, 'retail', 119900000, 1
from public.product_variants v
where v.product_id = 'mac-studio-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-pro-m5', null, 'retail', 209900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'mac-pro-m5' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-pro-m5', v.id, 'retail', 209900000, 1
from public.product_variants v
where v.product_id = 'mac-pro-m5' and v.legacy_key = 'v1'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'mac-pro-m5', v.id, 'retail', 209900000, 1
from public.product_variants v
where v.product_id = 'mac-pro-m5' and v.legacy_key = 'v2'
  and not exists (
    select 1 from public.product_prices pp
    where pp.product_id = v.product_id and pp.variant_id = v.id
      and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'airpods-pro-2', null, 'retail', 7400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'airpods-pro-2' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'apple-watch-ultra-2', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'apple-watch-ultra-2' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'part-iphone-15-pro-display', null, 'retail', 9800000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'part-iphone-15-pro-display' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'part-iphone-15-pro-battery', null, 'retail', 2900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'part-iphone-15-pro-battery' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'acc-magsafe-charger', null, 'retail', 1100000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'acc-magsafe-charger' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'part-macbook-pro-14-display', null, 'retail', 23900000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'part-macbook-pro-14-display' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'acc-iphone-15-case', null, 'retail', 1400000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'acc-iphone-15-case' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'acc-usbc-cable-60w', null, 'retail', 500000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'acc-usbc-cable-60w' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);
insert into public.product_prices (product_id, variant_id, tier_code, price_cents, min_qty)
select 'acc-power-adapter-20w', null, 'retail', 500000, 1
where not exists (
  select 1 from public.product_prices pp
  where pp.product_id = 'acc-power-adapter-20w' and pp.variant_id is null
    and pp.tier_code = 'retail' and pp.min_qty = 1 and pp.ends_at is null);

-- ---------- featured_products (slot: home) ----------
insert into public.featured_products (slot, product_id, position)
values ('home', 'iphone-17-pro-max', 1)
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;
insert into public.featured_products (slot, product_id, position)
values ('home', 'macbook-pro-16', 2)
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;
insert into public.featured_products (slot, product_id, position)
values ('home', 'airpods-pro-2', 3)
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;
insert into public.featured_products (slot, product_id, position)
values ('home', 'apple-watch-ultra-2', 4)
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;
insert into public.featured_products (slot, product_id, position)
values ('home', 'part-iphone-15-pro-display', 5)
on conflict (slot, product_id) do update set position = excluded.position, is_active = true;

-- ---------- category tracking rules (mirror migrations 20261028120000, 20261101100000 + 20261101140000) ----------
update public.categories set requires_serial = true where slug = 'iphone';
update public.categories set default_tracking_mode = 'unit' where slug in ('iphone', 'ipad', 'mac', 'watch', 'airpods');
update public.categories set allows_shared_barcode = true where slug in ('accessories', 'parts', 'batteries', 'displays');
-- ---------- derived condition / warranty rows (mirror migrations 20261002120000 + 20261003120000) ----------
update public.products
   set warranty_type = case when warranty_status = 'active' then 'included' else 'none' end
 where warranty_type is distinct from case when warranty_status = 'active' then 'included' else 'none' end;
insert into public.product_warranty_plans
  (product_id, variant_id, warranty_type, warranty_duration, warranty_months,
   warranty_title, warranty_description, warranty_covered, warranty_excluded)
select p.id, null, p.warranty_type, p.warranty_duration, p.warranty_months,
       p.warranty_title, p.warranty_description, p.warranty_covered, p.warranty_excluded
from public.products p
on conflict (product_id, variant_id) do nothing;
insert into public.product_conditions
  (product_id, variant_id, condition, condition_grade_id, battery_health, cycle_count,
   physical_condition, accessories_included, device_notes)
select p.id, null, p.condition, p.condition_grade_id, p.battery_health, p.cycle_count,
       p.physical_condition, p.accessories_included, p.device_notes
from public.products p
where not exists (select 1 from public.product_variants v where v.product_id = p.id)
on conflict (product_id, variant_id) do nothing;

commit;
