"use client"

import { useState } from 'react'
import { AlertCircle, CheckCircle2, LoaderCircle, Printer } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { UNIT_STATUS_LABEL, type UnitStatus } from '@/lib/admin/units'
import { buildLabelPdf, openPdf, LABEL_LAYOUTS, type LabelItem, type LabelLayout } from '@/lib/admin/labels'

export function ErrorNote({ message, className }: { message: string; className?: string }) {
  return (
    <div className={cn('flex items-start gap-2 rounded-2xl border border-red-500/25 bg-red-500/8 px-3.5 py-2.5', className)}>
      <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
      <p className="text-[12.5px] text-foreground">{message}</p>
    </div>
  )
}

export function SuccessNote({ message, className }: { message: string; className?: string }) {
  return (
    <div className={cn('flex items-start gap-2 rounded-2xl border border-primary/25 bg-primary-soft px-3.5 py-2.5', className)}>
      <CheckCircle2 size={15} className="mt-0.5 shrink-0 text-primary" />
      <p className="text-[12.5px] text-foreground">{message}</p>
    </div>
  )
}

const STATUS_CLASS: Record<UnitStatus, string> = {
  in_stock: 'bg-primary-soft text-primary border-mint-deep',
  reserved: 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/30',
  sold: 'bg-muted text-muted-foreground border-border',
  written_off: 'bg-red-500/8 text-red-600 dark:text-red-400 border-red-500/25',
  returned_to_supplier: 'bg-sky-500/10 text-sky-700 dark:text-sky-300 border-sky-500/30',
  quarantined: 'bg-orange-500/10 text-orange-700 dark:text-orange-300 border-orange-500/30',
}

export function UnitStatusBadge({ status }: { status: string }) {
  const s = (status in STATUS_CLASS ? status : 'sold') as UnitStatus
  return (
    <span className={cn('inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-semibold whitespace-nowrap', STATUS_CLASS[s])}>
      {UNIT_STATUS_LABEL[s] ?? status}
    </span>
  )
}

export const TH = 'px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground whitespace-nowrap'
export const TABLE_CARD = 'bg-surface border border-mint/80 dark:border-border rounded-[26px] shadow-card overflow-hidden'
export const SELECT_CLASS =
  'focus-ring h-11 rounded-xl border border-mint-deep dark:border-border bg-card px-3 text-sm text-foreground focus:outline-none focus:border-primary/45'

/** Layout picker + print button for a set of unit labels. */
export function PrintLabels({ items, fileName, label = 'Print labels' }: {
  items: LabelItem[]
  fileName: string
  label?: string
}) {
  const [layout, setLayout] = useState<LabelLayout>('sticker')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function print() {
    setBusy(true)
    setError(null)
    try {
      await openPdf(await buildLabelPdf(items, layout), fileName)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create the labels.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-2">
      <div className="flex flex-col sm:flex-row gap-2">
        <select aria-label="Label layout" value={layout} disabled={busy}
          onChange={(e) => setLayout(e.target.value as LabelLayout)} className={cn(SELECT_CLASS, 'flex-1')}>
          {LABEL_LAYOUTS.map((l) => <option key={l.value} value={l.value}>{l.label}</option>)}
        </select>
        <Button onClick={() => void print()} disabled={busy || items.length === 0}>
          {busy
            ? <><LoaderCircle size={15} className="mr-1.5 animate-spin motion-reduce:animate-none" /> Preparing…</>
            : <><Printer size={15} className="mr-1.5" /> {label} ({items.length})</>}
        </Button>
      </div>
      <p className="text-[11.5px] text-muted-foreground">{LABEL_LAYOUTS.find((l) => l.value === layout)?.hint}</p>
      {error && <ErrorNote message={error} />}
    </div>
  )
}

/**
 * A cost typed by a person, keeping "not entered" apart from zero, because a blank
 * cost must never become a free item. 'blank' | cents | null when not valid.
 */
export function parseCost(text: string): number | 'blank' | null {
  return text.trim() === '' ? 'blank' : parseRupees(text)
}

/** Rupees typed by a person -> cents, or null when not a valid amount. */
export function parseRupees(text: string): number | null {
  const clean = text.replace(/[,\s]/g, '')
  if (clean === '') return 0
  if (!/^\d+(\.\d{1,2})?$/.test(clean)) return null
  return Math.round(Number(clean) * 100)
}
