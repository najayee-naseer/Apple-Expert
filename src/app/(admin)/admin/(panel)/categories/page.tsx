"use client"

import { useCallback, useEffect, useState } from 'react'
import {
  FolderTree, Plus, LoaderCircle, AlertCircle, Check, Eye, EyeOff, Lock, X, Info,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { useAdminAuth } from '@/context/AdminAuthContext'
import {
  listCategories, createCategory, updateCategory, setCategoryActive,
  countProductsByCategory, canEditCatalog, slugify, validateSlug,
  type CategoryRow, type CategoryInput,
} from '@/lib/admin/products'
import { TextField, NumberField, SelectField, CheckboxField, EditorSection, FieldLabel } from '@/components/admin/products/fields'

/**
 * Category management.
 *
 * Categories come from public.categories — the same rows the storefront reads —
 * so nothing about the grouping of products is hardcoded in the app any more.
 * The table already supports a parent_id, so a subcategory is just a category
 * with a parent, and no schema change was needed to offer it here.
 *
 * ONE HONEST LIMITATION, stated in the UI as well as here: /categories/<slug>
 * pages are prerendered at build time because the app ships as a static export
 * inside an APK. A category created here groups products immediately and is
 * usable everywhere the admin panel and product data are involved, but it does
 * not get its own customer listing page until the next build. Products created
 * inside the seven existing categories are unaffected and go live at once.
 */

type Load = { kind: 'loading' } | { kind: 'ready' } | { kind: 'error'; message: string }
type Editing = { kind: 'new' } | { kind: 'existing'; row: CategoryRow }

const BLANK: CategoryInput = {
  slug: '', name: '', subtitle: null, parent_id: null,
  hero_eyebrow: null, hero_headline: null, hero_blurb: null,
  image_path: null, sort_order: 0, is_active: true,
}

export default function AdminCategoriesPage() {
  const { role } = useAdminAuth()
  const canEdit = canEditCatalog(role)

  const [load, setLoad] = useState<Load>({ kind: 'loading' })
  const [rows, setRows] = useState<CategoryRow[]>([])
  const [counts, setCounts] = useState<Map<string, number>>(new Map())
  const [editing, setEditing] = useState<Editing | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    const [categories, productCounts] = await Promise.all([listCategories(), countProductsByCategory()])
    return { categories, productCounts }
  }, [])

  const applyData = useCallback((categories: CategoryRow[], productCounts: Map<string, number>) => {
    setRows(categories)
    setCounts(productCounts)
    setLoad({ kind: 'ready' })
  }, [])

  const applyError = useCallback((err: unknown) => {
    setLoad({ kind: 'error', message: err instanceof Error ? err.message : 'Could not load categories.' })
  }, [])

  const refresh = useCallback(() => {
    fetchAll().then(({ categories, productCounts }) => applyData(categories, productCounts)).catch(applyError)
  }, [fetchAll, applyData, applyError])

  useEffect(() => {
    let cancelled = false
    fetchAll()
      .then(({ categories, productCounts }) => { if (!cancelled) applyData(categories, productCounts) })
      .catch((err) => { if (!cancelled) applyError(err) })
    return () => { cancelled = true }
  }, [fetchAll, applyData, applyError])

  useEffect(() => {
    if (!toast) return
    const id = window.setTimeout(() => setToast(null), 4000)
    return () => window.clearTimeout(id)
  }, [toast])

  async function toggleActive(row: CategoryRow) {
    try {
      await setCategoryActive(row.id, !row.is_active)
      setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, is_active: !row.is_active } : r)))
      setToast(`${row.name} is now ${row.is_active ? 'hidden' : 'visible'}.`)
    } catch (err) {
      setToast(err instanceof Error ? err.message : 'Could not change the category.')
    }
  }

  const nameById = new Map(rows.map((r) => [r.id, r.name]))

  return (
    <>
      <AdminPageHeading
        title="Categories"
        subtitle={
          load.kind === 'ready'
            ? `${rows.length} categories · ${rows.filter((r) => r.is_active).length} visible to customers`
            : 'How products are grouped, in the database.'
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2.5">
        <Button onClick={() => setEditing({ kind: 'new' })} disabled={!canEdit || load.kind !== 'ready'}>
          <Plus size={16} className="mr-1.5" />
          Add category
        </Button>
      </div>

      {!canEdit && load.kind === 'ready' && (
        <div className="mb-4 flex items-start gap-2.5 rounded-2xl border border-amber-500/25 bg-amber-500/10 px-4 py-3">
          <Lock size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
          <p className="text-[13px] leading-snug text-foreground">
            You have read-only access. The database refuses catalog writes for your role.
          </p>
        </div>
      )}

      {load.kind === 'loading' && (
        <div className="flex items-center justify-center gap-2.5 py-16 text-sm text-muted-foreground">
          <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" /> Loading categories…
        </div>
      )}

      {load.kind === 'error' && (
        <div className="rounded-[26px] border border-mint/80 bg-surface px-6 py-12 text-center shadow-card dark:border-border">
          <span className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full border border-red-500/20 bg-red-500/8 text-red-500">
            <AlertCircle size={24} />
          </span>
          <h2 className="mb-1.5 text-lg font-bold tracking-tight text-foreground">Could not load categories</h2>
          <p className="mx-auto mb-5 max-w-md text-sm text-muted-foreground">{load.message}</p>
          <Button onClick={() => { setLoad({ kind: 'loading' }); refresh() }}>Try again</Button>
        </div>
      )}

      {load.kind === 'ready' && (
        <div className="overflow-hidden rounded-[26px] border border-mint/80 bg-surface shadow-card dark:border-border">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-mint/70 bg-muted/60 dark:border-border">
                  {['Category', 'Slug', 'Parent', 'Products', 'State', ''].map((h, i) => (
                    <th key={h || i} scope="col"
                      className={cn('whitespace-nowrap px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-[0.1em] text-muted-foreground',
                        h === 'Products' && 'text-right')}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-mint/50 transition-colors last:border-0 hover:bg-primary-soft/40 dark:border-border/70">
                    <td className="px-4 py-3 min-w-[180px]">
                      <span className="block font-semibold leading-tight text-foreground">{row.name}</span>
                      {row.subtitle && <span className="block text-[11px] text-muted-foreground">{row.subtitle}</span>}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 font-mono text-[12px] text-muted-foreground">{row.slug}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-muted-foreground">
                      {row.parent_id ? nameById.get(row.parent_id) ?? '—' : '—'}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right tabular-nums text-foreground">
                      {counts.get(row.id) ?? 0}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3">
                      <span className={cn('inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-semibold',
                        row.is_active
                          ? 'border-mint-deep bg-primary-soft text-primary'
                          : 'border-border bg-muted text-muted-foreground')}>
                        {row.is_active ? <Eye size={12} /> : <EyeOff size={12} />}
                        {row.is_active ? 'Visible' : 'Hidden'}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <div className="inline-flex items-center gap-1.5">
                        <Button size="sm" variant="secondary" onClick={() => setEditing({ kind: 'existing', row })}>
                          {canEdit ? 'Edit' : 'View'}
                        </Button>
                        <Button size="sm" variant="ghost" disabled={!canEdit} onClick={() => void toggleActive(row)}>
                          {row.is_active ? 'Hide' : 'Show'}
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {load.kind === 'ready' && (
        <div className="mt-4 flex items-start gap-2.5 rounded-2xl border border-mint/70 bg-muted px-4 py-3 dark:border-border">
          <Info size={15} className="mt-0.5 shrink-0 text-muted-foreground" />
          <p className="text-[12.5px] leading-relaxed text-muted-foreground">
            Products added to one of the existing customer categories appear in the store immediately.
            A brand-new category groups and labels products straight away, but its own
            <span className="font-mono"> /categories/… </span> browse page is part of the app build, so
            that page arrives with the next app update.
          </p>
        </div>
      )}

      {toast && (
        <div role="status" aria-live="polite"
          className="fixed bottom-5 left-1/2 z-50 flex -translate-x-1/2 items-center gap-2 rounded-full border border-mint-deep bg-surface px-4 py-2.5 shadow-float">
          <Check size={15} className="shrink-0 text-primary" />
          <span className="text-[13px] font-medium text-foreground">{toast}</span>
        </div>
      )}

      {editing && (
        <CategoryEditor
          key={editing.kind === 'new' ? 'new' : editing.row.id}
          editing={editing}
          categories={rows}
          canEdit={canEdit}
          onClose={() => setEditing(null)}
          onSaved={(message) => { setEditing(null); setToast(message); refresh() }}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

function CategoryEditor({
  editing, categories, canEdit, onClose, onSaved,
}: {
  editing: Editing
  categories: CategoryRow[]
  canEdit: boolean
  onClose: () => void
  onSaved: (message: string) => void
}) {
  const existing = editing.kind === 'existing' ? editing.row : null

  const [form, setForm] = useState<CategoryInput>(
    existing
      ? {
          slug: existing.slug, name: existing.name, subtitle: existing.subtitle,
          parent_id: existing.parent_id, hero_eyebrow: existing.hero_eyebrow,
          hero_headline: existing.hero_headline, hero_blurb: existing.hero_blurb,
          image_path: existing.image_path, sort_order: existing.sort_order,
          is_active: existing.is_active,
        }
      : BLANK,
  )
  const [slugEdited, setSlugEdited] = useState(existing !== null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function patch<K extends keyof CategoryInput>(key: K, value: CategoryInput[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
    setError(null)
  }

  async function handleSave() {
    if (form.name.trim() === '') { setError('Give the category a name.'); return }
    const slug = validateSlug(form.slug, 'Slug')
    if (!slug.ok) { setError(slug.reason); return }

    setBusy(true)
    try {
      if (existing) {
        await updateCategory(existing.id, { ...form, name: form.name.trim() })
        onSaved(`${form.name.trim()} updated.`)
      } else {
        await createCategory({ ...form, name: form.name.trim() })
        onSaved(`${form.name.trim()} created.`)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The database refused the category.')
    } finally {
      setBusy(false)
    }
  }

  const disabled = !canEdit || busy
  // A category cannot be its own parent, and the schema forbids it too.
  const parentOptions = categories
    .filter((c) => c.id !== existing?.id)
    .map((c) => ({ value: c.id, label: c.name }))

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label={existing ? 'Edit category' : 'Add category'}
        className="relative safe-y flex h-full w-full max-w-lg flex-col border-l border-mint/80 bg-background shadow-float dark:border-border">

        <header className="flex items-center gap-3 border-b border-mint/80 bg-glass px-5 py-4 backdrop-blur-xl dark:border-border">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">
              {existing ? existing.name : 'Add category'}
            </h2>
            <p className="truncate text-[12px] text-muted-foreground">
              {existing ? 'Stored in public.categories' : 'Grouping for the catalog'}
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground transition hover:bg-primary-soft active:scale-95">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 space-y-4 overflow-y-auto px-5 py-5">
          {!canEdit && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-amber-500/25 bg-amber-500/10 px-4 py-3">
              <Lock size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">Read-only for your role.</p>
            </div>
          )}

          <EditorSection title="Category">
            <div className="grid gap-4">
              <TextField id="c-name" label="Name" value={form.name} disabled={disabled}
                placeholder="iPhone"
                onChange={(v) => {
                  patch('name', v)
                  if (!slugEdited) patch('slug', slugify(v))
                }} />

              <label htmlFor="c-slug" className="block">
                <FieldLabel hint={existing ? 'changing this moves the customer URL' : 'the customer URL segment'}>
                  Slug
                </FieldLabel>
                <input id="c-slug" type="text" value={form.slug} disabled={disabled} placeholder="iphone"
                  onChange={(e) => { setSlugEdited(true); patch('slug', e.target.value) }}
                  className="focus-ring w-full rounded-xl border border-mint-deep bg-card px-3 py-2.5 font-mono text-sm text-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60 dark:border-border" />
              </label>

              <TextField id="c-sub" label="Subtitle" value={form.subtitle ?? ''} disabled={disabled}
                hint="optional" onChange={(v) => patch('subtitle', v || null)} />

              <div className="grid gap-4 sm:grid-cols-2">
                <SelectField id="c-parent" label="Parent category" value={form.parent_id ?? ''} disabled={disabled}
                  allowEmpty hint="optional" onChange={(v) => patch('parent_id', v || null)}
                  options={parentOptions} />
                <NumberField id="c-sort" label="Sort order" min={0} value={form.sort_order} disabled={disabled}
                  onChange={(v) => patch('sort_order', v ?? 0)} />
              </div>

              <CheckboxField id="c-active" label="Visible to customers" checked={form.is_active} disabled={disabled}
                onChange={(v) => patch('is_active', v)} />
            </div>
          </EditorSection>

          <EditorSection title="Storefront copy" description="Used by the category page header where one exists.">
            <div className="grid gap-4">
              <TextField id="c-eyebrow" label="Eyebrow" value={form.hero_eyebrow ?? ''} disabled={disabled}
                onChange={(v) => patch('hero_eyebrow', v || null)} />
              <TextField id="c-headline" label="Headline" value={form.hero_headline ?? ''} disabled={disabled}
                onChange={(v) => patch('hero_headline', v || null)} />
              <TextField id="c-blurb" label="Blurb" value={form.hero_blurb ?? ''} disabled={disabled}
                onChange={(v) => patch('hero_blurb', v || null)} />
              <TextField id="c-image" label="Image path" value={form.image_path ?? ''} disabled={disabled}
                hint="bundled path or https:// URL" onChange={(v) => patch('image_path', v || null)} />
            </div>
          </EditorSection>

          <div className="flex items-start gap-2.5 rounded-2xl border border-mint/70 bg-muted px-4 py-3 dark:border-border">
            <FolderTree size={15} className="mt-0.5 shrink-0 text-muted-foreground" />
            <p className="text-[12.5px] leading-snug text-muted-foreground">
              Hiding a category does not touch its products. They keep their rows and their prices, and
              simply stop being grouped under it for customers.
            </p>
          </div>
        </div>

        <footer className="border-t border-mint/80 bg-glass px-5 py-4 backdrop-blur-xl dark:border-border">
          {error && (
            <div className="mb-3 flex items-start gap-2 rounded-xl border border-red-500/25 bg-red-500/8 px-3 py-2">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[12.5px] text-foreground">{error}</p>
            </div>
          )}
          <div className="flex items-center gap-2.5">
            <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
            <Button className="flex-1" onClick={() => void handleSave()} disabled={disabled}>
              {busy
                ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</>
                : existing ? 'Save changes' : 'Create category'}
            </Button>
          </div>
        </footer>
      </div>
    </div>
  )
}
