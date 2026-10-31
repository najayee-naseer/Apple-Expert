"use client"

import { useState } from 'react'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { ArrowLeft, Check, Star, ShieldCheck, Minus, Plus } from 'lucide-react'
import { formatPrice } from '@/utils/formatPrice'
import { useCart } from '@/context/CartContext'
import { InfoBox } from '@/components/ui/InfoBox'
import { StickyActionBar } from '@/components/ui/StickyActionBar'
import { EmptyState } from '@/components/ui/EmptyState'
import { getCategoryTheme } from '@/lib/categoryTheme'
import { buildPartProduct, type PartKind } from '@/lib/partProduct'
import { useCatalogProduct, resolveWarrantyOption } from '@/lib/catalog'
import { WarrantyPicker, PriceBreakdown, WarrantyTerms } from '@/components/product/ProductConditionWarranty'
import type { IPhoneModel } from '@/data/iphoneModels'

interface PartDetailViewProps {
  model: IPhoneModel | undefined
  partKind: PartKind
}

const partLabel: Record<PartKind, string> = { display: 'Display', battery: 'Battery' }

export function PartDetailView({ model, partKind }: PartDetailViewProps) {
  const { addToCart } = useCart()
  const [activeImageIndex, setActiveImageIndex] = useState(0)
  const [quantity, setQuantity] = useState(1)
  const [selectedWarrantyId, setSelectedWarrantyId] = useState<string | undefined>(undefined)
  // The bundled part, replaced by its live catalog product once an
  // administrator has priced and published it — which is what brings live
  // price, stock and the part's warranty options to this page.
  const bundledPart = model ? buildPartProduct(model, partKind) : undefined
  const livePart = useCatalogProduct(bundledPart?.id)
  const listHref = `/categories/replacement-parts/${partKind === 'display' ? 'displays' : 'batteries'}`
  const theme = getCategoryTheme(partKind === 'display' ? 'displays' : 'batteries')

  if (!model) {
    return (
      <EmptyState
        icon={ShieldCheck}
        title={`${partLabel[partKind]} Not Found`}
        subtitle={`The ${partKind} for this model doesn't exist.`}
        ctaLabel={`View All ${partLabel[partKind]}s`}
        ctaHref={listHref}
      />
    )
  }

  const product = livePart ?? bundledPart!
  const warrantyOption = resolveWarrantyOption(product, undefined, selectedWarrantyId)
    ?? resolveWarrantyOption(product, undefined, undefined)
  const unitTotal = product.price + (warrantyOption?.addOn ?? 0)

  return (
    <div className="flex flex-col min-h-screen pb-24">
      {/* Breadcrumb */}
      <div className="px-4 py-3 flex items-center text-sm text-muted-foreground">
        <Link href={listHref} className="hover:text-primary flex items-center min-h-[44px] font-medium">
          <ArrowLeft size={16} className="mr-1" /> {partLabel[partKind]}s
        </Link>
      </div>

      {/* Image Gallery */}
      <div className="px-4">
        <div className={`w-full aspect-[4/5] sm:aspect-square ${theme.well} border border-mint/80 dark:border-border rounded-[30px] relative p-7 flex flex-col items-center justify-center overflow-hidden shadow-card`}>
          <motion.img
            key={activeImageIndex}
            initial={{ opacity: 0, scale: 0.97 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
            src={product.images[activeImageIndex]}
            alt={product.name}
            className="w-full h-full object-contain mix-blend-multiply dark:mix-blend-normal drop-shadow-xl"
          />
          <div className="h-7 w-2/3 -mt-1 rounded-[100%] bg-pedestal blur-[8px]" aria-hidden="true" />
        </div>
      </div>

      {/* Product Info */}
      <div className="px-4 py-6">
        <div className="mb-1.5 inline-flex items-center px-2.5 py-1 rounded-full bg-primary-soft border border-mint-deep text-[11px] font-bold uppercase tracking-wide text-primary">
          {product.subcategory}
        </div>
        <h1 className="text-2xl sm:text-[32px] font-bold tracking-tight mb-2 leading-tight">{product.name}</h1>

        <div className="flex items-center gap-2 mb-4 flex-wrap">
          <div className="flex items-center text-amber-500">
            <Star size={16} fill="currentColor" />
            <span className="ml-1 text-sm font-semibold text-foreground">{product.rating}</span>
          </div>
          <span className="text-muted-foreground text-sm">({product.reviewsCount} reviews)</span>
          <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary">
            <span className="w-1.5 h-1.5 rounded-full bg-primary" /> In Stock
          </span>
        </div>

        <div className={`text-[26px] font-bold tracking-tight ${warrantyOption ? 'mb-3' : 'mb-6'}`}>{formatPrice(unitTotal)}</div>
        <PriceBreakdown product={product} base={product.price} option={warrantyOption} />

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

        {/* Compatibility */}
        <InfoBox icon={ShieldCheck} title="Compatibility" tone="info" className="mb-6">
          <ul className="space-y-2">
            <li className="flex items-center text-foreground/85 text-sm font-medium">
              <Check size={16} className="mr-2 text-primary shrink-0" />
              {model.name} Only
            </li>
          </ul>
        </InfoBox>

        {/* Description */}
        <div className="mb-6">
          <h3 className="text-lg font-bold tracking-tight mb-2">Overview</h3>
          <p className="text-muted-foreground text-sm leading-relaxed">{product.description}</p>
        </div>

        {/* Specifications */}
        <WarrantyPicker product={product} selected={warrantyOption} onSelect={(o) => setSelectedWarrantyId(o.id)} />

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

        {/* Only once live: the bundled part has no admin-managed warranty. */}
        {livePart && <WarrantyTerms product={livePart} />}
      </div>

      <StickyActionBar
        title={product.name}
        price={formatPrice(unitTotal * quantity)}
        onAddToCart={() => addToCart(product, undefined, quantity, warrantyOption)}
        disabled={product.stock <= 0}
        ctaLabel={product.stock <= 0 ? 'Out of Stock' : undefined}
      />
    </div>
  )
}
