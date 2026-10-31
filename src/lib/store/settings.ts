"use client"

import { useEffect, useState, useSyncExternalStore } from 'react'
import { getSupabaseClient, isSupabaseConfigured } from '@/lib/supabase/client'
import type { Database } from '@/lib/supabase/database.types'

/**
 * Store settings for the customer app — the public, read-only side of
 * /admin/settings.
 *
 * One row in public.store_settings (RLS: readable by everyone, writable only by
 * owner/admin). Loaded once on first use and re-read when the app returns to
 * the foreground, the same way the catalog picks up admin price changes, so a
 * setting changed in the admin panel reaches installed APKs without a rebuild.
 *
 * If the row cannot be read, DEFAULT_STORE_SETTINGS applies: everything
 * visible, store open, no maintenance. A network failure must never lock
 * customers out of the store or hide it by accident.
 */

export type StoreSettings = Database['public']['Tables']['store_settings']['Row']
export type StoreSettingsStatus = 'loading' | 'ready' | 'fallback'

export const DEFAULT_STORE_SETTINGS: StoreSettings = {
  id: true,
  store_name: 'Apple Expert',
  description: null,
  contact_phone: null,
  whatsapp_number: null,
  email: null,
  address: null,
  opening_hours: null,
  is_open: true,
  maintenance_mode: false,
  currency: 'LKR',
  show_featured_products: true,
  show_banners: true,
  show_new_arrivals: true,
  show_stock_status: true,
  retail_enabled: true,
  wholesale_enabled: true,
  updated_by: null,
  created_at: '',
  updated_at: '',
}

interface Snapshot {
  settings: StoreSettings
  status: StoreSettingsStatus
}

const SERVER_SNAPSHOT: Snapshot = { settings: DEFAULT_STORE_SETTINGS, status: 'loading' }

let snapshot: Snapshot = isSupabaseConfigured()
  ? SERVER_SNAPSHOT
  : { settings: DEFAULT_STORE_SETTINGS, status: 'fallback' }
const listeners = new Set<() => void>()
let started = false
let inFlight = false
let lastLoadedAt = 0
/** Returning to the app after this long re-reads the settings. */
const RETURN_STALE_MS = 3_000

function emit() {
  for (const listener of listeners) listener()
}

async function load(): Promise<void> {
  if (inFlight || !isSupabaseConfigured()) return
  inFlight = true
  try {
    // 5-second timeout: network hang-ஆனா forever 'loading' stuck ஆகாமல் fallback-க்கு போகும்
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('store_settings fetch timeout')), 5000)
    )
    const query = getSupabaseClient()
      .from('store_settings')
      .select('*')
      .eq('id', true)
      .maybeSingle()
    const { data, error } = await Promise.race([query, timeout])
    snapshot = error || !data
      ? { settings: snapshot.status === 'ready' ? snapshot.settings : DEFAULT_STORE_SETTINGS, status: snapshot.status === 'ready' ? 'ready' : 'fallback' }
      : { settings: data, status: 'ready' }
  } catch {
    snapshot = { settings: snapshot.status === 'ready' ? snapshot.settings : DEFAULT_STORE_SETTINGS, status: snapshot.status === 'ready' ? 'ready' : 'fallback' }
  } finally {
    inFlight = false
    lastLoadedAt = Date.now()
    emit()
  }
}

function handleReturn() {
  if (document.visibilityState !== 'visible') return
  if (Date.now() - lastLoadedAt >= RETURN_STALE_MS) void load()
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  if (!started && typeof window !== 'undefined') {
    started = true
    window.addEventListener('focus', handleReturn)
    document.addEventListener('visibilitychange', handleReturn)
    void load()
  }
  return () => { listeners.delete(listener) }
}

/** The store settings and whether they are loaded yet. */
export function useStoreSettings(): Snapshot {
  return useSyncExternalStore(subscribe, () => snapshot, () => SERVER_SNAPSHOT)
}

/** Re-reads the settings now — used after the admin panel saves them. */
export function reloadStoreSettings(): void {
  if (started) void load()
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

export type BannerSlot = 'home' | 'wholesale'

export interface StorefrontBanner {
  id: string
  title: string | null
  subtitle: string | null
  cta_label: string | null
  cta_href: string | null
  imageUrl: string | null
}

/** Public URL of a banner image stored in the `banners` Storage bucket. */
export function bannerImageUrl(path: string | null): string | null {
  if (!path || !isSupabaseConfigured()) return null
  return getSupabaseClient().storage.from('banners').getPublicUrl(path).data.publicUrl
}

/**
 * Active banners for one storefront slot, in admin order. RLS ("banners public
 * read") already limits rows to is_active and the start/end window, so what
 * comes back is exactly what may be shown.
 */
export function useBanners(slot: BannerSlot, enabled: boolean): StorefrontBanner[] {
  const [banners, setBanners] = useState<StorefrontBanner[]>([])

  useEffect(() => {
    if (!enabled || !isSupabaseConfigured()) return
    let cancelled = false
    getSupabaseClient()
      .from('banners')
      .select('id, title, subtitle, cta_label, cta_href, image_path')
      .eq('slot', slot)
      .order('sort_order', { ascending: true })
      .then(({ data, error }) => {
        if (cancelled || error || !data) return
        setBanners(data.map((row) => ({
          id: row.id,
          title: row.title,
          subtitle: row.subtitle,
          cta_label: row.cta_label,
          cta_href: row.cta_href,
          imageUrl: bannerImageUrl(row.image_path),
        })))
      })
    return () => { cancelled = true }
  }, [slot, enabled])

  return enabled ? banners : []
}
