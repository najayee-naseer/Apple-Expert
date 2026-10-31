"use client"
import { formatPrice } from '@/utils/formatPrice'

import { useRef, useState } from 'react'
import Link from 'next/link'
import { Header } from '@/components/ui/Header'
import { Button } from '@/components/ui/Button'
import { useCart } from '@/context/CartContext'
import { useWishlist } from '@/context/WishlistContext'
import { useCustomerAuth } from '@/context/CustomerAuthContext'
import { VipBadge } from '@/components/account/VipBadge'
import { motion, AnimatePresence } from 'framer-motion'
import { Minus, Plus, Trash2, ShoppingBag, Star, Heart, ArrowRight, Box, ShieldCheck, AlertCircle, LoaderCircle, CheckCircle2 } from 'lucide-react'
import type { CartItem } from '@/types'
import { ConditionChip } from '@/components/product/ProductConditionWarranty'
import { cartOrderKey, newOrderRequestId, placeOrder, type PlacedOrder } from '@/lib/customer/orders'
import { centsToRupees, useCatalogProduct } from '@/lib/catalog'

/**
 * The one line under the product name that tells the customer exactly which
 * thing they picked. Built only from fields that exist on the item — a chosen
 * variant's storage and colour, or, for a replacement part, the model it fits.
 * Nothing here is invented.
 */
function describeSelection(item: CartItem): string | null {
  if (item.variant) {
    const parts = [item.variant.storage, item.variant.color].filter(Boolean)
    return parts.length > 0 ? parts.join(' · ') : item.variant.name
  }
  const fits = item.product.model ?? item.product.compatibility?.[0]
  if (fits) return `For ${fits}`
  if (item.product.subcategory && item.product.subcategory !== 'Devices') {
    return item.product.subcategory
  }
  return null
}

/** Studio shots sit on a white sweep and need multiply to dissolve into the
 *  well; lifestyle photography fills the frame instead. */
function fillsFrame(src?: string): boolean {
  return !(src?.startsWith('/images/products/iphone/') ?? false)
}

function CartItemCard({ item }: { item: CartItem }) {
  const { removeFromCart, updateQuantity, unitPrice: resolveUnitPrice, warrantyFor } = useCart()
  const { isWishlisted, toggleWishlist } = useWishlist()

  // Resolved from the live catalog, not from the copy frozen into localStorage
  // when the line was added, so the cart agrees with the card and the detail page.
  const unitPrice = resolveUnitPrice(item)
  const warranty = warrantyFor(item)
  const liveProduct = useCatalogProduct(item.product.id)
  const liveVariant = item.variant ? liveProduct?.variants?.find((v) => v.id === item.variant!.id) : undefined
  const lineTotal = unitPrice * item.quantity
  // What can be bought of this exact option right now. undefined until live data loads.
  const available = liveVariant?.available ?? (item.variant ? undefined : liveProduct?.stock)
  const selection = describeSelection(item)
  const wishlisted = isWishlisted(item.product.id)
  const src = item.product.images[0]
  const cover = fillsFrame(src)

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.96 }}
      transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
      className="bg-surface border border-mint/80 dark:border-border rounded-[26px] p-3 shadow-card"
    >
      {/* Exactly what was selected — the model's own photograph */}
      <div className={`relative w-full aspect-[16/10] bg-well-cool rounded-[20px] overflow-hidden border border-mint/60 dark:border-border ${cover ? '' : 'p-2.5'} flex items-center justify-center`}>
        {src ? (
          <img
            src={src}
            alt={item.product.name}
            className={`w-full h-full ${cover ? 'object-cover' : 'object-contain mix-blend-multiply dark:mix-blend-normal'}`}
          />
        ) : (
          <Box size={36} strokeWidth={1.5} className="text-primary/40" />
        )}
        <div className="absolute top-2 left-2 inline-flex items-center gap-1 pl-1.5 pr-2 py-1 rounded-full bg-white/92 dark:bg-black/50 backdrop-blur-sm border border-white/70 dark:border-white/10 shadow-card">
          <Star size={10} className="text-amber-400 shrink-0" fill="currentColor" />
          <span className="text-[10px] font-bold leading-none text-foreground">{item.product.rating}</span>
        </div>
      </div>

      <div className="pt-3 px-1">
        <div className="flex items-start gap-2">
          <h3 className="flex-1 min-w-0 font-semibold text-[15px] leading-tight text-foreground line-clamp-2">
            {item.product.name}
          </h3>
          <button
            type="button"
            onClick={() => toggleWishlist(item.product.id)}
            aria-label={wishlisted ? 'Remove from wishlist' : 'Save to wishlist'}
            aria-pressed={wishlisted}
            className="shrink-0 w-9 h-9 -mt-1 rounded-full bg-card border border-mint/70 dark:border-border shadow-card flex items-center justify-center active:scale-90 transition-transform"
          >
            <Heart
              size={15}
              strokeWidth={2.2}
              className={wishlisted ? 'text-rose-500' : 'text-primary/70'}
              fill={wishlisted ? 'currentColor' : 'none'}
            />
          </button>
        </div>

        {selection && (
          <p className="flex items-center gap-1.5 text-xs text-muted-foreground mt-1 min-w-0">
            {item.variant?.colorCode && (
              <span
                className="w-3 h-3 rounded-full border border-mint-deep shrink-0"
                style={{ backgroundColor: item.variant.colorCode }}
                aria-hidden="true"
              />
            )}
            <span className="truncate">{selection}</span>
          </p>
        )}

        {/* The line's own variant's condition, read live — never the product's. */}
        <ConditionChip product={liveProduct ?? item.product} variant={liveVariant ?? item.variant} className="mt-1.5" />

        {available !== undefined && available < item.quantity && (
          <p className="mt-1.5 flex items-center gap-1.5 text-xs text-red-500">
            <AlertCircle size={13} className="shrink-0" />
            <span>{available <= 0 ? 'This option is out of stock' : `Only ${available} of this option available`}</span>
          </p>
        )}

        {warranty && (
          <p className={`mt-1.5 flex items-center gap-1.5 text-xs ${warranty.unavailable ? 'text-red-500' : 'text-muted-foreground'}`}>
            {warranty.unavailable
              ? <AlertCircle size={13} className="shrink-0" />
              : <ShieldCheck size={13} className="shrink-0 text-primary" />}
            <span className="truncate">
              {warranty.unavailable
                ? `${warranty.label} is no longer offered — remove this item and choose again`
                : `${warranty.label} · ${warranty.addOn === 0 ? 'Included' : `+${formatPrice(warranty.addOn)}`}`}
            </span>
          </p>
        )}

        <div className="flex items-end justify-between gap-2 mt-3">
          <div className="min-w-0">
            {item.quantity > 1 && (
              <span className="block text-[10px] text-muted-foreground leading-none mb-1">
                {formatPrice(unitPrice)} each
              </span>
            )}
            <span className="block font-bold tracking-tight text-[17px] text-foreground truncate">
              {formatPrice(lineTotal)}
            </span>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <div className="flex items-center bg-primary-soft border border-mint-deep rounded-full p-1">
              <button
                onClick={() => updateQuantity(item.id, item.quantity - 1)}
                disabled={item.quantity <= 1}
                aria-label={`Decrease quantity of ${item.product.name}`}
                className="w-7 h-7 rounded-full text-primary flex items-center justify-center hover:bg-card active:scale-90 disabled:opacity-40 transition-all"
              >
                <Minus size={14} />
              </button>
              <span className="w-7 text-center font-semibold text-sm text-foreground tabular-nums">{item.quantity}</span>
              <button
                onClick={() => updateQuantity(item.id, item.quantity + 1)}
                disabled={available !== undefined && item.quantity >= available}
                aria-label={`Increase quantity of ${item.product.name}`}
                className="w-7 h-7 rounded-full text-primary flex items-center justify-center hover:bg-card active:scale-90 transition-all"
              >
                <Plus size={14} />
              </button>
            </div>
            <button
              onClick={() => removeFromCart(item.id)}
              aria-label={`Remove ${item.product.name} from bag`}
              className="w-9 h-9 rounded-full text-muted-foreground hover:text-red-500 hover:bg-red-500/8 active:scale-90 transition-all flex items-center justify-center"
            >
              <Trash2 size={16} />
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  )
}

export default function CartPage() {
  const { cart, cartTotal, cartCount, clearCart, warrantyFor } = useCart()
  const { isWholesaleVip } = useCustomerAuth()
  const [placing, setPlacing] = useState(false)
  const [orderError, setOrderError] = useState<string | null>(null)
  const [placed, setPlaced] = useState<PlacedOrder | null>(null)

  const blocked = cart.some((item) => warrantyFor(item)?.unavailable)
  // One request id per basket: retrying the same basket can never order it twice.
  const orderRequest = useRef<{ key: string; id: string } | null>(null)

  /** The database prices every line again; the total it returns is the one recorded. */
  async function submitOrder() {
    setPlacing(true)
    setOrderError(null)
    try {
      const key = cartOrderKey(cart)
      if (orderRequest.current?.key !== key) orderRequest.current = { key, id: newOrderRequestId() }
      const order = await placeOrder(cart, orderRequest.current.id)
      orderRequest.current = null
      clearCart()
      setPlaced(order)
    } catch (err) {
      setOrderError(err instanceof Error ? err.message : 'Your order could not be placed. Please try again.')
    } finally {
      setPlacing(false)
    }
  }

  if (placed) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <div className="w-24 h-24 rounded-full bg-well-cool border border-mint-deep shadow-card flex items-center justify-center mb-6">
            <CheckCircle2 size={40} strokeWidth={1.6} className="text-primary" />
          </div>
          <h1 className="text-[22px] font-bold tracking-tight mb-1.5">Order placed</h1>
          <p className="text-sm text-muted-foreground mb-1">Order {placed.orderNumber}</p>
          <p className="text-lg font-bold tracking-tight mb-2">{formatPrice(centsToRupees(placed.totalCents))}</p>
          <p className="text-[13px] text-muted-foreground mb-8 max-w-xs leading-relaxed">
            We are holding your items and will contact you to confirm delivery and payment. Orders not confirmed within 48 hours are released.
          </p>
          <div className="flex w-full max-w-xs flex-col gap-2.5">
            <Link href="/orders"><Button fullWidth size="lg">View my orders</Button></Link>
            <Link href="/categories"><Button fullWidth variant="secondary">Continue shopping</Button></Link>
          </div>
        </main>
      </div>
    )
  }

  if (cart.length === 0) {
    return (
      <div className="flex flex-col min-h-screen">
        <Header />
        <main className="flex-1 flex flex-col items-center justify-center text-center px-6 py-16">
          <div className="w-28 h-28 rounded-full bg-well-cool border border-mint-deep shadow-card flex items-center justify-center mb-7">
            <ShoppingBag size={40} strokeWidth={1.5} className="text-primary" />
          </div>
          <h1 className="text-[22px] font-bold tracking-tight mb-2">Your cart is empty</h1>
          <p className="text-sm text-muted-foreground mb-8 max-w-xs leading-relaxed">
            Browse Apple devices, genuine replacement parts and accessories, then add them here to check out.
          </p>
          <Link href="/categories" className="w-full max-w-xs">
            <Button fullWidth size="lg" className="h-13">
              Continue Shopping <ArrowRight size={18} className="ml-1.5" />
            </Button>
          </Link>
        </main>
      </div>
    )
  }

  return (
    <div className="flex flex-col min-h-screen pb-36">
      <Header />

      <main className="px-4 py-6">
        <div className="mb-5">
          <h1 className="text-[28px] sm:text-[34px] font-bold tracking-tight leading-tight text-foreground">
            Review your bag.
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            {cartCount} {cartCount === 1 ? 'item' : 'items'} · every model exactly as you picked it.
          </p>
        </div>

        <div className="space-y-3.5">
          <AnimatePresence initial={false}>
            {cart.map(item => (
              <CartItemCard key={item.id} item={item} />
            ))}
          </AnimatePresence>
        </div>

        {/* Order summary — only figures that actually exist */}
        <div className="mt-5 bg-surface border border-mint/80 dark:border-border rounded-[26px] p-5 shadow-card">
          {/* A label only: every line above is already priced by the database
              for this account (my_effective_prices), never on this device. */}
          {isWholesaleVip && (
            <div className="flex flex-wrap items-center gap-2 mb-4 pb-4 border-b border-mint/70 dark:border-border">
              <VipBadge />
              <span className="text-[12px] text-muted-foreground">Wholesale VIP pricing applied where set</span>
            </div>
          )}
          <div className="flex justify-between items-center mb-3 text-sm text-muted-foreground">
            <span>Subtotal</span>
            <span className="font-semibold text-foreground">{formatPrice(cartTotal)}</span>
          </div>
          <div className="flex justify-between items-center mb-4 text-sm text-muted-foreground">
            <span>Delivery</span>
            <span className="font-semibold text-primary">Free</span>
          </div>
          <div className="flex justify-between items-center text-lg font-bold pt-4 border-t border-mint-deep">
            <span>Total</span>
            <span>{formatPrice(cartTotal)}</span>
          </div>
          <p className="mt-3 text-[11.5px] leading-relaxed text-muted-foreground">
            Prices and warranty add-ons are confirmed by our system when you place the order.
          </p>
        </div>

        {orderError && (
          <div role="alert" className="mt-4 flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
            <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
            <p className="text-[13px] text-foreground">{orderError}</p>
          </div>
        )}
      </main>

      {/* Floating purchase panel — sits above the bottom navigation, sharing its
          geometry tokens so the two can never overlap. */}
      <div
        className="fixed left-3 right-3 z-40 mx-auto w-auto max-w-[456px]"
        style={{ bottom: 'calc(var(--nav-offset) + 0.5rem)' }}
      >
        {/* Restrained green glow that bleeds softly beyond the panel's edges. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-x-3 -top-2 bottom-2 -z-10 rounded-[32px] bg-primary-bright/20 blur-xl dark:bg-primary-bright/10"
        />
        <div className="rounded-[26px] border border-primary/25 dark:border-primary/15 bg-purchase shadow-purchase p-3">
          <div className="flex items-center gap-2">
            <div className="min-w-0 flex-1">
              <span className="block text-[11px] font-medium text-foreground/70 dark:text-muted-foreground leading-none mb-1">Total</span>
              <span className="block text-[17px] min-[360px]:text-[19px] font-bold tracking-tight text-[var(--purchase-price)] dark:text-foreground truncate">
                {formatPrice(cartTotal)}
              </span>
            </div>

            <Link
              href="/categories"
              aria-label="Continue shopping"
              className="relative shrink-0 w-11 h-11 min-[360px]:w-12 min-[360px]:h-12 rounded-2xl bg-foreground text-background flex items-center justify-center shadow-card active:scale-95 transition-transform"
            >
              <ShoppingBag size={19} strokeWidth={2} />
              <span className="absolute -top-1 -right-1 bg-gradient-cta text-white text-[10px] font-bold h-5 min-w-5 px-1 rounded-full flex items-center justify-center border-2 border-background">
                {cartCount > 99 ? '99+' : cartCount}
              </span>
            </Link>

            <Button
              size="lg"
              disabled={placing || blocked}
              onClick={() => void submitOrder()}
              className="shrink-0 h-11 min-[360px]:h-12 px-5 min-[360px]:px-6 text-[15px] bg-gradient-cta-deep hover:bg-gradient-cta-deep-hover shadow-purchase-cta hover:shadow-purchase-cta-hover"
            >
              {placing
                ? <><LoaderCircle size={16} className="mr-1.5 animate-spin motion-reduce:animate-none" />Placing…</>
                : 'Place order'}
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
