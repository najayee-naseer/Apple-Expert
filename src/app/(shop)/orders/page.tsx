"use client"

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { AlertCircle, ChevronDown, LoaderCircle, MapPin, Package, RotateCw, ShieldCheck } from 'lucide-react'
import { Header } from '@/components/ui/Header'
import { Button } from '@/components/ui/Button'
import { VipBadge } from '@/components/account/VipBadge'
import { DeliverySnapshotLines } from '@/components/account/AddressCard'
import { deliveryPlace, type DeliverySnapshot } from '@/lib/customer/addresses'
import { listMyOrders, type MyOrder } from '@/lib/customer/orders'
import { centsToRupees, CONDITION_LABEL } from '@/lib/catalog'
import { formatPrice } from '@/utils/formatPrice'
import type { ProductCondition } from '@/types'

/**
 * The customer's own orders, read under "orders read own".
 *
 * Every figure is the snapshot place_order() wrote — base price, warranty
 * add-on, condition — so an order reads exactly as it was placed even after
 * the product or its warranty prices change.
 */

const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending', confirmed: 'Confirmed', processing: 'Processing', shipped: 'Shipped',
  delivered: 'Delivered', cancelled: 'Cancelled', refunded: 'Refunded',
}

function rupees(cents: number): string {
  return formatPrice(centsToRupees(cents))
}

/** The order's own copy of the address, never whatever is saved in the account today. */
function OrderDelivery({ delivery }: { delivery: DeliverySnapshot | null }) {
  const [open, setOpen] = useState(false)

  if (!delivery) {
    return (
      <p className="mb-3 flex items-center gap-1.5 text-[12px] text-muted-foreground">
        <MapPin size={13} className="shrink-0" /> No delivery address was recorded for this order.
      </p>
    )
  }

  return (
    <div className="mb-3">
      <button type="button" aria-expanded={open} onClick={() => setOpen((v) => !v)}
        className="focus-ring -mx-1 flex min-h-11 w-[calc(100%+0.5rem)] items-center gap-1.5 rounded-xl px-1 text-left text-[12.5px] text-muted-foreground hover:bg-primary-soft/60">
        <MapPin size={13} className="shrink-0 text-primary" />
        <span className="min-w-0 flex-1 truncate">Delivering to <span className="font-semibold text-foreground">{deliveryPlace(delivery)}</span></span>
        <span className="shrink-0 font-semibold text-primary">{open ? 'Hide' : 'View address'}</span>
        <ChevronDown size={14} className={`shrink-0 text-primary transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="mt-1.5 rounded-xl bg-muted/60 px-3 py-2.5">
          <DeliverySnapshotLines snapshot={delivery} />
        </div>
      )}
    </div>
  )
}

export default function OrdersPage() {
  const [orders, setOrders] = useState<MyOrder[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let cancelled = false
    listMyOrders()
      .then((rows) => { if (!cancelled) { setOrders(rows); setError(null) } })
      .catch((err) => { if (!cancelled) setError(err instanceof Error ? err.message : 'Could not load your orders.') })
    return () => { cancelled = true }
  }, [attempt])

  return (
    <div className="flex flex-col min-h-screen pb-10">
      <Header />
      <main className="px-4 py-6">
        <h1 className="mb-1 text-[28px] font-bold leading-tight tracking-tight">My Orders</h1>
        <p className="mb-5 text-sm text-muted-foreground">Every order exactly as it was placed.</p>

        {error && (
          <div className="flex items-center justify-between gap-3 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
            <p className="flex items-center gap-2 text-[13px] text-foreground">
              <AlertCircle size={15} className="shrink-0 text-red-500" /> {error}
            </p>
            <button type="button" onClick={() => { setError(null); setOrders(null); setAttempt((n) => n + 1) }}
              className="focus-ring inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-[13px] font-semibold text-primary">
              <RotateCw size={14} /> Retry
            </button>
          </div>
        )}

        {!orders && !error && (
          <div className="flex items-center justify-center gap-2.5 py-16 text-sm text-muted-foreground">
            <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading your orders…
          </div>
        )}

        {orders && orders.length === 0 && (
          <div className="flex flex-col items-center py-14 text-center">
            <span className="mb-4 flex h-16 w-16 items-center justify-center rounded-full border border-mint-deep bg-well-cool text-primary shadow-card">
              <Package size={26} strokeWidth={1.6} />
            </span>
            <p className="mb-6 text-sm text-muted-foreground">You have not placed an order yet.</p>
            <Link href="/categories"><Button>Start shopping</Button></Link>
          </div>
        )}

        <div className="space-y-3.5">
          {orders?.map((order) => (
            <article key={order.id} className="rounded-[26px] border border-mint/80 dark:border-border bg-surface p-4 shadow-card">
              <header className="mb-3 flex flex-wrap items-center gap-2">
                <h2 className="text-[15px] font-bold tracking-tight">{order.orderNumber}</h2>
                <span className="rounded-full border border-mint-deep bg-primary-soft px-2 py-0.5 text-[11px] font-semibold text-primary">
                  {STATUS_LABEL[order.status] ?? order.status}
                </span>
                <span className="ml-auto text-[11.5px] text-muted-foreground">
                  {new Date(order.placedAt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
                </span>
              </header>

              <p className="mb-3 flex items-center gap-2 text-[12px] text-muted-foreground">
                Customer type:
                {order.customerType === 'wholesale_vip'
                  ? <VipBadge size="sm" label="Wholesale VIP" />
                  : <span className="font-semibold text-foreground">Retail</span>}
              </p>

              <OrderDelivery delivery={order.delivery} />

              <ul className="divide-y divide-mint/70 dark:divide-border">
                {order.lines.map((line) => (
                  <li key={line.id} className="py-3 first:pt-0 last:pb-0">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-[14px] font-semibold leading-tight">{line.productName}</p>
                        <p className="mt-0.5 text-[12px] text-muted-foreground">
                          {[line.variantLabel,
                            line.condition && line.condition !== 'brand_new'
                              ? CONDITION_LABEL[line.condition as ProductCondition] ?? line.condition
                              : null,
                            line.conditionGrade,
                            `Qty ${line.quantity}`,
                          ].filter(Boolean).join(' · ')}
                        </p>
                      </div>
                      <span className="shrink-0 text-[14px] font-bold">{rupees(line.lineTotalCents)}</span>
                    </div>
                    {line.warrantyLabel && (
                      <dl className="mt-2 space-y-0.5 rounded-xl bg-muted/60 px-3 py-2 text-[12px]">
                        {line.basePriceCents !== null && (
                          <div className="flex justify-between">
                            <dt className="text-muted-foreground">Base price</dt>
                            <dd>{rupees(line.basePriceCents)}</dd>
                          </div>
                        )}
                        <div className="flex justify-between">
                          <dt className="flex items-center gap-1 text-muted-foreground">
                            <ShieldCheck size={12} className="text-primary" /> {line.warrantyLabel}
                          </dt>
                          <dd>{line.warrantyPriceCents === 0 ? 'Included' : `+${rupees(line.warrantyPriceCents)}`}</dd>
                        </div>
                        <div className="flex justify-between font-semibold">
                          <dt>Unit price</dt>
                          <dd>{rupees(line.unitPriceCents)}</dd>
                        </div>
                      </dl>
                    )}
                  </li>
                ))}
              </ul>

              <footer className="mt-3 flex justify-between border-t border-mint-deep pt-3 text-[15px] font-bold">
                <span>Total</span>
                <span>{rupees(order.totalCents)}</span>
              </footer>
            </article>
          ))}
        </div>
      </main>
    </div>
  )
}
