"use client"

import { useEffect, useState } from 'react'
import {
  X, LoaderCircle, AlertCircle, Crown, User, Mail, Phone, CalendarDays,
  ShoppingCart, ShieldCheck, Lock, BadgeCheck, KeyRound,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { OrderStatusBadge } from '@/components/admin/orders/OrderDetail'
import { canManageVip, setCustomerType, vipStatus } from '@/lib/admin/customers'
import {
  ACCOUNT_ROLES, ACCOUNT_ROLE_LABEL, ACCOUNT_STATUS_NOTE, canManageRoles,
  displayRole, listRecentOrdersForUser, setUserRole,
  type AccountRole, type AdminUser, type RecentOrder,
} from '@/lib/admin/users'
import type { AdminRole } from '@/lib/admin/roles'
import { CustomerTypeBadge, RoleBadge } from './badges'

type Busy =
  | { kind: 'idle' }
  | { kind: 'working' }
  | { kind: 'error'; message: string }

/** What the user is being asked to confirm before it is applied. */
type Pending =
  | { kind: 'vip'; grant: boolean }
  | { kind: 'role'; next: AccountRole }

function dateOnly(iso: string): string {
  return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

function dateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

function Section({ icon: Icon, title, children, note }: {
  icon: typeof User
  title: string
  children: React.ReactNode
  note?: string
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

/** Label/value row used throughout the profile summary. */
function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5 py-2 border-b border-mint/50 dark:border-border/70 last:border-0">
      <dt className="text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">{label}</dt>
      <dd className="min-w-0 text-right text-[13px] text-foreground">{children}</dd>
    </div>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex-1 rounded-xl border border-mint/70 dark:border-border bg-card px-3.5 py-3">
      <span className="block text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
        {label}
      </span>
      <span className="mt-1 block text-[20px] font-bold tracking-tight tabular-nums text-foreground leading-none">
        {value}
      </span>
    </div>
  )
}

export function UserDetail({
  user, viewerRole, viewerId, ownerCount, rolesVisible, onClose, onChanged, onToast,
}: {
  user: AdminUser
  viewerRole: AdminRole | null
  viewerId: string | null
  /** Owner grants currently visible, used to refuse demoting the last one. */
  ownerCount: number
  /** False when RLS did not return other people's grants (migration 15 missing). */
  rolesVisible: boolean
  onClose: () => void
  onChanged: () => void
  onToast: (message: string) => void
}) {
  const manageVip = canManageVip(viewerRole)
  const manageRoles = canManageRoles(viewerRole)

  const [orders, setOrders] = useState<RecentOrder[] | null>(null)
  const [ordersError, setOrdersError] = useState<string | null>(null)
  const [busy, setBusy] = useState<Busy>({ kind: 'idle' })
  const [pending, setPending] = useState<Pending | null>(null)

  // State is written only from the promise callbacks, never synchronously here.
  useEffect(() => {
    let cancelled = false
    listRecentOrdersForUser(user.id)
      .then((rows) => { if (!cancelled) setOrders(rows) })
      .catch((err) => {
        if (!cancelled) {
          setOrdersError(err instanceof Error ? err.message : 'Could not load this customer’s orders.')
        }
      })
    return () => { cancelled = true }
  }, [user.id])

  const label = user.full_name || user.email || 'This user'
  const status = vipStatus(user)
  const isVip = user.customer_type === 'wholesale_vip'
  const current = displayRole(user)

  // An owner demoting themselves, or the last owner being demoted, would leave
  // the store with no one able to grant a role ever again — there is no server
  // or service-role key in this deployment to repair it from. The database
  // refuses it too; this is the copy that explains why before it is attempted.
  const isSelf = user.id === viewerId
  const isLastOwner = current === 'owner' && ownerCount <= 1

  function roleBlockedReason(next: AccountRole): string | null {
    if (next === current) return null
    if (isSelf) return 'You cannot change your own role. Ask another owner to do it.'
    if (isLastOwner) return 'This is the only owner. Promote another owner before changing this one.'
    return null
  }

  async function applyVip(grant: boolean) {
    setPending(null)
    setBusy({ kind: 'working' })
    try {
      await setCustomerType(user.id, grant ? 'wholesale_vip' : 'retail')
      setBusy({ kind: 'idle' })
      onChanged()
      onToast(grant
        ? `${label} now receives Wholesale VIP pricing.`
        : `${label} has returned to Retail pricing.`)
    } catch (err) {
      // Never claim success when the database refused.
      setBusy({ kind: 'error', message: err instanceof Error ? err.message : 'The database refused the change.' })
    }
  }

  async function applyRole(next: AccountRole) {
    setPending(null)
    setBusy({ kind: 'working' })
    try {
      await setUserRole(user.id, next, viewerId)
      setBusy({ kind: 'idle' })
      onChanged()
      onToast(next === 'customer'
        ? `${label} no longer has administrator access.`
        : `${label} is now ${ACCOUNT_ROLE_LABEL[next]}.`)
    } catch (err) {
      setBusy({ kind: 'error', message: err instanceof Error ? err.message : 'The database refused the change.' })
    }
  }

  const working = busy.kind === 'working'

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label="User detail"
        className="relative safe-y flex h-full w-full max-w-2xl flex-col bg-background border-l border-mint/80 dark:border-border shadow-float">

        <header className="flex items-start gap-3 border-b border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">
              {user.full_name || <span className="font-semibold text-muted-foreground">No name on file</span>}
            </h2>
            <p className="mt-1 flex flex-wrap items-center gap-2">
              <CustomerTypeBadge status={status} />
              <RoleBadge role={current} known={rolesVisible || isSelf} />
              <span className="text-[11px] text-muted-foreground">Joined {dateOnly(user.created_at)}</span>
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
          {busy.kind === 'error' && (
            <div role="alert" className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
              <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[13px] leading-snug text-foreground">{busy.message}</p>
            </div>
          )}

          <Section icon={User} title="Profile">
            <dl>
              <Field label="Full name">
                {user.full_name || <span className="text-muted-foreground">Not provided</span>}
              </Field>
              <Field label="Email">
                {user.email
                  ? <span className="inline-flex items-center gap-1.5 break-all"><Mail size={12} className="shrink-0 text-muted-foreground" />{user.email}</span>
                  : <span className="text-muted-foreground">Not provided</span>}
              </Field>
              <Field label="Phone">
                {user.phone
                  ? <span className="inline-flex items-center gap-1.5"><Phone size={12} className="shrink-0 text-muted-foreground" />{user.phone}</span>
                  : <span className="text-muted-foreground">Not provided</span>}
              </Field>
              <Field label="Customer type"><CustomerTypeBadge status={status} /></Field>
              <Field label="Role"><RoleBadge role={current} known={rolesVisible || isSelf} /></Field>
              <Field label="Account status">
                <span className="inline-flex items-center gap-1.5 text-primary font-semibold">
                  <BadgeCheck size={13} className="shrink-0" /> Active
                </span>
              </Field>
              <Field label="Joined">
                <span className="inline-flex items-center gap-1.5">
                  <CalendarDays size={12} className="shrink-0 text-muted-foreground" />{dateTime(user.created_at)}
                </span>
              </Field>
            </dl>
            <p className="mt-3 text-[11.5px] leading-relaxed text-muted-foreground">{ACCOUNT_STATUS_NOTE}</p>
          </Section>

          <Section
            icon={ShoppingCart}
            title="Orders"
            note="Total spent excludes cancelled and refunded orders, matching the Orders workspace."
          >
            <div className="flex gap-2.5">
              <Stat label="Orders" value={String(user.stats.orderCount)} />
              <Stat label="Total spent" value={formatPrice(centsToRupees(user.stats.spentCents))} />
            </div>

            <div className="mt-3">
              {!orders && !ordersError && (
                <div className="flex items-center justify-center gap-2.5 py-6 text-[13px] text-muted-foreground">
                  <LoaderCircle size={16} className="animate-spin motion-reduce:animate-none" /> Loading orders…
                </div>
              )}

              {ordersError && (
                <div className="flex items-start gap-2.5 rounded-xl border border-red-500/25 bg-red-500/8 px-3.5 py-2.5">
                  <AlertCircle size={14} className="mt-0.5 shrink-0 text-red-500" />
                  <p className="text-[12.5px] text-foreground">{ordersError}</p>
                </div>
              )}

              {orders && orders.length === 0 && (
                <p className="rounded-xl border border-mint/70 dark:border-border bg-card px-3.5 py-3 text-[13px] text-muted-foreground">
                  This customer has not placed an order yet.
                </p>
              )}

              {orders && orders.length > 0 && (
                <ul className="space-y-2">
                  {orders.map((order) => (
                    <li key={order.id}
                      className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1.5 rounded-xl border border-mint/70 dark:border-border bg-card px-3.5 py-2.5">
                      <span className="min-w-0">
                        <span className="block text-[13px] font-semibold text-foreground truncate">{order.order_number}</span>
                        <span className="block text-[11px] text-muted-foreground">{dateTime(order.placed_at)}</span>
                      </span>
                      <span className="flex items-center gap-2.5">
                        <OrderStatusBadge status={order.status} />
                        <span className="text-[13px] font-semibold tabular-nums text-foreground whitespace-nowrap">
                          {formatPrice(centsToRupees(order.total_cents))}
                        </span>
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </Section>

          <Section
            icon={Crown}
            title="Pricing tier"
            note="Wholesale VIP is granted by hand through the audited database function — never earned automatically by order quantity or spend."
          >
            {status === 'vip_expired' && (
              <p className="mb-3 rounded-xl border border-amber-500/30 bg-amber-500/10 px-3.5 py-2.5 text-[12.5px] text-foreground">
                This customer is marked Wholesale VIP but the grant expired on{' '}
                {user.vip_expires_at ? dateOnly(user.vip_expires_at) : 'an earlier date'}, so the
                database is already pricing them at Retail.
              </p>
            )}

            {manageVip ? (
              <Button
                variant={isVip ? 'ghost' : 'secondary'}
                disabled={working}
                onClick={() => setPending({ kind: 'vip', grant: !isVip })}
              >
                {working
                  ? <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" />
                  : isVip ? 'Remove VIP' : 'Make Wholesale VIP'}
              </Button>
            ) : (
              <p className="flex items-center gap-2 text-[12.5px] text-muted-foreground">
                <Lock size={13} className="shrink-0" /> Your role cannot change pricing tiers.
              </p>
            )}
          </Section>

          <Section
            icon={KeyRound}
            title="Administrator access"
            note="Only an owner may grant or revoke a role. Row-level security enforces this inside PostgreSQL, so this control is a convenience — not the check itself."
          >
            {manageRoles ? (
              <>
                <div className="flex flex-wrap gap-2">
                  {ACCOUNT_ROLES.map((option) => {
                    const active = option === current
                    const blocked = roleBlockedReason(option)
                    return (
                      <Button
                        key={option}
                        size="sm"
                        variant={active ? 'secondary' : 'ghost'}
                        aria-pressed={active}
                        disabled={active || working || blocked !== null}
                        onClick={() => setPending({ kind: 'role', next: option })}
                      >
                        {ACCOUNT_ROLE_LABEL[option]}
                      </Button>
                    )
                  })}
                </div>
                {(isSelf || isLastOwner) && (
                  <p className="mt-3 flex items-start gap-2 text-[12.5px] text-muted-foreground">
                    <ShieldCheck size={13} className="mt-0.5 shrink-0" />
                    {isSelf
                      ? 'You cannot change your own role. Another owner must do it, so nobody can lock themselves out.'
                      : 'This is the only owner account. Promote a second owner before changing this one — the database refuses to remove the final owner grant.'}
                  </p>
                )}
              </>
            ) : (
              <p className="flex items-center gap-2 text-[12.5px] text-muted-foreground">
                <Lock size={13} className="shrink-0" />
                {rolesVisible
                  ? 'Only an owner can grant or revoke administrator roles.'
                  : 'Only an owner can see and change administrator roles.'}
              </p>
            )}
          </Section>
        </div>
      </div>

      {pending && (
        <div className="absolute inset-0 z-10 flex items-center justify-center px-5">
          <button type="button" aria-label="Cancel" onClick={() => setPending(null)}
            className="absolute inset-0 bg-black/55" />
          <div role="dialog" aria-modal="true" aria-labelledby="user-confirm-title"
            className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float">
            <span className={cn('mb-4 flex h-12 w-12 items-center justify-center rounded-full border',
              pending.kind === 'role' && pending.next === 'customer'
                ? 'border-border bg-muted text-muted-foreground'
                : 'border-mint-deep bg-primary-soft text-primary')}>
              {pending.kind === 'vip' ? <Crown size={22} strokeWidth={1.9} /> : <KeyRound size={22} strokeWidth={1.9} />}
            </span>

            <h2 id="user-confirm-title" className="text-lg font-bold tracking-tight text-foreground mb-2">
              {pending.kind === 'vip'
                ? (pending.grant ? 'Grant Wholesale VIP?' : 'Remove Wholesale VIP?')
                : pending.next === 'customer'
                  ? 'Remove administrator access?'
                  : `Make this user ${ACCOUNT_ROLE_LABEL[pending.next]}?`}
            </h2>

            <div className="mb-3 rounded-xl border border-mint/70 dark:border-border bg-card px-3 py-2.5">
              <span className="block text-[13px] font-semibold text-foreground truncate">
                {user.full_name || 'No name'}
              </span>
              {user.email && <span className="block text-[12px] text-muted-foreground truncate">{user.email}</span>}
              {user.phone && <span className="block text-[12px] text-muted-foreground truncate">{user.phone}</span>}
            </div>

            <p className="text-sm text-muted-foreground leading-relaxed mb-5">
              {pending.kind === 'vip'
                ? pending.grant
                  ? 'This customer will immediately receive Wholesale VIP pricing on every product that has a VIP price, and the Retail price everywhere else.'
                  : 'This customer will return to Retail pricing immediately and lose access to Wholesale VIP prices.'
                : pending.next === 'customer'
                  ? 'They will lose access to the admin panel immediately. Their profile, orders and pricing tier are not changed.'
                  : `They will be able to sign into the admin panel with ${ACCOUNT_ROLE_LABEL[pending.next]} permissions. Any role they hold now is replaced.`}
            </p>

            <div className="flex gap-2.5">
              <Button variant="ghost" fullWidth onClick={() => setPending(null)}>Cancel</Button>
              <Button fullWidth onClick={() => {
                if (pending.kind === 'vip') void applyVip(pending.grant)
                else void applyRole(pending.next)
              }}>
                {pending.kind === 'vip'
                  ? (pending.grant ? 'Make VIP' : 'Remove VIP')
                  : pending.next === 'customer' ? 'Remove access' : ACCOUNT_ROLE_LABEL[pending.next]}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
