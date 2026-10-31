-- ============================================================================
-- Apple Expert · Inventory integration 2/4 · goods receiving
-- ----------------------------------------------------------------------------
-- Replaces admin_post_grn() and the old admin_receive_goods() with one receiving
-- function, because neither has shipped in an APK.
--
--   ordered  : what the PO line still expected (NULL without a PO)
--   received : what physically arrived           = accepted + rejected
--   accepted : what enters stock and what the shop owes for
--   rejected : recorded with a reason, never stocked, never owed
--
-- WHAT A GRN DOES BY TRACKING MODE
--   unit:     one barcoded unit per accepted item, IMEI/serial as the category
--             requires. The number equals the holder's units in the shop.
--   quantity: the number rises. No units, no labels.
--
-- DUPLICATE PROTECTION, in layers
--   * Same request id + same content: returns the first GRN.
--   * Same request id + different content: refused.
--   * Same supplier + same invoice under another request: refused as a POSSIBLE
--     duplicate unless the person confirms with a note (one invoice can honestly
--     cover two part-deliveries). Invoice numbers are compared per supplier only.
--   * An IMEI can be physically in the shop only once (unique index, 1/4).
--
-- AN IMEI OVER TIME
--   An IMEI seen before but no longer in the shop (sold, written off, returned to
--   supplier) can be received again only with a stated reason. The new unit gets
--   a new barcode and points at the old one; history is never edited.
--
-- COSTS
--   A blank cost is no longer zero. A line either states a cost (0 is a real,
--   explicit value) or is marked cost_pending, stays out of what is owed, and is
--   finished later by admin_set_grn_line_cost().
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. GRN columns
-- ----------------------------------------------------------------------------
alter table public.grn_lines rename column quantity to accepted_quantity;
alter table public.grn_lines drop constraint if exists grn_lines_quantity_check;

alter table public.grn_lines
  alter column unit_cost_cents drop not null,
  alter column unit_cost_cents drop default,
  add column ordered_quantity       integer check (ordered_quantity is null or ordered_quantity >= 0),
  add column received_quantity      integer,
  add column rejected_quantity      integer not null default 0 check (rejected_quantity >= 0),
  add column rejection_reason       text check (rejection_reason is null or length(rejection_reason) <= 300),
  add column purchase_order_line_id uuid references public.purchase_order_lines (id) on delete restrict,
  add column po_unit_cost_cents     bigint check (po_unit_cost_cents is null or po_unit_cost_cents >= 0),
  add column cost_pending           boolean not null default false,
  add column cost_note              text check (cost_note is null or length(cost_note) <= 300),
  add column corrected_quantity     integer not null default 0 check (corrected_quantity >= 0),
  add column returned_quantity      integer not null default 0 check (returned_quantity >= 0),
  add column tracking_mode_snapshot text;

update public.grn_lines
   set received_quantity = accepted_quantity,
       tracking_mode_snapshot = 'unit';

alter table public.grn_lines
  alter column received_quantity set not null,
  alter column tracking_mode_snapshot set not null,
  add constraint grn_lines_accepted_range check (accepted_quantity between 0 and 2000),
  add constraint grn_lines_quantities_add_up check (received_quantity = accepted_quantity + rejected_quantity and received_quantity > 0),
  add constraint grn_lines_rejection_has_reason check (rejected_quantity = 0 or rejection_reason is not null),
  add constraint grn_lines_cost_state check (cost_pending = (unit_cost_cents is null)),
  add constraint grn_lines_adjustments_within_accepted check (corrected_quantity + returned_quantity <= accepted_quantity),
  add constraint grn_lines_tracking_mode_snapshot_check check (tracking_mode_snapshot in ('quantity', 'unit'));

create index grn_lines_po_line_idx on public.grn_lines (purchase_order_line_id)
  where purchase_order_line_id is not null;

comment on column public.grn_lines.accepted_quantity is 'What entered stock. The shop owes for this, less corrected_quantity.';
comment on column public.grn_lines.rejected_quantity is 'Arrived but refused: never stocked and never owed.';

alter table public.grns drop constraint if exists grns_total_units_check;

alter table public.grns
  add column source_type          text not null default 'supplier'
    constraint grns_source_type_check check (source_type in ('supplier', 'opening', 'buyback')),
  add column request_fingerprint  text,
  add column rejected_units       integer not null default 0 check (rejected_units >= 0),
  add column corrected_cost_cents bigint not null default 0 check (corrected_cost_cents >= 0),
  add column pending_cost_lines   integer not null default 0 check (pending_cost_lines >= 0),
  add column duplicate_invoice_note text check (duplicate_invoice_note is null or length(duplicate_invoice_note) <= 300),
  add constraint grns_total_units_check check (total_units >= 0);

comment on column public.grns.source_type is
  'supplier: a delivery. opening: counted stock at cutover (no supplier, nothing owed). buyback: a device bought from a person.';

create index grns_supplier_invoice_idx on public.grns (supplier_id, lower(btrim(supplier_invoice)))
  where supplier_invoice is not null;

alter table public.inventory_units
  alter column unit_cost_cents drop not null,
  alter column unit_cost_cents drop default;

alter table public.purchase_order_lines
  alter column unit_cost_cents drop not null,
  alter column unit_cost_cents drop default,
  add column rejected_quantity integer not null default 0 check (rejected_quantity >= 0),
  add column returned_quantity integer not null default 0 check (returned_quantity >= 0),
  add column cost_pending boolean not null default false;

alter table public.purchase_order_lines
  add constraint purchase_order_lines_cost_state check (cost_pending = (unit_cost_cents is null));

comment on column public.purchase_order_lines.received_quantity is 'Accepted so far. Rejected goods do not fill the order.';

create table public.grn_corrections (
  id                  uuid primary key default gen_random_uuid(),
  grn_id              uuid not null references public.grns (id) on delete restrict,
  grn_line_id         uuid not null references public.grn_lines (id) on delete restrict,
  quantity            integer not null check (quantity > 0),
  value_cents         bigint not null default 0 check (value_cents >= 0),
  note                text not null check (length(note) between 3 and 500),
  request_id          uuid not null unique,
  request_fingerprint text not null,
  created_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now()
);

create index grn_corrections_grn_idx on public.grn_corrections (grn_id);

comment on table public.grn_corrections is
  'A GRN is never edited. Goods recorded by mistake are taken back out here, which also corrects the PO and what is owed.';

alter table public.grn_corrections enable row level security;
create policy "grn_corrections admin read" on public.grn_corrections
  for select to authenticated using (private.has_role('admin'));

revoke all on public.grn_corrections from anon;
revoke insert, update, delete, truncate on public.grn_corrections from authenticated, service_role;
grant select on public.grn_corrections to authenticated;


-- ----------------------------------------------------------------------------
-- 2. Helpers
-- ----------------------------------------------------------------------------
-- A barcode, else the unit in the shop with that serial, else its latest record.
create or replace function private.find_unit_by_code(p_code text)
returns public.inventory_units
language sql
stable
security definer
set search_path = ''
as $$
  select u.* from public.inventory_units u
   where u.barcode = p_code or u.serial_number = p_code
   order by (u.barcode = p_code) desc,
            (u.status in ('in_stock', 'reserved', 'quarantined')) desc,
            u.created_at desc
   limit 1
$$;

-- Cancelled and closed POs stay as they are; the rest follow their lines.
create or replace function private.refresh_po_status(p_po_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_open     integer;
  v_received integer;
begin
  select count(*) filter (where l.received_quantity < l.quantity), coalesce(sum(l.received_quantity), 0)
    into v_open, v_received
    from public.purchase_order_lines l where l.purchase_order_id = p_po_id;

  update public.purchase_orders
     set status = case when v_open = 0 then 'received'
                       when v_received > 0 then 'partially_received'
                       else 'open' end
   where id = p_po_id and status not in ('closed', 'cancelled');
end;
$$;

-- Totals are always derived from the lines, never adjusted by increments.
create or replace function private.refresh_grn_totals(p_grn_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.grns g
     set total_units = t.accepted,
         rejected_units = t.rejected,
         total_cost_cents = t.cost,
         corrected_cost_cents = t.corrected,
         pending_cost_lines = t.pending
    from (
      select coalesce(sum(l.accepted_quantity), 0)::integer as accepted,
             coalesce(sum(l.rejected_quantity), 0)::integer as rejected,
             coalesce(sum(l.accepted_quantity * coalesce(l.unit_cost_cents, 0)), 0)::bigint as cost,
             coalesce(sum(l.corrected_quantity * coalesce(l.unit_cost_cents, 0)), 0)::bigint as corrected,
             count(*) filter (where l.cost_pending and l.accepted_quantity > 0)::integer as pending
        from public.grn_lines l where l.grn_id = p_grn_id
    ) t
   where g.id = p_grn_id
$$;

revoke all on function private.find_unit_by_code(text) from public, anon, authenticated, service_role;
revoke all on function private.refresh_po_status(uuid) from public, anon, authenticated, service_role;
revoke all on function private.refresh_grn_totals(uuid) from public, anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 3. Receiving
-- ----------------------------------------------------------------------------
drop function if exists public.admin_post_grn(text, text, date, text, jsonb, uuid);
drop function if exists public.admin_receive_goods(uuid, uuid, text, date, text, jsonb, uuid);

-- p_lines: [{ product_id, variant_id, purchase_order_line_id?,
--             received_quantity, rejected_quantity?, rejection_reason?,
--             unit_cost_cents | null, cost_pending?, cost_note?,
--             serials?: [text], serial_reentry_reason? }]
-- serials cover ACCEPTED items only.
create or replace function public.admin_receive_goods(
  p_source_type               text,
  p_supplier_id               uuid,
  p_source_name               text,
  p_purchase_order_id         uuid,
  p_supplier_invoice          text,
  p_confirm_duplicate_invoice boolean,
  p_duplicate_invoice_note    text,
  p_received_on               date,
  p_note                      text,
  p_lines                     jsonb,
  p_request_id                uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_invoice     text := nullif(btrim(coalesce(p_supplier_invoice, '')), '');
  v_note        text := nullif(btrim(coalesce(p_note, '')), '');
  v_dup_note    text := nullif(btrim(coalesce(p_duplicate_invoice_note, '')), '');
  v_name        text := btrim(coalesce(p_source_name, ''));
  v_today       date := (now() at time zone 'Asia/Colombo')::date;
  v_fingerprint text;
  v_grn         public.grns;
  v_supplier    public.suppliers;
  v_po          public.purchase_orders;
  v_product_ids text[];
  v_line        jsonb;
  v_line_no     integer := 0;
  v_product     public.products;
  v_variant     public.product_variants;
  v_mode        text;
  v_needs_sn    boolean;
  v_received    integer;
  v_rejected    integer;
  v_accepted    integer;
  v_reason      text;
  v_cost        bigint;
  v_pending     boolean;
  v_cost_note   text;
  v_pol         public.purchase_order_lines;
  v_pol_id      uuid;
  v_ordered     integer;
  v_po_cost     bigint;
  v_serials     jsonb;
  v_serial      text;
  v_seen        text[] := '{}';
  v_reentry     text;
  v_prior       public.inventory_units;
  v_line_id     uuid;
  v_total       integer := 0;
  v_holder      record;
  v_stock       integer;
  v_counted     integer;
  i             integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in to receive stock' using errcode = '42501';
  end if;
  if not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object(
    'source', p_source_type, 'supplier', p_supplier_id, 'name', v_name, 'po', p_purchase_order_id,
    'invoice', v_invoice, 'received_on', p_received_on, 'note', v_note, 'lines', p_lines));

  -- Replay before anything else, so a retry can never count anything twice.
  select * into v_grn from public.grns where request_id = p_request_id;
  if found then
    if v_grn.request_fingerprint is distinct from v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different delivery' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_grn.id, 'grn_number', v_grn.grn_number,
                              'total_units', v_grn.total_units, 'rejected_units', v_grn.rejected_units, 'replayed', true);
  end if;

  if p_source_type is null or p_source_type not in ('supplier', 'opening', 'buyback') then
    raise exception 'invalid_source: choose supplier, opening stock or buy-back' using errcode = '22023';
  end if;
  if v_invoice is not null and length(v_invoice) > 60 then
    raise exception 'invalid_invoice: the supplier invoice number is limited to 60 characters' using errcode = '22023';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'invalid_note: the note is limited to 500 characters' using errcode = '22023';
  end if;
  if p_received_on is null or p_received_on > v_today or p_received_on < v_today - 366 then
    raise exception 'invalid_date: the received date must be within the last year and not in the future' using errcode = '22023';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 100 then
    raise exception 'invalid_lines: between 1 and 100 GRN lines are required' using errcode = '22023';
  end if;

  -- Documents first: supplier, then PO. The supplier lock also makes the
  -- duplicate-invoice check below safe against a concurrent post.
  if p_source_type = 'supplier' then
    select * into v_supplier from public.suppliers where id = p_supplier_id for no key update;
    if not found then
      raise exception 'unknown_supplier: choose a supplier' using errcode = 'P0001';
    end if;
    if not v_supplier.is_active then
      raise exception 'supplier_inactive: % is deactivated', v_supplier.name using errcode = 'P0001';
    end if;
    v_name := v_supplier.name;

    if p_purchase_order_id is not null then
      select * into v_po from public.purchase_orders where id = p_purchase_order_id for update;
      if not found then
        raise exception 'unknown_purchase_order: %', p_purchase_order_id using errcode = 'P0001';
      end if;
      if v_po.supplier_id <> v_supplier.id then
        raise exception 'purchase_order_mismatch: % was ordered from a different supplier', v_po.po_number using errcode = 'P0001';
      end if;
      if v_po.status not in ('open', 'partially_received') then
        raise exception 'purchase_order_finished: % is already %', v_po.po_number, replace(v_po.status, '_', ' ')
          using errcode = 'P0001';
      end if;
    end if;

    if v_invoice is not null and exists (
         select 1 from public.grns g
          where g.supplier_id = v_supplier.id and lower(btrim(g.supplier_invoice)) = lower(v_invoice)) then
      if not coalesce(p_confirm_duplicate_invoice, false) or coalesce(length(v_dup_note), 0) < 3 then
        raise exception 'possible_duplicate_delivery: invoice % from % has already been received. If this is another part of the same invoice, confirm it with a note.',
          v_invoice, v_supplier.name using errcode = 'P0001';
      end if;
    end if;
  else
    if p_supplier_id is not null or p_purchase_order_id is not null then
      raise exception 'invalid_source: opening stock and buy-backs have no supplier or purchase order' using errcode = '22023';
    end if;
    if p_source_type = 'opening' then
      v_name := 'Opening stock';
    elsif length(v_name) < 2 then
      raise exception 'invalid_supplier: enter who the device was bought from' using errcode = '22023';
    end if;
  end if;
  if length(v_name) > 120 then
    raise exception 'invalid_supplier: a name of up to 120 characters is required' using errcode = '22023';
  end if;

  -- Parents before children: no line, unit or ledger row exists yet.
  select array_agg(l.value ->> 'product_id') into v_product_ids from jsonb_array_elements(p_lines) as l(value);
  perform private.lock_products(v_product_ids);

  insert into public.grns (grn_number, supplier_name, supplier_id, purchase_order_id, source_type, supplier_invoice,
                           received_on, note, total_units, total_cost_cents, created_by, request_id,
                           request_fingerprint, duplicate_invoice_note)
  values ('GRN-' || to_char(now() at time zone 'Asia/Colombo', 'YYMMDD') || '-'
            || lpad(nextval('private.grn_number_seq')::text, 4, '0'),
          v_name, v_supplier.id, p_purchase_order_id, p_source_type, v_invoice, p_received_on, v_note,
          0, 0, v_uid, p_request_id, v_fingerprint, v_dup_note)
  returning * into v_grn;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_line_no := v_line_no + 1;

    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'invalid_lines: line % must be an object', v_line_no using errcode = '22023';
    end if;

    -- Quantities
    if coalesce(jsonb_typeof(v_line -> 'received_quantity'), '') <> 'number'
       or coalesce(v_line ->> 'received_quantity', '') !~ '^[0-9]{1,4}$'
       or (v_line ->> 'received_quantity')::integer not between 1 and 2000 then
      raise exception 'invalid_quantity: line % received quantity must be a whole number from 1 to 2000', v_line_no
        using errcode = '22023';
    end if;
    v_received := (v_line ->> 'received_quantity')::integer;
    v_rejected := 0;
    if jsonb_typeof(v_line -> 'rejected_quantity') = 'number' then
      if (v_line ->> 'rejected_quantity') !~ '^[0-9]{1,4}$' then
        raise exception 'invalid_quantity: line % rejected quantity must be a whole number', v_line_no using errcode = '22023';
      end if;
      v_rejected := (v_line ->> 'rejected_quantity')::integer;
    end if;
    if v_rejected > v_received then
      raise exception 'invalid_quantity: line % rejects more than was received', v_line_no using errcode = '22023';
    end if;
    v_accepted := v_received - v_rejected;
    v_reason := nullif(btrim(coalesce(v_line ->> 'rejection_reason', '')), '');
    if v_rejected > 0 and (v_reason is null or length(v_reason) < 3) then
      raise exception 'rejection_reason_required: line % needs a reason for the rejected items', v_line_no using errcode = '22023';
    end if;
    if v_reason is not null and length(v_reason) > 300 then
      raise exception 'rejection_reason_required: line % reason is limited to 300 characters', v_line_no using errcode = '22023';
    end if;

    -- Cost: stated, or explicitly pending. Blank is never zero.
    v_cost := null;
    v_pending := coalesce((v_line ->> 'cost_pending')::boolean, false);
    if jsonb_typeof(v_line -> 'unit_cost_cents') = 'number' then
      if (v_line ->> 'unit_cost_cents') !~ '^[0-9]{1,12}$' then
        raise exception 'invalid_cost: line % unit cost must be a whole number of cents', v_line_no using errcode = '22023';
      end if;
      v_cost := (v_line ->> 'unit_cost_cents')::bigint;
      v_pending := false;
    elsif not v_pending then
      raise exception 'cost_required: line % needs a cost, or mark it as cost pending', v_line_no using errcode = '22023';
    end if;
    v_cost_note := nullif(btrim(coalesce(v_line ->> 'cost_note', '')), '');
    if v_cost_note is not null and length(v_cost_note) > 300 then
      raise exception 'invalid_note: line % cost note is limited to 300 characters', v_line_no using errcode = '22023';
    end if;

    -- Product and variant
    select * into v_product from public.products where id = v_line ->> 'product_id';
    if not found then
      raise exception 'unknown_product: %', coalesce(v_line ->> 'product_id', '(missing)') using errcode = 'P0001';
    end if;

    v_variant := null;
    if nullif(v_line ->> 'variant_id', '') is not null then
      begin
        select * into v_variant from public.product_variants
         where id = (v_line ->> 'variant_id')::uuid and product_id = v_product.id;
      exception when invalid_text_representation then
        raise exception 'invalid_variant: line % has a malformed variant id', v_line_no using errcode = '22023';
      end;
      if v_variant.id is null then
        raise exception 'variant_product_mismatch: that variant does not belong to %', v_product.id using errcode = 'P0001';
      end if;
    elsif exists (select 1 from public.product_variants where product_id = v_product.id) then
      raise exception 'variant_required: choose the variant (colour / storage) for %', v_product.name using errcode = 'P0001';
    end if;

    v_mode := private.tracking_mode_of(v_product.id, v_variant.id);
    select c.requires_serial into v_needs_sn from public.categories c where c.id = v_product.category_id;
    v_needs_sn := coalesce(v_needs_sn, false);
    if v_needs_sn and v_mode <> 'unit' and v_accepted > 0 then
      raise exception 'tracking_mode_required: % must be switched to individual tracking before it can be received. Count existing stock first.', v_product.name
        using errcode = 'P0001';
    end if;

    -- Reconcile against the PO: never beyond what is still due.
    v_pol_id := null;
    v_ordered := null;
    v_po_cost := null;
    if p_purchase_order_id is not null then
      v_pol := null;
      if nullif(v_line ->> 'purchase_order_line_id', '') is not null then
        begin
          select * into v_pol from public.purchase_order_lines
           where id = (v_line ->> 'purchase_order_line_id')::uuid
             and purchase_order_id = p_purchase_order_id
             and product_id = v_product.id and variant_id is not distinct from v_variant.id
           for update;
        exception when invalid_text_representation then
          raise exception 'invalid_lines: line % has a malformed purchase order line id', v_line_no using errcode = '22023';
        end;
      else
        select * into v_pol from public.purchase_order_lines
         where purchase_order_id = p_purchase_order_id
           and product_id = v_product.id and variant_id is not distinct from v_variant.id
           and quantity - received_quantity >= v_received
         order by line_no limit 1
         for update;
      end if;

      if v_pol.id is null or v_received > v_pol.quantity - v_pol.received_quantity then
        raise exception 'exceeds_purchase_order: % % is more than is still due on %. Receive the extra on a separate GRN without a PO.',
          v_product.name, coalesce('(' || v_variant.name || ')', ''), v_po.po_number
          using errcode = 'P0001';
      end if;

      v_pol_id := v_pol.id;
      v_ordered := v_pol.quantity - v_pol.received_quantity;
      v_po_cost := v_pol.unit_cost_cents;

      if v_cost is not null and v_po_cost is not null and v_cost <> v_po_cost
         and (v_cost_note is null or length(v_cost_note) < 3) then
        raise exception 'cost_discrepancy_note_required: % costs % on the PO but % here. Add a note explaining the difference.',
          v_product.name, v_po_cost, v_cost using errcode = 'P0001';
      end if;

      update public.purchase_order_lines
         set received_quantity = received_quantity + v_accepted,
             rejected_quantity = rejected_quantity + v_rejected
       where id = v_pol_id;
    end if;

    -- Serials
    v_serials := v_line -> 'serials';
    if v_serials is null or jsonb_typeof(v_serials) = 'null' then
      v_serials := '[]'::jsonb;
    end if;
    if jsonb_typeof(v_serials) <> 'array' then
      raise exception 'invalid_serials: line % serials must be a list', v_line_no using errcode = '22023';
    end if;
    if v_mode = 'quantity' and jsonb_array_length(v_serials) > 0 then
      raise exception 'invalid_serials: % is tracked by quantity, so it takes no serial numbers', v_product.name using errcode = '22023';
    end if;
    if jsonb_array_length(v_serials) not in (0, v_accepted) then
      raise exception 'invalid_serials: line % has % serial numbers for % accepted units', v_line_no, jsonb_array_length(v_serials), v_accepted
        using errcode = '22023';
    end if;
    if v_needs_sn and jsonb_array_length(v_serials) <> v_accepted then
      raise exception 'serial_required: % needs an IMEI / serial number for each of the % accepted units', v_product.name, v_accepted
        using errcode = '22023';
    end if;
    v_reentry := nullif(btrim(coalesce(v_line ->> 'serial_reentry_reason', '')), '');

    insert into public.grn_lines (grn_id, line_no, product_id, variant_id, product_name_snapshot, variant_label_snapshot,
                                  ordered_quantity, received_quantity, accepted_quantity, rejected_quantity,
                                  rejection_reason, purchase_order_line_id, unit_cost_cents, po_unit_cost_cents,
                                  cost_pending, cost_note, tracking_mode_snapshot)
    values (v_grn.id, v_line_no, v_product.id, v_variant.id, v_product.name, v_variant.name,
            v_ordered, v_received, v_accepted, v_rejected, v_reason, v_pol_id, v_cost, v_po_cost,
            v_cost is null, v_cost_note, v_mode)
    returning id into v_line_id;

    if v_mode = 'unit' then
      for i in 1..v_accepted loop
        v_serial := null;
        v_prior := null;
        if jsonb_array_length(v_serials) > 0 then
          if jsonb_typeof(v_serials -> (i - 1)) not in ('string', 'null') then
            raise exception 'invalid_serials: line % serial % must be text', v_line_no, i using errcode = '22023';
          end if;
          v_serial := private.normalize_serial(v_serials ->> (i - 1));
        end if;

        if v_serial is null and v_needs_sn then
          raise exception 'serial_required: % unit % has no IMEI / serial number', v_product.name, i using errcode = '22023';
        end if;

        if v_serial is not null then
          if v_serial !~ '^[A-Z0-9][A-Z0-9-]{3,29}$' then
            raise exception 'invalid_serial: "%" is not a valid IMEI / serial (4 to 30 letters or digits)', v_serial
              using errcode = '22023';
          end if;
          -- Would be unreachable at the counter: a barcode always wins a lookup.
          if v_serial ~ '^AE[0-9]{8,}$' then
            raise exception 'invalid_serial: "%" looks like one of this shop''s own barcodes, not an IMEI / serial', v_serial
              using errcode = '22023';
          end if;
          if v_needs_sn and v_serial ~ '^[0-9]{15}$' and not private.imei_ok(v_serial) then
            raise exception 'invalid_imei: % fails the IMEI check digit - please re-type it', v_serial using errcode = '22023';
          end if;
          if v_serial = any (v_seen) then
            raise exception 'duplicate_serial: % is entered twice in this GRN', v_serial using errcode = '23505';
          end if;

          select * into v_prior from public.inventory_units u
           where u.serial_number = v_serial
           order by (u.status in ('in_stock', 'reserved', 'quarantined')) desc, u.created_at desc
           limit 1;
          if v_prior.id is not null then
            if v_prior.status in ('in_stock', 'reserved', 'quarantined') then
              raise exception 'duplicate_serial: % is already in the shop as unit %', v_serial, v_prior.barcode using errcode = '23505';
            end if;
            if v_reentry is null or length(v_reentry) < 3 then
              raise exception 'serial_previously_recorded: % was unit % (%). If it has legitimately come back, say why it is re-entering stock.',
                v_serial, v_prior.barcode, replace(v_prior.status, '_', ' ') using errcode = 'P0001';
            end if;
          end if;
          v_seen := v_seen || v_serial;
        end if;

        insert into public.inventory_units (barcode, serial_number, product_id, variant_id, grn_id, grn_line_id,
                                            unit_cost_cents, received_on, reentry_of_unit_id, status_note)
        values ('AE' || lpad(nextval('private.inventory_unit_barcode_seq')::text, 8, '0'),
                v_serial, v_product.id, v_variant.id, v_grn.id, v_line_id, v_cost, p_received_on, v_prior.id,
                case when v_prior.id is not null then 'Re-entered: ' || left(v_reentry, 480) end);

        if v_prior.id is not null then
          perform private.audit('inventory_unit', v_prior.id::text, 're_entered',
                                jsonb_build_object('status', v_prior.status, 'barcode', v_prior.barcode),
                                jsonb_build_object('grn_id', v_grn.id), v_reentry);
        end if;
      end loop;
    end if;

    v_total := v_total + v_accepted;
  end loop;

  if v_total > 2000 then
    raise exception 'invalid_lines: a GRN is limited to 2000 units' using errcode = '22023';
  end if;

  -- Stock: one ledger row per stock holder, accepted items only. A unit-tracked
  -- holder's number must already equal its units in the shop (reserved units are
  -- still physically here), or it carries stock no one has a barcode for.
  for v_holder in
    select l.product_id,
           case when v.stock is not null then v.id end as holder_variant,
           min(l.variant_id::text)::uuid as any_variant,
           min(l.tracking_mode_snapshot) as tracking_mode,
           sum(l.accepted_quantity)::integer as qty
      from public.grn_lines l
      left join public.product_variants v on v.id = l.variant_id
     where l.grn_id = v_grn.id and l.accepted_quantity > 0
     group by l.product_id, case when v.stock is not null then v.id end
     order by l.product_id, 2
  loop
    if v_holder.tracking_mode = 'unit' then
      if v_holder.holder_variant is null then
        select p.stock into v_stock from public.products p where p.id = v_holder.product_id;
        select count(*) into v_counted from public.inventory_units u
         where u.product_id = v_holder.product_id and u.status in ('in_stock', 'reserved') and u.grn_id <> v_grn.id
           and (u.variant_id is null
                or exists (select 1 from public.product_variants pv where pv.id = u.variant_id and pv.stock is null));
      else
        select pv.stock into v_stock from public.product_variants pv where pv.id = v_holder.holder_variant;
        select count(*) into v_counted from public.inventory_units u
         where u.variant_id = v_holder.holder_variant and u.status in ('in_stock', 'reserved') and u.grn_id <> v_grn.id;
      end if;

      if v_stock <> v_counted then
        raise exception 'untracked_stock: % has % in stock without barcodes (% tracked). Count it first.',
          v_holder.product_id, v_stock - v_counted, v_counted
          using errcode = 'P0001';
      end if;
    end if;

    perform private.move_stock(v_holder.product_id, coalesce(v_holder.holder_variant, v_holder.any_variant),
                               v_holder.qty,
                               case when p_source_type = 'opening' then 'opening_balance' else 'restock' end,
                               'GRN ' || v_grn.grn_number || ' from ' || v_name,
                               null, v_grn.id, null);
  end loop;

  perform private.refresh_grn_totals(v_grn.id);

  if p_purchase_order_id is not null then
    perform private.refresh_po_status(p_purchase_order_id);
  end if;

  select * into v_grn from public.grns where id = v_grn.id;

  return jsonb_build_object('id', v_grn.id, 'grn_number', v_grn.grn_number, 'total_units', v_grn.total_units,
                            'rejected_units', v_grn.rejected_units, 'replayed', false);
end;
$$;

comment on function public.admin_receive_goods(text, uuid, text, uuid, text, boolean, text, date, text, jsonb, uuid) is
  'Admin/owner. Records received, accepted and rejected goods; accepted items enter stock through the ledger and count off the PO.';

revoke all on function public.admin_receive_goods(text, uuid, text, uuid, text, boolean, text, date, text, jsonb, uuid) from public, anon, service_role;
grant execute on function public.admin_receive_goods(text, uuid, text, uuid, text, boolean, text, date, text, jsonb, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 4. Finishing a pending cost / correcting a stated one
-- ----------------------------------------------------------------------------
create or replace function public.admin_set_grn_line_cost(
  p_grn_line_id     uuid,
  p_unit_cost_cents bigint,
  p_note            text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text := btrim(coalesce(p_note, ''));
  v_grn  public.grns;
  v_line public.grn_lines;
begin
  if (select auth.uid()) is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_unit_cost_cents is null or p_unit_cost_cents < 0 or p_unit_cost_cents > 100000000000 then
    raise exception 'invalid_cost: enter the unit cost' using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 300 then
    raise exception 'invalid_note: a note of 3 to 300 characters is required' using errcode = '22023';
  end if;

  select g.* into v_grn from public.grns g
    join public.grn_lines l on l.grn_id = g.id
   where l.id = p_grn_line_id for update of g;
  if not found then
    raise exception 'unknown_grn_line: %', coalesce(p_grn_line_id::text, '(missing)') using errcode = 'P0001';
  end if;

  select * into v_line from public.grn_lines where id = p_grn_line_id for update;
  if v_line.returned_quantity > 0 then
    -- A credit was already calculated from the old cost.
    raise exception 'cost_locked_by_return: items on this line were returned to the supplier at the stated cost. Reverse that return first.'
      using errcode = 'P0001';
  end if;
  if v_line.unit_cost_cents is not distinct from p_unit_cost_cents then
    return jsonb_build_object('grn_line_id', v_line.id, 'unit_cost_cents', p_unit_cost_cents, 'changed', false);
  end if;

  update public.grn_lines
     set unit_cost_cents = p_unit_cost_cents, cost_pending = false, cost_note = v_note
   where id = v_line.id;
  update public.inventory_units set unit_cost_cents = p_unit_cost_cents where grn_line_id = v_line.id;

  perform private.refresh_grn_totals(v_grn.id);
  perform private.audit('grn_line', v_line.id::text, 'cost',
                        jsonb_build_object('unit_cost_cents', v_line.unit_cost_cents),
                        jsonb_build_object('unit_cost_cents', p_unit_cost_cents), v_note);

  return jsonb_build_object('grn_line_id', v_line.id, 'unit_cost_cents', p_unit_cost_cents, 'changed', true);
end;
$$;

revoke all on function public.admin_set_grn_line_cost(uuid, bigint, text) from public, anon, service_role;
grant execute on function public.admin_set_grn_line_cost(uuid, bigint, text) to authenticated;


-- ----------------------------------------------------------------------------
-- 5. Correcting a GRN: goods recorded by mistake leave stock, the PO and the debt
-- ----------------------------------------------------------------------------
-- p_unit_ids for a unit-tracked line, p_quantity for a quantity-tracked one.
create or replace function public.admin_correct_grn_line(
  p_grn_line_id uuid,
  p_unit_ids    uuid[],
  p_quantity    integer,
  p_note        text,
  p_request_id  uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_note        text := btrim(coalesce(p_note, ''));
  v_fingerprint text;
  v_prior       public.grn_corrections;
  v_line        public.grn_lines;
  v_grn         public.grns;
  v_unit        public.inventory_units;
  v_qty         integer := 0;
begin
  if v_uid is null or not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'invalid_request: a request id is required' using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  v_fingerprint := private.fingerprint(jsonb_build_object('line', p_grn_line_id, 'units', to_jsonb(p_unit_ids),
                                                          'quantity', p_quantity, 'note', v_note));
  select * into v_prior from public.grn_corrections where request_id = p_request_id;
  if found then
    if v_prior.request_fingerprint <> v_fingerprint then
      raise exception 'request_id_reused: this request id was already used for a different correction' using errcode = 'P0001';
    end if;
    return jsonb_build_object('id', v_prior.id, 'quantity', v_prior.quantity, 'replayed', true);
  end if;

  select * into v_line from public.grn_lines where id = p_grn_line_id;
  if not found then
    raise exception 'unknown_grn_line: %', coalesce(p_grn_line_id::text, '(missing)') using errcode = 'P0001';
  end if;
  if v_line.cost_pending then
    raise exception 'cost_pending: state this line''s cost before correcting it' using errcode = 'P0001';
  end if;

  -- Documents, then product, then children.
  select * into v_grn from public.grns where id = v_line.grn_id for update;
  if v_grn.purchase_order_id is not null then
    perform 1 from public.purchase_orders where id = v_grn.purchase_order_id for update;
  end if;
  perform private.lock_products(array[v_line.product_id]);
  select * into v_line from public.grn_lines where id = p_grn_line_id for update;

  if v_line.tracking_mode_snapshot = 'unit' then
    if p_unit_ids is null or cardinality(p_unit_ids) = 0 then
      raise exception 'invalid_items: choose the units received by mistake' using errcode = '22023';
    end if;
    for v_unit in
      select * from public.inventory_units where id = any (p_unit_ids) order by barcode for update
    loop
      if v_unit.grn_line_id <> v_line.id then
        raise exception 'unit_not_on_line: % was not received on this GRN line', v_unit.barcode using errcode = 'P0001';
      end if;
      if v_unit.status <> 'in_stock' then
        raise exception 'unit_not_available: % is % and cannot be corrected', v_unit.barcode, replace(v_unit.status, '_', ' ')
          using errcode = 'P0001';
      end if;
      update public.inventory_units
         set status = 'written_off', status_changed_at = now(),
             status_note = 'GRN correction: ' || left(v_note, 470)
       where id = v_unit.id;
      v_qty := v_qty + 1;
    end loop;
    if v_qty <> cardinality(p_unit_ids) then
      raise exception 'unit_not_found: % of the chosen units do not exist', cardinality(p_unit_ids) - v_qty using errcode = 'P0001';
    end if;
  else
    if p_quantity is null or p_quantity < 1 then
      raise exception 'invalid_quantity: enter how many were received by mistake' using errcode = '22023';
    end if;
    v_qty := p_quantity;
  end if;

  if v_line.corrected_quantity + v_line.returned_quantity + v_qty > v_line.accepted_quantity then
    raise exception 'invalid_quantity: only % can still be corrected on this line',
      v_line.accepted_quantity - v_line.corrected_quantity - v_line.returned_quantity using errcode = '22023';
  end if;

  perform private.move_stock(v_line.product_id, v_line.variant_id, -v_qty, 'correction',
                             'GRN correction ' || v_grn.grn_number || ': ' || left(v_note, 400), null, v_grn.id, null);

  update public.grn_lines set corrected_quantity = corrected_quantity + v_qty where id = v_line.id;

  if v_line.purchase_order_line_id is not null then
    update public.purchase_order_lines
       set received_quantity = received_quantity - v_qty
     where id = v_line.purchase_order_line_id;
    perform private.refresh_po_status(v_grn.purchase_order_id);
  end if;

  perform private.refresh_grn_totals(v_grn.id);

  insert into public.grn_corrections (grn_id, grn_line_id, quantity, value_cents, note, request_id, request_fingerprint, created_by)
  values (v_grn.id, v_line.id, v_qty, v_qty * v_line.unit_cost_cents, v_note, p_request_id, v_fingerprint, v_uid)
  returning * into v_prior;

  return jsonb_build_object('id', v_prior.id, 'quantity', v_qty, 'replayed', false);
end;
$$;

revoke all on function public.admin_correct_grn_line(uuid, uuid[], integer, text, uuid) from public, anon, service_role;
grant execute on function public.admin_correct_grn_line(uuid, uuid[], integer, text, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- 6. Write-off: from the shelf or from quarantine
-- ----------------------------------------------------------------------------
-- A quarantined unit is already out of the number, so only a shelf unit moves it.
create or replace function public.admin_write_off_units(
  p_unit_ids uuid[],
  p_reason   text,
  p_note     text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note     text := btrim(coalesce(p_note, ''));
  v_products text[];
  v_unit     public.inventory_units;
  v_holder   record;
  v_shelf    uuid[] := '{}';
  v_count    integer := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'not_authenticated: sign in to write off stock' using errcode = '42501';
  end if;
  if not private.has_role('admin') then
    raise exception 'insufficient_privilege: admin or owner role required' using errcode = '42501';
  end if;
  if p_unit_ids is null or cardinality(p_unit_ids) = 0 or cardinality(p_unit_ids) > 500 then
    raise exception 'invalid_items: choose between 1 and 500 units' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in ('damage', 'correction') then
    raise exception 'invalid_reason: %', coalesce(p_reason, '(missing)') using errcode = '22023';
  end if;
  if length(v_note) < 3 or length(v_note) > 500 then
    raise exception 'invalid_note: a note of 3 to 500 characters is required' using errcode = '22023';
  end if;

  select array_agg(u.product_id) into v_products from public.inventory_units u where u.id = any (p_unit_ids);
  perform private.lock_products(coalesce(v_products, '{}'::text[]));

  for v_unit in
    select * from public.inventory_units where id = any (p_unit_ids) order by barcode for update
  loop
    if v_unit.status not in ('in_stock', 'quarantined') then
      raise exception 'unit_not_available: % is % and cannot be written off', v_unit.barcode, replace(v_unit.status, '_', ' ')
        using errcode = 'P0001';
    end if;
    if v_unit.status = 'in_stock' then
      v_shelf := v_shelf || v_unit.id;
    end if;
    update public.inventory_units
       set status = 'written_off', location_code = 'MAIN_SHOP', status_changed_at = now(), status_note = v_note
     where id = v_unit.id;
    v_count := v_count + 1;
  end loop;

  if v_count <> cardinality(p_unit_ids) then
    raise exception 'unit_not_found: % of the chosen units do not exist', cardinality(p_unit_ids) - v_count
      using errcode = 'P0001';
  end if;

  for v_holder in
    select u.product_id, u.variant_id, count(*)::integer as qty
      from public.inventory_units u
     where u.id = any (v_shelf)
     group by u.product_id, u.variant_id
     order by u.product_id, u.variant_id
  loop
    perform private.move_stock(v_holder.product_id, v_holder.variant_id, -v_holder.qty, p_reason,
                               'Write-off: ' || v_note, null, null, null);
  end loop;

  return jsonb_build_object('written_off', v_count);
end;
$$;


-- ----------------------------------------------------------------------------
-- 7. Self-verification
-- ----------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.admin_post_grn(text, text, date, text, jsonb, uuid)') is not null then
    raise exception 'verify: admin_post_grn should be gone';
  end if;
  if has_function_privilege('anon', 'public.admin_receive_goods(text, uuid, text, uuid, text, boolean, text, date, text, jsonb, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.find_unit_by_code(text)', 'EXECUTE') then
    raise exception 'verify: function grants are wrong';
  end if;
  if has_table_privilege('authenticated', 'public.grn_corrections', 'INSERT') then
    raise exception 'verify: grn_corrections can be written directly';
  end if;
  raise notice 'verified: receiving goes through admin_receive_goods only';
end
$$;
