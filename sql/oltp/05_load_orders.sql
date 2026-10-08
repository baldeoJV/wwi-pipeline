BEGIN;

CREATE TEMP TABLE tmp_ord ON COMMIT DROP AS
WITH conv AS (
    SELECT
        to_jsonb(r)                              AS row_data,
        etl.try_int(r."OrderID")                 AS order_id,
        etl.try_int(r."CustomerID")              AS customer_id,
        etl.try_int(r."SalespersonPersonID")     AS salesperson_person_id,
        etl.try_int(r."PickedByPersonID")        AS picked_by_person_id,
        etl.try_int(r."ContactPersonID")         AS contact_person_id,
        etl.try_int(r."BackorderOrderID")        AS backorder_order_id,
        etl.try_date(r."OrderDate")              AS order_date,
        etl.try_date(r."ExpectedDeliveryDate")   AS expected_delivery_date,
        etl.clean(r."CustomerPurchaseOrderNumber") AS customer_po_number,
        (r."IsUndersupplyBackordered" = '1')     AS is_undersupply_backordered,
        etl.try_ts(r."PickingCompletedWhen")     AS picking_completed_when,
        etl.clean(r."ExpectedDeliveryDate")      AS expected_raw,
        etl.clean(r."PickedByPersonID")          AS picked_raw,
        etl.clean(r."ContactPersonID")           AS contact_raw
    FROM raw.orders r
), flagged AS (
    SELECT *, row_number() OVER (PARTITION BY order_id ORDER BY customer_id) AS rn
    FROM conv
)
SELECT *,
    CASE
        WHEN order_id IS NULL THEN 'order_id missing or not a number'
        WHEN rn > 1 THEN 'duplicate order_id'
        WHEN customer_id IS NULL THEN 'customer_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.customers c WHERE c.customer_id = flagged.customer_id)
            THEN 'customer_id not found in customers'
        WHEN salesperson_person_id IS NULL THEN 'salesperson missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.people p WHERE p.person_id = flagged.salesperson_person_id)
            THEN 'salesperson not found in people'
        WHEN order_date IS NULL THEN 'order_date missing or invalid'
        WHEN expected_raw IS NOT NULL AND expected_delivery_date IS NULL
            THEN 'expected_delivery_date invalid'
        WHEN picked_raw IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM oltp.people p WHERE p.person_id = flagged.picked_by_person_id)
            THEN 'picked_by_person not found in people'
        WHEN contact_raw IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM oltp.people p WHERE p.person_id = flagged.contact_person_id)
            THEN 'contact_person not found in people'
    END AS reject_reason
FROM flagged;

INSERT INTO etl.rejected_rows (run_id, source_file, target_table, reason, row_data)
SELECT :'run_id', 'Sales.Orders.csv', 'oltp.orders', reject_reason, row_data
FROM tmp_ord WHERE reject_reason IS NOT NULL;

INSERT INTO oltp.orders (order_id, customer_id, salesperson_person_id, picked_by_person_id,
    contact_person_id, backorder_order_id, order_date, expected_delivery_date,
    customer_purchase_order_number, is_undersupply_backordered, picking_completed_when)
SELECT order_id, customer_id, salesperson_person_id, picked_by_person_id,
    contact_person_id, backorder_order_id, order_date, expected_delivery_date,
    customer_po_number, is_undersupply_backordered, picking_completed_when
FROM tmp_ord WHERE reject_reason IS NULL;

INSERT INTO etl.ingestion_log (run_id, source_file, target_table, rows_read, rows_loaded, rows_rejected)
SELECT :'run_id', 'Sales.Orders.csv', 'oltp.orders',
       count(*),
       count(*) FILTER (WHERE reject_reason IS NULL),
       count(*) FILTER (WHERE reject_reason IS NOT NULL)
FROM tmp_ord;

COMMIT;