# GRN, inventory, the shop counter and returns

Rollout steps are in [inventory-cutover-plan.md](inventory-cutover-plan.md).

Stock has two forms, chosen per stock holder and changed only by an admin:

- **Quantity tracked:** a number. Ordinary accessories.
- **Individually tracked:** every item is a barcoded unit. Apple devices and selected parts.

The stock number means sellable stock physically in the shop, including items held
for online orders. **Available = on hand − active holds.**

```
Delivery arrives ──► Goods Received (received = accepted + rejected)
                        │  accepted items enter stock; rejected are recorded, never owed
                        │  individually tracked: one barcode per item, IMEI where required
                        ▼
                    in_stock
          ┌─────────────┴──────────────┐
  online order                     shop counter
  held (FIFO), number unmoved      scan label or IMEI, or add by product → bill → sold
  48 h unconfirmed → released
  confirmed / processing → held, never expires
  first shipped or delivered → sold, deducted exactly once
  cancelled before shipping → released
  cancelled after shipping → nothing restored

  customer return → quarantine → verified: in_stock, or written off
```

## Screens

| Screen | Who | What |
|---|---|---|
| **Good Receive Notice** `/admin/grn` | owner, admin post · staff view without costs | Supplier delivery, counted opening stock, or buy-back. Records received, accepted and rejected with a reason. Blank cost is never zero: state it or mark it pending. Correct goods received by mistake here. |
| **Inventory** `/admin/inventory` | staff view · owner, admin act | One trusted figure per stock holder: in shop, available, reserved, sold, quarantine, returned. Units tab: find by barcode or IMEI, labels, write-off, quarantine. Quarantine tab: verify or write off. |
| **Shop counter** `/admin/pos` | owner, admin, staff | Scan with a USB/Bluetooth scanner, the camera or by typing. Add quantity items by product. Attach an account for wholesale prices. Discounts above the limit need approval, for that bill. |
| **Customer returns** `/admin/returns` | owner, admin record · staff view | Goods back go to quarantine. Money back is a separate record. |
| **Orders** (existing) | — | Shows the order's stock state and **Units to pack**. |
| **Settings** | owner, admin | Customer hold limits and the staff discount limit. |

Customers never see a barcode or IMEI. Staff never see purchase costs: those columns
are not granted to browser sessions, and owner/admin read them through checked functions.

## Rules worth knowing

- Switching a holder to individual tracking needs zero stock: count it, set it to 0,
  switch, then receive the items as Opening stock so each gets a label.
- Adjust stock works on quantity-tracked holders only, and cannot go below active holds.
- An own-stock variant has its own number and mode, whatever its siblings do.
- An IMEI can be in the shop only once. One recorded earlier can come back (repair,
  buy-back, a corrected GRN) only with a stated reason; it gets a new barcode, and
  history is kept.
- Every create is safe to retry: the same request returns the first result, and the
  same request id with different content is refused.
- The same invoice from the same supplier is refused as a possible duplicate, unless a
  person confirms it with a note.

## Reservation expiry

Without pg_cron or pg_net. Overdue holds stop counting at once, every stock-taking path
releases overdue orders for the products it touches, and the Inventory screen runs
`expire_pending_orders()` on load. The `expire-reservations` edge function lets an
external scheduler keep order statuses current too; setting one up is optional.

## Database

Migrations `20261028120000`, `20261028160000` and `20261101100000` to `20261101130000`.
Verified by `supabase/tests/verify_grn_units_pos.sql`, `verify_purchase_returns.sql`,
`verify_inventory_master.sql` and `verify_inventory_master_concurrency.sh`.

## Android

`CAMERA` permission for scanning. Labels and bills go through the system share sheet in
the APK, via `@capacitor/filesystem` and `@capacitor/share`, because a WebView cannot
open or download a PDF itself. Typing a code always works where the camera does not.

# Purchase & Returns

Sidebar group **Purchase & Returns**:

| Page | What it does |
|---|---|
| **Supplier Details** `/admin/suppliers` | Suppliers, opening balance with an audit note, and for owner/admin a statement of every transaction. Deactivate instead of deleting. |
| **Good Receive Notice** `/admin/grn` | See above. Against a PO, its open lines are filled in and over-receiving is refused. |
| **Purchase Orders** `/admin/purchase-orders` | Order from a supplier; receive against it (Open → Partly received → Received); close the rest when it will not come. |
| **Supplier Returns** `/admin/supplier-returns` | Scan units from the shelf or quarantine, or enter quantities per delivery. Cash = money handed back; Credit = deducted from what you owe. A mistake is reversed, and the record stays. |
| **Supplier Payments** `/admin/supplier-payments` | Money paid, optionally applied to GRNs. Mistakes are voided, not deleted. Owner/admin only. |

**Amount owed** = opening balance + accepted goods at stated cost − GRN corrections −
credit returns − payments. Lines with a pending cost are not included, and the screen
says how many there are.
