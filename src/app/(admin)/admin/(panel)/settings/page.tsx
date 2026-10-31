"use client"

import { useEffect, useState } from 'react'
import { Eye, LoaderCircle, RotateCw } from 'lucide-react'
import { AdminPageHeading } from '@/components/admin/AdminPage'
import { Button } from '@/components/ui/Button'
import { StoreConfigCard } from '@/components/admin/settings/StoreConfigCard'
import { StorefrontControlsCard } from '@/components/admin/settings/StorefrontControlsCard'
import { FeaturedProductsCard } from '@/components/admin/settings/FeaturedProductsCard'
import { BannersCard } from '@/components/admin/settings/BannersCard'
import { InventoryPolicyCard } from '@/components/admin/settings/InventoryPolicyCard'
import { useAdminAuth } from '@/context/AdminAuthContext'
import { canEditCatalog } from '@/lib/admin/products'
import { loadStoreSettings } from '@/lib/admin/storefront'
import { describeAdminError, logAdminError } from '@/lib/admin/errors'
import { reloadStoreSettings, type StoreSettings } from '@/lib/store/settings'

/**
 * Store management: configuration, storefront switches, featured products and
 * promotional banners — all read by the customer app from Supabase at runtime,
 * so nothing here needs an APK rebuild.
 *
 * Owner and admin can edit; staff see everything read-only. The UI's canEdit is
 * a convenience — RLS on store_settings, featured_products, banners and the
 * `banners` Storage bucket is what actually refuses a staff write.
 */
export default function AdminSettingsPage() {
  const { role } = useAdminAuth()
  const canEdit = canEditCatalog(role)

  const [settings, setSettings] = useState<StoreSettings | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let cancelled = false
    loadStoreSettings()
      .then((row) => { if (!cancelled) { setSettings(row); setError(null) } })
      .catch((err) => {
        logAdminError('settings.load', err)
        if (!cancelled) setError(describeAdminError(err, 'Could not load the store settings.'))
      })
    return () => { cancelled = true }
  }, [attempt])

  /** Keeps both cards in step, and refreshes the customer app's copy in this session. */
  function handleSaved(next: StoreSettings) {
    setSettings(next)
    reloadStoreSettings()
  }

  return (
    <>
      <AdminPageHeading title="Settings" subtitle="Store configuration, storefront controls, featured products and promotional banners." />

      {!canEdit && role && (
        <p className="mb-5 flex items-center gap-2 rounded-2xl border border-mint/80 dark:border-border bg-surface px-4 py-3 text-[13px] text-muted-foreground shadow-card">
          <Eye size={15} className="shrink-0 text-primary" />
          You are viewing settings as staff. Only an owner or admin can change them.
        </p>
      )}

      <div className="space-y-5">
        {error && (
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-[22px] border border-red-500/25 bg-red-500/5 p-5">
            <p role="alert" className="min-w-0 text-[13px] text-red-500 break-words">{error}</p>
            <Button size="sm" variant="secondary" onClick={() => { setError(null); setAttempt((n) => n + 1) }}>
              <RotateCw size={14} className="mr-1.5" /> Retry
            </Button>
          </div>
        )}
        {!error && !settings && (
          <p className="flex items-center gap-2 rounded-[22px] border border-mint/80 dark:border-border bg-surface p-5 text-[13px] text-muted-foreground shadow-card">
            <LoaderCircle size={15} className="animate-spin motion-reduce:animate-none" /> Loading store settings…
          </p>
        )}
        {settings && (
          <>
            <StoreConfigCard settings={settings} canEdit={canEdit} onSaved={handleSaved} />
            <StorefrontControlsCard settings={settings} canEdit={canEdit} onSaved={handleSaved} />
          </>
        )}
        <FeaturedProductsCard canEdit={canEdit} />
        <BannersCard canEdit={canEdit} />
        <InventoryPolicyCard canEdit={canEdit} />
      </div>
    </>
  )
}
