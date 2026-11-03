"use client"

import { useEffect, useRef, useState, type RefObject } from 'react'

/**
 * Keyboard behaviour for a modal dialog: focus moves into it, Tab and Shift+Tab
 * cycle inside it, Escape calls onEscape, and focus returns to whatever opened it.
 *
 * A dialog portalled to <body> also makes the rest of the page inert while it is
 * open, so neither a keyboard nor a screen reader can reach what is behind it.
 * Dialogs can nest (a confirmation over a form): only the newest one answers keys.
 */

const FOCUSABLE = [
  'a[href]', 'button:not([disabled])', 'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])', 'textarea:not([disabled])', '[tabindex]:not([tabindex="-1"])',
].join(',')

const open: HTMLElement[] = []

function focusables(root: HTMLElement): HTMLElement[] {
  return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE))
    .filter((el) => el.getClientRects().length > 0 && !el.closest('[inert]'))
}

export function useDialogFocus(ref: RefObject<HTMLElement | null>, onEscape: () => void) {
  const onEscapeRef = useRef(onEscape)
  useEffect(() => { onEscapeRef.current = onEscape })

  // Read on the first render: an autoFocus control inside takes focus before any
  // effect runs, which would hide what opened the dialog.
  const [opener] = useState(() =>
    typeof document !== 'undefined' && document.activeElement instanceof HTMLElement ? document.activeElement : null)

  useEffect(() => {
    const dialog = ref.current
    if (!dialog) return
    open.push(dialog)

    // An element inside asking for focus (autoFocus) keeps it.
    if (!dialog.contains(document.activeElement)) dialog.focus({ preventScroll: true })

    // Only a dialog that is a direct child of <body>, through its portal, mutes
    // the page; a nested one already sits inside a dialog that did.
    const layer = Array.from(document.body.children).find((child) => child.contains(dialog))
    const muted: Element[] = []
    if (layer && open.length === 1) {
      for (const child of Array.from(document.body.children)) {
        if (child !== layer && !child.hasAttribute('inert')) {
          child.setAttribute('inert', '')
          muted.push(child)
        }
      }
    }

    function onKeyDown(event: KeyboardEvent) {
      if (open[open.length - 1] !== dialog) return
      if (event.key === 'Escape') {
        event.preventDefault()
        onEscapeRef.current()
        return
      }
      if (event.key !== 'Tab') return
      const items = focusables(dialog!)
      if (items.length === 0) {
        event.preventDefault()
        dialog!.focus()
        return
      }
      const first = items[0]
      const last = items[items.length - 1]
      const active = document.activeElement
      if (event.shiftKey && (active === first || !dialog!.contains(active))) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && (active === last || !dialog!.contains(active))) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      open.splice(open.indexOf(dialog), 1)
      for (const child of muted) child.removeAttribute('inert')
      if (opener?.isConnected) opener.focus({ preventScroll: true })
    }
  }, [ref, opener])
}
