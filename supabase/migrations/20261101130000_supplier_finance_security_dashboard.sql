-- ============================================================================
-- Apple Expert · Inventory integration 4/4 · supplier finance, cost security and
-- the inventory dashboard
-- ----------------------------------------------------------------------------
-- WHAT THE SHOP OWES A SUPPLIER
--   opening balance (when one has been entered)
--   + accepted goods at their stated cost, less GRN corrections
--   - supplier returns settled as credit (reversed ones excluded)
--   - payments (voided ones excluded)
--   Lines whose cost is still pending are NOT in the figure, and the figure says
--   how many there are, so nobody reads an understated balance as final.
--
-- COST SECURITY
--   RLS works on rows, and staff legitimately read these rows for operations, so
--   the money columns are removed with PostgreSQL column privileges. A staff
--   session can neither select those columns nor filter on them through PostgREST.
--   staff, admin and owner are one database role (authenticated), so admin screens
--   read money through admin_purchase_costs() and the supplier functions, each of
--   which re-checks the role. Staff cannot call them.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Columns
-- ----------------------------------------------------------------------------
-- NULL = no opening balance entered yet: never assumed to be zero, never invented.
alter table public.suppliers
  alter column opening_balance_cents drop not null,
  alter column opening_balance_cents drop default;

alter table public.purchase_orders add column request_fingerprint text;

alter table public.supplier_returns
  add column request_fingerprint  text,
  add column reversed_at          timestamptz,
  add column reversed_by          uuid references public.profiles (id) on delete set null,
  add column reversal_note        text check (reversal_note is null or length(reversal_note) <= 500),
  add constraint supplier_returns_reversal_complete check ((reversed_at is null) = (reversal_note is null));

alter table public.supplier_return_items
  alter column unit_id drop not null,
  alter column barcode_snapshot drop not null,
  drop constraint supplier_return_items_unit_id_key,
  add column quantity    integer not null default 1 check (quantity > 0),
  add column grn_line_id uuid references public.grn_lines (id) on delete restrict,
  add column from_status text,
  add column reversed_at timestamptz,
  add constraint supplier_return_items_unit_is_one check (unit_id is null or quantity = 1),
  add constraint supplier_return_items_has_source check (unit_id is not null or grn_line_id is not null);

update public.supplier_return_items set from_status = 'in_stock' where unit_id is not null;

-- A reversed return frees its unit to be returned again for real.
create unique index supplier_return_items_active_unit_key on public.supplier_return_items (unit_id)
  where unit_id is not null and reversed_at is null;

alter table public.supplier_payments add column request_fingerprint text;

create table public.supplier_payment_allocations (
  id            uuid primary key default gen_random_uuid(),
  payment_id    uuid not null references public.supplier_payments (id) on delete restrict,
  grn_id        uuid not null references public.grns (id) on delete restrict,
  amount_cents  bigint not null check (amount_cents > 0),
  constraint supplier_payment_allocations_once unique (payment_id, grn_id)
);

create index supplier_payment_allocations_grn_idx on public.supplier_payment_allocations (grn_id);

comment on table public.supplier_payment_allocations is
  'Optional: which GRNs a payment settles. An unallocated payment still reduces what is owed. Allocations of a voided payment no longer count.';

alter table public.supplier_payment_allocations enable row level security;
create policy "supplier_payment_allocations admin read" on public.supplier_payment_allocations
  for select to authenticated using (private.has_role('admin'));

revoke all on public.supplier_payment_allocations from anon;
revoke insert, update, delete, truncate on public.supplier_payment_allocations from authenticated, service_role;
grant select on public.supplier_payment_allocations to authenticated;


-- ----------------------------------------------------------------------------
-- 2. Suppliers: the opening balance has a history
-- ----------------------------------------------------------------------------
drop function if exists public.admin_save_supplier(uuid, text, text, text, text, text, text, bigint, boolean);

create or replace function public.admin_save_supplier(
  p_id                    uuid,
  p_name                  text,
  p_contact_person        text,
  p_phone                 text,
  p_email                 text,
  p_address               text,
  p_note                  text,
  p_opening_balance_cents bigint,
  p_opening_balance_note  text,
  p_is_active             boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := private.require_admin('save a supplier');
  v_name      text := btrim(coalesce(p_name, ''));
  v_contact   text := nullif(btrim(coalesce(p_contact_person, '')), '');
  v_phone     text := nullif(btrim(coalesce(p_phone, '')), '');
  v_email     text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  v_address   text := nullif(btrim(coalesce(p_address, '')), '');
  v_note      text := nullif(btrim(coalesce(p_note, '')), '');
  v_open_note text := nullif(btrim(coalesce(p_opening_balance_note, '')), '');
  v_before    public.suppliers;
  v_row       public.suppliers;
begin
  if length(v_name) < 2 or length(v_name) > 120 then
    raise exception 'invalid_supplier: a supplier name of 2 to 120 characters is required' using errcode = '22023';
  end if;
  if v_contact is not null and length(v_contact) > 120 then
    raise exception 'invalid_supplier: the contact person is limited to 120 characters' using errcode = '22023';
  end if;
  if v_phone is not null and (length(v_phone) > 30 or v_phone !~ '^[0-9+() -]+$') then
    raise exception 'invalid_phone: enter the phone number with digits only (up to 30 characters)' using errcode = '22023';
  end if;
  if v_email is not null and (length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'invalid_email: % is not a valid email address', v_email using errcode = '22023';
  end if;
  if v_address is not null and length(v_address) > 500 then
    raise exception 'invalid_supplier: the address is limited to 500 characters' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if p_opening_balance_cents is not null and (p_opening_balance_cents < 0 or p_opening_balance_cents > 100000000000) then
    raise exception 'invalid_amount: the opening balance must be from 0 to Rs. 1,000,000,000' using errcode = '22023';
  end if;

  if exists (select 1 from public.suppliers s
              where lower(btrim(s.name)) = lower(v_name) and s.id is distinct from p_id) then
    raise exception 'duplicate_supplier: a supplier named % already exists', v_name using errcode = '23505';
  end if;

  if p_id is null then
    insert into public.suppliers (supplier_code, name, contact_person, phone, email, address, note,
                                  opening_balance_cents, is_active, created_by)
    values ('SUP-' || lpad(nextval('private.supplier_code_seq')::text, 4, '0'),
            v_name, v_contact, v_phone, v_email, v_address, v_note, p_opening_balance_cents,
            coalesce(p_is_active, true), v_uid)
    returning * into v_row;
    if p_opening_balance_cents is not null then
      perform private.audit('supplier', v_row.id::text, 'opening_balance', null,
                            jsonb_build_object('opening_balance_cents', p_opening_balance_cents), v_open_note);
    end if;
  else
    select * into v_before from public.suppliers where id = p_id for update;
    if not found then
      raise exception 'unknown_supplier: %', p_id using errcode = 'P0001';
    end if;
    if v_before.opening_balance_cents is distinct from p_opening_balance_cents then
      if v_open_note is null or length(v_open_note) < 3 then
        raise exception 'opening_balance_note_required: say why the opening balance is changing' using errcode = '22023';
      end if;
      perform private.audit('supplier', p_id::text, 'opening_balance',
                            jsonb_build_object('opening_balance_cents', v_before.opening_balance_cents),
                            jsonb_build_object('opening_balance_cents', p_opening_balance_cents), v_open_note);
    end if;
    update public.suppliers
       set name = v_name, contact_person = v_contact, phone = v_phone, email = v_email,
           address = v_address, note = v_note, opening_balance_cents = p_opening_balance_cents,
           is_active = coalesce(p_is_active, is_active), updated_at = now()
     where id = p_id
    returning * into v_row;
  end if;

  return jsonb_build_object('id', v_row.id, 'supplier_code', v_row.supplier_code, 'name', v_row.name);
end;
$$;

revoke all on function public.admin_save_supplier(uuid, text, text, text, text, text, text, bigint, text, boolean) from public, anon, service_role;
grant execute on function public.admin_save_supplier(uuid, text, text, text, text, text, text, bigint, text, boolean) to authenticated;


-- ----------------------------------------------------------------------------
-- 3. Purchase orders: a blank cost is pending, not zero
-- ----------------------------------------------------------------------------
create or replace function public.admin_create_purchase_order(
  p_supplier_id   uuid,
  p_order_date    date,
  p_expected_date date,
  p_note          text,
  p_lines         jsonb,
  p_request_id    uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := private.require_admin('create a purchase order');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_fingerprint text;
  v_supplier    public.suppliers;
  v_po          public.purchase_orders;
  v_line        jsonb;
  v_line_no     integer := 0;
  v_product     public.products;
  v_variant     public.product_variants;
  v_qty         integer;
  v_cost        bigint;
  v_total       bigint := 0;
begin
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('supplier', p_supplier_id, 'date', p_order_date,
                                                          'expected', p_expected_date, 'note', v_note, 'lines', p_lines));
  select * into v_po from public.purchase_orders where request_id = p_request_id;
  if found then
    if v_po.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different purchase order' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_po.id, 'po_number', v_po.po_number, 'replayed', true);
  end if;

  select * into v_supplier from public.suppliers where id = p_supplier_id;
  if not found then
    raise exception 'unknown_supplier: choose a supplier' using errcode = 'P0001';
  end if;
  if not v_supplier.is_active then
    raise exception 'supplier_inactive: % is deactivated', v_supplier.name using errcode = 'P0001';
  end if;
  perform private.check_business_date(p_order_date, 'order date');
  if p_expected_date is not null and (p_expected_date < p_order_date or p_expected_date > p_order_date + 366) then
    raise exception 'invalid_date: the expected date must be on or after the order date, within a year' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 100 then
    raise exception 'invalid_lines: between 1 and 100 lines are required' using errcode = '22023';
  end if;

  insert into public.purchase_orders (po_number, supplier_id, order_date, expected_date, note, created_by, request_id, request_fingerprint)
  values ('PO-' || lpad(nextval('private.purchase_order_number_seq')::text, 6, '0'),
          v_supplier.id, p_order_date, p_expected_date, v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_po;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_no := v_line_no + 1;
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'invalid_lines: line % must be an object', v_line_no using errcode = '22023';
    end if;
    if coalesce(jsonb_typeof(v_line -> 'quantity'), '') <> 'number'
       or (v_line ->> 'quantity') !~ '^[0-9]+$'
       or (v_line ->> 'quantity')::numeric not between 1 and 2000 then
      raise exception 'invalid_quantity: line % quantity must be a whole number from 1 to 2000', v_line_no
        using errcode = '22023';
    end if;
    v_qty := (v_line ->> 'quantity')::integer;

    v_cost := null;
    if jsonb_typeof(v_line -> 'unit_cost_cents') = 'number' then
      if (v_line ->> 'unit_cost_cents') !~ '^[0-9]+$'
         or (v_line ->> 'unit_cost_cents')::numeric > 100000000000 then
        raise exception 'invalid_cost: line % unit cost must be a whole number of cents', v_line_no using errcode = '22023';
      end if;
      v_cost := (v_line ->> 'unit_cost_cents')::bigint;
    elsif not coalesce((v_line ->> 'cost_pending')::boolean, false) then
      raise exception 'cost_required: line % needs a cost, or mark it as cost pending', v_line_no using errcode = '22023';
    end if;

    select * into v_product from public.products where id = v_line ->> 'product_id';
    if not found then
      raise exception 'unknown_product: %', coalesce(v_line ->> 'product_id', '(missing)') using errcode = 'P0001';
    end if;

    v_variant := null;
    if nullif(v_line ->> 'variant_id', '') is not null then
      if (v_line ->> 'variant_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise exception 'invalid_variant: line % has a malformed variant id', v_line_no using errcode = '22023';
      end if;
      select * into v_variant from public.product_variants
       where id = (v_line ->> 'variant_id')::uuid and product_id = v_product.id;
      if v_variant.id is null then
        raise exception 'variant_product_mismatch: that variant does not belong to %', v_product.id using errcode = 'P0001';
      end if;
    elsif exists (select 1 from public.product_variants where product_id = v_product.id) then
      raise exception 'variant_required: choose the variant (colour / storage) for %', v_product.name using errcode = 'P0001';
    end if;

    insert into public.purchase_order_lines (purchase_order_id, line_no, product_id, variant_id,
                                             product_name_snapshot, variant_label_snapshot, quantity,
                                             unit_cost_cents, cost_pending)
    values (v_po.id, v_line_no, v_product.id, v_variant.id, v_product.name, v_variant.name, v_qty, v_cost, v_cost is null);

    v_total := v_total + v_qty * coalesce(v_cost, 0);
  end loop;

  update public.purchase_orders set total_cents = v_total where id = v_po.id;

  return jsonb_build_object('id', v_po.id, 'po_number', v_po.po_number, 'replayed', false);
end;
$$;


-- ----------------------------------------------------------------------------
-- 4. Supplier returns: units or quantity, from the shelf or quarantine, reversible
-- ----------------------------------------------------------------------------
drop function if exists public.admin_create_supplier_return(uuid, date, text, text[], text, uuid);

-- p_codes: unit barcodes or IMEI / serial numbers.
-- p_quantity_lines: [{ "grn_line_id": uuid, "quantity": int }] for quantity-tracked
-- goods, valued at what that delivery cost.
create or replace function public.admin_create_supplier_return(
  p_supplier_id    uuid,
  p_return_date    date,
  p_return_type    text,
  p_codes          text[],
  p_quantity_lines jsonb,
  p_note           text,
  p_request_id     uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := private.require_admin('record a supplier return');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_lines       jsonb := coalesce(p_quantity_lines, '[]'::jsonb);
  v_fingerprint text;
  v_supplier    public.suppliers;
  v_ret         public.supplier_returns;
  v_code        text;
  v_unit        public.inventory_units;
  v_ids         uuid[] := '{}';
  v_products    text[] := '{}';
  v_shelf       uuid[] := '{}';
  v_grn         public.grns;
  v_gl          public.grn_lines;
  v_line        jsonb;
  v_qty         integer;
  v_holder      record;
  v_total       bigint := 0;
  v_count       integer := 0;
begin
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('supplier', p_supplier_id, 'date', p_return_date,
    'type', p_return_type, 'codes', to_jsonb(p_codes), 'lines', v_lines, 'note', v_note));
  select * into v_ret from public.supplier_returns where request_id = p_request_id;
  if found then
    if v_ret.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different return' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_ret.id, 'return_number', v_ret.return_number,
                              'total_cents', v_ret.total_cents, 'total_units', v_ret.total_units, 'replayed', true);
  end if;

  select * into v_supplier from public.suppliers where id = p_supplier_id;
  if not found then
    raise exception 'unknown_supplier: choose a supplier' using errcode = 'P0001';
  end if;
  perform private.check_business_date(p_return_date, 'return date');
  if p_return_type is null or p_return_type not in ('cash', 'credit') then
    raise exception 'invalid_return_type: choose cash or credit' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if jsonb_typeof(v_lines) <> 'array' then
    raise exception 'invalid_items: quantity lines must be a list' using errcode = '22023';
  end if;
  if coalesce(cardinality(p_codes), 0) + jsonb_array_length(v_lines) = 0
     or coalesce(cardinality(p_codes), 0) > 500 or jsonb_array_length(v_lines) > 100 then
    raise exception 'invalid_items: scan between 1 and 500 items' using errcode = '22023';
  end if;

  -- Resolve every code to one unit, once. No locks and no rows yet.
  foreach v_code in array coalesce(p_codes, '{}'::text[])
  loop
    v_code := private.normalize_serial(v_code);
    if v_code is null then
      continue;
    end if;
    select * into v_unit from private.find_unit_by_code(v_code);
    if v_unit.id is null then
      raise exception 'unit_not_found: no item with barcode or IMEI %', v_code using errcode = 'P0001';
    end if;
    if v_unit.id = any (v_ids) then
      raise exception 'duplicate_item: % is scanned twice', v_unit.barcode using errcode = '23505';
    end if;
    select * into v_grn from public.grns where id = v_unit.grn_id;
    if v_grn.supplier_id is not null and v_grn.supplier_id <> v_supplier.id then
      raise exception 'wrong_supplier: % was received from % (%), not from %',
        v_unit.barcode, v_grn.supplier_name, v_grn.grn_number, v_supplier.name using errcode = 'P0001';
    end if;
    v_ids := v_ids || v_unit.id;
    v_products := v_products || v_unit.product_id;
  end loop;

  select coalesce(array_agg(l.product_id), '{}'::text[]) || v_products into v_products
    from jsonb_array_elements(v_lines) x
    join public.grn_lines l on l.id = (x.value ->> 'grn_line_id')::uuid;

  if cardinality(v_ids) + jsonb_array_length(v_lines) = 0 then
    raise exception 'invalid_items: scan between 1 and 500 items' using errcode = '22023';
  end if;

  -- Parents first.
  perform private.lock_products(v_products);

  insert into public.supplier_returns (return_number, supplier_id, return_date, return_type, note, created_by, request_id, request_fingerprint)
  values ('SR-' || lpad(nextval('private.supplier_return_number_seq')::text, 6, '0'),
          v_supplier.id, p_return_date, p_return_type, v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_ret;

  for v_unit in
    select * from public.inventory_units where id = any (v_ids) order by barcode for update
  loop
    if v_unit.status not in ('in_stock', 'quarantined') then
      raise exception 'unit_not_available: % is % and cannot be returned to the supplier',
        v_unit.barcode, replace(v_unit.status, '_', ' ') using errcode = 'P0001';
    end if;
    if v_unit.unit_cost_cents is null then
      raise exception 'cost_pending: % has no cost yet. State the GRN cost before returning it.', v_unit.barcode using errcode = 'P0001';
    end if;
    if v_unit.status = 'in_stock' then
      v_shelf := v_shelf || v_unit.id;
    end if;

    insert into public.supplier_return_items (supplier_return_id, unit_id, product_id, variant_id,
                                              product_name_snapshot, variant_label_snapshot,
                                              barcode_snapshot, serial_snapshot, grn_id, grn_line_id,
                                              unit_cost_cents, quantity, from_status)
    select v_ret.id, v_unit.id, v_unit.product_id, v_unit.variant_id, p.name, v.name,
           v_unit.barcode, v_unit.serial_number, v_unit.grn_id, v_unit.grn_line_id,
           v_unit.unit_cost_cents, 1, v_unit.status
      from public.products p
      left join public.product_variants v on v.id = v_unit.variant_id
     where p.id = v_unit.product_id;

    update public.inventory_units
       set status = 'returned_to_supplier', location_code = 'MAIN_SHOP', supplier_return_id = v_ret.id,
           status_changed_at = now(),
           status_note = 'Returned to ' || v_supplier.name || ' (' || v_ret.return_number || ')'
     where id = v_unit.id;

    update public.grn_lines set returned_quantity = returned_quantity + 1 where id = v_unit.grn_line_id;
    update public.purchase_order_lines pl set returned_quantity = pl.returned_quantity + 1
      from public.grn_lines gl
     where gl.id = v_unit.grn_line_id and pl.id = gl.purchase_order_line_id;

    v_total := v_total + v_unit.unit_cost_cents;
    v_count := v_count + 1;
  end loop;

  for v_holder in
    select u.product_id, u.variant_id, count(*)::integer as qty
      from public.inventory_units u
     where u.id = any (v_shelf)
     group by u.product_id, u.variant_id
     order by u.product_id, u.variant_id
  loop
    perform private.move_stock(v_holder.product_id, v_holder.variant_id, -v_holder.qty, 'supplier_return',
                               'Supplier return ' || v_ret.return_number || ' to ' || v_supplier.name,
                               null, null, null);
  end loop;

  -- Quantity lines: valued at the delivery they came from.
  for v_line in select value from jsonb_array_elements(v_lines) loop
    if coalesce(jsonb_typeof(v_line -> 'quantity'), '') <> 'number'
       or coalesce(v_line ->> 'quantity', '') !~ '^[0-9]{1,4}$' or (v_line ->> 'quantity')::integer < 1 then
      raise exception 'invalid_quantity: a returned quantity must be a whole number' using errcode = '22023';
    end if;
    v_qty := (v_line ->> 'quantity')::integer;

    select * into v_gl from public.grn_lines where id = (v_line ->> 'grn_line_id')::uuid for update;
    if not found then
      raise exception 'unknown_grn_line: choose the delivery these came from' using errcode = 'P0001';
    end if;
    select * into v_grn from public.grns where id = v_gl.grn_id;
    if v_grn.supplier_id is distinct from v_supplier.id then
      raise exception 'wrong_supplier: % was received from %, not from %', v_grn.grn_number, v_grn.supplier_name, v_supplier.name
        using errcode = 'P0001';
    end if;
    if v_gl.tracking_mode_snapshot <> 'quantity' then
      raise exception 'scan_required: % is tracked individually. Scan each item.', v_gl.product_name_snapshot using errcode = 'P0001';
    end if;
    if v_gl.unit_cost_cents is null then
      raise exception 'cost_pending: state the cost on % before returning from it', v_grn.grn_number using errcode = 'P0001';
    end if;
    if v_gl.corrected_quantity + v_gl.returned_quantity + v_qty > v_gl.accepted_quantity then
      raise exception 'invalid_quantity: only % of % from % can still be returned',
        v_gl.accepted_quantity - v_gl.corrected_quantity - v_gl.returned_quantity,
        v_gl.product_name_snapshot, v_grn.grn_number using errcode = 'P0001';
    end if;

    perform private.move_stock(v_gl.product_id, v_gl.variant_id, -v_qty, 'supplier_return',
                               'Supplier return ' || v_ret.return_number || ' to ' || v_supplier.name,
                               null, null, null);

    insert into public.supplier_return_items (supplier_return_id, product_id, variant_id, product_name_snapshot,
                                              variant_label_snapshot, grn_id, grn_line_id, unit_cost_cents, quantity, from_status)
    values (v_ret.id, v_gl.product_id, v_gl.variant_id, v_gl.product_name_snapshot, v_gl.variant_label_snapshot,
            v_gl.grn_id, v_gl.id, v_gl.unit_cost_cents, v_qty, 'in_stock');

    update public.grn_lines set returned_quantity = returned_quantity + v_qty where id = v_gl.id;
    update public.purchase_order_lines set returned_quantity = returned_quantity + v_qty where id = v_gl.purchase_order_line_id;

    v_total := v_total + v_gl.unit_cost_cents * v_qty;
    v_count := v_count + v_qty;
  end loop;

  update public.supplier_returns set total_cents = v_total, total_units = v_count where id = v_ret.id;

  return jsonb_build_object('id', v_ret.id, 'return_number', v_ret.return_number,
                            'total_cents', v_total, 'total_units', v_count, 'replayed', false);
end;
$$;

comment on function public.admin_create_supplier_return(uuid, date, text, text[], jsonb, text, uuid) is
  'Admin/owner. Sends goods back to a supplier; shelf stock falls through the ledger. Reversible with admin_reverse_supplier_return().';

revoke all on function public.admin_create_supplier_return(uuid, date, text, text[], jsonb, text, uuid) from public, anon, service_role;
grant execute on function public.admin_create_supplier_return(uuid, date, text, text[], jsonb, text, uuid) to authenticated;

-- A return recorded by mistake, or goods the supplier sent straight back. The row
-- stays; its effect on stock and on what is owed is undone. Each unit goes back
-- where it came from, so a damaged unit returns to quarantine, not the shelf.
create or replace function public.admin_reverse_supplier_return(p_return_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := private.require_admin('reverse a supplier return');
  v_note     text := btrim(coalesce(p_note, ''));
  v_ret      public.supplier_returns;
  v_products text[];
  v_item     public.supplier_return_items;
  v_unit     public.inventory_units;
  v_count    integer := 0;
begin
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  select * into v_ret from public.supplier_returns where id = p_return_id for update;
  if not found then
    raise exception 'unknown_return: %', coalesce(p_return_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_ret.reversed_at is not null then
    raise exception 'return_reversed: % has already been reversed', v_ret.return_number using errcode = 'P0001';
  end if;

  select array_agg(i.product_id) into v_products
    from public.supplier_return_items i where i.supplier_return_id = v_ret.id and i.product_id is not null;
  perform private.lock_products(coalesce(v_products, '{}'::text[]));

  for v_item in
    select * from public.supplier_return_items where supplier_return_id = v_ret.id order by product_id, variant_id, id
  loop
    if v_item.product_id is null then
      raise exception 'product_missing: % no longer exists', v_item.product_name_snapshot using errcode = 'P0001';
    end if;

    if v_item.unit_id is not null then
      select * into v_unit from public.inventory_units where id = v_item.unit_id for update;
      if v_unit.status <> 'returned_to_supplier' or v_unit.supplier_return_id is distinct from v_ret.id then
        raise exception 'unit_not_available: % is no longer with the supplier on this return', v_unit.barcode using errcode = 'P0001';
      end if;
      update public.inventory_units
         set status = v_item.from_status,
             location_code = case when v_item.from_status = 'quarantined' then 'QUARANTINE' else 'MAIN_SHOP' end,
             supplier_return_id = null, status_changed_at = now(),
             status_note = left('Supplier return ' || v_ret.return_number || ' reversed: ' || v_note, 500)
       where id = v_unit.id;
    end if;

    if v_item.from_status = 'in_stock' then
      perform private.move_stock(v_item.product_id, v_item.variant_id, v_item.quantity, 'supplier_return_reversal',
                                 'Supplier return ' || v_ret.return_number || ' reversed', null, null, null);
    end if;

    update public.grn_lines set returned_quantity = returned_quantity - v_item.quantity where id = v_item.grn_line_id;
    update public.purchase_order_lines pl set returned_quantity = pl.returned_quantity - v_item.quantity
      from public.grn_lines gl
     where gl.id = v_item.grn_line_id and pl.id = gl.purchase_order_line_id;

    update public.supplier_return_items set reversed_at = now() where id = v_item.id;
    v_count := v_count + v_item.quantity;
  end loop;

  update public.supplier_returns
     set reversed_at = now(), reversed_by = v_uid, reversal_note = v_note
   where id = v_ret.id;

  perform private.audit('supplier_return', v_ret.id::text, 'reversed',
                        jsonb_build_object('total_cents', v_ret.total_cents, 'return_type', v_ret.return_type),
                        jsonb_build_object('units', v_count), v_note);

  return jsonb_build_object('id', v_ret.id, 'return_number', v_ret.return_number, 'reversed_units', v_count);
end;
$$;

revoke all on function public.admin_reverse_supplier_return(uuid, text) from public, anon, service_role;
grant execute on function public.admin_reverse_supplier_return(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Supplier payments, optionally allocated to GRNs
-- ----------------------------------------------------------------------------
drop function if exists public.admin_record_supplier_payment(uuid, date, bigint, text, text, text, uuid);

-- p_allocations: [{ "grn_id": uuid, "amount_cents": int }] or empty.
create or replace function public.admin_record_supplier_payment(
  p_supplier_id  uuid,
  p_paid_on      date,
  p_amount_cents bigint,
  p_method       text,
  p_reference    text,
  p_note         text,
  p_allocations  jsonb,
  p_request_id   uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := private.require_admin('record a supplier payment');
  v_ref         text := nullif(btrim(coalesce(p_reference, '')), '');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_allocations jsonb := coalesce(p_allocations, '[]'::jsonb);
  v_fingerprint text;
  v_supplier    public.suppliers;
  v_pay         public.supplier_payments;
  v_alloc       jsonb;
  v_grn         public.grns;
  v_amount      bigint;
  v_paid        bigint;
  v_sum         bigint := 0;
begin
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('supplier', p_supplier_id, 'date', p_paid_on, 'amount', p_amount_cents,
    'method', p_method, 'reference', v_ref, 'note', v_note, 'allocations', v_allocations));
  select * into v_pay from public.supplier_payments where request_id = p_request_id;
  if found then
    if v_pay.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different payment' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_pay.id, 'payment_number', v_pay.payment_number, 'replayed', true);
  end if;

  -- Serialises payments to one supplier, so allocations cannot over-settle a GRN.
  select * into v_supplier from public.suppliers where id = p_supplier_id for no key update;
  if not found then
    raise exception 'unknown_supplier: choose a supplier' using errcode = 'P0001';
  end if;
  perform private.check_business_date(p_paid_on, 'payment date');
  if p_amount_cents is null or p_amount_cents <= 0 or p_amount_cents > 100000000000 then
    raise exception 'invalid_amount: the amount must be more than zero' using errcode = '22023';
  end if;
  if p_method is null or p_method not in ('cash', 'bank_transfer', 'cheque', 'card', 'other') then
    raise exception 'invalid_method: choose how it was paid' using errcode = '22023';
  end if;
  if p_method = 'cheque' and v_ref is null then
    raise exception 'reference_required: enter the cheque number' using errcode = '22023';
  end if;
  if v_ref is not null and length(v_ref) > 60 then
    raise exception 'invalid_reference: the reference is limited to 60 characters' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if jsonb_typeof(v_allocations) <> 'array' then
    raise exception 'invalid_allocation: allocations must be a list' using errcode = '22023';
  end if;

  insert into public.supplier_payments (payment_number, supplier_id, paid_on, amount_cents, method,
                                        reference, note, created_by, request_id, request_fingerprint)
  values ('SP-' || lpad(nextval('private.supplier_payment_number_seq')::text, 6, '0'),
          v_supplier.id, p_paid_on, p_amount_cents, p_method, v_ref, v_note, v_uid, p_request_id, v_fingerprint)
  returning * into v_pay;

  for v_alloc in select value from jsonb_array_elements(v_allocations) loop
    if coalesce(jsonb_typeof(v_alloc -> 'amount_cents'), '') <> 'number'
       or coalesce(v_alloc ->> 'amount_cents', '') !~ '^[0-9]{1,12}$' or (v_alloc ->> 'amount_cents')::bigint <= 0 then
      raise exception 'invalid_allocation: an allocation must be a positive amount' using errcode = '22023';
    end if;
    v_amount := (v_alloc ->> 'amount_cents')::bigint;

    select * into v_grn from public.grns where id = (v_alloc ->> 'grn_id')::uuid;
    if not found or v_grn.supplier_id is distinct from v_supplier.id then
      raise exception 'invalid_allocation: that GRN is not from %', v_supplier.name using errcode = 'P0001';
    end if;

    select coalesce(sum(a.amount_cents), 0) into v_paid
      from public.supplier_payment_allocations a
      join public.supplier_payments p on p.id = a.payment_id
     where a.grn_id = v_grn.id and p.voided_at is null;

    if v_paid + v_amount > v_grn.total_cost_cents - v_grn.corrected_cost_cents then
      raise exception 'invalid_allocation: % has only % cents left to settle',
        v_grn.grn_number, greatest(v_grn.total_cost_cents - v_grn.corrected_cost_cents - v_paid, 0) using errcode = 'P0001';
    end if;

    insert into public.supplier_payment_allocations (payment_id, grn_id, amount_cents)
    values (v_pay.id, v_grn.id, v_amount);
    v_sum := v_sum + v_amount;
  end loop;

  if v_sum > p_amount_cents then
    raise exception 'invalid_allocation: allocations are more than the payment' using errcode = '22023';
  end if;

  return jsonb_build_object('id', v_pay.id, 'payment_number', v_pay.payment_number, 'replayed', false);
end;
$$;

revoke all on function public.admin_record_supplier_payment(uuid, date, bigint, text, text, text, jsonb, uuid) from public, anon, service_role;
grant execute on function public.admin_record_supplier_payment(uuid, date, bigint, text, text, text, jsonb, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 6. What is owed, and how it got there
-- ----------------------------------------------------------------------------
drop function if exists public.admin_supplier_balances();

create or replace function public.admin_supplier_balances()
returns table (
  supplier_id          uuid,
  opening_cents        bigint,
  purchases_cents      bigint,
  credit_returns_cents bigint,
  cash_returns_cents   bigint,
  payments_cents       bigint,
  balance_cents        bigint,
  pending_cost_lines   integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform private.require_admin('view supplier balances');
  return query
  select s.id,
         s.opening_balance_cents,
         coalesce(g.total, 0)::bigint,
         coalesce(r.credit, 0)::bigint,
         coalesce(r.cash, 0)::bigint,
         coalesce(p.total, 0)::bigint,
         (coalesce(s.opening_balance_cents, 0) + coalesce(g.total, 0) - coalesce(r.credit, 0) - coalesce(p.total, 0))::bigint,
         coalesce(g.pending, 0)::integer
    from public.suppliers s
    left join (select gr.supplier_id, sum(gr.total_cost_cents - gr.corrected_cost_cents) as total,
                      sum(gr.pending_cost_lines) as pending
                 from public.grns gr where gr.supplier_id is not null group by gr.supplier_id) g
      on g.supplier_id = s.id
    left join (select sr.supplier_id,
                      sum(sr.total_cents) filter (where sr.return_type = 'credit') as credit,
                      sum(sr.total_cents) filter (where sr.return_type = 'cash') as cash
                 from public.supplier_returns sr where sr.reversed_at is null group by sr.supplier_id) r
      on r.supplier_id = s.id
    left join (select sp.supplier_id, sum(sp.amount_cents) as total
                 from public.supplier_payments sp where sp.voided_at is null group by sp.supplier_id) p
      on p.supplier_id = s.id;
end;
$$;

comment on function public.admin_supplier_balances() is
  'Admin/owner. Opening + accepted GRN cost - corrections - credit returns - payments, per supplier. Pending-cost lines are not in the figure and are counted separately.';

revoke all on function public.admin_supplier_balances() from public, anon, service_role;
grant execute on function public.admin_supplier_balances() to authenticated;

-- Every transaction with one supplier, oldest first, for its statement.
create or replace function public.admin_supplier_statement(p_supplier_id uuid)
returns table (
  occurred_on  date,
  recorded_at  timestamptz,
  kind         text,
  reference    text,
  description  text,
  debit_cents  bigint,
  credit_cents bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform private.require_admin('view a supplier statement');
  return query
  select * from (
    select s.created_at::date as occurred_on, s.created_at as recorded_at, 'opening'::text as kind,
           s.supplier_code as reference, 'Opening balance'::text as description,
           s.opening_balance_cents as debit_cents, 0::bigint as credit_cents
      from public.suppliers s
     where s.id = p_supplier_id and s.opening_balance_cents is not null
    union all
    select g.received_on, g.created_at, 'grn', g.grn_number,
           concat_ws(' · ', 'Goods received', 'Invoice ' || g.supplier_invoice,
                     case when g.pending_cost_lines > 0 then g.pending_cost_lines || ' line(s) cost pending' end),
           g.total_cost_cents - g.corrected_cost_cents, 0::bigint
      from public.grns g where g.supplier_id = p_supplier_id
    union all
    select r.return_date, r.created_at, 'return', r.return_number,
           concat_ws(' · ', initcap(r.return_type) || ' return', case when r.reversed_at is not null then 'Reversed' end),
           0::bigint,
           case when r.return_type = 'credit' and r.reversed_at is null then r.total_cents else 0::bigint end
      from public.supplier_returns r where r.supplier_id = p_supplier_id
    union all
    select p.paid_on, p.created_at, 'payment', p.payment_number,
           concat_ws(' · ', initcap(replace(p.method, '_', ' ')), p.reference, case when p.voided_at is not null then 'Voided' end),
           0::bigint,
           case when p.voided_at is null then p.amount_cents else 0::bigint end
      from public.supplier_payments p where p.supplier_id = p_supplier_id
  ) t
  order by t.occurred_on, t.recorded_at;
end;
$$;

revoke all on function public.admin_supplier_statement(uuid) from public, anon, service_role;
grant execute on function public.admin_supplier_statement(uuid) to authenticated;

-- GRNs from one supplier with money still unsettled by allocations.
create or replace function public.admin_supplier_open_grns(p_supplier_id uuid)
returns table (
  grn_id            uuid,
  grn_number        text,
  received_on       date,
  supplier_invoice  text,
  amount_cents      bigint,
  allocated_cents   bigint,
  outstanding_cents bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform private.require_admin('view open GRNs');
  return query
  select g.id, g.grn_number, g.received_on, g.supplier_invoice,
         g.total_cost_cents - g.corrected_cost_cents,
         coalesce(a.paid, 0)::bigint,
         (g.total_cost_cents - g.corrected_cost_cents - coalesce(a.paid, 0))::bigint
    from public.grns g
    left join lateral (
      select sum(x.amount_cents) as paid
        from public.supplier_payment_allocations x
        join public.supplier_payments p on p.id = x.payment_id
       where x.grn_id = g.id and p.voided_at is null
    ) a on true
   where g.supplier_id = p_supplier_id
     and g.total_cost_cents - g.corrected_cost_cents - coalesce(a.paid, 0) > 0
   order by g.received_on, g.created_at;
end;
$$;

revoke all on function public.admin_supplier_open_grns(uuid) from public, anon, service_role;
grant execute on function public.admin_supplier_open_grns(uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 7. Cost security: money columns leave the staff-readable surface
-- ----------------------------------------------------------------------------
revoke select on public.suppliers, public.grns, public.grn_lines, public.inventory_units,
                 public.purchase_orders, public.purchase_order_lines,
                 public.supplier_returns, public.supplier_return_items
  from authenticated;

grant select (id, supplier_code, name, contact_person, phone, email, address, note, is_active,
              created_by, created_at, updated_at)
  on public.suppliers to authenticated;

grant select (id, grn_number, supplier_name, supplier_id, purchase_order_id, source_type, supplier_invoice,
              received_on, note, total_units, rejected_units, duplicate_invoice_note, created_by, request_id, created_at)
  on public.grns to authenticated;

grant select (id, grn_id, line_no, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
              ordered_quantity, received_quantity, accepted_quantity, rejected_quantity, rejection_reason,
              purchase_order_line_id, corrected_quantity, returned_quantity, tracking_mode_snapshot)
  on public.grn_lines to authenticated;

grant select (id, barcode, serial_number, product_id, variant_id, grn_id, grn_line_id, received_on, fifo_seq,
              status, location_code, order_id, order_item_id, pos_sale_id, supplier_return_id, reentry_of_unit_id,
              status_changed_at, status_note, created_at)
  on public.inventory_units to authenticated;

grant select (id, po_number, supplier_id, order_date, expected_date, status, note, close_note, closed_at,
              created_by, request_id, created_at)
  on public.purchase_orders to authenticated;

grant select (id, purchase_order_id, line_no, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
              quantity, received_quantity, rejected_quantity, returned_quantity)
  on public.purchase_order_lines to authenticated;

grant select (id, return_number, supplier_id, return_date, return_type, total_units, note, created_by,
              request_id, reversed_at, reversed_by, reversal_note, created_at)
  on public.supplier_returns to authenticated;

grant select (id, supplier_return_id, unit_id, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
              barcode_snapshot, serial_snapshot, grn_id, grn_line_id, quantity, from_status, reversed_at)
  on public.supplier_return_items to authenticated;

-- p_kind and what p_ids means:
--   grn, po, supplier_return          -> those documents
--   grn_line, po_line, supplier_return_item -> the documents whose lines to return
--   unit                              -> those units
create or replace function public.admin_purchase_costs(p_kind text, p_ids uuid[])
returns table (
  id        uuid,
  parent_id uuid,
  cents     bigint,
  pending   boolean,
  extra     jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform private.require_admin('view purchase costs');

  if p_kind = 'grn' then
    return query
      select g.id, null::uuid, g.total_cost_cents - g.corrected_cost_cents, g.pending_cost_lines > 0,
             jsonb_build_object('gross_cents', g.total_cost_cents, 'corrected_cents', g.corrected_cost_cents)
        from public.grns g where g.id = any (p_ids);
  elsif p_kind = 'grn_line' then
    return query
      select l.id, l.grn_id, l.unit_cost_cents, l.cost_pending,
             jsonb_build_object('po_unit_cost_cents', l.po_unit_cost_cents, 'cost_note', l.cost_note)
        from public.grn_lines l where l.grn_id = any (p_ids);
  elsif p_kind = 'po' then
    return query
      select po.id, null::uuid, po.total_cents,
             exists (select 1 from public.purchase_order_lines x where x.purchase_order_id = po.id and x.cost_pending),
             null::jsonb
        from public.purchase_orders po where po.id = any (p_ids);
  elsif p_kind = 'po_line' then
    return query
      select l.id, l.purchase_order_id, l.unit_cost_cents, l.cost_pending, null::jsonb
        from public.purchase_order_lines l where l.purchase_order_id = any (p_ids);
  elsif p_kind = 'supplier_return' then
    return query
      select r.id, null::uuid, r.total_cents, false, null::jsonb
        from public.supplier_returns r where r.id = any (p_ids);
  elsif p_kind = 'supplier_return_item' then
    return query
      select i.id, i.supplier_return_id, i.unit_cost_cents, false, null::jsonb
        from public.supplier_return_items i where i.supplier_return_id = any (p_ids);
  elsif p_kind = 'unit' then
    return query
      select u.id, null::uuid, u.unit_cost_cents, u.unit_cost_cents is null, null::jsonb
        from public.inventory_units u where u.id = any (p_ids);
  else
    raise exception 'invalid_kind: %', coalesce(p_kind, '(missing)') using errcode = '22023';
  end if;
end;
$$;

comment on function public.admin_purchase_costs(text, uuid[]) is
  'Admin/owner only. The single way a browser session reads purchase costs: the columns themselves are not granted to authenticated.';

revoke all on function public.admin_purchase_costs(text, uuid[]) from public, anon, service_role;
grant execute on function public.admin_purchase_costs(text, uuid[]) to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Inventory dashboard: one trusted source, quantity and unit items alike
-- ----------------------------------------------------------------------------
drop function if exists public.admin_unit_stock_summary();

-- One row per thing that has its own availability:
--   a product without variants; a shared quantity pool; each variant of a shared
--   unit-tracked product (its number is the sum of these rows); each own-stock variant.
create or replace function public.admin_inventory_dashboard()
returns table (
  product_id           text,
  variant_id           uuid,
  product_name         text,
  variant_name         text,
  category_name        text,
  is_active            boolean,
  tracking_mode        text,
  stock_scope          text,
  on_hand              integer,
  reserved             integer,
  available            integer,
  sold                 integer,
  quarantined          integer,
  returned_to_supplier integer,
  written_off          integer,
  serialised_units     integer,
  oldest_received_on   date,
  stock_status         text
)
language sql
stable
security definer
set search_path = ''
as $$
  with holders as (
    select p.id as pid, null::uuid as vid, p.name as pname, null::text as vname, c.name as cname, p.is_active as act,
           p.tracking_mode as mode, 'product'::text as scope, p.stock as num
      from public.products p
      left join public.categories c on c.id = p.category_id
     where not exists (select 1 from public.product_variants x where x.product_id = p.id)
    union all
    select p.id, null::uuid, p.name, null::text, c.name, p.is_active, p.tracking_mode, 'shared', p.stock
      from public.products p
      left join public.categories c on c.id = p.category_id
     where p.tracking_mode = 'quantity'
       and exists (select 1 from public.product_variants x where x.product_id = p.id and x.stock is null)
    union all
    select p.id, v.id, p.name, v.name, c.name, p.is_active, 'unit', 'shared', null::integer
      from public.product_variants v
      join public.products p on p.id = v.product_id
      left join public.categories c on c.id = p.category_id
     where v.stock is null and p.tracking_mode = 'unit'
    union all
    select p.id, v.id, p.name, v.name, c.name, p.is_active, coalesce(v.tracking_mode, p.tracking_mode), 'own', v.stock
      from public.product_variants v
      join public.products p on p.id = v.product_id
      left join public.categories c on c.id = p.category_id
     where v.stock is not null
  ),
  units as (
    select u.product_id as pid, u.variant_id as vid,
           count(*) filter (where u.status = 'in_stock') as in_stock,
           count(*) filter (where u.status = 'reserved') as reserved,
           count(*) filter (where u.status = 'sold') as sold,
           count(*) filter (where u.status = 'quarantined') as quarantined,
           count(*) filter (where u.status = 'returned_to_supplier') as returned,
           count(*) filter (where u.status = 'written_off') as written_off,
           count(*) filter (where u.serial_number is not null and u.status in ('in_stock', 'reserved', 'quarantined')) as serialised,
           min(u.received_on) filter (where u.status = 'in_stock') as oldest
      from public.inventory_units u
     group by u.product_id, u.variant_id
  ),
  lots as (
    select l.product_id as pid, l.variant_id as vid, sum(l.open_quantity) as qty
      from public.quarantine_lots l group by l.product_id, l.variant_id
  ),
  sales as (
    select m.product_id as pid, m.variant_id as vid, -sum(m.delta) as qty
      from public.inventory_movements m where m.reason = 'sale' group by m.product_id, m.variant_id
  ),
  returned as (
    select i.product_id as pid, i.variant_id as vid, sum(i.quantity) as qty
      from public.supplier_return_items i
     where i.unit_id is null and i.reversed_at is null
     group by i.product_id, i.variant_id
  )
  select h.pid, h.vid, h.pname, h.vname, h.cname, h.act, h.mode, h.scope,
         (case when h.mode = 'unit' then coalesce(u.in_stock, 0) + coalesce(u.reserved, 0) else h.num end)::integer,
         (case when h.mode = 'unit' then coalesce(u.reserved, 0) else private.reserved_quantity(h.pid, h.vid) end)::integer,
         private.available_quantity(h.pid, h.vid),
         (case when h.mode = 'unit' then coalesce(u.sold, 0) else coalesce(s.qty, 0) end)::integer,
         (coalesce(u.quarantined, 0) + coalesce(l.qty, 0))::integer,
         (coalesce(u.returned, 0) + coalesce(r.qty, 0))::integer,
         coalesce(u.written_off, 0)::integer,
         coalesce(u.serialised, 0)::integer,
         u.oldest,
         case when private.available_quantity(h.pid, h.vid) <= 0 then 'out'
              when private.available_quantity(h.pid, h.vid) <= 5 then 'low'
              else 'in' end
    from holders h
    left join units u on u.pid = h.pid and u.vid is not distinct from h.vid
    left join lots l on l.pid = h.pid and l.vid is not distinct from h.vid
    left join sales s on s.pid = h.pid and s.vid is not distinct from h.vid
    left join returned r on r.pid = h.pid and r.vid is not distinct from h.vid
   where private.has_role('staff')
   order by h.pname, h.vname nulls first
$$;

comment on function public.admin_inventory_dashboard() is
  'Staff and above; everyone else gets no rows. Stock figures only, no cost. The one source every stock screen reads.';

revoke all on function public.admin_inventory_dashboard() from public, anon, service_role;
grant execute on function public.admin_inventory_dashboard() to authenticated;


-- ----------------------------------------------------------------------------
-- 9. Self-verification
-- ----------------------------------------------------------------------------
do $$
declare
  c record;
begin
  for c in
    select * from (values
      ('public.suppliers', 'opening_balance_cents'),
      ('public.grns', 'total_cost_cents'),
      ('public.grns', 'corrected_cost_cents'),
      ('public.grn_lines', 'unit_cost_cents'),
      ('public.grn_lines', 'po_unit_cost_cents'),
      ('public.inventory_units', 'unit_cost_cents'),
      ('public.purchase_orders', 'total_cents'),
      ('public.purchase_order_lines', 'unit_cost_cents'),
      ('public.supplier_returns', 'total_cents'),
      ('public.supplier_return_items', 'unit_cost_cents')
    ) as t(tbl, col)
  loop
    if has_column_privilege('authenticated', c.tbl, c.col, 'SELECT') then
      raise exception 'verify: authenticated can still read %.%', c.tbl, c.col;
    end if;
    if not has_column_privilege('service_role', c.tbl, c.col, 'SELECT') then
      raise notice 'note: service_role cannot read %.%', c.tbl, c.col;
    end if;
  end loop;

  if not has_column_privilege('authenticated', 'public.inventory_units', 'barcode', 'SELECT')
     or not has_column_privilege('authenticated', 'public.grns', 'grn_number', 'SELECT') then
    raise exception 'verify: operational columns are no longer readable';
  end if;

  if has_function_privilege('anon', 'public.admin_purchase_costs(text, uuid[])', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_inventory_dashboard()', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_supplier_statement(uuid)', 'EXECUTE')
     or has_table_privilege('authenticated', 'public.supplier_payment_allocations', 'INSERT') then
    raise exception 'verify: function or table grants are wrong';
  end if;

  raise notice 'verified: purchase money columns unreadable by authenticated; admin functions gated';
end
$$;
