#!/usr/bin/env node
/**
 * Apple Expert — the customer app's way into the admin panel.
 *
 *   node --test scripts/test-business-access.mjs
 *
 * Exercises src/lib/admin/entry.ts, plus the rule that decides it: Capacitor's
 * local server gives index.html to any path whose last segment has no ".". Node
 * runs the TypeScript directly. Sign-in, roles and screens need a browser and a
 * database, so they are tested against the local stack.
 */

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { adminLoginPath } from '../src/lib/admin/entry.ts'

/** Mirrors WebViewLocalServer.handleLocalRequest with html5mode on, its default. */
function servedByCapacitor(path) {
  const last = path.split('/').pop()
  return path === '/' || !last.includes('.') ? '/index.html' : path
}

test('the APK asks for the exported file, the web for the clean route', () => {
  assert.equal(adminLoginPath(true), '/admin/login.html')
  assert.equal(adminLoginPath(false), '/admin/login')
})

test('outside Capacitor the platform check picks the web route', () => {
  assert.equal(adminLoginPath(), '/admin/login')
})

test('the native path reaches the admin file under Capacitor; the web path would not', () => {
  assert.equal(servedByCapacitor(adminLoginPath(true)), '/admin/login.html')
  assert.equal(servedByCapacitor(adminLoginPath(false)), '/index.html')
})

test('the destination is fixed: no query string or fragment on either path', () => {
  for (const path of [adminLoginPath(true), adminLoginPath(false)]) {
    assert.doesNotMatch(path, /[?#]/)
    assert.ok(path.startsWith('/admin/login'))
  }
})
