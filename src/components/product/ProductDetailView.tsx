"use client"
import { formatPrice } from '@/utils/formatPrice'

import { useState } from 'react'
import { Header } from '@/components/ui/Header'
import { useCatalogProduct, resolveVariant, selectedPrice, selectedPriceIsVip, resolveWarrantyOption } from '@/lib/catalog'
import {
  ConditionChip, ConditionLine, PreOwnedDetails, WarrantyPicker, PriceBreakdown, WarrantyTerms,
} from '@/components/product/ProductConditionWarranty'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { VipPriceTag } from '@/components/account/VipBadge'
import { iphoneModels } from '@/data/iphoneModels'
import { categorySlugFromName } from '@/data/categoryMeta'
import { getCategoryTheme } from '@/lib/categoryTheme'
import { Button } from '@/components/ui/Button'
import { InfoBox } from '@/components/ui/InfoBox'
import { StickyActionBar } from '@/components/ui/StickyActionBar'
import { EmptyState } from '@/components/ui/EmptyState'
import { useCart } from '@/context/CartContext'
import { motion } from 'framer-motion'
import { ArrowLeft, ChevronRight, Check, Star, Wrench, ShieldCheck, PackageSearch, Minus, Plus, Box } from 'lucide-react'
import Link from 'next/link'
import { useStoreSettings } from '@/lib/store/settings'

/**
 * The product detail screen, addressed by product id rather than by route.
 *
 * Lifted out of app/(shop)/product/[id]/page.tsx unchanged so that TWO routes
 * can render it:
 *
 *   /product/<id>  – prerendered at build time for every bundled product
 *   /p?id=<id>     – one static page that resolves any id at runtime
 *
 * The second exists because this app is a static export: generateStaticParams
 * can only enumerate ids that existed when the APK was built, so a product an
 * administrator adds later has no page of its own. Everything else about the
 * screen is identical, and productHref() picks the right URL per product.
 */
export function ProductDetailView({ productId }: { productId: string }) {
  // Resolves against the bundled catalog immediately, then against the live
  // catalog once it loads. Live pricing and stock arrive with no route change.
  const product = useCatalogProduct(productId)
  const { addToCart } = useCart()
  const { isWholesaleVip } = useCustomerAuth()

  // Hold the variant ID, not the variant object. The object is re-read from the
  // current product on every render, so a live price update reaches the price,
  // the sticky bar and addToCart instead of being frozen at first render.
  const [selectedVariantId, setSelectedVariantId] = useState<string | undefined>(undefined)
  // Same pattern as the variant: hold the id, re-read the option (and its
  // add-on price) from the current product on every render.
  const [selectedWarrantyId, setSelectedWarrantyId] = useState<string | undefined>(undefined)
  const [activeImageIndex, setActiveImageIndex] = useState(0)
  const [quantity, setQuantity] = useState(1)
  // "Show stock status" in /admin/settings.
  const showStock = useStoreSettings().settings.show_stock_status

  if (!product) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <EmptyState
          icon={PackageSearch}
          title="Product Not Found"
          subtitle="The product you're looking for doesn't exist."
          ctaLabel="Browse Categories"
          ctaHref="/categories"
        />
      </div>
    )
  }

  const selectedVariant = resolveVariant(product, selectedVariantId)
  // The selected option's own availability, so a product is not shown as in stock
  // merely because another colour or storage is.
  const available = selectedVariant?.available ?? product.stock
  const currentPrice = selectedPrice(product, selectedVariant)
  // undefined unless the product sells a warranty choice; then the chosen
  // option, or the admin's default. A withdrawn option falls back to the default.
  // The plan in force for THIS variant (override, else product). An option
  // chosen under another variant's plan never carries over — it falls back to
  // this plan's default.
  const warrantyOption = resolveWarrantyOption(product, selectedVariant, selectedWarrantyId)
    ?? resolveWarrantyOption(product, selectedVariant, undefined)
  // The selected variant's own photos first, then the photos shared by every
  // variant. Without variant photos: the product's images as before.
  const sharedImages = product.sharedImages ?? product.images
  const gallery = selectedVariant?.images?.length
    ? [...selectedVariant.images, ...sharedImages.filter((src) => !selectedVariant.images!.includes(src))]
    : product.images
  const imageIndex = Math.min(activeImageIndex, Math.max(gallery.length - 1, 0))
  const unitTotal = currentPrice + (warrantyOption?.addOn ?? 0)
  const theme = getCategoryTheme(product.category)

  // Check if there are repair parts for this device (currently iPhones)
  const repairParts = iphoneModels.find(m => m.id === product.id)

  return (
    <div className="flex flex-col min-h-screen pb-24">
      <Header />
      
      <main className="flex-1 flex flex-col">
        {/* Breadcrumb */}
        <div className="px-4 py-3 flex items-center text-sm text-muted-foreground">
          <Link href="/categories" className="hover:text-primary flex items-center font-medium">
            <ArrowLeft size={16} className="mr-1" /> Back
          </Link>
          <span className="mx-2 text-mint-deep">/</span>
          <Link href={`/categories/${categorySlugFromName(product.category)}`} className="hover:text-primary font-medium">
            {product.category}
          </Link>
        </div>

        {/* Image Gallery */}
        <div className="px-4">
          <div className={`w-full aspect-square ${theme.well} border border-mint/80 dark:border-border rounded-[30px] relative p-7 flex flex-col items-center justify-center overflow-hidden shadow-card`}>
            {/* A product created in the admin panel may not have an image row
                yet. Rendering <img> with no src leaves a blank well, so the
                neutral mark is shown instead — the same one ProductCard falls
                back to when an image fails to load. */}
            {gallery.length > 0 ? (
              <motion.img
                key={gallery[imageIndex]}
                initial={{ opacity: 0, scale: 0.97 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
                src={gallery[imageIndex]}
                alt={product.name}
                className="w-full h-full object-contain mix-blend-multiply dark:mix-blend-normal drop-shadow-xl"
              />
            ) : (
              <div className="flex h-full w-full flex-col items-center justify-center text-primary/40">
                <Box size={52} strokeWidth={1.4} />
              </div>
            )}
            {/* Curved glossy shelf beneath the product */}
            <div className="h-7 w-2/3 -mt-1 rounded-[100%] bg-pedestal blur-[8px]" aria-hidden="true" />

            {gallery.length > 1 && (
              <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-2">
                {gallery.map((_, idx) => (
                  <button
                    key={idx}
                    onClick={() => setActiveImageIndex(idx)}
                    aria-label={`View image ${idx + 1}`}
                    className={`h-2 rounded-full transition-all duration-300 ${
                      idx === imageIndex ? 'bg-primary w-5' : 'bg-primary/25 w-2'
                    }`}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Product Info */}
        <div className="px-4 py-6">
          <div className="mb-1.5 inline-flex items-center px-2.5 py-1 rounded-full bg-primary-soft border border-mint-deep text-[11px] font-bold uppercase tracking-wide text-primary">
            {product.isNew || product.status === 'NEW' ? 'New' : product.subcategory}
          </div>
          <h1 className="text-2xl sm:text-[32px] font-bold tracking-tight mb-2 leading-tight">{product.name}</h1>

          <div className="flex items-center gap-2 mb-4 flex-wrap">
            <div className="flex items-center text-amber-500">
              <Star size={16} fill="currentColor" />
              <span className="ml-1 text-sm font-semibold text-foreground">{product.rating}</span>
            </div>
            <span className="text-muted-foreground text-sm">({product.reviewsCount} reviews)</span>
            {/* Real availability (it previously read "In Stock" regardless). */}
            {showStock && (
              available <= 0 ? (
                <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-red-500">
                  <span className="w-1.5 h-1.5 rounded-full bg-red-500" /> Out of Stock
                </span>
              ) : available <= 5 ? (
                <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-amber-600 dark:text-amber-400">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500" /> Low Stock
                </span>
              ) : (
                <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary">
                  <span className="w-1.5 h-1.5 rounded-full bg-primary" /> In Stock
                </span>
              )
            )}
          </div>

          <ConditionLine product={product} variant={selectedVariant} />

          <div className={warrantyOption ? 'mb-3' : 'mb-6'}>
            {isWholesaleVip && selectedPriceIsVip(product, selectedVariant) && <VipPriceTag className="mb-0.5" />}
            <div className="text-[26px] font-bold tracking-tight">{formatPrice(unitTotal)}</div>
          </div>
          <PriceBreakdown product={product} base={currentPrice} option={warrantyOption} />

          {/* Quantity */}
          <div className="mb-6">
            <h3 className="text-xs font-bold uppercase tracking-wider text-muted-foreground mb-3">
              Quantity
            </h3>
            <div className="inline-flex items-center bg-primary-soft border border-mint-deep rounded-full px-1 py-1">
              <button
                onClick={() => setQuantity(q => Math.max(1, q - 1))}
                aria-label="Decrease quantity"
                className="w-9 h-9 rounded-full text-primary flex items-center justify-center hover:bg-card active:scale-90 transition-all"
              >
                <Minus size={16} />
              </button>
              <span className="w-10 text-center font-semibold text-sm">{quantity}</span>
              <button
                onClick={() => setQuantity(q => q + 1)}
                aria-label="Increase quantity"
                className="w-9 h-9 rounded-full text-primary flex items-center justify-center hover:bg-card active:scale-90 transition-all"
              >
                <Plus size={16} />
              </button>
            </div>
          </div>

          {/* Variants */}
          {product.variants && product.variants.length > 0 && (
            <div className="mb-8">
              <h3 className="text-xs font-bold uppercase tracking-wider text-muted-foreground mb-3">
                Select Option
              </h3>
              <div className="space-y-2.5">
                {product.variants.map((variant) => {
                  const isSelected = selectedVariant?.id === variant.id
                  return (
                    <button
                      key={variant.id}
                      onClick={() => { setSelectedVariantId(variant.id); setActiveImageIndex(0) }}
                      className={`w-full flex items-center justify-between p-4 rounded-[20px] border transition-all duration-300 active:scale-[0.99] ${
                        isSelected
                          ? 'border-primary/45 bg-well-strong shadow-card'
                          : 'border-mint/80 dark:border-border bg-surface hover:border-primary/30'
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {variant.colorCode && (
                          <div
                            className="w-5 h-5 rounded-full border border-mint-deep shadow-sm shrink-0"
                            style={{ backgroundColor: variant.colorCode }}
                          />
                        )}
                        <span className="min-w-0 text-left">
                          <span className={`block font-semibold text-sm truncate ${isSelected ? 'text-primary' : 'text-foreground'}`}>
                            {variant.name}
                          </span>
                          <ConditionChip product={product} variant={variant} className="mt-1" />
                        </span>
                      </div>
                      <span className="font-bold text-sm shrink-0 ml-3">{formatPrice(variant.price)}</span>
                    </button>
                  )
                })}
              </div>
            </div>
          )}

          <WarrantyPicker product={product} variant={selectedVariant} selected={warrantyOption} onSelect={(o) => setSelectedWarrantyId(o.id)} />

          <PreOwnedDetails product={product} variant={selectedVariant} />

          {/* Compatibility (if Replacement Part) */}
          {product.compatibility && (
            <InfoBox icon={ShieldCheck} title="Compatibility" tone="info" className="mb-8">
              <ul className="space-y-2">
                {product.compatibility.map((model, idx) => (
                  <li key={idx} className="flex items-center text-foreground/85 text-sm font-medium">
                    <Check size={16} className="mr-2 text-primary shrink-0" />
                    {model}
                  </li>
                ))}
              </ul>
            </InfoBox>
          )}

          {/* Repair Parts Connection */}
          {repairParts && (
            <InfoBox icon={Wrench} title="Compatible Repair Parts" tone="accent" className="mb-8">
              <p className="text-sm text-foreground/75 mb-4">
                Genuine Apple replacement parts are available for {product.name}.
              </p>
              <div className="flex flex-col gap-2.5">
                <Link href={`/categories/replacement-parts/displays/${repairParts.id}`}>
                  <Button variant="secondary" className="w-full justify-between text-left h-12">
                    <span className="truncate text-[13px]">{repairParts.display.specifications['Part Type']}</span>
                    <ChevronRight size={16} className="text-primary shrink-0" />
                  </Button>
                </Link>
                <Link href={`/categories/replacement-parts/batteries/${repairParts.id}`}>
                  <Button variant="secondary" className="w-full justify-between text-left h-12">
                    <span className="truncate text-[13px]">{repairParts.battery.specifications['Part Type']}</span>
                    <ChevronRight size={16} className="text-primary shrink-0" />
                  </Button>
                </Link>
              </div>
            </InfoBox>
          )}

          {/* Description */}
          <div className="mb-6">
            <h3 className="text-lg font-bold tracking-tight mb-2">Overview</h3>
            <p className="text-muted-foreground text-sm leading-relaxed">
              {product.description}
            </p>
          </div>

          {/* Specifications */}
          <div className="mb-8">
            <h3 className="text-lg font-bold tracking-tight mb-3">Specifications</h3>
            <div className="bg-surface border border-mint/80 dark:border-border rounded-[26px] px-4 shadow-card divide-y divide-mint/80 dark:divide-border">
              {Object.entries(product.specifications).map(([key, value]) => (
                <div key={key} className="py-3.5 flex flex-col sm:flex-row sm:justify-between gap-1">
                  <span className="text-muted-foreground text-[13px] font-semibold">{key}</span>
                  <span className="text-foreground text-[13px] sm:text-right sm:w-2/3">{value}</span>
                </div>
              ))}
            </div>
          </div>

          <WarrantyTerms product={product} variant={selectedVariant} />
        </div>
      </main>

      <StickyActionBar
        title={product.name}
        price={formatPrice(unitTotal * quantity)}
        onAddToCart={() => addToCart(product, selectedVariant, quantity, warrantyOption)}
        disabled={available <= 0}
        ctaLabel={available <= 0 ? 'Out of Stock' : undefined}
      />
    </div>
  )
}


