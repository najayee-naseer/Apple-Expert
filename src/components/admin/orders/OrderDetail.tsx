"use client"

import { useCallback, useEffect, useState } from 'react'
import {
  X, LoaderCircle, AlertCircle, Check, Crown, User, Mail, Phone,
  Package, History, CreditCard, MapPin, Lock, ShieldCheck,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { VipBadge } from '@/components/account/VipBadge'
import { CONDITION_LABEL, snapshotImageUrl } from '@/lib/catalog'
import type { ProductCondition } from '@/types'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import {
  loadOrderDetail, updateOrderStatus, canManageOrders, canViewPayments,
  ORDER_STATUSES, ORDER_STATUS_LABEL, PAYMENT_STATUS_LABEL, SENSITIVE_STATUSES,
  isOrderStatus, STOCK_STATE_LABEL, type AdminOrderDetail, type OrderStatus,
} from '@/lib/admin/orders'
import type { AdminRole } from '@/lib/admin/roles'
import { describeUnitError } from '@/lib/admin/units'
import { OrderUnits } from './OrderUnits'

type Save =
  | { kind: 'idle' }
  | { kind: 'saving' }
  | { kind: 'saved'; message: string; warning: string | null }
  | { kind: 'error'; message: string }

function money(cents: number): string {
  return formatPrice(centsToRupees(cents))
}

function dateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

export function OrderStatusBadge({ status }: { status: string }) {
  const tone =
    status === 'delivered' ? 'border-mint-deep bg-primary-soft text-primary'
    : status === 'cancelled' || status === 'refunded' ? 'border-red-500/25 bg-red-500/8 text-red-500'
    : status === 'pending' ? 'border-amber-500/30 bg-amber-500/10 text-amber-600 dark:text-amber-400'
    : 'border-border bg-muted text-muted-foreground'
  return (
    <span className={cn('inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold whitespace-nowrap', tone)}>
      {isOrderStatus(status) ? ORDER_STATUS_LABEL[status] : status}
    </span>
  )
}

export function TierBadge({ tier }: { tier: string }) {
  if (tier === 'wholesale_vip') return <VipBadge label="Wholesale VIP" />
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-muted px-2.5 py-1 text-[11px] font-semibold whitespace-nowrap text-muted-foreground">
      <User size={12} /> Retail
    </span>
  )
}

function Section({ icon: Icon, title, children, note }: {
  icon: typeof Package; title: string; children: React.ReactNode; note?: string
}) {
  return (
    <section className="bg-surface border border-mint/80 dark:border-border rounded-[22px] shadow-card p-5">
      <h3 className="mb-1 flex items-center gap-2 text-[15px] font-bold tracking-tight text-foreground">
        <Icon size={16} className="text-muted-foreground" /> {title}
      </h3>
      {note && <p className="mb-3 text-[12px] text-muted-foreground leading-relaxed">{note}</p>}
      <div className={note ? '' : 'mt-3'}>{children}</div>
    </section>
  )
}

export function OrderDetail({
  orderId, role, onClose, onChanged,
}: {
  orderId: string
  role: AdminRole | null
  onClose: () => void
  onChanged: () => void
}) {
  const canManage = canManageOrders(role)
  const showPayments = canViewPayments(role)

  const [detail, setDetail] = useState<AdminOrderDetail | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [save, setSave] = useState<Save>({ kind: 'idle' })
  const [nextStatus, setNextStatus] = useState<OrderStatus | ''>('')
  const [note, setNote] = useState('')
  const [confirming, setConfirming] = useState<OrderStatus | null>(null)

  const load = useCallback(() => {
    loadOrderDetail(orderId, showPayments)
      .then(setDetail)
      .catch((err) => setLoadError(err instanceof Error ? err.message : 'Could not load this order.'))
  }, [orderId, showPayments])

  useEffect(() => {
    let cancelled = false
    loadOrderDetail(orderId, showPayments)
      .then((d) => { if (!cancelled) setDetail(d) })
      .catch((err) => { if (!cancelled) setLoadError(err instanceof Error ? err.message : 'Could not load this order.') })
    return () => { cancelled = true }
  }, [orderId, showPayments])

  async function applyStatus(to: OrderStatus) {
    if (!detail) return
    setConfirming(null)
    setSave({ kind: 'saving' })
    try {
      const result = await updateOrderStatus(detail.order.id, detail.order.status, to, note)
      setNote('')
      setNextStatus('')
      load()
      onChanged()
      setSave({
        kind: 'saved',
        message: `Status set to ${ORDER_STATUS_LABEL[to]}.`,
        warning: result.eventRecorded ? null : `The status was saved but the history entry failed: ${result.eventError}`,
      })
    } catch (err) {
      setSave({ kind: 'error', message: describeUnitError(err, 'The database refused the change.') })
    }
  }

  function requestChange() {
    if (!nextStatus) return
    if (SENSITIVE_STATUSES.includes(nextStatus)) { setConfirming(nextStatus); return }
    void applyStatus(nextStatus)
  }

  const busy = save.kind === 'saving'

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label="Order detail"
        className="relative flex h-full w-full max-w-2xl flex-col bg-background border-l border-mint/80 dark:border-border shadow-float">

        <header className="flex items-start gap-3 border-b border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">
              {detail ? detail.order.order_number : 'Loading…'}
            </h2>
            {detail && (
              <p className="mt-1 flex flex-wrap items-center gap-2">
                <OrderStatusBadge status={detail.order.status} />
                <TierBadge tier={detail.order.customer_type_at_purchase} />
                <span className="text-[11px] text-muted-foreground">{dateTime(detail.order.placed_at)}</span>
              </p>
            )}
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
          {!detail && !loadError && (
            <div className="flex items-center justify-center gap-2.5 py-10 text-sm text-muted-foreground">
              <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading order…
            </div>
          )}
          {loadError && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
              <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[13px] text-foreground">{loadError}</p>
            </div>
          )}

          {detail && (
            <>
              <Section icon={User} title="Customer">
                <div className="space-y-1.5">
                  <p className="text-sm font-semibold text-foreground">
                    {detail.customer?.full_name || <span className="font-normal text-muted-foreground">No name on file</span>}
                  </p>
                  {detail.customer?.email && (
                    <p className="flex items-center gap-1.5 text-[13px] text-muted-foreground">
                      <Mail size={12} className="shrink-0" /> {detail.customer.email}
                    </p>
                  )}
                  {detail.customer?.phone && (
                    <p className="flex items-center gap-1.5 text-[13px] text-muted-foreground">
                      <Phone size={12} className="shrink-0" /> {detail.customer.phone}
                    </p>
                  )}
                  {/* The tier recorded on the order, i.e. what this order was priced at. */}
                  <p className="flex flex-wrap items-center gap-2 pt-1 text-[12px] text-muted-foreground">
                    Customer type at purchase <TierBadge tier={detail.order.customer_type_at_purchase} />
                  </p>
                </div>
                {detail.order.shipping_address && (
                  <div className="mt-3 flex items-start gap-2 rounded-xl border border-mint/70 dark:border-border bg-card px-3 py-2.5">
                    <MapPin size={13} className="mt-0.5 shrink-0 text-muted-foreground" />
                    <pre className="min-w-0 flex-1 whitespace-pre-wrap break-words font-sans text-[12px] text-muted-foreground">
                      {JSON.stringify(detail.order.shipping_address, null, 2)}
                    </pre>
                  </div>
                )}
              </Section>

              <Section icon={Package} title="Items"
                note="Exactly what was purchased, as recorded at the time of the order. These figures are never re-read from the current catalog.">
                {detail.items.length === 0 && <p className="text-[13px] text-muted-foreground">No line items recorded.</p>}
                <ul className="space-y-2.5">
                  {detail.items.map((item) => (
                    <li key={item.id} className="flex items-start gap-3 rounded-2xl border border-mint/70 dark:border-border bg-card p-3">
                      <span className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-xl border border-mint/60 dark:border-border bg-well-cool">
                        {item.image_path_snapshot
                          ? <img src={snapshotImageUrl(item.image_path_snapshot)} alt="" className="h-full w-full object-contain mix-blend-multiply dark:mix-blend-normal" />
                          : <Package size={18} className="text-primary/40" />}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-[13.5px] font-semibold leading-tight text-foreground">{item.product_name_snapshot}</p>
                        {item.variant_label_snapshot && (
                          <p className="text-[12px] text-muted-foreground">{item.variant_label_snapshot}</p>
                        )}
                        {item.condition_snapshot && item.condition_snapshot !== 'brand_new' && (
                          <p className="text-[12px] text-amber-700 dark:text-amber-400">
                            {CONDITION_LABEL[item.condition_snapshot as ProductCondition] ?? item.condition_snapshot}
                            {item.condition_grade_snapshot && ` · ${item.condition_grade_snapshot}`}
                          </p>
                        )}
                        {item.warranty_label_snapshot && (
                          <p className="mt-1 text-[12px] text-muted-foreground tabular-nums">
                            {item.base_unit_price_cents !== null && <>Base {money(item.base_unit_price_cents)} · </>}
                            {item.warranty_label_snapshot}{' '}
                            {item.warranty_price_cents_snapshot === 0 ? '(included)' : `+${money(item.warranty_price_cents_snapshot)}`}
                          </p>
                        )}
                        <p className="mt-1 text-[12px] text-muted-foreground tabular-nums">
                          {item.quantity} × {money(item.unit_price_cents)}
                          {item.tier_code_snapshot === 'wholesale_vip' && (
                            <span className="ml-2 text-primary font-medium">VIP price</span>
                          )}
                        </p>
                      </div>
                      <span className="shrink-0 text-[14px] font-bold tabular-nums text-foreground">
                        {money(item.line_total_cents)}
                      </span>
                    </li>
                  ))}
                </ul>
              </Section>

              <div className="rounded-[22px] border border-mint/80 dark:border-border bg-surface px-5 py-3.5 shadow-card text-[13px]">
                <span className="font-semibold text-foreground">Stock: </span>
                <span className="text-muted-foreground">{STOCK_STATE_LABEL[detail.order.stock_state] ?? detail.order.stock_state}</span>
                {detail.order.reservation_expires_at && (
                  <span className="block text-[12px] text-muted-foreground">
                    Released automatically on {new Date(detail.order.reservation_expires_at).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })} unless confirmed.
                  </span>
                )}
              </div>

              <OrderUnits orderId={detail.order.id} version={detail.order.status} />

              <Section icon={ShieldCheck} title="Totals"
                note="Stored with the order. Never recalculated from current prices.">
                <dl className="space-y-1.5 text-sm">
                  <div className="flex justify-between"><dt className="text-muted-foreground">Subtotal</dt>
                    <dd className="tabular-nums text-foreground">{money(detail.order.subtotal_cents)}</dd></div>
                  <div className="flex justify-between"><dt className="text-muted-foreground">Delivery</dt>
                    <dd className="tabular-nums text-foreground">{money(detail.order.delivery_cents)}</dd></div>
                  {detail.order.discount_cents > 0 && (
                    <div className="flex justify-between"><dt className="text-muted-foreground">Discount</dt>
                      <dd className="tabular-nums text-primary">−{money(detail.order.discount_cents)}</dd></div>
                  )}
                  <div className="flex justify-between border-t border-mint-deep pt-2 mt-2 text-base font-bold">
                    <dt>Total</dt><dd className="tabular-nums">{money(detail.order.total_cents)}</dd>
                  </div>
                </dl>
              </Section>

              {showPayments ? (
                <Section icon={CreditCard} title="Payments" note="Read-only. No payment can be created or altered here.">
                  {detail.payments.length === 0 && <p className="text-[13px] text-muted-foreground">No payment records.</p>}
                  <ul className="space-y-2">
                    {detail.payments.map((p) => (
                      <li key={p.id} className="flex items-center justify-between gap-3 rounded-xl border border-mint/70 dark:border-border bg-card px-3 py-2.5">
                        <div className="min-w-0">
                          <p className="text-[13px] font-semibold text-foreground">{p.provider}</p>
                          {p.provider_ref && <p className="truncate font-mono text-[11px] text-muted-foreground">{p.provider_ref}</p>}
                          <p className="text-[11px] text-muted-foreground">{dateTime(p.created_at)}</p>
                        </div>
                        <div className="shrink-0 text-right">
                          <p className="text-[13px] font-bold tabular-nums text-foreground">{money(p.amount_cents)}</p>
                          <p className="text-[11px] text-muted-foreground">{PAYMENT_STATUS_LABEL[p.status] ?? p.status}</p>
                        </div>
                      </li>
                    ))}
                  </ul>
                </Section>
              ) : (
                <Section icon={CreditCard} title="Payments">
                  <p className="flex items-start gap-2 text-[13px] text-muted-foreground">
                    <Lock size={13} className="mt-0.5 shrink-0" />
                    Payment records are visible to administrators only.
                  </p>
                </Section>
              )}

              <Section icon={History} title="History">
                {detail.events.length === 0 && (
                  <p className="text-[13px] text-muted-foreground">No status changes recorded yet.</p>
                )}
                <ol className="space-y-2">
                  {detail.events.map((e) => (
                    <li key={e.id} className="rounded-xl border border-mint/70 dark:border-border bg-card px-3 py-2.5">
                      <p className="text-[13px] text-foreground">
                        {e.from_status
                          ? <>{isOrderStatus(e.from_status) ? ORDER_STATUS_LABEL[e.from_status] : e.from_status} → </>
                          : null}
                        <span className="font-semibold">
                          {isOrderStatus(e.to_status) ? ORDER_STATUS_LABEL[e.to_status] : e.to_status}
                        </span>
                      </p>
                      {e.note && <p className="mt-0.5 text-[12px] text-muted-foreground">{e.note}</p>}
                      <p className="mt-0.5 text-[11px] text-muted-foreground">{dateTime(e.created_at)}</p>
                    </li>
                  ))}
                </ol>
              </Section>
            </>
          )}
        </div>

        {detail && (
          <footer className="border-t border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
            {save.kind === 'error' && (
              <div className="mb-3 flex items-start gap-2 rounded-xl border border-red-500/25 bg-red-500/8 px-3 py-2">
                <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
                <p className="text-[12.5px] text-foreground">{save.message}</p>
              </div>
            )}
            {save.kind === 'saved' && (
              <div className={cn('mb-3 flex items-start gap-2 rounded-xl px-3 py-2 border',
                save.warning ? 'border-amber-500/30 bg-amber-500/10' : 'border-mint-deep bg-primary-soft')}>
                {save.warning
                  ? <AlertCircle size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
                  : <Check size={15} className="mt-0.5 shrink-0 text-primary" />}
                <p className={cn('text-[12.5px] font-medium', save.warning ? 'text-foreground' : 'text-primary')}>
                  {save.warning ?? save.message}
                </p>
              </div>
            )}

            {canManage ? (
              <div className="flex flex-col sm:flex-row gap-2.5">
                <select
                  aria-label="New status" value={nextStatus} disabled={busy}
                  onChange={(e) => { setNextStatus(e.target.value as OrderStatus | ''); setSave({ kind: 'idle' }) }}
                  className="focus-ring h-11 flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 text-sm text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60">
                  <option value="">Change status…</option>
                  {ORDER_STATUSES.filter((s) => s !== detail.order.status).map((s) => (
                    <option key={s} value={s}>{ORDER_STATUS_LABEL[s]}</option>
                  ))}
                </select>
                <input
                  type="text" value={note} disabled={busy} placeholder="Note (optional)" aria-label="Status note"
                  onChange={(e) => setNote(e.target.value)}
                  className="focus-ring h-11 flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
                <Button onClick={requestChange} disabled={busy || !nextStatus}>
                  {busy ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</> : 'Update'}
                </Button>
              </div>
            ) : (
              <p className="flex items-center gap-2 text-[12.5px] text-muted-foreground">
                <Lock size={13} className="shrink-0" /> Your role cannot change order status.
              </p>
            )}
          </footer>
        )}
      </div>

      {confirming && (
        <div className="absolute inset-0 z-10 flex items-center justify-center px-5">
          <button type="button" aria-label="Cancel" onClick={() => setConfirming(null)}
            className="absolute inset-0 bg-black/55" />
          <div role="dialog" aria-modal="true"
            className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float">
            <h2 className="text-lg font-bold tracking-tight text-foreground mb-2">
              Mark this order {ORDER_STATUS_LABEL[confirming].toLowerCase()}?
            </h2>
            <p className="text-sm text-muted-foreground leading-relaxed mb-5">
              {detail?.order.order_number} will be set to{' '}
              <strong className="text-foreground">{ORDER_STATUS_LABEL[confirming]}</strong>. The order
              total and the purchased items are not changed, and the transition is recorded in the history.
              {' '}{detail && ['consumed', 'legacy_done', 'needs_reconciliation'].includes(detail.order.stock_state)
                ? 'This order has shipped, so stock is not restored and no money moves: record a customer return when the goods come back, and a refund when money goes back.'
                : 'If it holds stock, that stock is released.'}
            </p>
            <div className="flex gap-2.5">
              <Button variant="ghost" fullWidth onClick={() => setConfirming(null)}>Cancel</Button>
              <Button fullWidth onClick={() => void applyStatus(confirming)}>
                {ORDER_STATUS_LABEL[confirming]}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
