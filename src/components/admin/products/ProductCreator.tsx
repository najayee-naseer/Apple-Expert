"use client"

import { useEffect, useState } from 'react'
import { X, LoaderCircle, Check, AlertCircle, Plus, Trash2, Info, Tags } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import {
  createProduct, slugify, validateSlug, isProductIdTaken, listDeviceModels, ProductKeptError,
  SUBCATEGORY_OPTIONS, LIFECYCLE_OPTIONS, WARRANTY_STATUS_OPTIONS,
  type CategoryRow, type NewProductInput, type NewVariantInput,
} from '@/lib/admin/products'
import { parseRupeeInput } from '@/lib/admin/pricing'
import { MAX_STOCK } from '@/lib/admin/inventory'
import { CONDITION_OPTIONS } from '@/lib/admin/warranty'
import {
  TextField, NumberField, TextAreaField, SelectField, CheckboxField, EditorSection, FieldLabel,
} from './fields'

/**
 * Add Product — the whole product, in one pass.
 *
 * This is the screen that makes the catalog data rather than code. Everything
 * Apple Expert needs to sell something new — the product, its variants, specs,
 * images, compatibility and both price tiers — is written to the existing
 * tables here, so releasing the iPhone 18 Pro is an evening's data entry
 * instead of a developer's afternoon.
 *
 * Two rules it enforces on the admin's behalf:
 *
 *   - A product is saved UNPUBLISHED and only goes live once every write has
 *     succeeded and a retail price exists. An incomplete product can never
 *     reach a customer.
 *   - The product ID is chosen once. It becomes the URL, the cart line and the
 *     wishlist entry, so the editor never lets it be changed afterwards.
 */

type SaveState = { kind: 'idle' } | { kind: 'saving' } | { kind: 'error'; message: string }

interface VariantDraft extends Omit<NewVariantInput, 'retailRupees' | 'vipRupees'> {
  retail: string
  vip: string
}

const EMPTY_VARIANT: VariantDraft = {
  name: '', color: null, color_code: null, storage: null, retail: '', vip: '',
  condition: 'brand_new',
}

const rowInput =
  'focus-ring w-full rounded-xl border border-mint-deep dark:border-border bg-card px-3 py-2 text-[13px] text-foreground placeholder:text-muted-foreground focus:outline-none focus:border-primary/45 disabled:opacity-60'

function RemoveButton({ label, onClick, disabled }: { label: string; onClick: () => void; disabled: boolean }) {
  return (
    <button
      type="button" aria-label={label} onClick={onClick} disabled={disabled}
      className="focus-ring mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-muted-foreground transition hover:bg-red-500/8 hover:text-red-500 active:scale-95 disabled:opacity-40"
    >
      <Trash2 size={15} />
    </button>
  )
}

export function ProductCreator({
  categories, onClose, onCreated,
}: {
  categories: CategoryRow[]
  onClose: () => void
  /** warning = the product needs attention (kept draft, opening stock not recorded). */
  onCreated: (message: string, warning?: boolean) => void
}) {
  const [name, setName] = useState('')
  const [productId, setProductId] = useState('')
  const [idEdited, setIdEdited] = useState(false)
  const [categoryId, setCategoryId] = useState(categories[0]?.id ?? '')
  const [subcategory, setSubcategory] = useState<string>('Devices')
  const [model, setModel] = useState('')
  const [description, setDescription] = useState('')
  const [stock, setStock] = useState<number | null>(0)
  const [lifecycle, setLifecycle] = useState<string>('NEW')
  const [isNew, setIsNew] = useState(true)
  // Brand New and Pre-Owned are separate products, each with its own ID,
  // price, stock, warranty and photos. Pre-owned details are added in the
  // editor once the product exists.
  const [condition, setCondition] = useState<'brand_new' | 'pre_owned'>('brand_new')

  const [warrantyText, setWarrantyText] = useState('')
  const [warrantyStatus, setWarrantyStatus] = useState('')
  const [warrantyDuration, setWarrantyDuration] = useState('')
  const [warrantyMonths, setWarrantyMonths] = useState<number | null>(null)
  const [warrantyCoverage, setWarrantyCoverage] = useState('')

  const [variants, setVariants] = useState<VariantDraft[]>([])
  const [specs, setSpecs] = useState<{ label: string; value: string }[]>([])
  const [images, setImages] = useState<{ path: string; alt: string }[]>([])
  const [compatibility, setCompatibility] = useState<{ label: string; device_model_id: string | null }[]>([])
  const [deviceModels, setDeviceModels] = useState<{ id: string; name: string }[]>([])

  const [retail, setRetail] = useState('')
  const [vip, setVip] = useState('')
  const [publish, setPublish] = useState(true)

  const [save, setSave] = useState<SaveState>({ kind: 'idle' })

  // The compatibility picker offers the existing device_models rows; free text
  // stays allowed, exactly as the column permits.
  useEffect(() => {
    let cancelled = false
    listDeviceModels()
      .then((rows) => { if (!cancelled) setDeviceModels(rows) })
      .catch(() => { /* free-text compatibility still works without the list */ })
    return () => { cancelled = true }
  }, [])

  /** The id follows the name until the admin types their own. */
  /** The suggested ID; a pre-owned listing gets its own, so it never collides with the new one. */
  function suggestId(value: string, cond: typeof condition): string {
    const base = slugify(value)
    return cond === 'pre_owned' && base ? `${base}-pre-owned` : base
  }

  function handleName(value: string) {
    setName(value)
    if (!idEdited) setProductId(suggestId(value, condition))
    setSave({ kind: 'idle' })
  }

  function handleCondition(value: typeof condition) {
    setCondition(value)
    if (!idEdited) setProductId(suggestId(name, value))
    setSave({ kind: 'idle' })
  }

  const hasVariants = variants.length > 0

  async function handleSave() {
    const trimmedName = name.trim()
    if (trimmedName === '') { setSave({ kind: 'error', message: 'Give the product a name.' }); return }

    const slug = validateSlug(productId, 'Product ID')
    if (!slug.ok) { setSave({ kind: 'error', message: slug.reason }); return }
    if (categoryId === '') { setSave({ kind: 'error', message: 'Choose a category.' }); return }
    if (stock !== null && (!Number.isInteger(stock) || stock < 0 || stock > MAX_STOCK)) {
      setSave({ kind: 'error', message: `Opening stock must be a whole number from 0 to ${MAX_STOCK.toLocaleString('en-US')}.` })
      return
    }

    // Prices: whole rupees only, parsed by the same rule the pricing screen uses.
    function rupees(raw: string, label: string): number | null | 'invalid' {
      if (raw.trim() === '') return null
      const parsed = parseRupeeInput(raw)
      if (!parsed.ok) { setSave({ kind: 'error', message: `${label} — ${parsed.reason}` }); return 'invalid' }
      return parsed.rupees
    }

    const productRetail = rupees(retail, 'Retail price')
    if (productRetail === 'invalid') return
    const productVip = rupees(vip, 'Wholesale VIP price')
    if (productVip === 'invalid') return

    const variantInputs: NewVariantInput[] = []
    for (const [index, variant] of variants.entries()) {
      if (variant.name.trim() === '') {
        setSave({ kind: 'error', message: `Variant ${index + 1} needs a label, for example 256GB.` })
        return
      }
      const variantRetail = rupees(variant.retail, `Variant ${index + 1} retail price`)
      if (variantRetail === 'invalid') return
      const variantVip = rupees(variant.vip, `Variant ${index + 1} wholesale VIP price`)
      if (variantVip === 'invalid') return

      variantInputs.push({
        name: variant.name,
        color: variant.color,
        color_code: variant.color_code,
        storage: variant.storage,
        retailRupees: variantRetail,
        vipRupees: variantVip,
        condition: variant.condition,
      })
    }

    setSave({ kind: 'saving' })
    try {
      if (await isProductIdTaken(productId)) {
        setSave({ kind: 'error', message: `The ID "${productId}" is already used by another product.` })
        return
      }

      const input: NewProductInput = {
        id: productId,
        name: trimmedName,
        category_id: categoryId,
        subcategory,
        model: model.trim() || null,
        description: description.trim(),
        // Individually tracked items get stock only through a GRN.
        openingStock: categories.find((c) => c.id === categoryId)?.default_tracking_mode === 'unit' ? 0 : stock ?? 0,
        lifecycle_status: lifecycle || null,
        is_new: isNew,
        condition,
        warranty_text: warrantyText.trim() || null,
        warranty_status: warrantyStatus || null,
        warranty_duration: warrantyDuration.trim() || null,
        warranty_months: warrantyMonths,
        warranty_coverage: warrantyCoverage.trim() || null,
        specs: specs.filter((s) => s.label.trim() !== ''),
        images: images.filter((i) => i.path.trim() !== '').map((i) => ({ path: i.path, alt: i.alt.trim() || null })),
        compatibility: compatibility.filter((c) => c.label.trim() !== ''),
        variants: variantInputs,
        retailRupees: productRetail,
        vipRupees: productVip,
        publish,
      }

      const result = await createProduct(input)
      const outcome = result.withheld
        ? `${trimmedName} — ${result.withheld}`
        : result.published
          ? `${trimmedName} is live in the customer catalog.`
          : `${trimmedName} saved as an unpublished draft.`
      onCreated(result.stockPending ? `${outcome} ${result.stockPending}` : outcome, Boolean(result.stockPending))
    } catch (err) {
      // The product exists as an unpublished draft: close, refresh the list so
      // it can be found, and say exactly what happened.
      if (err instanceof ProductKeptError) { onCreated(err.message, true); return }
      setSave({ kind: 'error', message: err instanceof Error ? err.message : 'The database refused the product.' })
    }
  }

  const busy = save.kind === 'saving'

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" aria-label="Close" onClick={onClose}
        className="absolute inset-0 bg-black/45 backdrop-blur-[2px]" />

      <div role="dialog" aria-modal="true" aria-label="Add product"
        className="relative flex h-full w-full max-w-2xl flex-col border-l border-mint/80 bg-background shadow-float dark:border-border">

        <header className="flex items-center gap-3 border-b border-mint/80 bg-glass px-5 py-4 backdrop-blur-xl dark:border-border">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-[17px] font-bold tracking-tight text-foreground">Add product</h2>
            <p className="truncate text-[12px] text-muted-foreground">
              Saved to Supabase — no app update needed.
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"
            className="focus-ring flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-muted-foreground transition hover:bg-primary-soft active:scale-95">
            <X size={18} />
          </button>
        </header>

        <div className="flex-1 space-y-4 overflow-y-auto px-5 py-5">
          <EditorSection title="Basics" description="The name customers see, and the permanent ID behind it.">
            <div className="grid gap-4">
              <TextField id="n-name" label="Product name" value={name} disabled={busy}
                placeholder="iPhone 18 Pro" onChange={handleName} />

              {variants.length > 0 ? (
                <p className="rounded-xl border border-dashed border-mint-deep dark:border-border px-3 py-2.5 text-[12px] leading-relaxed text-muted-foreground">
                  This product has variants, so each variant gets its own condition (Brand New or Pre-Owned) in the
                  Variants section. Pre-owned details and photos are added in the editor after creating it.
                </p>
              ) : (
              <fieldset>
                <legend className="mb-1.5 text-[13px] font-semibold text-foreground">Condition</legend>
                <div className="flex flex-wrap gap-2" role="radiogroup">
                  {CONDITION_OPTIONS.map((option) => (
                    <label key={option.value}
                      className={`flex cursor-pointer items-center gap-2 rounded-xl border px-3.5 py-2.5 text-[13px] font-semibold transition-colors ${
                        condition === option.value ? 'border-primary/45 bg-primary-soft text-primary' : 'border-mint-deep dark:border-border bg-card text-foreground'
                      }`}>
                      <input type="radio" name="n-condition" value={option.value} disabled={busy}
                        checked={condition === option.value} onChange={() => handleCondition(option.value)}
                        className="accent-[var(--primary)]" />
                      {option.label}
                    </label>
                  ))}
                </div>
                <span className="mt-1.5 block text-[11px] text-muted-foreground">
                  Selling a model both new and used? Create one product for each — customers see both.
                  {condition === 'pre_owned' && ' Add the grade, battery health and actual-unit photos in the editor after creating it.'}
                </span>
              </fieldset>
              )}

              <label htmlFor="n-id" className="block">
                <FieldLabel hint="permanent — it becomes the product's address">Product ID</FieldLabel>
                <input id="n-id" type="text" value={productId} disabled={busy}
                  placeholder="iphone-18-pro"
                  onChange={(e) => { setIdEdited(true); setProductId(e.target.value); setSave({ kind: 'idle' }) }}
                  className={`${rowInput} font-mono`} />
                <span className="mt-1.5 block text-[11px] text-muted-foreground">
                  Lowercase letters, numbers and single hyphens. It cannot be changed later, because saved
                  carts and links point at it.
                </span>
              </label>

              <div className="grid gap-4 sm:grid-cols-2">
                <SelectField id="n-cat" label="Category" value={categoryId} disabled={busy}
                  onChange={setCategoryId}
                  options={categories.map((c) => ({ value: c.id, label: c.is_active ? c.name : `${c.name} (hidden)` }))} />
                <SelectField id="n-sub" label="Subcategory" value={subcategory} disabled={busy}
                  onChange={setSubcategory}
                  options={SUBCATEGORY_OPTIONS.map((s) => ({ value: s, label: s }))} />
              </div>

              <TextField id="n-model" label="Model" value={model} disabled={busy}
                hint="optional" placeholder="iPhone 18 Pro" onChange={setModel} />
              <TextAreaField id="n-desc" label="Description" value={description} disabled={busy}
                onChange={setDescription} />

              <div className="grid gap-4 sm:grid-cols-2">
                {categories.find((c) => c.id === categoryId)?.default_tracking_mode === 'unit' ? (
                  <div>
                    <span className="mb-1.5 block text-[13px] font-semibold text-foreground">Stock</span>
                    <p className="rounded-xl border border-dashed border-mint-deep dark:border-border px-3 py-2 text-[12.5px] text-muted-foreground">
                      Tracked item by item. Receive its stock with a GRN so every item gets a barcode.
                    </p>
                  </div>
                ) : (
                  <NumberField id="n-stock" label="Opening stock" min={0} value={stock} disabled={busy} onChange={setStock}
                    hint={hasVariants ? 'shared by all variants' : 'recorded in stock history'} />
                )}
                <SelectField id="n-life" label="Lifecycle" value={lifecycle} disabled={busy} allowEmpty
                  onChange={setLifecycle}
                  options={LIFECYCLE_OPTIONS.map((s) => ({ value: s, label: s }))} />
              </div>

              <CheckboxField id="n-isnew" label="Show “New” badge" checked={isNew} disabled={busy}
                onChange={setIsNew} />
            </div>
          </EditorSection>

          <EditorSection title="Variants"
            description="Storage, colour or size options. Leave empty for a product sold as one thing — then set the price below instead.">
            <div className="space-y-4">
              {variants.map((variant, index) => (
                <div key={index} className="rounded-2xl border border-mint/70 bg-card p-4 dark:border-border">
                  <div className="mb-3 flex items-center justify-between gap-2">
                    <span className="rounded-full border border-mint-deep bg-primary-soft px-2 py-0.5 font-mono text-[11px] font-semibold text-primary">
                      v{index + 1}
                    </span>
                    <RemoveButton label={`Remove variant ${index + 1}`} disabled={busy}
                      onClick={() => setVariants((p) => p.filter((_, i) => i !== index))} />
                  </div>
                  <div className="grid gap-3">
                    <div className="grid gap-3 sm:grid-cols-[1fr_11rem]">
                      <input aria-label={`Variant ${index + 1} label`} value={variant.name} disabled={busy}
                        placeholder="256GB"
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, name: e.target.value } : v))}
                        className={rowInput} />
                      {/* This variant's own condition — never shared with the others. */}
                      <select aria-label={`Variant ${index + 1} condition`} value={variant.condition} disabled={busy}
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index
                          ? { ...v, condition: e.target.value as VariantDraft['condition'] } : v))}
                        className={rowInput}>
                        {CONDITION_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                      </select>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-3">
                      <input aria-label={`Variant ${index + 1} storage`} value={variant.storage ?? ''} disabled={busy}
                        placeholder="Storage"
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, storage: e.target.value || null } : v))}
                        className={rowInput} />
                      <input aria-label={`Variant ${index + 1} colour`} value={variant.color ?? ''} disabled={busy}
                        placeholder="Colour"
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, color: e.target.value || null } : v))}
                        className={rowInput} />
                      <input aria-label={`Variant ${index + 1} colour code`} value={variant.color_code ?? ''} disabled={busy}
                        placeholder="#1A1A1A"
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, color_code: e.target.value || null } : v))}
                        className={`${rowInput} font-mono`} />
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <input aria-label={`Variant ${index + 1} retail price`} value={variant.retail} disabled={busy}
                        inputMode="numeric" placeholder="Retail Rs."
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, retail: e.target.value } : v))}
                        className={`${rowInput} tabular-nums`} />
                      <input aria-label={`Variant ${index + 1} wholesale VIP price`} value={variant.vip} disabled={busy}
                        inputMode="numeric" placeholder="VIP Rs. (optional)"
                        onChange={(e) => setVariants((p) => p.map((v, i) => i === index ? { ...v, vip: e.target.value } : v))}
                        className={`${rowInput} tabular-nums`} />
                    </div>
                  </div>
                </div>
              ))}
              <Button type="button" variant="outline" size="sm" disabled={busy}
                onClick={() => setVariants((p) => [...p, { ...EMPTY_VARIANT }])}>
                <Plus size={14} className="mr-1.5" /> Add variant
              </Button>
            </div>
          </EditorSection>

          <EditorSection title="Pricing"
            description={hasVariants
              ? 'Each variant carries its own prices above. A product-level price here is the fallback for variants left unpriced.'
              : 'Whole rupees. Retail is required before customers can see the product; wholesale VIP is optional and independent.'}>
            <div className="grid gap-4 sm:grid-cols-2">
              <label htmlFor="n-retail" className="block">
                <FieldLabel hint="required to publish">Retail price</FieldLabel>
                <input id="n-retail" value={retail} disabled={busy} inputMode="numeric" placeholder="499999"
                  onChange={(e) => { setRetail(e.target.value); setSave({ kind: 'idle' }) }}
                  className={`${rowInput} tabular-nums`} />
              </label>
              <label htmlFor="n-vip" className="block">
                <FieldLabel hint="optional">Wholesale VIP price</FieldLabel>
                <input id="n-vip" value={vip} disabled={busy} inputMode="numeric" placeholder="475000"
                  onChange={(e) => { setVip(e.target.value); setSave({ kind: 'idle' }) }}
                  className={`${rowInput} tabular-nums`} />
              </label>
            </div>
            <p className="mt-3 flex items-start gap-2 rounded-xl border border-mint/70 bg-muted px-3 py-2.5 dark:border-border">
              <Tags size={14} className="mt-0.5 shrink-0 text-muted-foreground" />
              <span className="text-[12px] leading-snug text-muted-foreground">
                Prices are written through the audited admin_set_price() function, the same one the Pricing
                screen uses. Every change keeps its history.
              </span>
            </p>
          </EditorSection>

          <EditorSection title="Specifications" description="Shown on the product page in this order.">
            <div className="space-y-2.5">
              {specs.map((spec, index) => (
                <div key={index} className="flex items-start gap-2">
                  <input aria-label={`Specification ${index + 1} label`} value={spec.label} disabled={busy}
                    placeholder="Display"
                    onChange={(e) => setSpecs((p) => p.map((s, i) => i === index ? { ...s, label: e.target.value } : s))}
                    className={`${rowInput} w-[38%] font-semibold`} />
                  <input aria-label={`Specification ${index + 1} value`} value={spec.value} disabled={busy}
                    placeholder="6.3-inch Super Retina XDR"
                    onChange={(e) => setSpecs((p) => p.map((s, i) => i === index ? { ...s, value: e.target.value } : s))}
                    className={`${rowInput} flex-1`} />
                  <RemoveButton label={`Remove specification ${index + 1}`} disabled={busy}
                    onClick={() => setSpecs((p) => p.filter((_, i) => i !== index))} />
                </div>
              ))}
              <Button type="button" variant="outline" size="sm" disabled={busy}
                onClick={() => setSpecs((p) => [...p, { label: '', value: '' }])}>
                <Plus size={14} className="mr-1.5" /> Add specification
              </Button>
            </div>
          </EditorSection>

          <EditorSection title="Images"
            description="The first image is the one customers see on the card. Paths point at the app's bundled image library, or at a full https:// URL.">
            <div className="space-y-2.5">
              {images.map((image, index) => (
                <div key={index} className="flex items-start gap-2">
                  <input aria-label={`Image ${index + 1} path`} value={image.path} disabled={busy}
                    placeholder="/images/products/iphone/iphone-18-pro.jpg"
                    onChange={(e) => setImages((p) => p.map((x, i) => i === index ? { ...x, path: e.target.value } : x))}
                    className={`${rowInput} flex-1 font-mono text-[12px]`} />
                  <input aria-label={`Image ${index + 1} alt text`} value={image.alt} disabled={busy}
                    placeholder="Alt text"
                    onChange={(e) => setImages((p) => p.map((x, i) => i === index ? { ...x, alt: e.target.value } : x))}
                    className={`${rowInput} w-[30%]`} />
                  <RemoveButton label={`Remove image ${index + 1}`} disabled={busy}
                    onClick={() => setImages((p) => p.filter((_, i) => i !== index))} />
                </div>
              ))}
              <Button type="button" variant="outline" size="sm" disabled={busy}
                onClick={() => setImages((p) => [...p, { path: '', alt: '' }])}>
                <Plus size={14} className="mr-1.5" /> Add image
              </Button>
            </div>
          </EditorSection>

          <EditorSection title="Compatibility"
            description="For parts and accessories: which devices this fits. Pick a known model or type anything.">
            <div className="space-y-2.5">
              {compatibility.map((entry, index) => (
                <div key={index} className="flex items-start gap-2">
                  <input aria-label={`Compatibility ${index + 1} label`} value={entry.label} disabled={busy}
                    placeholder="iPhone 18 Pro"
                    onChange={(e) => setCompatibility((p) => p.map((c, i) => i === index ? { ...c, label: e.target.value } : c))}
                    className={`${rowInput} flex-1`} />
                  <select aria-label={`Compatibility ${index + 1} device model`} value={entry.device_model_id ?? ''} disabled={busy}
                    onChange={(e) => setCompatibility((p) => p.map((c, i) => i === index ? { ...c, device_model_id: e.target.value || null } : c))}
                    className={`${rowInput} w-[38%]`}>
                    <option value="">Free text</option>
                    {deviceModels.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
                  </select>
                  <RemoveButton label={`Remove compatibility ${index + 1}`} disabled={busy}
                    onClick={() => setCompatibility((p) => p.filter((_, i) => i !== index))} />
                </div>
              ))}
              <Button type="button" variant="outline" size="sm" disabled={busy}
                onClick={() => setCompatibility((p) => [...p, { label: '', device_model_id: null }])}>
                <Plus size={14} className="mr-1.5" /> Add compatibility
              </Button>
            </div>
          </EditorSection>

          <EditorSection title="Warranty" description="Optional. Shown on the product page when a status is set.">
            <div className="grid gap-4">
              <TextField id="n-wtext" label="Warranty text" value={warrantyText} disabled={busy} onChange={setWarrantyText} />
              <div className="grid gap-4 sm:grid-cols-3">
                <SelectField id="n-wstat" label="Status" value={warrantyStatus} disabled={busy} allowEmpty
                  onChange={setWarrantyStatus}
                  options={WARRANTY_STATUS_OPTIONS.map((s) => ({ value: s, label: s }))} />
                <TextField id="n-wdur" label="Duration" value={warrantyDuration} disabled={busy} onChange={setWarrantyDuration} />
                <NumberField id="n-wmon" label="Months" min={0} value={warrantyMonths} disabled={busy} onChange={setWarrantyMonths} />
              </div>
              <TextField id="n-wcov" label="Coverage" value={warrantyCoverage} disabled={busy} onChange={setWarrantyCoverage} />
            </div>
          </EditorSection>

          <EditorSection title="Publish">
            <CheckboxField id="n-publish" label="Publish to the customer catalog when saved" checked={publish}
              disabled={busy} onChange={setPublish}
              hint="Held back automatically if anything is missing — a product without a retail price stays a draft." />
            <p className="mt-3 flex items-start gap-2 rounded-xl border border-mint/70 bg-muted px-3 py-2.5 dark:border-border">
              <Info size={14} className="mt-0.5 shrink-0 text-muted-foreground" />
              <span className="text-[12px] leading-snug text-muted-foreground">
                The product is written unpublished first and only goes live once every part of it saved
                cleanly, so customers never see a half-finished product.
              </span>
            </p>
          </EditorSection>
        </div>

        <footer className="border-t border-mint/80 bg-glass px-5 py-4 backdrop-blur-xl dark:border-border">
          {save.kind === 'error' && (
            <div className="mb-3 flex items-start gap-2 rounded-xl border border-red-500/25 bg-red-500/8 px-3 py-2">
              <AlertCircle size={15} className="mt-0.5 shrink-0 text-red-500" />
              <p className="text-[12.5px] text-foreground">{save.message}</p>
            </div>
          )}
          <div className="flex items-center gap-2.5">
            <Button variant="ghost" onClick={onClose} disabled={busy}>Cancel</Button>
            <Button className="flex-1" onClick={() => void handleSave()} disabled={busy}>
              {busy
                ? <><LoaderCircle size={16} className="mr-2 animate-spin motion-reduce:animate-none" />Creating…</>
                : <><Check size={16} className="mr-2" />Create product</>}
            </Button>
          </div>
        </footer>
      </div>
    </div>
  )
}
