-- ============================================================================
-- Removes everything the inventory suites could leave behind: gt-, pt-, mt- and
-- cc- fixtures, their test accounts, and anything those accounts created. Those
-- suites commit fixtures, and their own end-of-run cleanup does not run when a
-- check fails, which would leave active test products in the local shop.
--
-- LOCAL ONLY. Run as postgres; safe to run repeatedly. It only touches fixture
-- ids and the suites' fixed test account ids. Sequence values are not rewound.
-- ============================================================================
\set ON_ERROR_STOP on
begin;

create temp table fx_users on commit drop as
select id from auth.users where id in (
  '91111111-1111-1111-1111-111111111111', '92222222-2222-2222-2222-222222222222', '93333333-3333-3333-3333-333333333333',
  '81111111-1111-1111-1111-111111111111', '82222222-2222-2222-2222-222222222222', '83333333-3333-3333-3333-333333333333',
  '71111111-1111-1111-1111-111111111111', '72222222-2222-2222-2222-222222222222', '73333333-3333-3333-3333-333333333333',
  '61111111-1111-1111-1111-111111111111', '62222222-2222-2222-2222-222222222222', '63333333-3333-3333-3333-333333333333');

create temp table fx_products on commit drop as
select id from public.products where id ~ '^(gt|pt|mt|cc|db)-';

delete from public.inventory_audit_log
 where entity_type = 'product_barcode'
   and entity_id in (select b.id::text from public.product_barcodes b where b.product_id in (select id from fx_products));

delete from public.barcode_registry
 where unit_id in (select u.id from public.inventory_units u where u.product_id in (select id from fx_products))
    or product_barcode_id in (select b.id from public.product_barcodes b where b.product_id in (select id from fx_products));
delete from public.product_barcodes where product_id in (select id from fx_products);

delete from public.inventory_audit_log
 where actor_id in (select id from fx_users)
    or entity_id in (select u.id::text from public.inventory_units u where u.product_id in (select id from fx_products));

delete from public.customer_refunds where created_by in (select id from fx_users);
delete from public.customer_return_items where product_id in (select id from fx_products);
delete from public.quarantine_lots where product_id in (select id from fx_products);
delete from public.customer_returns where created_by in (select id from fx_users);

update public.pos_sales set discount_approval_id = null where cashier_id in (select id from fx_users);
delete from public.pos_discount_approvals where requested_by in (select id from fx_users);

delete from public.supplier_payment_allocations
 where payment_id in (select p.id from public.supplier_payments p where p.created_by in (select id from fx_users));
delete from public.supplier_payments where created_by in (select id from fx_users);
delete from public.supplier_return_items where product_id in (select id from fx_products);
update public.inventory_units set supplier_return_id = null where product_id in (select id from fx_products);
delete from public.supplier_returns where created_by in (select id from fx_users);

delete from public.inventory_movements where product_id in (select id from fx_products);
delete from public.stock_reservations where product_id in (select id from fx_products);
delete from public.stock_reconciliation_flags where product_id in (select id from fx_products);
delete from public.order_events where order_id in (select o.id from public.orders o where o.profile_id in (select id from fx_users));
delete from public.pos_sale_items where product_id in (select id from fx_products);
update public.inventory_units set reentry_of_unit_id = null where product_id in (select id from fx_products);
delete from public.inventory_units where product_id in (select id from fx_products);
delete from public.orders where profile_id in (select id from fx_users);
delete from public.pos_sales where cashier_id in (select id from fx_users);
delete from public.grn_corrections where created_by in (select id from fx_users);
delete from public.grn_lines where product_id in (select id from fx_products);
delete from public.grns where created_by in (select id from fx_users);
delete from public.purchase_order_lines where product_id in (select id from fx_products);
delete from public.purchase_orders where created_by in (select id from fx_users);
delete from public.suppliers where created_by in (select id from fx_users);

update public.product_variants set stock = 0 where product_id in (select id from fx_products) and stock is not null;
update public.products set stock = 0 where id in (select id from fx_products);
delete from public.product_prices where product_id in (select id from fx_products);
delete from public.product_variants where product_id in (select id from fx_products);
delete from public.products where id in (select id from fx_products);
delete from public.categories where slug = 'gt-phones';
delete from auth.users where id in (select id from fx_users);

commit;
