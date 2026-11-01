"use client"

import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { getSupabaseClient, isSupabaseConfigured } from '@/lib/supabase/client'
import { fetchAdminRole, type AdminRole } from '@/lib/admin/roles'

/**
 * Admin session + authorization state.
 *
 * `loading`      – still resolving the session or the role lookup
 * `signed-out`   – no Supabase session; the guard sends the visitor to /admin/login
 * `unauthorized` – authenticated, but holds no owner/admin/staff row in user_roles
 * `authorized`   – authenticated and the database returned an admin role
 * `error`        – the role lookup failed (network/config); deliberately NOT
 *                  collapsed into `unauthorized`, so a transient failure never
 *                  looks like a permission decision
 */
export type AdminAuthStatus =
  | 'loading'
  | 'signed-out'
  | 'unauthorized'
  | 'authorized'
  | 'error'

interface AdminAuthValue {
  status: AdminAuthStatus
  userId: string | null
  email: string | null
  role: AdminRole | null
  errorMessage: string | null
  signOut: () => Promise<void>
  refresh: () => Promise<void>
}

const AdminAuthContext = createContext<AdminAuthValue | undefined>(undefined)

/** Evaluated once: these are build-time inlined NEXT_PUBLIC_ values. */
const CONFIGURED = isSupabaseConfigured()

export function AdminAuthProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<AdminAuthStatus>(CONFIGURED ? 'loading' : 'error')
  const [userId, setUserId] = useState<string | null>(null)
  const [email, setEmail] = useState<string | null>(null)
  const [role, setRole] = useState<AdminRole | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(
    CONFIGURED ? null : 'Supabase is not configured for this build.',
  )

  // Guards against a slow role lookup resolving after a newer auth event has
  // already updated the state.
  const requestRef = useRef(0)

  const applySession = useCallback(async (session: Session | null) => {
    const ticket = ++requestRef.current

    if (!session?.user) {
      setUserId(null)
      setEmail(null)
      setRole(null)
      setErrorMessage(null)
      setStatus('signed-out')
      return
    }

    setUserId(session.user.id)
    setEmail(session.user.email ?? null)

    try {
      // The authorization decision is made by PostgreSQL, not here: RLS on
      // user_roles only ever returns rows belonging to the caller.
      const resolvedRole = await fetchAdminRole(session.user.id)
      if (ticket !== requestRef.current) return

      setRole(resolvedRole)
      setErrorMessage(null)
      setStatus(resolvedRole ? 'authorized' : 'unauthorized')
    } catch (err) {
      if (ticket !== requestRef.current) return
      setRole(null)
      setStatus('error')
      setErrorMessage(err instanceof Error ? err.message : 'Could not verify your access.')
    }
  }, [])

  /** Re-reads the session and role. Called from event handlers, never an effect. */
  const refresh = useCallback(async () => {
    if (!CONFIGURED) return
    const supabase = getSupabaseClient()
    const { data: { session } } = await supabase.auth.getSession()
    await applySession(session)
  }, [applySession])

  useEffect(() => {
    if (!CONFIGURED) return

    // Subscribing is enough to bootstrap: supabase-js emits INITIAL_SESSION to
    // every new listener immediately (with a null session when there is none,
    // and even when reading storage fails), so no separate initial fetch is
    // needed and state is only ever set from this external-system callback.
    const supabase = getSupabaseClient()
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      void applySession(session)
    })

    return () => subscription.unsubscribe()
  }, [applySession])

  const signOut = useCallback(async () => {
    if (!CONFIGURED) return
    const supabase = getSupabaseClient()
    const { error } = await supabase.auth.signOut()
    // A failed server call leaves the session on the device. Someone who pressed
    // sign out on a shared phone must not stay signed in, so end it here anyway.
    if (error) await supabase.auth.signOut({ scope: 'local' })
    // onAuthStateChange fires SIGNED_OUT, which moves status to 'signed-out'.
  }, [])

  return (
    <AdminAuthContext.Provider
      value={{ status, userId, email, role, errorMessage, signOut, refresh }}
    >
      {children}
    </AdminAuthContext.Provider>
  )
}

export function useAdminAuth() {
  const context = useContext(AdminAuthContext)
  if (context === undefined) {
    throw new Error('useAdminAuth must be used within an AdminAuthProvider')
  }
  return context
}
