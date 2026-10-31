"use client"

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Plus, Search, LoaderCircle, PackagePlus } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { formatPrice } from '@/utils/formatPrice'
import { centsToRupees } from '@/lib/admin/pricing'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { GrnCreator } from '@/components/admin/inventory/GrnCreator'
import { GrnDetail } from '@/components/admin/inventory/GrnDetail'
import { ErrorNote, TH, TABLE_CARD } from '@/components/admin/inventory/shared'
import { useAdminAuth } from '@/context/AdminAuthContext'
import {
  listGrns, listProductsForGrn, canReceiveStock, describeUnitError, formatDate, loadCosts,
  type CostRow, type GrnListItem, type GrnProductOption,
} from '@/lib/admin/units'
import {
  listSuppliers, listPurchaseOrders, isPoReceivable,
  type SupplierRow, type PurchaseOrderListItem, type GrnResult,
} from '@/lib/admin/purchasing'

type Load = { kind: 'loading' } | { kind: 'ready' } | { kind: 'error'; message: string }

export default function AdminGrnPage() {
  const { role } = useAdminAuth()
  const canPost = canReceiveStock(role)

  const [load, setLoad] = useState<Load>({ kind: 'loading' })
  const [grns, setGrns] = useState<GrnListItem[]>([])
  const [products, setProducts] = useState<GrnProductOption[]>([])
  const [suppliers, setSuppliers] = useState<SupplierRow[]>([])
  const [pos, setPos] = useState<PurchaseOrderListItem[]>([])
  const [costs, setCosts] = useState<Map<string, CostRow>>(new Map())
  const [query, setQuery] = useState('')
  const [creating, setCreating] = useState(false)
  const [open, setOpen] = useState<{ id: string; notice: string | null } | null>(null)

  const fetchAll = useCallback(async () => {
    const [g, p, s, o] = await Promise.all([listGrns(), listProductsForGrn(), listSuppliers(), listPurchaseOrders()])
    // Money comes separately: staff are refused it by the database.
    const c = canPost ? await loadCosts('grn', g.map((x) => x.id)) : new Map<string, CostRow>()
    return [g, p, s, o, c] as const
  }, [canPost])
  const apply = useCallback(([g, p, s, o, c]: readonly [GrnListItem[], GrnProductOption[], SupplierRow[], PurchaseOrderListItem[], Map<string, CostRow>]) => {
    setGrns(g); setProducts(p); setSuppliers(s); setPos(o.filter((po) => isPoReceivable(po.status))); setCosts(c); setLoad({ kind: 'ready' })
  }, [])

  const refresh = useCallback(() => {
    fetchAll()
      .then(apply)
      .catch((err) => setLoad({ kind: 'error', message: describeUnitError(err, 'Could not load GRNs.') }))
  }, [fetchAll, apply])

  useEffect(() => {
    let cancelled = false
    fetchAll()
      .then((r) => { if (!cancelled) apply(r) })
      .catch((err) => { if (!cancelled) setLoad({ kind: 'error', message: describeUnitError(err, 'Could not load GRNs.') }) })
    return () => { cancelled = true }
  }, [fetchAll, apply])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return grns
    return grns.filter((g) => [g.grn_number, g.supplier_name, g.supplier_invoice ?? ''].some((s) => s.toLowerCase().includes(q)))
  }, [grns, query])

  function onPosted(result: GrnResult) {
    setCreating(false)
    setOpen({
      id: result.id,
      notice: result.replayed
        ? `${result.grn_number} had already been posted — nothing was received twice.`
        : `${result.grn_number} posted: ${result.total_units} accepted${result.rejected_units > 0 ? `, ${result.rejected_units} rejected` : ''}. Print any barcode labels below.`,
    })
    refresh()
  }

  return (
    <>
      <div className="flex flex-col sm:flex-row sm:items-start gap-3">
        <AdminPageHeading className="flex-1" title="Good Receive Notice"
          subtitle="Record every delivery: what arrived, what you accepted and what you refused. Accepted items enter stock automatically." />
        {canPost && (
          <Button onClick={() => setCreating(true)} disabled={load.kind !== 'ready'}>
            <Plus size={16} className="mr-1.5" /> New GRN
          </Button>
        )}
      </div>

      {!canPost && (
        <p className="mb-4 text-[12.5px] text-muted-foreground">You can view GRNs and print labels. Posting a GRN and seeing its costs needs an owner or admin.</p>
      )}

      <div className="relative mb-4">
        <span className="pointer-events-none absolute inset-y-0 left-0 flex w-11 items-center justify-center text-muted-foreground"><Search size={16} /></span>
        <input type="search" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search GRNs"
          placeholder="Search GRN number, supplier or invoice…"
          className="focus-ring h-11 w-full rounded-xl border border-mint-deep dark:border-border bg-card pl-11 pr-3 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45" />
      </div>

      {load.kind === 'loading' && (
        <div className="flex items-center justify-center gap-2.5 py-16 text-sm text-muted-foreground">
          <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading GRNs…
        </div>
      )}

      {load.kind === 'error' && (
        <div className="space-y-3">
          <ErrorNote message={load.message} />
          <Button variant="secondary" onClick={() => { setLoad({ kind: 'loading' }); refresh() }}>Try again</Button>
        </div>
      )}

      {load.kind === 'ready' && filtered.length === 0 && (
        <div className="bg-surface border border-mint/80 dark:border-border rounded-[26px] shadow-card px-6 py-14 text-center">
          <span className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-well-strong border border-mint-deep text-primary">
            <PackagePlus size={24} strokeWidth={1.8} />
          </span>
          <h2 className="text-lg font-bold tracking-tight text-foreground mb-1.5">{grns.length === 0 ? 'No goods received yet' : 'No GRNs match'}</h2>
          <p className="mx-auto max-w-md text-sm text-muted-foreground">
            {grns.length === 0 ? 'When a delivery arrives, post a GRN to give every item a barcode and add it to stock.' : 'Try a different search.'}
          </p>
        </div>
      )}

      {load.kind === 'ready' && filtered.length > 0 && (
        <div className={TABLE_CARD}>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-mint/70 dark:border-border bg-muted/60">
                  <th scope="col" className={TH}>GRN</th>
                  <th scope="col" className={TH}>Supplier</th>
                  <th scope="col" className={`${TH} text-right`}>Accepted</th>
                  {canPost && <th scope="col" className={`${TH} text-right`}>Cost</th>}
                  <th scope="col" className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((g) => (
                  <tr key={g.id} className="border-b border-mint/50 dark:border-border/70 last:border-0 hover:bg-primary-soft/40 transition-colors">
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span className="block font-semibold text-foreground">{g.grn_number}</span>
                      <span className="block text-[11px] text-muted-foreground">{formatDate(g.received_on)}{g.createdByName ? ` · ${g.createdByName}` : ''}</span>
                    </td>
                    <td className="px-4 py-3 min-w-[180px]">
                      <span className="block text-foreground">{g.supplier_name}</span>
                      {g.supplier_invoice && <span className="block text-[11px] text-muted-foreground">Invoice {g.supplier_invoice}</span>}
                    </td>
                    <td className="px-4 py-3 text-right tabular-nums">
                      {g.total_units}
                      {g.rejected_units > 0 && <span className="block text-[11px] text-muted-foreground">{g.rejected_units} rejected</span>}
                    </td>
                    {canPost && (
                      <td className="px-4 py-3 text-right tabular-nums whitespace-nowrap">
                        {formatPrice(centsToRupees(costs.get(g.id)?.cents ?? 0))}
                        {costs.get(g.id)?.pending && <span className="block text-[11px] font-semibold text-amber-600 dark:text-amber-400">cost pending</span>}
                      </td>
                    )}
                    <td className="px-4 py-3 text-right whitespace-nowrap">
                      <Button size="sm" variant="secondary" onClick={() => setOpen({ id: g.id, notice: null })}>{g.unitCount > 0 ? 'View & Labels' : 'View'}</Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {creating && <GrnCreator products={products} suppliers={suppliers} purchaseOrders={pos} onClose={() => setCreating(false)} onPosted={onPosted} />}
      {open && <GrnDetail key={open.id} grnId={open.id} showMoney={canPost} justPosted={open.notice} onClose={() => setOpen(null)} onChanged={refresh} />}
    </>
  )
}
