#!/usr/bin/env node
/**
 * Apple Expert — counter scan rules.
 *
 *   node --test scripts/test-pos-cart.mjs
 *
 * Exercises src/lib/admin/posCart.ts: repeated product scans, duplicate units,
 * availability, refusals by status, and the queue that keeps a fast USB scanner
 * from losing codes. Node runs the TypeScript directly; the module has no runtime
 * imports. Prices, stock and locking are checked by the database:
 * supabase/tests/verify_dual_barcodes*.
 */

import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  addQuantity, addUnit, applyPriceChanges, changeQuantity, classifySaleError, createTaskQueue, expectedPrices, isCodeOnBill, isConnectionError,
  lineCents, parsePriceChanges, unitRefusal,
} from '../src/lib/admin/posCart.ts'

const quote = (over = {}) => ({
  kind: 'product', product_id: 'cable', variant_id: null, product_name: 'Cable', variant_name: null,
  tracking_mode: 'quantity', available: 3, price_cents: 1000, tier_code: 'retail', ...over,
})
const unit = (over = {}) => ({
  kind: 'unit', unit_id: 'u1', barcode: 'AE00000001', serial_number: '356000000000001', status: 'in_stock',
  product_id: 'phone', variant_id: null, product_name: 'Phone', variant_name: null, price_cents: 5000, tier_code: 'retail', ...over,
})
const deferred = () => {
  let resolve
  const promise = new Promise((r) => { resolve = r })
  return { promise, resolve }
}

test('a repeated product scan adds to one line', () => {
  let { cart } = addQuantity([], quote(), 1)
  ;({ cart } = addQuantity(cart, quote(), 1))
  assert.equal(cart.length, 1)
  assert.equal(cart[0].quantity, 2)
  assert.equal(lineCents(cart[0]), 2000)
})

test('each variant has its own line; a product without variants has one', () => {
  let { cart } = addQuantity([], quote({ variant_id: 'a' }), 1)
  ;({ cart } = addQuantity(cart, quote({ variant_id: 'b' }), 1))
  ;({ cart } = addQuantity(cart, quote(), 1))
  assert.equal(cart.length, 3)
})

test('the total is capped by availability, counting what is on the bill', () => {
  const { cart } = addQuantity([], quote(), 3)
  const change = addQuantity(cart, quote(), 1)
  assert.equal(change.cart, cart)
  assert.match(change.error, /Only 3 of Cable/)
})

test('a repeat scan keeps the price the cashier saw, and takes the new availability', () => {
  const { cart } = addQuantity([], quote(), 2)
  const next = addQuantity(cart, quote({ available: 5, price_cents: 1200, tier_code: 'wholesale_vip' }), 1)
  assert.equal(next.cart[0].quantity, 3)
  assert.equal(lineCents(next.cart[0]), 3000)
  assert.equal(next.cart[0].item.tier_code, 'retail')
  assert.equal(next.cart[0].item.available, 5)
  assert.match(addQuantity(cart, quote({ available: 2 }), 1).error, /Only 2/)
})

test('no price and individually tracked items are refused', () => {
  assert.match(addQuantity([], quote({ price_cents: null }), 1).error, /no price/)
  assert.match(addQuantity([], quote({ tracking_mode: 'unit' }), 1).error, /tracked individually/)
})

test('+ and − stay between 1 and what is available', () => {
  const { cart } = addQuantity([], quote(), 1)
  const key = cart[0].key
  assert.equal(changeQuantity(cart, key, -1).cart[0].quantity, 1)
  const two = changeQuantity(cart, key, 1).cart
  assert.equal(two[0].quantity, 2)
  assert.equal(changeQuantity(two, key, -1).cart[0].quantity, 1)
  assert.match(changeQuantity(addQuantity([], quote(), 3).cart, key, 1).error, /Only 3/)
})

test('a unit can be on a bill only once, by barcode or by serial', () => {
  const { cart } = addUnit([], unit())
  assert.equal(cart.length, 1)
  assert.match(addUnit(cart, unit()).error, /already on this bill/)
  assert.equal(isCodeOnBill(cart, 'AE00000001'), true)
  assert.equal(isCodeOnBill(cart, '356000000000001'), true)
  assert.equal(isCodeOnBill(cart, 'AE00000002'), false)
})

test('every status that cannot be sold says why and adds nothing', () => {
  const expected = {
    reserved: /held for an online order/,
    sold: /already been sold/,
    quarantined: /in quarantine/,
    written_off: /written off/,
    returned_to_supplier: /returned to the supplier/,
  }
  for (const [status, pattern] of Object.entries(expected)) {
    const change = addUnit([], unit({ status }))
    assert.equal(change.cart.length, 0, status)
    assert.match(change.error, pattern)
  }
  assert.match(unitRefusal(unit({ status: 'sold' }), 'AE00000099'), /came back as AE00000099/)
  assert.match(addUnit([], unit({ price_cents: null })).error, /no price/)
  assert.equal(unitRefusal(unit()), null)
})

test('units and quantity lines are independent', () => {
  let { cart } = addUnit([], unit())
  ;({ cart } = addQuantity(cart, quote(), 2))
  assert.equal(cart.length, 2)
  assert.equal(cart.reduce((sum, l) => sum + lineCents(l), 0), 7000)
})

test('rapid scans: answers out of order still apply in scan order, none lost', async () => {
  const queue = createTaskQueue()
  const answers = [deferred(), deferred(), deferred(), deferred()]
  let cart = []
  const applied = []
  const scan = (i) => queue.run(async () => {
    const r = await answers[i].promise
    cart = (r.kind === 'unit' ? addUnit(cart, r) : addQuantity(cart, r, 1)).cart
    applied.push(i)
  })
  const all = [scan(0), scan(1), scan(2), scan(3)]
  answers[3].resolve(quote())
  answers[1].resolve(unit({ unit_id: 'u2', barcode: 'AE00000002' }))
  answers[2].resolve(quote())
  answers[0].resolve(unit())
  await Promise.all(all)
  assert.deepEqual(applied, [0, 1, 2, 3])
  assert.equal(cart.length, 3)
  assert.equal(cart.find((l) => l.kind === 'quantity').quantity, 2)
})

test('the queue survives a failed task and reports busy once per burst', async () => {
  const changes = []
  const queue = createTaskQueue((b) => changes.push(b))
  const seen = []
  const a = queue.run(async () => { throw new Error('network') })
  const b = queue.run(async () => { seen.push('b') })
  const c = queue.run(async () => { seen.push('c') })
  await Promise.all([a, b, c])
  assert.deepEqual(seen, ['b', 'c'])
  assert.deepEqual(changes, [true, false])
})

test('a sale queued behind scans waits; a scan behind the sale lands after it', async () => {
  const queue = createTaskQueue()
  const order = []
  const gate = deferred()
  const first = queue.run(async () => { await gate.promise; order.push('scan-before') })
  const sale = queue.run(async () => { order.push('sale') })
  const after = queue.run(async () => { order.push('scan-after') })
  gate.resolve()
  await Promise.all([first, sale, after])
  assert.deepEqual(order, ['scan-before', 'sale', 'scan-after'])
})

const change = (over = {}) => ({
  code: null, product_id: 'cable', variant_id: null, product_name: 'Cable', variant_name: null,
  previous_cents: 1000, current_cents: 1200, current_tier: 'retail', reason: 'price_changed', ...over,
})

test('the prices sent are the ones on screen, line for line', () => {
  let { cart } = addQuantity([], quote(), 2)
  ;({ cart } = addUnit(cart, unit()))
  assert.deepEqual(expectedPrices(cart), [{ price_cents: 1000, tier_code: 'retail' }, { price_cents: 5000, tier_code: 'retail' }])
})

test('a price_changed refusal yields its items; anything else yields none', () => {
  const details = JSON.stringify([change()])
  assert.equal(parsePriceChanges({ message: 'price_changed: 1 item changed', details }).length, 1)
  assert.deepEqual(parsePriceChanges({ message: 'insufficient_stock: x', details }), [])
  assert.deepEqual(parsePriceChanges({ message: 'price_changed: x', details: 'not json' }), [])
  assert.deepEqual(parsePriceChanges(null), [])
})

test('accepting new prices updates only the lines that changed, and drops one with no price', () => {
  let { cart } = addQuantity([], quote(), 2)
  ;({ cart } = addQuantity(cart, quote({ product_id: 'dock', product_name: 'Dock' }), 1))
  ;({ cart } = addUnit(cart, unit()))
  ;({ cart } = addUnit(cart, unit({ unit_id: 'u2', barcode: 'AE00000002', serial_number: null })))
  const next = applyPriceChanges(cart, [
    change(),
    change({ code: 'AE00000001', product_id: 'phone', previous_cents: 5000, current_cents: 5500, current_tier: 'wholesale_vip', reason: 'tier_changed' }),
    change({ code: 'AE00000002', product_id: 'phone', previous_cents: 5000, current_cents: null, current_tier: null, reason: 'price_removed' }),
  ])
  assert.equal(next.length, 3)
  assert.equal(lineCents(next[0]), 2400)
  assert.equal(lineCents(next[1]), 1000)
  assert.equal(next[2].unit.price_cents, 5500)
  assert.equal(next[2].unit.tier_code, 'wholesale_vip')
  assert.equal(next[0].quantity, 2)
})

test('a sale is called failed only when the server answered', () => {
  const unknown = [
    { message: 'TypeError: Failed to fetch', details: 'stack', code: '' },
    { message: 'AbortError: signal timed out', code: '' },
    { message: '<html>502 Bad Gateway</html>', code: '' },
    { message: 'duplicate key value violates unique constraint', code: '23505' },
    { message: 'Database client error', code: 'PGRST000' },
    new TypeError('Load failed'),
    null,
  ]
  for (const err of unknown) assert.equal(classifySaleError(err), 'unknown', JSON.stringify(err))
  assert.equal(classifySaleError({ message: 'price_changed: 1 item', code: 'P0001' }), 'price_changed')
  assert.equal(classifySaleError({ message: 'insufficient_stock: x', code: 'P0001' }), 'refused')
  assert.equal(classifySaleError({ message: 'request_id_reused: x', code: 'P0001' }), 'refused')
  assert.equal(classifySaleError({ message: 'deadlock detected', code: '40P01' }), 'refused')
  assert.equal(classifySaleError({ message: 'JWT expired', code: 'PGRST301' }), 'refused')
})

test('only the browser reporting no answer counts as a connection error', () => {
  assert.equal(isConnectionError({ message: 'TypeError: Failed to fetch', code: '' }), true)
  assert.equal(isConnectionError({ message: 'TypeError: NetworkError when attempting to fetch resource.' }), true)
  assert.equal(isConnectionError({ message: 'AbortError: signal timed out' }), true)
  assert.equal(isConnectionError({ message: 'insufficient_stock: x', code: 'P0001' }), false)
  assert.equal(isConnectionError(null), false)
})
