"use client"

import { useEffect, useRef, useState } from 'react'
import {
  X, LoaderCircle, Check, AlertCircle, Plus, Trash2, Lock, ImageIcon, Info, Star, Ban, Upload,
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { cn } from '@/lib/utils'
import {
  loadProductDetail, updateProduct, updateVariant, saveSpecs, updateImage,
  addVariant, deleteVariant, addImage, deleteImage, setPrimaryImage,
  addCompatibility, deleteCompatibility, deleteProduct, countOrderLines,
  SUBCATEGORY_OPTIONS, LIFECYCLE_OPTIONS,
  type AdminProductDetail, type CategoryRow, type ProductPatch,
  type VariantPatch, type SpecDraft, type ProductRow,
} from '@/lib/admin/products'
import {
  listWarrantyOptions, addWarrantyOption, updateWarrantyOption, deleteWarrantyOption,
  setDefaultWarrantyOption, reorderWarrantyOptions, listConditionGrades,
  uploadProductImage, PRODUCT_IMAGE_BUCKET, BRAND_NEW_FIELDS,
  listConditions, saveCondition, deleteCondition, clearLegacyCondition,
  listPlans, createPlan, updatePlan, deletePlan,
  type WarrantyOptionRow, type ConditionGradeRow, type ConditionRow, type WarrantyPlanRow,
} from '@/lib/admin/warranty'
import { productImageUrl, warrantyNoun } from '@/lib/catalog'
import { describeAdminError } from '@/lib/admin/errors'
import { listMovements, reasonLabel, setTrackingMode, describeStockError, MOVEMENT_LIMIT, type MovementRow, type StockResult } from '@/lib/admin/inventory'
import { confirmAdjustment } from '@/lib/admin/stockFlow'
import { StockAdjustDialog } from './StockAdjustDialog'
import {
  ConditionEditor, GradesManager, PlanEditor, toDraft, draftToPatch,
  conditionDraftFrom, conditionChanged, planDraftFrom, planChanged,
  type WarrantyOptionDraft, type ConditionDraft, type PlanDraft,
} from './ConditionWarrantyEditor'
import {
  TextField, NumberField, TextAreaField, SelectField, LockedField,
  CheckboxField, EditorSection,
} from './fields'

type SaveState = { kind: 'idle' } | { kind: 'saving' } | { kind: 'saved' } | { kind: 'error'; message: string }

interface Props {
  productId: string
  categories: CategoryRow[]
  canEdit: boolean
  onClose: () => void
  onSaved: () => void
  /** Called after the product row itself has been removed. */
  onDeleted?: (name: string) => void
}

/**
 * A destructive action awaiting confirmation.
 *
 * Every delete in this editor goes through one of these rather than firing on
 * click: a variant carries its price history, an image is a customer-facing
 * asset, and a product is the anchor for links and saved carts.
 */
type Confirm =
  | { kind: 'variant'; id: string; label: string }
  | { kind: 'image'; id: string; label: string }
  | { kind: 'compatibility'; id: string; label: string }
  | { kind: 'warranty'; id: string; label: string }
  | { kind: 'plan'; id: string; label: string }
  /** Pre-Owned -> Brand New on one item: clears THAT item's pre-owned details. */
  | { kind: 'brand-new'; key: string; label: string }
  | { kind: 'product'; orderLines: number }

/** Condition drafts are keyed by variant id, or this key for a product without variants. */
const PRODUCT_KEY = 'product'

/** The editable fields of a product row, as the form holds them. */
function formFrom(p: ProductRow): ProductPatch {
  return {
    name: p.name,
    category_id: p.category_id,
    subcategory: p.subcategory,
    model: p.model,
    description: p.description,
    warranty_text: p.warranty_text,
    warranty_coverage: p.warranty_coverage,
    lifecycle_status: p.lifecycle_status,
    is_new: p.is_new,
  }
}

/**
 * Product-level pre-owned values left on a product WITH variants from before
 * conditions were per variant. Migration 20261003120000 did not guess which
 * variant they describe, so they are shown to the admin to assign or clear.
 */
function legacyCondition(p: ProductRow) {
  const has = p.condition !== 'brand_new' || p.condition_grade_id !== null || p.battery_health !== null
    || p.cycle_count !== null || p.physical_condition !== null || p.accessories_included !== null || p.device_notes !== null
  return has ? p : null
}

export function ProductEditor({ productId, categories, canEdit, onClose, onSaved, onDeleted }: Props) {
  const [detail, setDetail] = useState<AdminProductDetail | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [save, setSave] = useState<SaveState>({ kind: 'idle' })

  const [form, setForm] = useState<ProductPatch | null>(null)
  const [variants, setVariants] = useState<(VariantPatch & { id: string; legacyKey: string | null })[]>([])
  const [specs, setSpecs] = useState<SpecDraft[]>([])
  const [images, setImages] = useState<{ id: string; path: string; alt: string; position: number; variant_id: string | null }[]>([])
  const [grades, setGrades] = useState<ConditionGradeRow[]>([])
  const [gradesError, setGradesError] = useState<string | null>(null)
  const [managingGrades, setManagingGrades] = useState(false)
  // Conditions and warranty plans per product / variant. Drafts hold only what
  // the admin has edited; everything else reads straight from the rows.
  const [conditionRows, setConditionRows] = useState<ConditionRow[]>([])
  const [conditionDrafts, setConditionDrafts] = useState<Record<string, ConditionDraft>>({})
  const [planRows, setPlanRows] = useState<WarrantyPlanRow[]>([])
  const [planDrafts, setPlanDrafts] = useState<Record<string, PlanDraft>>({})
  const [optionRows, setOptionRows] = useState<WarrantyOptionRow[]>([])
  const [optionDrafts, setOptionDrafts] = useState<WarrantyOptionDraft[]>([])
  const [extrasError, setExtrasError] = useState<string | null>(null)
  /** '' = upload as shared photos; otherwise the variant the upload belongs to. */
  const [uploadTarget, setUploadTarget] = useState('')
  const fileInput = useRef<HTMLInputElement>(null)

  // Rows added or removed here are written immediately rather than batched with
  // "Save changes": an insert needs a database id before its fields can be
  // edited, and a delete deserves its own confirmation rather than riding along
  // with unrelated edits.
  const [newVariantName, setNewVariantName] = useState('')
  const [newImagePath, setNewImagePath] = useState('')
  const [newCompatibility, setNewCompatibility] = useState('')
  const [rowBusy, setRowBusy] = useState(false)
  const [rowError, setRowError] = useState<string | null>(null)
  const [confirm, setConfirm] = useState<Confirm | null>(null)
  // Stock is never part of "Save changes": it moves only through the Adjust
  // stock dialog, one audited admin_set_stock() call at a time.
  const [movements, setMovements] = useState<(MovementRow & { actorName: string | null })[]>([])
  const [movementsError, setMovementsError] = useState<string | null>(null)
  const [adjusting, setAdjusting] = useState<{ variantId: string | null; label: string; current: number } | null>(null)
  const [modeChange, setModeChange] = useState<{ variantId: string | null; label: string; to: 'quantity' | 'unit' } | null>(null)
  // After an ACCEPTED adjustment: the confirmation, and a refresh problem kept
  // apart from rowError so it can never read as the change being refused.
  const [stockNotice, setStockNotice] = useState<string | null>(null)
  const [refreshError, setRefreshError] = useState<string | null>(null)

  // The parent mounts this component with key={productId}, so a different
  // product gets a fresh instance and the initial state above is already the
  // reset — no synchronous state writes are needed in this effect.
  useEffect(() => {
    let cancelled = false

    // Grades and warranty options load beside the product; a failure there is
    // reported in its own section rather than blocking the whole editor.
    listConditionGrades()
      .then((rows) => { if (!cancelled) setGrades(rows) })
      .catch((err) => { if (!cancelled) setGradesError(describeAdminError(err, 'Could not load condition grades.')) })
    Promise.all([listConditions(productId), listPlans(productId), listWarrantyOptions(productId)])
      .then(([conds, plans, options]) => {
        if (cancelled) return
        setConditionRows(conds)
        setPlanRows(plans)
        setOptionRows(options)
        setOptionDrafts(options.map(toDraft))
      })
      .catch((err) => { if (!cancelled) setExtrasError(describeAdminError(err, 'Could not load condition and warranty settings.')) })

    loadProductDetail(productId)
      .then((d) => {
        if (cancelled) return
        setDetail(d)
        setForm(formFrom(d.product))
        setVariants(d.variants.map((v) => ({
          id: v.id, legacyKey: v.legacy_key, name: v.name, color: v.color,
          color_code: v.color_code, storage: v.storage, sort_order: v.sort_order,
        })))
        setSpecs(d.specs.map((s) => ({ id: s.id, label: s.label, value: s.value })))
        setImages(d.images.map((i) => ({ id: i.id, path: i.path, alt: i.alt ?? '', position: i.position, variant_id: i.variant_id })))
      })
      .catch((err) => { if (!cancelled) setLoadError(err instanceof Error ? err.message : 'Could not load this product.') })

    // Stock history is reported in its own section; a failure never blocks editing.
    listMovements(productId)
      .then((rows) => { if (!cancelled) setMovements(rows) })
      .catch((err) => { if (!cancelled) setMovementsError(describeAdminError(err, 'Could not load stock history.')) })

    return () => { cancelled = true }
  }, [productId])

  function patchForm<K extends keyof ProductPatch>(key: K, value: ProductPatch[K]) {
    setForm((prev) => (prev ? { ...prev, [key]: value } : prev))
    setSave({ kind: 'idle' })
  }

  /** Re-reads the product so newly inserted rows arrive with their ids. */
  async function reload() {
    const fresh = await loadProductDetail(productId)
    setDetail(fresh)
    setVariants(fresh.variants.map((v) => ({
      id: v.id, legacyKey: v.legacy_key, name: v.name, color: v.color,
      color_code: v.color_code, storage: v.storage, sort_order: v.sort_order,
    })))
    setSpecs(fresh.specs.map((sp) => ({ id: sp.id, label: sp.label, value: sp.value })))
    setImages(fresh.images.map((i) => ({ id: i.id, path: i.path, alt: i.alt ?? '', position: i.position, variant_id: i.variant_id })))
    await reloadExtras()
    await reloadMovements()
  }

  /**
   * The database accepted a stock change. Show the new figure at once (so the
   * screen is right even if the refresh fails), confirm it, then re-read.
   *
   * Like every immediate row action here, the refresh re-reads variants,
   * specs and images, so unsaved edits in those sections are replaced by what
   * is saved. Product details and condition/warranty drafts are kept.
   */
  async function handleAdjusted(result: StockResult, variantId: string | null) {
    setAdjusting(null)
    setRowError(null)
    setDetail((prev) => prev && (variantId === null
      ? { ...prev, product: { ...prev.product, stock: result.current_quantity } }
      : { ...prev, variants: prev.variants.map((v) => v.id === variantId ? { ...v, stock: result.current_quantity } : v) }))
    setRowBusy(true)
    const outcome = await confirmAdjustment(result, async () => { await reload(); onSaved() },
      (err) => describeAdminError(err, 'Could not reload the product.'))
    setRowBusy(false)
    setStockNotice(outcome.notice)
    setRefreshError(outcome.refreshError)
  }

  async function retryRefresh() {
    setRowBusy(true)
    try {
      await reload()
      onSaved()
      setRefreshError(null)
    } catch (err) {
      setRefreshError(`This screen could not refresh: ${describeAdminError(err, 'Could not reload the product.')}`)
    } finally {
      setRowBusy(false)
    }
  }

  async function reloadMovements() {
    try {
      setMovements(await listMovements(productId))
      setMovementsError(null)
    } catch (err) {
      setMovementsError(describeAdminError(err, 'Could not load stock history.'))
    }
  }

  /**
   * Re-reads conditions, plans and options. Unsaved edits are kept for items
   * that still exist, so an immediate action (adding an option, say) never
   * throws away a condition the admin is part-way through editing.
   */
  async function reloadExtras(discardDrafts = false) {
    const [conds, plans, options] = await Promise.all([
      listConditions(productId), listPlans(productId), listWarrantyOptions(productId),
    ])
    setConditionRows(conds)
    setPlanRows(plans)
    setOptionRows(options)
    if (discardDrafts) {
      setConditionDrafts({})
      setPlanDrafts({})
      setOptionDrafts(options.map(toDraft))
    } else {
      setPlanDrafts((prev) => Object.fromEntries(Object.entries(prev).filter(([id]) => plans.some((p) => p.id === id))))
      setOptionDrafts((prev) => options.map((row) => prev.find((d) => d.id === row.id) ?? toDraft(row)))
    }
    setExtrasError(null)
  }

  function conditionRowFor(key: string): ConditionRow | undefined {
    return conditionRows.find((r) => (key === PRODUCT_KEY ? r.variant_id === null : r.variant_id === key))
  }

  /** The item's condition as currently edited (no row = Brand New). */
  function conditionDraftFor(key: string): ConditionDraft {
    return conditionDrafts[key] ?? conditionDraftFrom(conditionRowFor(key))
  }

  function setConditionDraft(key: string, draft: ConditionDraft) {
    setConditionDrafts((prev) => ({ ...prev, [key]: draft }))
    setSave({ kind: 'idle' })
  }

  function planDraftFor(row: WarrantyPlanRow): PlanDraft {
    return planDrafts[row.id] ?? planDraftFrom(row)
  }

  /** Swaps an option with its neighbour within its plan and rewrites the order. */
  function moveOption(planId: string, id: string, direction: -1 | 1) {
    const ids = optionDrafts.filter((d) => optionRows.find((r) => r.id === d.id)?.plan_id === planId).map((d) => d.id)
    const from = ids.indexOf(id)
    const to = from + direction
    if (from < 0 || to < 0 || to >= ids.length) return
    ;[ids[from], ids[to]] = [ids[to], ids[from]]
    void runRowAction(() => reorderWarrantyOptions(ids))
  }

  /** Uploads a photo to the product-images bucket and attaches it to this product. */
  async function uploadImages(files: FileList | null) {
    if (!files || files.length === 0 || !detail) return
    const list = Array.from(files)
    await runRowAction(async () => {
      let existing = detail.images
      for (const file of list) {
        const path = await uploadProductImage(productId, file)
        const row = await addImage(productId, {
          path, alt: null, storage_bucket: PRODUCT_IMAGE_BUCKET, variant_id: uploadTarget || null,
        }, existing)
        existing = [...existing, row]
      }
    })
    if (fileInput.current) fileInput.current.value = ''
  }

  /** Runs one immediate row write, keeping its error separate from the form's. */
  async function runRowAction(action: () => Promise<void>) {
    setRowBusy(true)
    setRowError(null)
    try {
      await action()
      await reload()
      onSaved()
    } catch (err) {
      setRowError(describeAdminError(err, 'The database refused that change.'))
    } finally {
      setRowBusy(false)
    }
  }

  async function handleDeleteProduct() {
    if (!detail) return
    setRowBusy(true)
    setRowError(null)
    try {
      const outcome = await deleteProduct(detail.product.id)
      if (!outcome.ok) {
        setRowError(outcome.reason)
        setConfirm(null)
        return
      }
      onDeleted?.(detail.product.name)
    } catch (err) {
      setRowError(err instanceof Error ? err.message : 'The database refused the deletion.')
    } finally {
      setRowBusy(false)
    }
  }

  async function handleSave() {
    if (!form || !detail) return
    // Validate warranty option edits before writing anything.
    const optionPatches: { id: string; patch: Parameters<typeof updateWarrantyOption>[1] }[] = []
    for (const draft of optionDrafts) {
      const before = optionRows.find((r) => r.id === draft.id)
      if (!before) continue
      const parsed = draftToPatch(draft)
      if (!parsed.ok) { setSave({ kind: 'error', message: parsed.reason }); return }
      const p = parsed.patch
      if (p.duration_months !== before.duration_months || p.additional_price_cents !== before.additional_price_cents
          || p.is_enabled !== before.is_enabled) {
        optionPatches.push({ id: draft.id, patch: p })
      }
    }

    // Condition edits: one per item — each variant on its own, or the product
    // itself when it has no variants. Never one value across every variant.
    const conditionKeys = detail.variants.length > 0 ? detail.variants.map((v) => v.id) : [PRODUCT_KEY]
    for (const key of conditionKeys) {
      const d = conditionDraftFor(key)
      if (d.battery_health !== null && (d.battery_health < 0 || d.battery_health > 100)) {
        setSave({ kind: 'error', message: 'Battery health must be between 0 and 100%.' }); return
      }
      if (d.cycle_count !== null && d.cycle_count < 0) {
        setSave({ kind: 'error', message: 'Cycle count cannot be negative.' }); return
      }
    }

    setSave({ kind: 'saving' })
    try {
      await updateProduct(detail.product.id, form)

      for (const key of conditionKeys) {
        const row = conditionRowFor(key)
        const draft = conditionDraftFor(key)
        if (!conditionChanged(draft, row)) continue
        const variantId = key === PRODUCT_KEY ? null : key
        // A variant with no row is Brand New: switching one back removes its row.
        if (variantId && draft.condition === 'brand_new') {
          if (row) await deleteCondition(row.id)
          continue
        }
        await saveCondition(detail.product.id, variantId, row?.id ?? null, draft)
      }

      for (const row of planRows) {
        const draft = planDrafts[row.id]
        if (!draft || !planChanged(draft, row)) continue
        const { id, ...fields } = draft
        await updatePlan(id, fields)
      }

      for (const { id, patch } of optionPatches) await updateWarrantyOption(id, patch)

      for (const variant of variants) {
        const before = detail.variants.find((v) => v.id === variant.id)
        if (!before) continue
        const changed =
          before.name !== variant.name || before.color !== variant.color ||
          before.color_code !== variant.color_code || before.storage !== variant.storage ||
          before.sort_order !== variant.sort_order
        if (!changed) continue
        // legacy_key and stock are never sent — cart identity depends on the
        // key, and stock changes only through Adjust stock.
        await updateVariant(variant.id, {
          name: variant.name, color: variant.color, color_code: variant.color_code,
          storage: variant.storage, sort_order: variant.sort_order,
        })
      }

      await saveSpecs(detail.product.id, specs, detail.specs)

      for (const image of images) {
        const before = detail.images.find((i) => i.id === image.id)
        if (!before) continue
        if (before.path === image.path && (before.alt ?? '') === image.alt && before.position === image.position
            && before.variant_id === image.variant_id) continue
        await updateImage(image.id, { path: image.path, alt: image.alt || null, position: image.position, variant_id: image.variant_id })
      }

      const fresh = await loadProductDetail(detail.product.id)
      setDetail(fresh)
      setForm(formFrom(fresh.product))
      setSpecs(fresh.specs.map((s) => ({ id: s.id, label: s.label, value: s.value })))
      setImages(fresh.images.map((i) => ({ id: i.id, path: i.path, alt: i.alt ?? '', position: i.position, variant_id: i.variant_id })))
      await reloadExtras(true)
      setSave({ kind: 'saved' })
      onSaved()
    } catch (err) {
      setSave({ kind: 'error', message: describeAdminError(err, 'Save failed.') })
    }
  }

  const disabled = !canEdit || save.kind === 'saving'
  const hasVariants = (detail?.variants.length ?? 0) > 0
  const legacy = detail && hasVariants ? legacyCondition(detail.product) : null
  const productPlan = planRows.find((r) => r.variant_id === null)
  const noun = warrantyNoun({ subcategory: form?.subcategory ?? '' })

  // Stock as recorded, and what the database will refuse to delete: anything
  // holding stock, and anything with stock history (the ledger keeps it).
  const productStock = detail?.product.stock ?? 0
  const productMode = detail?.product.tracking_mode === 'unit' ? 'unit' : 'quantity'
  const variantRows = detail?.variants ?? []
  const sharedVariants = variantRows.filter((v) => v.stock === null).length
  const variantsWithHistory = new Set(movements.map((m) => m.variant_id).filter(Boolean))
  const productDeleteBlock =
    productStock > 0 ? `It still has ${productStock} in stock. Set its stock to 0 first, or unpublish it.`
    : variantRows.some((v) => (v.stock ?? 0) > 0) ? 'A variant still has stock. Set it to 0 first, or unpublish the product.'
    : movements.length > 0 ? 'It has stock history, which is kept permanently. Unpublish it instead.'
    : null
  function variantDeleteBlock(variantId: string): string | null {
    const stock = variantRows.find((v) => v.id === variantId)?.stock ?? null
    if (stock !== null && stock > 0) return 'Has stock — adjust it to 0 first.'
    if (variantsWithHistory.has(variantId)) return 'Has stock history — kept for the record. Retiring variants comes in a later update.'
    return null
  }

  /** One plan's editor: the product default or a variant override. */
  function renderPlan(row: WarrantyPlanRow, idPrefix: string) {
    const ids = new Set(optionRows.filter((o) => o.plan_id === row.id).map((o) => o.id))
    return (
      <PlanEditor
        key={row.id}
        idPrefix={idPrefix}
        noun={noun}
        plan={planDraftFor(row)}
        onChange={(next) => { setPlanDrafts((prev) => ({ ...prev, [row.id]: next })); setSave({ kind: 'idle' }) }}
        rows={optionRows.filter((o) => o.plan_id === row.id)}
        drafts={optionDrafts.filter((d) => ids.has(d.id))}
        setDrafts={setOptionDrafts}
        disabled={disabled}
        rowBusy={rowBusy}
        onAdd={async (months, addOnCents) => {
          let ok = false
          await runRowAction(async () => {
            await addWarrantyOption(productId, row.id, { months, addOnCents }, optionRows.filter((o) => o.plan_id === row.id))
            ok = true
          })
          return ok
        }}
        onSetDefault={(id) => void runRowAction(() => setDefaultWarrantyOption(row.id, id))}
        onMove={(id, direction) => moveOption(row.id, id, direction)}
        onAskDelete={(id, label) => setConfirm({ kind: 'warranty', id, label })}
      />
    )
  }

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close editor" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label="Edit product"
        className="relative flex h-full w-full max-w-2xl flex-col bg-background border-l border-mint/80 dark:border-border shadow-float">

        <header className="flex items-center gap-3 border-b border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">
              {detail?.product.name ?? 'Loading…'}
            </h2>
            {detail && <p className="truncate font-mono text-[11px] text-muted-foreground">{detail.product.id}</p>}
          </div>
          <button type="button" onClick={onClose} aria-label="Close editor"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-primary-soft active:scale-95 transition">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
          {!detail && !loadError && (
            <div className="flex items-center gap-2.5 text-sm text-muted-foreground py-10 justify-center">
              <LoaderCircle size={18} className="animate-spin motion-reduce:animate-none" />
              Loading product…
            </div>
          )}

          {loadError && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
              <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[13px] text-foreground">{loadError}</p>
            </div>
          )}

          {!canEdit && detail && (
            <div className="flex items-start gap-2.5 rounded-2xl border border-amber-500/25 bg-amber-500/10 px-4 py-3">
              <Lock size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
              <p className="text-[13px] leading-snug text-foreground">
                Read-only. Your role can view the catalog but the database refuses catalog writes.
              </p>
            </div>
          )}

          {detail && form && (
            <>
              <EditorSection title="Details">
                <div className="grid gap-4">
                  <LockedField label="Product ID" value={detail.product.id}
                    hint="read-only — static routes, cart and wishlist entries depend on it" />
                  <TextField id="p-name" label="Name" value={form.name} disabled={disabled}
                    onChange={(v) => patchForm('name', v)} />
                  <div className="grid sm:grid-cols-2 gap-4">
                    <SelectField id="p-cat" label="Category" value={form.category_id} disabled={disabled}
                      onChange={(v) => patchForm('category_id', v)}
                      options={categories.map((c) => ({ value: c.id, label: c.name }))} />
                    <SelectField id="p-sub" label="Subcategory" value={form.subcategory} disabled={disabled}
                      onChange={(v) => patchForm('subcategory', v)}
                      options={SUBCATEGORY_OPTIONS.map((s) => ({ value: s, label: s }))} />
                  </div>
                  <TextField id="p-model" label="Model" value={form.model ?? ''} disabled={disabled}
                    onChange={(v) => patchForm('model', v || null)} />
                  <TextAreaField id="p-desc" label="Description" value={form.description} disabled={disabled}
                    onChange={(v) => patchForm('description', v)} />
                </div>
              </EditorSection>

              <EditorSection title="Status">
                <div className="grid sm:grid-cols-2 gap-4 items-start">
                  <SelectField id="p-life" label="Lifecycle" value={form.lifecycle_status ?? ''} disabled={disabled}
                    allowEmpty onChange={(v) => patchForm('lifecycle_status', v || null)}
                    options={LIFECYCLE_OPTIONS.map((s) => ({ value: s, label: s }))} />
                  <div className="pt-6">
                    <CheckboxField id="p-isnew" label="Show “New” badge" checked={form.is_new} disabled={disabled}
                      onChange={(v) => patchForm('is_new', v)} />
                  </div>
                </div>
              </EditorSection>

              <EditorSection title="Stock"
                description="Stock changes only through Adjust stock. Every change is recorded with who made it, the reason and a note, and cannot be edited later.">
                <div className="grid gap-3">
                  <div className="flex flex-wrap items-end gap-4">
                    <div>
                      <p className="text-[12px] text-muted-foreground">{hasVariants ? 'Product stock' : 'In stock'}</p>
                      <p className="text-2xl font-bold tabular-nums tracking-tight text-foreground">{productStock}</p>
                    </div>
                    {canEdit && productMode === 'quantity' && (
                      <Button type="button" variant="outline" size="sm" disabled={rowBusy}
                        onClick={() => setAdjusting({ variantId: null, label: detail.product.name, current: productStock })}>
                        Adjust stock
                      </Button>
                    )}
                    {canEdit && (
                      <Button type="button" variant="ghost" size="sm" disabled={rowBusy}
                        onClick={() => setModeChange({ variantId: null, label: detail.product.name, to: productMode === 'unit' ? 'quantity' : 'unit' })}>
                        {productMode === 'unit' ? 'Track by quantity' : 'Track individually'}
                      </Button>
                    )}
                  </div>
                  <p className="text-[12.5px] leading-snug text-muted-foreground">
                    {productMode === 'unit'
                      ? 'Tracked item by item: stock comes in through a GRN and leaves by sale, return or write-off.'
                      : 'Tracked by quantity: a number, with no barcode per item.'}
                  </p>
                  {hasVariants && (
                    <p className="text-[12.5px] leading-snug text-muted-foreground">
                      {sharedVariants === variantRows.length
                        ? `All ${variantRows.length} variants share this stock.`
                        : sharedVariants === 0
                          ? 'Every variant has its own stock (shown in its card), so checkout does not use this product figure.'
                          : `${sharedVariants} of ${variantRows.length} variants share this stock; the others have their own, shown in their cards.`}
                    </p>
                  )}

                  {stockNotice && (
                    <p role="status" className="flex items-center gap-1.5 text-[12.5px] font-semibold text-primary">
                      <Check size={14} className="shrink-0" /> {stockNotice}
                    </p>
                  )}
                  {refreshError && (
                    <div className="flex flex-wrap items-start gap-2.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-3.5 py-2.5">
                      <AlertCircle size={15} className="mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
                      <p className="min-w-0 flex-1 text-[12.5px] text-foreground">{refreshError}</p>
                      <Button type="button" variant="outline" size="sm" disabled={rowBusy} onClick={() => void retryRefresh()}>
                        Refresh
                      </Button>
                    </div>
                  )}

                  {movementsError && <p className="text-[12px] text-red-500">{movementsError}</p>}
                  {movements.length > 0 && (
                    <div className="rounded-xl border border-mint/70 dark:border-border">
                      <p className="border-b border-mint/70 dark:border-border px-3 py-2 text-[12px] font-semibold text-foreground">
                        Stock history
                        {movements.length > 30 && (
                          <span className="font-normal text-muted-foreground">
                            {' '}· latest 30 shown{movements.length >= MOVEMENT_LIMIT ? `; only the latest ${MOVEMENT_LIMIT} are loaded here, older history is kept in full` : ''}
                          </span>
                        )}
                      </p>
                      <ul className="max-h-60 divide-y divide-mint/60 dark:divide-border overflow-y-auto">
                        {movements.slice(0, 30).map((m) => (
                          <li key={m.id} className="px-3 py-2 text-[12px] leading-snug">
                            <p className="text-foreground">
                              <span className={cn('font-semibold tabular-nums', m.delta > 0 ? 'text-primary' : 'text-red-500')}>
                                {m.delta > 0 ? '+' : ''}{m.delta}
                              </span>
                              {m.quantity_before != null && m.quantity_after != null && (
                                <span className="tabular-nums text-muted-foreground"> ({m.quantity_before} → {m.quantity_after})</span>
                              )}
                              {' · '}{reasonLabel(m.reason)}
                              {' · '}{m.variant_id ? (variantRows.find((v) => v.id === m.variant_id)?.name ?? 'Variant') : 'Product'}
                            </p>
                            <p className="text-muted-foreground">
                              {new Date(m.created_at).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })}
                              {m.actorName ? ` · ${m.actorName}` : ''}
                              {m.note ? ` · ${m.note}` : ''}
                            </p>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              </EditorSection>

              <EditorSection title="Condition"
                description={hasVariants
                  ? 'Each variant has its own condition — set it in the variant cards below. Changing one variant never changes another, and a variant with no condition set is Brand New.'
                  : 'Brand New or Pre-Owned. To sell a model both new and used, give it variants (each with its own condition) or create a separate product.'}>
                <div className="grid gap-4">
                  {extrasError && <p className="text-[12.5px] text-red-500">{extrasError}</p>}

                  {!hasVariants && (
                    <ConditionEditor idPrefix="p" draft={conditionDraftFor(PRODUCT_KEY)} grades={grades} disabled={disabled}
                      onChange={(d) => setConditionDraft(PRODUCT_KEY, d)}
                      onRequestBrandNew={() => setConfirm({ kind: 'brand-new', key: PRODUCT_KEY, label: 'this product' })} />
                  )}

                  {legacy && (
                    <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-3.5 text-[12.5px] leading-relaxed text-foreground">
                      <p className="mb-1 font-semibold">Older product-level condition — not shown to customers</p>
                      <p className="text-muted-foreground">
                        Before conditions were set per variant, this whole product was recorded as{' '}
                        <strong>{legacy.condition === 'pre_owned' ? 'Pre-Owned' : legacy.condition}</strong>
                        {[
                          legacy.condition_grade_id && `grade: ${grades.find((g) => g.id === legacy.condition_grade_id)?.label ?? 'set'}`,
                          legacy.battery_health !== null && `battery ${legacy.battery_health}%`,
                          legacy.cycle_count !== null && `${legacy.cycle_count} cycles`,
                          legacy.physical_condition, legacy.accessories_included, legacy.device_notes,
                        ].filter(Boolean).map((part) => ` · ${part}`)}.
                        It was not copied to any variant because it does not say which variant it describes.
                        Use “Apply older details” on the right variant, then clear it here.
                      </p>
                      {canEdit && (
                        <Button type="button" variant="outline" size="sm" className="mt-2.5" disabled={rowBusy}
                          onClick={() => void runRowAction(() => clearLegacyCondition(productId))}>
                          Clear older details
                        </Button>
                      )}
                    </div>
                  )}

                  {gradesError && <p className="text-[12px] text-red-500">{gradesError}</p>}
                  {canEdit && (
                    <div>
                      <button type="button" onClick={() => setManagingGrades((m) => !m)}
                        className="focus-ring inline-flex items-center gap-1.5 rounded-full text-[12.5px] font-semibold text-primary">
                        {managingGrades ? 'Close grade list' : 'Manage condition grades'}
                      </button>
                      {managingGrades && (
                        <GradesManager grades={grades} onChanged={async () => { setGrades(await listConditionGrades()); setGradesError(null) }} />
                      )}
                    </div>
                  )}
                </div>
              </EditorSection>

              <EditorSection title="Warranty"
                description={`The product's default warranty. ${hasVariants ? 'A variant can override it in its own card. ' : ''}Customers see it as “${noun}”.`}>
                {productPlan
                  ? renderPlan(productPlan, 'pw')
                  : (
                    <div className="grid gap-2">
                      <p className="text-[12.5px] text-muted-foreground">This product has no warranty set up yet (customers see no warranty).</p>
                      {canEdit && (
                        <Button type="button" variant="outline" size="sm" className="w-fit" disabled={rowBusy}
                          onClick={() => void runRowAction(async () => { await createPlan(productId, null, {}) })}>
                          <Plus size={14} className="mr-1.5" /> Set up warranty
                        </Button>
                      )}
                    </div>
                  )}
              </EditorSection>

              <EditorSection title="Variants"
                  description="Variant keys are fixed once created: they map database rows back to saved carts and wishlists. Prices for each variant live on the Pricing screen.">
                  <div className="space-y-4">
                    {variants.map((variant, index) => (
                      <div key={variant.id} className="rounded-2xl border border-mint/70 dark:border-border bg-card p-4">
                        <div className="mb-3 flex items-center gap-2">
                          <span className="rounded-full border border-mint-deep bg-primary-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-primary">
                            {variant.legacyKey ?? '—'}
                          </span>
                          <Lock size={12} className="text-muted-foreground" />
                          {canEdit && variantDeleteBlock(variant.id) && (
                            <span className="ml-auto text-right text-[11px] leading-tight text-muted-foreground">
                              {variantDeleteBlock(variant.id)}
                            </span>
                          )}
                          <button type="button" disabled={disabled || rowBusy || variantDeleteBlock(variant.id) !== null}
                            aria-label={`Remove variant ${variant.name}`}
                            title={variantDeleteBlock(variant.id) ?? undefined}
                            onClick={() => setConfirm({ kind: 'variant', id: variant.id, label: variant.name })}
                            className={cn('focus-ring flex h-8 w-8 shrink-0 items-center justify-center rounded-xl text-muted-foreground transition hover:bg-red-500/8 hover:text-red-500 active:scale-95 disabled:opacity-40',
                              canEdit && variantDeleteBlock(variant.id) ? 'ml-1' : 'ml-auto')}>
                            <Trash2 size={14} />
                          </button>
                        </div>
                        <div className="grid gap-3">
                          <TextField id={`v-name-${variant.id}`} label="Label" value={variant.name} disabled={disabled}
                            onChange={(v) => setVariants((p) => p.map((x, i) => i === index ? { ...x, name: v } : x))} />
                          <div className="grid sm:grid-cols-3 gap-3">
                            <TextField id={`v-color-${variant.id}`} label="Colour" value={variant.color ?? ''} disabled={disabled}
                              onChange={(v) => setVariants((p) => p.map((x, i) => i === index ? { ...x, color: v || null } : x))} />
                            <TextField id={`v-hex-${variant.id}`} label="Colour code" value={variant.color_code ?? ''} disabled={disabled}
                              onChange={(v) => setVariants((p) => p.map((x, i) => i === index ? { ...x, color_code: v || null } : x))} />
                            <TextField id={`v-store-${variant.id}`} label="Storage" value={variant.storage ?? ''} disabled={disabled}
                              onChange={(v) => setVariants((p) => p.map((x, i) => i === index ? { ...x, storage: v || null } : x))} />
                          </div>
                          <div className="grid sm:grid-cols-2 gap-3">
                            {(() => {
                              const own = variantRows.find((v) => v.id === variant.id)?.stock ?? null
                              return (
                                <div>
                                  <span className="mb-1.5 block text-[13px] font-semibold text-foreground">Stock</span>
                                  <div className="flex min-h-[42px] items-center gap-2 rounded-xl border border-dashed border-mint-deep dark:border-border px-3 py-2">
                                    <span className="flex-1 text-[13px] text-foreground">
                                      {own === null
                                        ? <>Shares product stock <span className="tabular-nums text-muted-foreground">({productStock})</span></>
                                        : <>Own stock: <strong className="tabular-nums">{own}</strong></>}
                                    </span>
                                    {canEdit && own !== null && (() => {
                                      const row = variantRows.find((v) => v.id === variant.id)
                                      const mode = row?.tracking_mode === 'unit' || row?.tracking_mode === 'quantity' ? row.tracking_mode : productMode
                                      return (
                                        <>
                                          {mode === 'quantity' && (
                                            <button type="button" disabled={rowBusy}
                                              onClick={() => setAdjusting({ variantId: variant.id, label: variant.name, current: own })}
                                              className="focus-ring rounded-full text-[12px] font-semibold text-primary disabled:opacity-50">
                                              Adjust
                                            </button>
                                          )}
                                          <button type="button" disabled={rowBusy}
                                            onClick={() => setModeChange({ variantId: variant.id, label: variant.name, to: mode === 'unit' ? 'quantity' : 'unit' })}
                                            className="focus-ring rounded-full text-[12px] font-semibold text-primary disabled:opacity-50">
                                            {mode === 'unit' ? 'Track by quantity' : 'Track individually'}
                                          </button>
                                        </>
                                      )
                                    })()}
                                  </div>
                                </div>
                              )
                            })()}
                            <NumberField id={`v-sort-${variant.id}`} label="Order" min={0} value={variant.sort_order} disabled={disabled}
                              onChange={(v) => setVariants((p) => p.map((x, i) => i === index ? { ...x, sort_order: v ?? 0 } : x))} />
                          </div>

                          {/* This variant's OWN condition — editing it never touches another variant. */}
                          <div className="rounded-xl border border-dashed border-mint-deep dark:border-border p-3">
                            <ConditionEditor idPrefix={`v-${variant.id}`} draft={conditionDraftFor(variant.id)} grades={grades} disabled={disabled}
                              onChange={(d) => setConditionDraft(variant.id, d)}
                              onRequestBrandNew={() => setConfirm({ kind: 'brand-new', key: variant.id, label: variant.name })} />
                            {legacy && canEdit && (
                              <button type="button" disabled={disabled}
                                onClick={() => setConditionDraft(variant.id, {
                                  rowId: conditionDraftFor(variant.id).rowId,
                                  condition: legacy.condition === 'refurbished' ? 'refurbished' : 'pre_owned',
                                  condition_grade_id: legacy.condition_grade_id, battery_health: legacy.battery_health,
                                  cycle_count: legacy.cycle_count, physical_condition: legacy.physical_condition,
                                  accessories_included: legacy.accessories_included, device_notes: legacy.device_notes,
                                })}
                                className="focus-ring mt-2 rounded-full text-[12px] font-semibold text-amber-700 dark:text-amber-400">
                                Apply older details to this variant
                              </button>
                            )}
                          </div>

                          {/* Warranty: the product default unless this variant overrides it. */}
                          {(() => {
                            const override = planRows.find((r) => r.variant_id === variant.id)
                            return (
                              <div className="rounded-xl border border-dashed border-mint-deep dark:border-border p-3">
                                <p className="mb-2 text-[12.5px] font-semibold text-foreground">Warranty</p>
                                {override ? (
                                  <>
                                    {renderPlan(override, `vw-${variant.id}`)}
                                    {canEdit && (
                                      <button type="button" disabled={disabled || rowBusy}
                                        onClick={() => setConfirm({ kind: 'plan', id: override.id, label: variant.name })}
                                        className="focus-ring mt-3 rounded-full text-[12px] font-semibold text-red-500">
                                        Remove override — use the product warranty
                                      </button>
                                    )}
                                  </>
                                ) : (
                                  <div className="flex flex-wrap items-center gap-2">
                                    <p className="text-[12.5px] text-muted-foreground">Uses the product warranty.</p>
                                    {canEdit && (
                                      <Button type="button" variant="outline" size="sm" disabled={disabled || rowBusy}
                                        onClick={() => void runRowAction(async () => {
                                          // Starts as "No Warranty"; configure it here before saving.
                                          await createPlan(productId, variant.id, { warranty_type: 'none' })
                                        })}>
                                        Override for this variant
                                      </Button>
                                    )}
                                  </div>
                                )}
                              </div>
                            )
                          })()}
                        </div>
                      </div>
                    ))}

                    {variants.length === 0 && (
                      <p className="text-[13px] text-muted-foreground">
                        This product is sold as one thing. Add a variant to offer storage, colour or size
                        options — each one can then be priced separately.
                      </p>
                    )}

                    <div className="flex items-start gap-2">
                      <input aria-label="New variant label" value={newVariantName} disabled={disabled || rowBusy}
                        placeholder="New variant, e.g. 512GB"
                        onChange={(e) => setNewVariantName(e.target.value)}
                        className="focus-ring flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] text-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60" />
                      <Button type="button" variant="outline" size="sm"
                        disabled={disabled || rowBusy || newVariantName.trim() === ''}
                        onClick={() => void runRowAction(async () => {
                          await addVariant(
                            productId,
                            { name: newVariantName, color: null, color_code: null, storage: null },
                            detail.variants,
                          )
                          setNewVariantName('')
                        })}>
                        <Plus size={14} className="mr-1.5" /> Add
                      </Button>
                    </div>
                  </div>
                </EditorSection>

              <EditorSection title="Specifications" description="Rendered on the product page in this order.">
                <div className="space-y-2.5">
                  {specs.map((spec, index) => (
                    <div key={spec.id ?? `new-${index}`} className="flex items-start gap-2">
                      <input aria-label="Specification label" value={spec.label} disabled={disabled}
                        placeholder="Label"
                        onChange={(e) => setSpecs((p) => p.map((s, i) => i === index ? { ...s, label: e.target.value } : s))}
                        className="focus-ring w-[38%] rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] font-semibold text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
                      <input aria-label="Specification value" value={spec.value} disabled={disabled}
                        placeholder="Value"
                        onChange={(e) => setSpecs((p) => p.map((s, i) => i === index ? { ...s, value: e.target.value } : s))}
                        className="focus-ring flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
                      <button type="button" disabled={disabled} aria-label={`Remove ${spec.label || 'specification'}`}
                        onClick={() => setSpecs((p) => p.filter((_, i) => i !== index))}
                        className="focus-ring mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-muted-foreground hover:text-red-500 hover:bg-red-500/8 active:scale-95 transition disabled:opacity-40">
                        <Trash2 size={15} />
                      </button>
                    </div>
                  ))}
                  <Button type="button" variant="outline" size="sm" disabled={disabled}
                    onClick={() => setSpecs((p) => [...p, { id: null, label: '', value: '' }])}>
                    <Plus size={14} className="mr-1.5" /> Add specification
                  </Button>
                </div>
              </EditorSection>

              <EditorSection title="Images"
                description="Upload photos to Supabase Storage (JPG, PNG or WebP, up to 5 MB) — never bundled into the app. For a pre-owned unit, upload photos of the actual device and label each one (Front, Back, Battery health…). Older images keep their bundled paths.">
                <div className="space-y-3">
                  {images.length === 0 && (
                    <p className="text-[13px] text-muted-foreground">
                      No images yet. The first one added becomes the card image customers see.
                    </p>
                  )}
                  {images.map((image, index) => {
                    const row = detail.images.find((i) => i.id === image.id)
                    const uploaded = Boolean(row?.storage_bucket)
                    return (
                    <div key={image.id} className="flex items-start gap-3 rounded-2xl border border-mint/70 dark:border-border bg-card p-3">
                      <span className={`flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-xl border ${
                        row?.is_primary
                          ? 'border-mint-deep bg-primary-soft text-primary'
                          : 'border-mint/70 dark:border-border bg-muted text-muted-foreground'
                      }`}>
                        {row
                          ? <img src={productImageUrl(row)} alt="" className="h-full w-full object-cover" />
                          : <ImageIcon size={16} />}
                      </span>
                      <div className="min-w-0 flex-1 grid gap-2">
                        {uploaded ? (
                          <p className="truncate rounded-xl border border-dashed border-mint-deep dark:border-border bg-muted px-3 py-2 font-mono text-[11px] text-muted-foreground">
                            Uploaded · {image.path}
                          </p>
                        ) : (
                          <input aria-label="Image path" value={image.path} disabled={disabled}
                            onChange={(e) => setImages((p) => p.map((x, i) => i === index ? { ...x, path: e.target.value } : x))}
                            className="focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-background px-3 py-2 font-mono text-[12px] text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
                        )}
                        {hasVariants && (
                          <select aria-label="Shown for" value={image.variant_id ?? ''} disabled={disabled}
                            onChange={(e) => setImages((p) => p.map((x, i) => i === index ? { ...x, variant_id: e.target.value || null } : x))}
                            className="focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-background px-3 py-2 text-[13px] text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60">
                            <option value="">All variants</option>
                            {detail.variants.map((v) => <option key={v.id} value={v.id}>Only {v.name}</option>)}
                          </select>
                        )}
                        <input aria-label="Image label" value={image.alt} disabled={disabled} placeholder="Label, e.g. Front, Back, Battery health"
                          onChange={(e) => setImages((p) => p.map((x, i) => i === index ? { ...x, alt: e.target.value } : x))}
                          className="focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-background px-3 py-2 text-[13px] text-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60" />
                      </div>
                      <div className="flex shrink-0 flex-col gap-1">
                        <button type="button" disabled={disabled || rowBusy}
                          aria-label={detail.images.find((i) => i.id === image.id)?.is_primary ? 'Primary image' : 'Make primary image'}
                          onClick={() => void runRowAction(() => setPrimaryImage(productId, image.id))}
                          className={`focus-ring flex h-9 w-9 items-center justify-center rounded-xl transition active:scale-95 disabled:opacity-40 ${
                            detail.images.find((i) => i.id === image.id)?.is_primary
                              ? 'text-primary'
                              : 'text-muted-foreground hover:bg-primary-soft hover:text-primary'
                          }`}>
                          <Star size={15} fill={detail.images.find((i) => i.id === image.id)?.is_primary ? 'currentColor' : 'none'} />
                        </button>
                        <button type="button" disabled={disabled || rowBusy} aria-label="Remove image"
                          onClick={() => setConfirm({ kind: 'image', id: image.id, label: image.path })}
                          className="focus-ring flex h-9 w-9 items-center justify-center rounded-xl text-muted-foreground transition hover:bg-red-500/8 hover:text-red-500 active:scale-95 disabled:opacity-40">
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </div>
                    )
                  })}

                  <input ref={fileInput} type="file" accept="image/jpeg,image/png,image/webp" multiple hidden
                    onChange={(e) => void uploadImages(e.target.files)} />
                  {hasVariants && (
                    <select aria-label="Upload photos for" value={uploadTarget} disabled={disabled || rowBusy}
                      onChange={(e) => setUploadTarget(e.target.value)}
                      className="focus-ring mr-2 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] text-foreground focus:outline-none disabled:opacity-60">
                      <option value="">For all variants</option>
                      {detail.variants.map((v) => <option key={v.id} value={v.id}>For {v.name} only</option>)}
                    </select>
                  )}
                  <Button type="button" variant="outline" size="sm" disabled={disabled || rowBusy}
                    onClick={() => fileInput.current?.click()}>
                    {rowBusy
                      ? <LoaderCircle size={14} className="mr-1.5 animate-spin motion-reduce:animate-none" />
                      : <Upload size={14} className="mr-1.5" />}
                    Upload photos
                  </Button>

                  <p className="pt-1 text-[11.5px] text-muted-foreground">Or reference a bundled image path:</p>
                  <div className="flex items-start gap-2">
                    <input aria-label="New image path" value={newImagePath} disabled={disabled || rowBusy}
                      placeholder="/images/products/iphone/iphone-18-pro.jpg"
                      onChange={(e) => setNewImagePath(e.target.value)}
                      className="focus-ring flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 font-mono text-[12px] text-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60" />
                    <Button type="button" variant="outline" size="sm"
                      disabled={disabled || rowBusy || newImagePath.trim() === ''}
                      onClick={() => void runRowAction(async () => {
                        await addImage(productId, { path: newImagePath, alt: null }, detail.images)
                        setNewImagePath('')
                      })}>
                      <Plus size={14} className="mr-1.5" /> Add
                    </Button>
                  </div>
                </div>
              </EditorSection>

              <EditorSection title="Compatibility"
                description="Which devices this product fits. Shown on the product page for parts and accessories.">
                <div className="space-y-2.5">
                  {detail.compatibility.length === 0 && (
                    <p className="text-[13px] text-muted-foreground">No compatibility entries.</p>
                  )}
                  <div className="flex flex-wrap gap-2">
                    {detail.compatibility.map((c) => (
                      <span key={c.id}
                        className="inline-flex items-center gap-1.5 rounded-full border border-mint-deep bg-primary-soft py-1 pl-3 pr-1 text-[12px] text-primary">
                        {c.label}
                        <button type="button" disabled={disabled || rowBusy} aria-label={`Remove ${c.label}`}
                          onClick={() => setConfirm({ kind: 'compatibility', id: c.id, label: c.label })}
                          className="focus-ring flex h-5 w-5 items-center justify-center rounded-full text-primary/70 transition hover:bg-red-500/10 hover:text-red-500 disabled:opacity-40">
                          <X size={12} />
                        </button>
                      </span>
                    ))}
                  </div>

                  <div className="flex items-start gap-2">
                    <input aria-label="New compatibility entry" value={newCompatibility} disabled={disabled || rowBusy}
                      placeholder="iPhone 18 Pro"
                      onChange={(e) => setNewCompatibility(e.target.value)}
                      className="focus-ring flex-1 rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] text-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60" />
                    <Button type="button" variant="outline" size="sm"
                      disabled={disabled || rowBusy || newCompatibility.trim() === ''}
                      onClick={() => void runRowAction(async () => {
                        await addCompatibility(productId, { label: newCompatibility, device_model_id: null }, detail.compatibility)
                        setNewCompatibility('')
                      })}>
                      <Plus size={14} className="mr-1.5" /> Add
                    </Button>
                  </div>
                </div>
              </EditorSection>

              {canEdit && (
                <EditorSection title="Danger zone"
                  description="A product that has ever been ordered, holds stock or has stock history is unpublished, never deleted — that is what keeps past orders and the stock record readable.">
                  {productDeleteBlock && (
                    <p className="mb-2.5 text-[12.5px] leading-snug text-muted-foreground">{productDeleteBlock}</p>
                  )}
                  <Button type="button" variant="outline" disabled={rowBusy || productDeleteBlock !== null}
                    className="border-red-500/40 text-red-500 hover:bg-red-500/8"
                    onClick={() => void (async () => {
                      setRowError(null)
                      try {
                        setConfirm({ kind: 'product', orderLines: await countOrderLines(productId) })
                      } catch (err) {
                        setRowError(err instanceof Error ? err.message : 'Could not check order history.')
                      }
                    })()}>
                    <Ban size={15} className="mr-1.5" />
                    Delete this product
                  </Button>
                </EditorSection>
              )}

              {rowError && (
                <div className="flex items-start gap-2.5 rounded-2xl border border-red-500/25 bg-red-500/8 px-4 py-3">
                  <AlertCircle size={16} className="mt-0.5 shrink-0 text-red-500" />
                  <p className="text-[13px] text-foreground">{rowError}</p>
                </div>
              )}

              <div className="flex items-start gap-2.5 rounded-2xl border border-mint/70 dark:border-border bg-muted px-4 py-3">
                <Info size={15} className="mt-0.5 shrink-0 text-muted-foreground" />
                <p className="text-[12.5px] leading-snug text-muted-foreground">
                  Prices are set on the Pricing screen. Stock changes only through Adjust stock above. Both go through audited database functions.
                </p>
              </div>
            </>
          )}
        </div>

        {modeChange && detail && (
          <TrackingModeDialog
            productId={detail.product.id}
            variantId={modeChange.variantId}
            label={modeChange.label}
            to={modeChange.to}
            onClose={() => setModeChange(null)}
            onDone={() => { setModeChange(null); void reload().then(() => onSaved()) }}
          />
        )}
        {adjusting && detail && (
          <StockAdjustDialog
            productId={detail.product.id}
            variantId={adjusting.variantId}
            label={adjusting.label}
            current={adjusting.current}
            onClose={() => setAdjusting(null)}
            onDone={(result) => void handleAdjusted(result, adjusting.variantId)}
          />
        )}

        {confirm && (
          <div className="absolute inset-0 z-10 flex items-center justify-center px-5">
            <button type="button" aria-label="Cancel" onClick={() => setConfirm(null)}
              className="absolute inset-0 bg-black/55 backdrop-blur-[2px]" />
            <div role="dialog" aria-modal="true"
              className="relative w-full max-w-sm rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float">
              <h3 className="mb-2 text-lg font-bold tracking-tight text-foreground">
                {confirm.kind === 'variant' ? 'Remove this variant?'
                  : confirm.kind === 'image' ? 'Remove this image?'
                  : confirm.kind === 'compatibility' ? 'Remove this entry?'
                  : confirm.kind === 'warranty' ? 'Delete this warranty option?'
                  : confirm.kind === 'plan' ? 'Remove this warranty override?'
                  : confirm.kind === 'brand-new' ? 'Switch to Brand New?'
                  : confirm.orderLines > 0 ? 'This product has been ordered' : 'Delete this product?'}
              </h3>
              <p className="mb-5 text-sm leading-relaxed text-muted-foreground">
                {confirm.kind === 'variant'
                  ? `“${confirm.label}” and its price history, condition, warranty override and variant-only photos are removed permanently. Carts that hold it will no longer resolve it.`
                  : confirm.kind === 'image'
                    ? `${confirm.label} stops being shown. An uploaded file is deleted from storage; a bundled file is untouched.`
                  : confirm.kind === 'warranty'
                    ? `The ${confirm.label} stops being offered. Orders already placed with it keep their recorded warranty and price.`
                  : confirm.kind === 'plan'
                    ? `${confirm.label} goes back to the product warranty, and this override's options are deleted. Placed orders keep their recorded warranty.`
                  : confirm.kind === 'brand-new'
                    ? `The grade, battery health, cycle count, physical condition, accessories and notes of ${confirm.label} will be cleared when you save. Other variants are not affected, and photos are not deleted.`
                    : confirm.kind === 'compatibility'
                      ? `“${confirm.label}” is removed from this product's compatibility list.`
                      : confirm.orderLines > 0
                        ? `It appears on ${confirm.orderLines} order line${confirm.orderLines === 1 ? '' : 's'}, so it cannot be deleted. Unpublish it instead — customers stop seeing it and every order stays intact.`
                        : 'The product, its variants, images, specifications and price history are removed permanently. It has never been ordered, so no order history is affected.'}
              </p>
              <div className="flex gap-2.5">
                <Button variant="ghost" fullWidth onClick={() => setConfirm(null)} disabled={rowBusy}>
                  {confirm.kind === 'product' && confirm.orderLines > 0 ? 'Close' : 'Cancel'}
                </Button>
                {!(confirm.kind === 'product' && confirm.orderLines > 0) && (
                  <Button fullWidth disabled={rowBusy}
                    className="bg-red-500 hover:bg-red-500/90 shadow-none"
                    onClick={() => {
                      const target = confirm
                      setConfirm(null)
                      if (target.kind === 'variant') void runRowAction(() => deleteVariant(target.id))
                      else if (target.kind === 'image') void runRowAction(() => deleteImage(target.id))
                      else if (target.kind === 'compatibility') void runRowAction(() => deleteCompatibility(target.id))
                      else if (target.kind === 'warranty') void runRowAction(() => deleteWarrantyOption(target.id))
                      else if (target.kind === 'plan') void runRowAction(() => deletePlan(target.id))
                      else if (target.kind === 'brand-new') {
                        setConditionDraft(target.key, { ...BRAND_NEW_FIELDS, rowId: conditionDraftFor(target.key).rowId })
                      }
                      else void handleDeleteProduct()
                    }}>
                    {rowBusy
                      ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Removing…</>
                      : confirm.kind === 'brand-new' ? 'Switch to Brand New' : 'Remove'}
                  </Button>
                )}
              </div>
            </div>
          </div>
        )}

        <footer className="border-t border-mint/80 dark:border-border px-5 py-4 bg-glass backdrop-blur-xl">
          {save.kind === 'error' && (
            <div className="mb-3 flex items-start gap-2 rounded-xl border border-red-500/25 bg-red-500/8 px-3 py-2">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[12.5px] text-foreground">{save.message}</p>
            </div>
          )}
          {save.kind === 'saved' && (
            <div className="mb-3 flex items-center gap-2 rounded-xl border border-mint-deep bg-primary-soft px-3 py-2">
              <Check size={15} className="shrink-0 text-primary" />
              <p className="text-[12.5px] font-medium text-primary">Saved to the database.</p>
            </div>
          )}
          <div className="flex items-center gap-2.5">
            <Button variant="ghost" onClick={onClose} disabled={save.kind === 'saving'}>Cancel</Button>
            <Button className="flex-1" onClick={() => void handleSave()} disabled={disabled || !detail}>
              {save.kind === 'saving' ? (
                <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Saving…</>
              ) : 'Save changes'}
            </Button>
          </div>
        </footer>
      </div>
    </div>
  )
}

/** Switching mode needs a counted zero: the database refuses while any stock exists. */
function TrackingModeDialog({ productId, variantId, label, to, onClose, onDone }: {
  productId: string
  variantId: string | null
  label: string
  to: 'quantity' | 'unit'
  onClose: () => void
  onDone: () => void
}) {
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    if (note.trim().length < 3) { setError('Add a note of 3 to 500 characters.'); return }
    setBusy(true)
    setError(null)
    try {
      await setTrackingMode(productId, variantId, to, note.trim())
      onDone()
    } catch (err) {
      setError(describeStockError(err))
      setBusy(false)
    }
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center px-5">
      <button type="button" aria-label="Cancel" onClick={busy ? undefined : onClose} className="absolute inset-0 bg-black/55 backdrop-blur-[2px]" />
      <div role="dialog" aria-modal="true" aria-label="Change tracking"
        className="relative w-full max-w-sm space-y-3.5 rounded-[26px] border border-mint/80 dark:border-border bg-surface p-6 shadow-float">
        <div>
          <h3 className="text-lg font-bold tracking-tight">{to === 'unit' ? 'Track individually' : 'Track by quantity'} · {label}</h3>
          <p className="mt-1 text-[13px] leading-snug text-muted-foreground">
            {to === 'unit'
              ? 'Count it first and set its stock to 0. Afterwards receive the counted items with a GRN (Opening stock), so each gets a barcode.'
              : 'Only possible once no individually tracked unit of it is left in the shop or in quarantine.'}
          </p>
        </div>
        <textarea rows={2} value={note} disabled={busy} onChange={(e) => { setNote(e.target.value); setError(null) }}
          placeholder="Note (required)"
          className="focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2.5 text-sm focus:outline-none focus:border-primary/45" />
        {error && <p role="alert" className="text-[12.5px] text-red-600 dark:text-red-400">{error}</p>}
        <div className="flex gap-2.5">
          <Button variant="ghost" fullWidth onClick={onClose} disabled={busy}>Cancel</Button>
          <Button fullWidth onClick={() => void submit()} disabled={busy}>{busy ? 'Saving…' : 'Confirm'}</Button>
        </div>
      </div>
    </div>
  )
}
