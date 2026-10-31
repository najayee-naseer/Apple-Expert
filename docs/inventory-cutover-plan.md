# Inventory go-live: cutover plan

For the owner and whoever runs the rollout. Nothing here has been run. The steps are
in order; do not skip the local database phase.

**Current production stock figures are not verified physical quantities.** They are
never reset or assumed by any migration. The 3,722 units seen earlier were a local
seed total, not a count.

## Before anything: decisions the business must make

| Decision | Where it is set | Until decided |
|---|---|---|
| Items one customer may hold, and open orders per customer | Settings → Stock and discount rules | No limit |
| Staff discount allowed without approval | Same card | 0%: every staff discount needs owner/admin approval |
| Which accessories and parts are tracked individually | Product editor | Everything existing is tracked by quantity |
| Whether iPad, Mac, Watch and AirPods need a serial on every unit (iPhone always does) | `categories.requires_serial` | Serial optional for them |
| External scheduler for reservation expiry (optional) | `expire-reservations` edge function | Expiry still enforced; see Database below |

## 1. Prove it locally first

1. Apply all migrations to the local stack and run every suite in `supabase/tests`,
   including `verify_inventory_master.sql` and `verify_inventory_master_concurrency.sh`.
2. Regenerate `src/lib/supabase/database.types.ts` from the local database and check
   it matches the hand-edited version.
3. Test labels, bills and the camera on a real Android device. These have not been
   tested on a device.

Do not continue until these pass.

## 2. Confirm what production already has

The owner runs `supabase migration list --linked` and compares it with the repository.
Earlier notes showed `20261003120000` and `20261005120000` may not have been pushed.
Everything missing goes up together, in order.

## 3. Physical stock count

Run per product, ideally outside trading hours.

1. Print a count sheet from Inventory or the product list. Do not show the system
   figure to the people counting.
2. Count every sellable item in the shop. Keep damaged or doubtful items apart.
3. For every Apple device and every individually tracked part, record the **IMEI or
   serial** by scanning it, and check it against the device (Settings → About).
   Note the exact variant: colour and storage.
4. Have a second person recount anything that differs from the system figure.
5. **The two iPhone products found inconsistent in P0b stay untouched until their
   physical counts are done.** No migration or step here changes them first. The
   repository does not name them: the owner must identify them before counting.

## 4. Existing products and variants

For each product, using the count:

- **Variants sharing stock (today, all of them locally):** their common number stays
  on the product. Availability per variant is real only once the product is tracked
  individually.
- **Own-stock variants:** each keeps its own number and may have its own tracking mode.
- Decide quantity or individual tracking per the approved rule: Apple devices and
  selected uniquely identifiable parts individually; ordinary accessories by quantity.

## 5. Existing orders

The migration classifies every order by its status at that moment, without moving
stock:

| Status at cutover | Treatment |
|---|---|
| Shipped, delivered | `legacy_done`: never deducted again |
| Cancelled, refunded | `legacy_closed` |
| Anything else | `legacy_open`: no reservation. On first shipment, stock is deducted if sufficient; otherwise it is flagged in Inventory → Needs reconciliation for a person to resolve |

Before cutover, staff should work through open orders so as few as possible remain
`legacy_open`. If any order was placed on an environment that already ran the GRN
migration, `20261101100000` stops rather than guessing; reconcile those first.

## 6. Suppliers and purchase history

1. Enter suppliers (Supplier Details).
2. Enter each opening balance **from the shop's records, with a note**. If it is not
   known, leave it blank: blank shows as not entered, never as zero. Never estimate.
3. Purchase history is **not** migrated. Past deliveries stay in the shop's records;
   only opening balances carry forward. If the business wants history imported, that
   is a separate decision with its own source data.
4. Unknown purchase costs on opening stock use **Cost pending**, not zero.

## 7. Training (before the switch)

| Who | What |
|---|---|
| Owner, admin | Goods Received: accepted vs rejected, cost pending, duplicate invoice warning, GRN corrections. Discount approvals. Customer returns vs refunds. Quarantine decisions. Supplier statement, payments, return reversal |
| Staff | Counter: scan, add by product, attach an account for wholesale prices, ask for discount approval. Picking "Units to pack". What 48-hour release means for customers. Staff cannot see costs |
| Everyone | Cancelling after shipping does not restore stock. Goods come back through Customer returns, and go to quarantine first |

## 8. The switch

Run in one window, in this order.

1. Take a full database backup. It is the only real rollback: see Risks.
2. Turn on **maintenance mode** (Settings). `place_order` then refuses new orders.
3. The owner runs `supabase db push`, applying in order: P1 (if missing),
   `20261028120000`, `20261028160000`, then `20261101100000` to `20261101130000`.
4. Check each migration's self-verification printed no error. If one fails, stop and
   restore; do not edit the database by hand.
5. Open stock, per counted product:
   - **Quantity tracked:** Adjust stock → Stock count to the counted figure.
   - **Individually tracked:** Adjust stock → 0 (stock count, note the count sheet),
     then Track individually, then Goods Received → Opening stock with the scanned
     IMEIs, then print and stick the labels.
6. Quarantine what was set aside as damaged or doubtful.
7. Spot-check the dashboard against the count sheets.
8. Distribute the new APK (below), then turn maintenance mode off.

## 9. APK distribution

Not done in this work. When the steps above pass:

1. `npm ci && npm run build && npx cap sync android`, then build and sign the release.
2. Install on one staff device first: sign in, scan, print a label, print a bill.
3. Distribute to staff, then customers. Installed customer apps keep working through
   the `place_order(jsonb, text)` wrapper, without retry protection until they update.

## 10. Verify after rollout

Same day:

- [ ] Place a test order: availability falls, the stock number does not.
- [ ] Cancel it: availability returns.
- [ ] Place, confirm and ship one: the number falls once, and one `sale` row is in the ledger.
- [ ] Sign in as staff and confirm costs are absent on GRN, PO, returns and suppliers.
- [ ] Sell at the counter, print the bill, and record a return: it reaches quarantine.
- [ ] Choose an out-of-stock variant: the storefront refuses it.

Weekly at first: check Needs reconciliation is empty, spot-count a few items, and run
this, which must return no rows:

```sql
-- A unit-tracked holder whose number differs from its units in the shop.
select p.id, p.stock,
       count(u.*) filter (where u.status in ('in_stock', 'reserved')) as units
  from public.products p
  left join public.inventory_units u on u.product_id = p.id
  left join public.product_variants v on v.id = u.variant_id
 where p.tracking_mode = 'unit' and (u.id is null or v.stock is null)
 group by p.id, p.stock
having p.stock <> count(u.*) filter (where u.status in ('in_stock', 'reserved'));
```

## Risks

- **No practical rollback once a reservation or GRN exists.** Stock changes meaning
  (on hand, not available), so old code would ignore every hold. Before go-live,
  restore the backup. After go-live, fix forward.
- **A product at zero during step 5 shows Out of Stock.** That is why it happens under
  maintenance mode.
- **Installed apps have no retry protection** until they update.
