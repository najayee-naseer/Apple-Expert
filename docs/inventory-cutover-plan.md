# Inventory, delivery address and checkout go-live: cutover plan

For the owner and whoever runs the rollout. Nothing here has been run. The steps are
in order. Do not skip a step, and do not continue past a checkpoint until it is
signed off.

Source of truth: the production readiness review of 3 November 2026
(<https://claude.ai/artifact/HJCxAEfQMCYVMqDFEgt5M1>). Its verdict was **NO-GO**
until the six prerequisites in section 1 are met. The production facts below come
from read-only queries made that day; recheck them before the window.

**Current production stock figures are not verified physical quantities.**
Production records 3,727 units with no ledger history. That is seed data (the
local seed totals 3,722), not a count. No migration resets or adjusts these
figures; the physical count in section 6 does.

## 0. Production at the time of review (3 November 2026)

| Item | Value |
|---|---|
| Migrations applied | 23, the last being `20261005120000` (wholesale_application_workflow) |
| Migrations pending | 13 (section 3). 36 in total once applied |
| Orders | 1, already cancelled (section 7). No pending, confirmed or shipped orders |
| Automatic backups | None listed. Point-in-time recovery is off |
| Database size | 14 MB |
| Products / variants | 108 / 73 (54 active; 4 variants hold their own stock) |
| Stock on record | 3,727 units, 0 inventory ledger rows |
| Accounts | 11 (3 Wholesale VIP, 1 staff role: the owner) |
| Saved addresses | 0 |

## 1. Prerequisites before any window is booked

All six must be met. Each was a blocking issue in the readiness review.

| # | Prerequisite | Where |
|---|---|---|
| P1 | A manual backup taken **and** restored successfully into a scratch database | Section 4 |
| P2 | Release builds for Android and iOS built from one commit that contains the delivery address and checkout work | Section 5 |
| P3 | Device tests passed on a real Android phone and a real iPhone | Section 5 |
| P4 | All 13 migrations rehearsed on a copy of production's real data | Section 4 |
| P5 | Client approvals CP1 and CP2 signed | Section 2 |
| P6 | Physical stock counted, or the recorded figures accepted in writing, and the two inconsistent iPhone products settled | Section 6 |

## 2. Client approvals

Nothing moves to the next stage without the named checkpoint signed: name, date
and the decision recorded here or in writing.

### CP1. Business decisions, before release work starts

| Decision | Where it is set | Until decided |
|---|---|---|
| **Installed apps stop ordering after the migration** and customers must update. Agree how customers are told (section 5) | Release communication | Required, no default |
| Go live on the 3,727 recorded units, or count first (section 6) | Owner | Required, no default |
| How to correct `iphone-17-pro-max` and `iphone-18-pro` (section 6) | Owner | Required, no default |
| Staff lose access to customers' saved address books; delivery details come from each order only | Migration `20261101160000` | As built |
| City/town is typed freely. Orders placed before this release keep no delivery address | Same | As built |
| Items one customer may hold, and open orders per customer | Settings → Stock and discount rules | No limit |
| Staff discount allowed without approval | Same card | 0%: every staff discount needs owner/admin approval |
| Unconfirmed online orders are released after 48 hours | Inventory policy | 48 hours |
| Which accessories and parts are tracked individually | Product editor | Everything existing is tracked by quantity |
| Whether iPad, Mac, Watch and AirPods need a serial on every unit (iPhone always does) | `categories.requires_serial` | Serial optional for them |
| Where supplier opening balances come from | Supplier Details | Blank, shown as not entered |
| How the iOS app is distributed (TestFlight or App Store), and under which Apple developer account | Release | Required for iOS |
| External scheduler for reservation expiry (optional) | `expire-reservations` edge function | Expiry still enforced when stock is checked |

### CP2. Confirmation of the cancelled test order

The owner confirms in writing that the cancellation of order **AE-261023-A7A1A2**
on 3 November 2026 was intentional (section 7).

### CP3. Go decision for the window

Signed only when P1 to P6 are met, the rehearsal report (section 4) is accepted,
and the window date, time, length and the person running `supabase db push` are
agreed.

### CP4. Go-live decision, inside the window

Signed after the staff-device check in section 9 passes, while maintenance mode is
still on. This is the last point at which restoring the backup is clean.

## 3. The 13 pending migrations

They are applied together, in this order, in one window. Several check for the
previous ones and stop if they are missing. `20261101150000` is broken without
`20261101150100`, and `20261101160000` needs `place_order_impl` from
`20261101100000`.

| # | Migration | What it does | Risk |
|---|---|---|---|
| 1 | `20261023120000_inventory_ledger_and_stock_guard` | Stock changes only with a ledger entry; adds `admin_set_stock`. Removes client writes on the ledger and anonymous writes on products and variants | Medium |
| 2 | `20261023120100_revoke_anon_catalog_writes` | Removes anonymous write grants on 8 catalog tables | Low |
| 3 | `20261028120000_grn_barcode_units_and_pos` | Goods received, barcoded units, counter sales. 5 new tables; adds `orders.stock_state`; requires a serial for iPhone | Medium |
| 4 | `20261028160000_suppliers_purchase_orders_returns_payments` | Suppliers, purchase orders, supplier returns and payments. 6 new tables | Low |
| 5 | `20261101100000_inventory_foundation_and_reservations` | The ordering model changes: orders reserve stock, which is consumed at shipment and released after 48 hours. Existing orders get a `stock_state`. Signed-in users can no longer insert orders directly | High |
| 6 | `20261101110000_grn_acceptance_and_serial_lifecycle` | One receiving function: accepted/rejected quantities, pending costs, GRN corrections | Low |
| 7 | `20261101120000_pos_discounts_customer_returns_refunds` | Counter discounts with approval, customer returns to quarantine, refunds. Counter functions recreated with new signatures | Medium |
| 8 | `20261101130000_supplier_finance_security_dashboard` | Supplier balances; staff can no longer read cost columns | Medium |
| 9 | `20261101140000_dual_barcodes` | Product and manufacturer barcodes alongside unit barcodes | Low |
| 10 | `20261101150000_pos_checkout` | Counter checkout with price protection and duplicate-request safety | Low |
| 11 | `20261101150100_pos_checkout_fix` | Fixes one function in #10 | Low |
| 12 | `20261101160000_delivery_addresses` | Saved addresses, provinces and districts, ordering through `place_order_v3`, a locked delivery snapshot on each order, staff delivery notes. **`place_order` and `place_order_v2` now refuse every call** | High |
| 13 | `20261103120000_address_book_rpc_only` | Addresses can only be changed through their functions; at most 20 per customer | Low |

In total: 27 new tables. No existing column is dropped and no existing row is
deleted. The only existing data rewritten in production is:

- category flags: `requires_serial` (iPhone), `default_tracking_mode` (iPhone, iPad,
  Mac, Watch, AirPods) and `allows_shared_barcode` (accessories, parts, batteries,
  displays)
- the one existing order's `stock_state`, which becomes `legacy_closed`
- new reference rows: 25 districts, 2 inventory locations and 1 inventory policy row

`supabase db push` applies the files one at a time. If one fails, those before it
stay applied: stop and follow section 11. Do not edit the database by hand.

## 4. Backup, verified restore and rehearsal

### 4.1 Manual backup (mandatory)

Production has no automatic backups and no point-in-time recovery, so these dumps
are the only rollback. The client runs them from the repository root; each command
asks for the database password.

```sh
supabase db dump --linked --role-only -f roles.sql
supabase db dump --linked             -f schema.sql
supabase db dump --linked --data-only -f data.sql
```

Also export the files in the storage buckets (storefront banners). A database dump
does not include them.

Before relying on the dump, count every table's rows in production with the query
below (read-only), and save the result as `production-counts.txt`:

```sql
select t.table_name,
       (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', t.table_name), false, true, '')))[1]::text as rows
  from information_schema.tables t
 where t.table_schema = 'public' and t.table_type = 'BASE TABLE'
 order by 1;
```

Store the dump files and counts somewhere other than the laptop running the push.
They hold customer data: keep them private and delete them once the release is
settled.

### 4.2 Verified restore (mandatory)

Done by the developer, in the local Docker container only, never against
production.

1. Create a scratch database in the local container. Before loading, pre-create the
   schemas `vault`, `extensions` and `graphql`, the extensions `pgcrypto` and
   `uuid-ossp`, and the publication `supabase_realtime`. Then load the auth,
   storage and extensions schema from the local stack, as in the 2 November
   rehearsal.
2. Load `roles.sql` (errors about roles that already exist are expected), then
   `schema.sql`, then `data.sql`.
3. Run the counting query on the scratch database. It must match
   `production-counts.txt` table for table.

If the counts do not match, the backup is not verified. Take it again before going
on.

### 4.3 Rehearsal of all 13 migrations (mandatory)

On the scratch database restored in 4.2, which holds a copy of production's real
data:

1. Apply the 13 files in section 3's order, each as one transaction, as `postgres`:
   `psql -1 -v ON_ERROR_STOP=1 -f <file>`.
2. Each file's self-check must finish without an error. Record how long each file
   took.
3. Run the counting query again. The only differences from
   `production-counts.txt` may be the 27 new tables (empty, apart from 25 rows in
   `delivery_regions`, 2 in `inventory_locations` and 1 in `inventory_policy`).
   Every existing table keeps its row count.
4. Check the expected changes:
   - the order AE-261023-A7A1A2 has `stock_state = 'legacy_closed'`
   - `delivery_regions` holds 25 districts in 9 provinces
   - the category flags are as listed in section 3
5. Point a build of the app at the scratch database once. Save an address, place
   an order with it, and cancel the order.
6. Drop the scratch database.

Write a short rehearsal report: the timings, the self-check output and the count
comparison. CP3 depends on it.

The 2 November rehearsal does not count for this. It used production's schema with
test rows, and only the first 12 files.

## 5. Release builds for iOS and Android (mandatory)

### Installed apps lose ordering

From the moment migration #12 is applied, **every app already installed on a phone
can no longer place orders**. Their `place_order` call is refused with
"address_required: please update the app to choose a delivery address", and older
apps show that text as it is. This is intended: an order must never exist without a
delivery address.

Installed apps keep browsing the catalog, signing in, showing the profile, showing
My Orders and sending wholesale applications. Admin stock, goods-received and
counter screens in older builds fail, as they already do in production today.

Customers must update to the new version. Agree the message under CP1, and send it
when maintenance mode is turned off.

The new app cannot order before the migrations are applied either (it calls
`place_order_v3`). The database and both apps are released together.

### The release version

1. Commit everything for this release in one commit: delivery addresses and
   checkout, retry safety, the address limit, the signed-out handling, the dialog
   and keyboard work, the `@capacitor/keyboard` plugin and the `ios/` project. Note
   the commit hash in the rehearsal report.
2. Android: raise `versionCode` above 3, and give `versionName` a new number such
   as `1.2.0`.
3. iOS: set a real version and build number (the project still says 1.0, build 1).
4. Build from that commit:
   ```sh
   npm ci
   npm run build
   npx cap sync
   ```
   `npm run build` reads `.env.local`, which points at production. Check that
   `.env.development.local` is not used, and never run `supabase config push`:
   `supabase/config.toml` holds a local-only SMS hook.
5. Produce the signed Android release and the iOS build. **Do not distribute
   either until CP4.**

### Device tests (mandatory)

On a real Android phone and a real iPhone, with builds pointed at the local stack:

- sign in
- add, edit and delete an address; the keyboard must not cover a field or Save
- place an order with an address, and cancel it
- scan a barcode with the camera
- print a unit label and a counter bill

Neither has been tested on a device yet. This Mac has no working Android emulator.

## 6. Physical stock count and reconciliation

Production records **3,727 units** (accessories 1,270, iPhone 946, parts 871,
iPad 245, Mac 210, AirPods 150, Watch 35) with no ledger history. Under CP1 the
owner decides either to count, or to go live on these figures and accept them in
writing. Counting is strongly recommended.

Run the count per product, ideally outside trading hours.

1. Print a count sheet from Inventory or the product list. Do not show the system
   figure to the people counting.
2. Count every sellable item in the shop. Keep damaged or doubtful items apart.
3. For every Apple device and every individually tracked part, record the **IMEI or
   serial** by scanning it, and check it against the device (Settings → About). Note
   the exact variant: colour and storage.
4. Have a second person recount anything that differs from the system figure.
5. **Settle the two inconsistent iPhone products from the count. No migration or
   step here changes them first:**

   | Product | Recorded on the product | Recorded on its variants |
   |---|---|---|
   | `iphone-17-pro-max` | 50 | 3 of its 4 variants hold their own stock, totalling 2; the fourth shares the product's figure |
   | `iphone-18-pro` | 5 | 1 of its 2 variants holds its own stock: 21 |

   Decide for each whether stock is kept per variant or per product, then enter the
   counted figures in section 9, step 6.

Keep the count sheets. The post-deployment spot checks compare against them.

### Existing products and variants

For each product, using the count:

- **Variants sharing stock:** their common number stays on the product.
  Availability per variant is real only once the product is tracked individually.
- **Own-stock variants:** each keeps its own number and may have its own tracking
  mode.
- Decide quantity or individual tracking per the approved rule: Apple devices and
  selected uniquely identifiable parts individually, ordinary accessories by
  quantity.

## 7. Existing orders and the cancelled test order

Production holds one order:

| Item | Value |
|---|---|
| Order | AE-261023-A7A1A2 (`cb2f0c20-f74d-44f2-a242-85449fc9bc4c`), placed 23 October 2026 from the owner's account |
| Items | 1 × MacBook Pro 16-inch, Space Black M4 Pro 24GB 512GB, Brand New, 1 Year Warranty (included), Rs. 749,000 |
| Status | **Cancelled**, 3 November 2026 06:10 UTC. No actor is recorded: the admin panel never records who changes a status |
| Payments, stock movement, reservation | None |
| After migration #5 | `legacy_closed`. Nothing further happens to it |

The client confirms the cancellation under CP2.

Migration #5 classifies every order by its status at that moment, without moving
stock:

| Status at cutover | Treatment |
|---|---|
| Shipped, delivered | `legacy_done`: never deducted again |
| Cancelled, refunded | `legacy_closed` |
| Anything else | `legacy_open`: no reservation. On first shipment, stock is deducted if sufficient; otherwise it is flagged in Inventory → Needs reconciliation for a person to resolve |

No order is open today. Any order placed between now and the window must be
resolved (confirmed and shipped, or cancelled) before the window, or it becomes
`legacy_open`. Section 9 checks this again.

## 8. Suppliers and training

### Suppliers and purchase history

1. Enter suppliers (Supplier Details).
2. Enter each opening balance **from the shop's records, with a note**. If it is not
   known, leave it blank: blank shows as not entered, never as zero. Never estimate.
3. Purchase history is **not** migrated. Past deliveries stay in the shop's records;
   only opening balances carry forward. Importing history is a separate decision
   with its own source data.
4. Unknown purchase costs on opening stock use **Cost pending**, not zero.

### Training (before the switch)

| Who | What |
|---|---|
| Owner, admin | Goods Received: accepted vs rejected, cost pending, duplicate invoice warning, GRN corrections. Discount approvals. Customer returns vs refunds. Quarantine decisions. Supplier statement, payments, return reversal |
| Staff | Counter: scan, add by product, attach an account for wholesale prices, ask for discount approval. Picking "Units to pack". What 48-hour release means for customers. Staff cannot see costs. Each order's delivery address and internal delivery notes |
| Everyone | Cancelling after shipping does not restore stock. Goods come back through Customer returns, and go to quarantine first. Customers on old apps must update to order |

## 9. The window

Run in one window, in this order. The stop conditions in section 11 apply
throughout.

### Pre-deployment checks (before the window opens)

- [ ] CP1, CP2 and CP3 signed.
- [ ] The rehearsal report is accepted, and the release commit hash matches the
      builds.
- [ ] Signed Android and iOS release builds are ready and not yet distributed.
- [ ] Count sheets are ready, or the CP1 acceptance of recorded figures is signed.
- [ ] Recheck orders (read-only): `select status, count(*) from public.orders group by status;`
      The only row should be cancelled; resolve anything else first.

### Deployment

1. Turn on **maintenance mode** (Settings). The current `place_order` then refuses
   new orders. This has been confirmed in production.
2. Take a fresh backup (section 4.1) and save the counts. This is the window-start
   backup.
3. Run `supabase migration list --linked`. Exactly 23 must be applied, ending at
   `20261005120000`.
4. From the release commit, the owner runs `supabase db push`. Do not add
   `--include-seed`.
5. Check that each migration's self-check printed no error.
6. Run `supabase migration list --linked` again. Exactly 36 must be applied, ending
   at `20261103120000`.
7. Enter opening stock, per counted product:
   - **Quantity tracked:** Adjust stock → Stock count to the counted figure.
   - **Individually tracked:** Adjust stock → 0 (stock count, noting the count
     sheet), then Track individually, then Goods Received → Opening stock with the
     scanned IMEIs, then print and stick the labels.
8. Quarantine what was set aside as damaged or doubtful.
9. Spot-check the dashboard against the count sheets.
10. **Staff-device check**, still in maintenance mode. Install the release build on
    one staff phone and:
    - sign in
    - open Add address: 9 provinces and 25 districts load, with no "Provinces could
      not be loaded"
    - save an address, place a test order with it, and cancel it
    - scan a unit and print its label
11. Sign **CP4**, or stop and restore (section 11).
12. Distribute the Android release and the iOS build, then turn maintenance mode
    off and send the update message to customers.

### Post-deployment verification

Same day:

- [ ] The address form shows 9 provinces and 25 districts on iPhone and Android.
- [ ] Save an address and place an order with it: the order shows that address,
      and staff see it under Delivery Information.
- [ ] Edit the saved address: the placed order still shows the original.
- [ ] Place a test order: availability falls, the stock number does not. Cancel it:
      availability returns.
- [ ] Place, confirm and ship one: the number falls once, and the ledger has one
      `sale` row.
- [ ] Sign in as staff and confirm costs are absent on GRN, PO, returns and
      suppliers.
- [ ] Sell at the counter, print the bill, and record a return: it reaches
      quarantine.
- [ ] Choose an out-of-stock variant: the storefront refuses it.
- [ ] An older installed app trying to order gets the update message, and nothing
      else breaks.

Weekly at first: check Needs reconciliation is empty, spot-count a few items
against the count sheets, and run this, which must return no rows:

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

## 10. Distribution after the window

1. Distribute the Android release to staff first, then customers.
2. Publish the iOS build through the channel chosen under CP1 (TestFlight or the App
   Store).
3. Remind customers on older apps to update. They can browse, but cannot order,
   until they do.

## 11. Rollback and stop conditions

### Stop the deployment if any of these happens

- The backup or its test restore is not verified (section 4).
- `migration list` does not show exactly 23 applied before the push.
- An order other than AE-261023-A7A1A2 exists and is not resolved.
- `supabase db push` reports an error, or any self-check fails.
- `migration list` does not show exactly 36 applied after the push.
- Any step of the staff-device check fails.
- The release builds are not ready, or were not built from the rehearsed commit.
- A required approval (CP1 to CP4) is missing.

### What to do when stopped

- **Before the push:** keep maintenance mode on until the cause is understood,
  then turn it off. Production is unchanged.
- **During or after the push, before CP4:** keep maintenance mode on. Restore the
  window-start backup with the developer, rather than fixing by hand. Then confirm
  `migration list` shows 23 and the row counts match the saved counts. Old apps then
  order again.
- **After CP4, once a reservation, goods receipt or counter sale exists under the
  new model:** do not restore. Stock now means on hand, not available, so the old
  code would ignore every hold, and restoring would lose those records. Fix
  forward.

### Risks

- **No practical rollback once a reservation or GRN exists.** That is why
  maintenance mode stays on until CP4.
- **There is no automatic backup.** The manual dump in section 4 is the only way
  back.
- **A product at zero during deployment step 7 shows Out of Stock.** That is why it
  happens under maintenance mode.
- **Installed apps cannot order after the migration** until customers update.
- **Recorded stock is not a count.** Going live without counting carries the seed
  figures into real availability.
- **No order status change records who made it.** This is a known gap, not blocking.
