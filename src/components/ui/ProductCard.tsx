"use client"
import { formatPrice } from '@/utils/formatPrice'

import React, { useState, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { Product } from '@/types'
import { Button } from './Button'
import { Badge, statusTone } from './Badge'
import { useCart } from '@/context/CartContext'
import { useWishlist } from '@/context/WishlistContext'
import { displayPrice, displayPriceIsVip, hasVariantPricing, anyWarrantyChoice, productHref } from '@/lib/catalog'
import { ConditionChip } from '@/components/product/ProductConditionWarranty'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { VipPriceTag } from '@/components/account/VipBadge'
import { getCategoryTheme } from '@/lib/categoryTheme'
import { getIphoneCardTone } from '@/lib/iphoneCardTheme'
import { getProductSpecChips } from '@/lib/productSpecChips'
import { Box, Check, Heart, ArrowRight, ShieldCheck } from 'lucide-react'
import { useStoreSettings } from '@/lib/store/settings'

interface ProductCardProps {
  product: Product
  featured?: boolean
}

function resolveHref(product: Product): string {
  if (product.id === 'part-iphone-15-pro-display') return '/categories/replacement-parts/displays'
  if (product.id === 'part-iphone-15-pro-battery') return '/categories/replacement-parts/batteries'
  // Bundled products keep their prerendered /product/<id> URL; anything an
  // administrator added after this build is served by the runtime page.
  return productHref(product.id)
}

export function ProductCard({ product, featured = false }: ProductCardProps) {
  const router = useRouter()
  const { addToCart } = useCart()
  const { isWishlisted, toggleWishlist } = useWishlist()
  const [imgError, setImgError] = useState(false)
  const [imgLoaded, setImgLoaded] = useState(false)
  const [justAdded, setJustAdded] = useState(false)

  const theme = getCategoryTheme(product.category)
  const wishlisted = isWishlisted(product.id)
  const availability = product.stock <= 0 ? 'out' : product.stock <= 5 ? 'low' : 'in'
  // "Show stock status" in /admin/settings.
  const showStock = useStoreSettings().settings.show_stock_status
  const isIphone = product.category === 'iPhone'
  const iphoneTone = isIphone ? getIphoneCardTone(product.name) : null

  // Cached images can finish loading before React attaches the onLoad
  // listener, so also check `.complete` synchronously when the node mounts.
  const imgCallbackRef = useCallback((node: HTMLImageElement | null) => {
    if (node?.complete && node.naturalWidth > 0) setImgLoaded(true)
  }, [])

  const href = resolveHref(product)
  const isPartSelector = product.id === 'part-iphone-15-pro-display' || product.id === 'part-iphone-15-pro-battery'
  const hasVariants = hasVariantPricing(product)
  const minPrice = displayPrice(product)
  // Both must hold: a database-confirmed VIP, and this number being their VIP row.
  const showVipPrice = useCustomerAuth().isWholesaleVip && displayPriceIsVip(product)
  const tone = statusTone(product.status) !== 'neutral' ? statusTone(product.status) : (product.isNew ? 'new' : 'neutral')

  // A product that sells a warranty choice is never quick-added: the customer
  // picks the cover (and sees its price) on the product page.
  const needsChoice = hasVariants || anyWarrantyChoice(product)
  const ctaLabel = isPartSelector ? 'Select Model' : needsChoice ? 'View Options' : justAdded ? 'Added' : 'Add to Cart'
  const tagline = product.description?.split('.')[0]
  const specChips = getProductSpecChips(product)

  // Catalogue shots are studio cutouts on white — they belong inside the mint
  // well, centred and multiplied. Remote editorial photography is full-bleed
  // landscape, so letterboxing it in the well reads as a black box; on the
  // featured card those fill the frame instead.
  const fillsFrame = featured && !product.images[0]?.startsWith('/')

  const handleCta = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()

    // Same client-side navigation as the card's Link. Under Capacitor a page load
    // of a path with no "." gets index.html, the home page, so never set location.
    if (isPartSelector || needsChoice) {
      router.push(href)
      return
    }
    addToCart(product)
    setJustAdded(true)
    setTimeout(() => setJustAdded(false), 1400)
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 14 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      whileHover={{ y: -5 }}
      transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
      className={`group relative flex flex-col bg-surface rounded-[26px] overflow-hidden border border-mint/80 dark:border-border ${theme.glow} hover:shadow-float transition-shadow duration-400 ${featured ? 'w-[calc(100%-4.5rem)] max-w-[360px] shrink-0 snap-start shadow-card sm:w-full sm:max-w-none' : 'w-full'}`}
    >
      <Link href={href} className="flex flex-col flex-1 p-2.5 sm:p-3">
        <div className={`relative w-full mb-3 ${featured ? 'aspect-[4/3]' : 'aspect-square'} ${iphoneTone ? iphoneTone.well : theme.well} rounded-[20px] overflow-hidden ${fillsFrame ? 'p-0' : isIphone ? 'p-2 sm:p-2.5' : 'p-4 sm:p-5'} flex items-center justify-center`}>
          {tone !== 'neutral' && (
            <div className="absolute top-2.5 left-2.5 z-10">
              <Badge tone={tone}>{tone === 'new' ? 'New' : 'Current'}</Badge>
            </div>
          )}
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault()
              e.stopPropagation()
              toggleWishlist(product.id)
            }}
            aria-label={wishlisted ? 'Remove from wishlist' : 'Add to wishlist'}
            aria-pressed={wishlisted}
            className="absolute top-2 right-2 z-10 w-8 h-8 rounded-full bg-white/90 dark:bg-black/45 backdrop-blur-sm border border-white/70 dark:border-white/10 shadow-card flex items-center justify-center active:scale-90 transition-transform"
          >
            <motion.span
              key={wishlisted ? 'on' : 'off'}
              initial={{ scale: 0.6 }}
              animate={{ scale: 1 }}
              transition={{ type: 'spring', stiffness: 500, damping: 20 }}
              className="flex items-center justify-center"
            >
              <Heart
                size={15}
                strokeWidth={2.2}
                className={wishlisted ? 'text-rose-500' : 'text-primary/70'}
                fill={wishlisted ? 'currentColor' : 'none'}
              />
            </motion.span>
          </button>
          {/* Soft blurred glow behind the product photo — a plain (non-negative)
              z-index child painted first in DOM order, kept behind the `relative`
              image below it. Negative z-index inside an overflow-hidden ancestor
              fails to paint in some Chromium versions, so DOM order is used instead. */}
          {iphoneTone && (
            <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[70%] h-[70%] rounded-full blur-2xl ${iphoneTone.glow}`} aria-hidden="true" />
          )}

          {!imgError && product.images[0] ? (
            <img
              ref={imgCallbackRef}
              src={product.images[0]}
              alt={product.name}
              onError={() => setImgError(true)}
              onLoad={() => setImgLoaded(true)}
              className={`relative w-full h-full transition-all duration-500 ${fillsFrame ? 'object-cover group-hover:scale-[1.04]' : 'object-contain mix-blend-multiply dark:mix-blend-normal group-hover:scale-[1.06]'} ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
            />
          ) : (
            <div className="relative flex flex-col items-center justify-center text-primary/40">
              <Box size={40} strokeWidth={1.5} />
            </div>
          )}
        </div>

        <div className="flex flex-col flex-1 px-1">
          {product.category === 'Replacement Parts' && product.compatibility?.[0] && (
            <span className="text-[10px] sm:text-xs text-primary font-semibold mb-1 line-clamp-1">
              For {product.compatibility[0]}
            </span>
          )}
          {/* No variant chosen yet: the shared condition, or "New & Pre-Owned". */}
          <ConditionChip product={product} className="mb-1.5 w-fit" />
          <h3 className={`font-semibold text-foreground leading-tight mb-1 line-clamp-2 ${featured ? 'text-[15px]' : 'text-sm'}`}>
            {product.name}
          </h3>
          {tagline && (
            <p className="text-[11px] sm:text-xs text-muted-foreground leading-snug line-clamp-1 mb-1.5">
              {tagline}.
            </p>
          )}
          {showStock && availability !== 'in' && (
            <span className={`inline-flex items-center gap-1 text-[10px] sm:text-xs font-medium mb-1 ${availability === 'low' ? 'text-amber-600 dark:text-amber-400' : 'text-red-500'}`}>
              <span className={`w-1.5 h-1.5 rounded-full ${availability === 'low' ? 'bg-amber-500' : 'bg-red-500'}`} />
              {availability === 'low' ? 'Low Stock' : 'Out of Stock'}
            </span>
          )}
          <div className="mt-auto">
            {showVipPrice && <VipPriceTag className="mb-0.5" />}
            <span className={`font-bold tracking-tight block mb-2 text-foreground ${featured ? 'text-lg' : 'text-[15px] sm:text-base'}`}>
              {hasVariants && <span className="text-[11px] font-medium text-muted-foreground mr-0.5">From</span>}{formatPrice(minPrice)}
            </span>
            {specChips.length > 0 && (
              <div className="flex items-center gap-1.5 flex-wrap mb-1.5">
                {specChips.map(({ icon: Icon, label }) => (
                  <span
                    key={label}
                    className="inline-flex items-center gap-1 px-1.5 py-1 rounded-lg bg-primary-soft text-[10px] font-semibold text-primary whitespace-nowrap"
                  >
                    <Icon size={11} className="shrink-0" />
                    {label}
                  </span>
                ))}
              </div>
            )}
            {product.warrantyInfo?.status === 'active' && (
              <span className="inline-flex items-center gap-1 text-[10px] sm:text-xs font-medium text-muted-foreground">
                <ShieldCheck size={12} className="shrink-0 text-primary" />
                {product.warrantyInfo.duration} Warranty
              </span>
            )}
          </div>
        </div>
      </Link>

      <div className="p-2.5 pt-2 sm:p-3 sm:pt-2">
        <Button
          fullWidth
          size="sm"
          variant={justAdded ? 'secondary' : 'primary'}
          onClick={handleCta}
        >
          {justAdded ? (
            <span className="flex items-center gap-1.5">
              <Check size={14} strokeWidth={2.5} /> {ctaLabel}
            </span>
          ) : (
            <span className="flex items-center gap-1.5">
              {ctaLabel} <ArrowRight size={13} strokeWidth={2.5} />
            </span>
          )}
        </Button>
      </div>
    </motion.div>
  )
}
