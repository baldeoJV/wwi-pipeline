BEGIN;

-- Check every raw row once; keep the verdict in a temp table
CREATE TEMP TABLE tmp_ol ON COMMIT DROP AS
WITH conv AS (
    SELECT
        to_jsonb(r)                           AS row_data,
        etl.try_int(r."OrderLineID")          AS order_line_id,
        etl.try_int(r."OrderID")              AS order_id,
        etl.try_int(r."StockItemID")          AS stock_item_id,
        etl.clean(r."Description")            AS description,
        etl.try_int(r."PackageTypeID")        AS package_type_id,
        etl.try_int(r."Quantity")             AS quantity,
        etl.try_num(r."UnitPrice")            AS unit_price,
        etl.try_num(r."TaxRate")              AS tax_rate,
        etl.try_int(r."PickedQuantity")       AS picked_quantity,
        etl.clean(r."PickingCompletedWhen")::timestamp AS picking_completed_when
    FROM raw.orderlines r
), flagged AS (
    SELECT *, row_number() OVER (PARTITION BY order_line_id ORDER BY order_id) AS rn
    FROM conv
)
SELECT *,
    CASE
        WHEN order_line_id IS NULL THEN 'order_line_id missing or not a number'
        WHEN rn > 1 THEN 'duplicate order_line_id'
        WHEN order_id IS NULL THEN 'order_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.orders o WHERE o.order_id = flagged.order_id)
            THEN 'order_id not found in orders'
        WHEN stock_item_id IS NULL THEN 'stock_item_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.stock_items s WHERE s.stock_item_id = flagged.stock_item_id)
            THEN 'stock_item_id not found in stock_items'
        WHEN quantity IS NULL OR quantity <= 0 THEN 'quantity missing or not positive'
        WHEN package_type_id IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM oltp.package_types p WHERE p.package_type_id = flagged.package_type_id)
            THEN 'package_type_id not found in package_types'
    END AS reject_reason
FROM flagged;

-- Bad rows: set aside with the reason and the full original row
INSERT INTO etl.rejected_rows (run_id, source_file, target_table, reason, row_data)
SELECT :'run_id', 'Sales.OrderLines.csv', 'oltp.order_lines', reject_reason, row_data
FROM tmp_ol WHERE reject_reason IS NOT NULL;

-- Good rows: load into the typed table
INSERT INTO oltp.order_lines (order_line_id, order_id, stock_item_id, description,
    package_type_id, quantity, unit_price, tax_rate, picked_quantity, picking_completed_when)
SELECT order_line_id, order_id, stock_item_id, description,
    package_type_id, quantity, unit_price, tax_rate, picked_quantity, picking_completed_when
FROM tmp_ol WHERE reject_reason IS NULL;

-- One log line for this load
INSERT INTO etl.ingestion_log (run_id, source_file, target_table, rows_read, rows_loaded, rows_rejected)
SELECT :'run_id', 'Sales.OrderLines.csv', 'oltp.order_lines',
       count(*),
       count(*) FILTER (WHERE reject_reason IS NULL),
       count(*) FILTER (WHERE reject_reason IS NOT NULL)
FROM tmp_ol;

COMMIT;