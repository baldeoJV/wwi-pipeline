BEGIN;

CREATE TEMP TABLE tmp_il ON COMMIT DROP AS
WITH conv AS (
    SELECT
        to_jsonb(r)                           AS row_data,
        etl.try_int(r."InvoiceLineID")        AS invoice_line_id,
        etl.try_int(r."InvoiceID")            AS invoice_id,
        etl.try_int(r."StockItemID")          AS stock_item_id,
        etl.clean(r."Description")            AS description,
        etl.try_int(r."PackageTypeID")        AS package_type_id,
        etl.try_int(r."Quantity")             AS quantity,
        etl.try_num(r."UnitPrice")            AS unit_price,
        etl.try_num(r."TaxRate")              AS tax_rate,
        etl.try_num(r."TaxAmount")            AS tax_amount,
        etl.try_num(r."LineProfit")           AS line_profit,
        etl.try_num(r."ExtendedPrice")        AS extended_price
    FROM raw.invoicelines r
), flagged AS (
    SELECT *, row_number() OVER (PARTITION BY invoice_line_id ORDER BY invoice_id) AS rn
    FROM conv
)
SELECT *,
    CASE
        WHEN invoice_line_id IS NULL THEN 'invoice_line_id missing or not a number'
        WHEN rn > 1 THEN 'duplicate invoice_line_id'
        WHEN invoice_id IS NULL THEN 'invoice_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.invoices i WHERE i.invoice_id = flagged.invoice_id)
            THEN 'invoice_id not found in invoices'
        WHEN stock_item_id IS NULL THEN 'stock_item_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.stock_items s WHERE s.stock_item_id = flagged.stock_item_id)
            THEN 'stock_item_id not found in stock_items'
        WHEN quantity IS NULL OR quantity <= 0 THEN 'quantity missing or not positive'
        WHEN unit_price IS NULL OR unit_price < 0 THEN 'unit_price missing or negative'
        WHEN tax_amount IS NULL OR tax_amount < 0 THEN 'tax_amount missing or negative'
        WHEN package_type_id IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM oltp.package_types p WHERE p.package_type_id = flagged.package_type_id)
            THEN 'package_type_id not found in package_types'
    END AS reject_reason
FROM flagged;

INSERT INTO etl.rejected_rows (run_id, source_file, target_table, reason, row_data)
SELECT :'run_id', 'Sales.InvoiceLines.csv', 'oltp.invoice_lines', reject_reason, row_data
FROM tmp_il WHERE reject_reason IS NOT NULL;

INSERT INTO oltp.invoice_lines (invoice_line_id, invoice_id, stock_item_id, description,
    package_type_id, quantity, unit_price, tax_rate, tax_amount, line_profit, extended_price)
SELECT invoice_line_id, invoice_id, stock_item_id, description,
    package_type_id, quantity, unit_price, tax_rate, tax_amount, line_profit, extended_price
FROM tmp_il WHERE reject_reason IS NULL;

INSERT INTO etl.ingestion_log (run_id, source_file, target_table, rows_read, rows_loaded, rows_rejected)
SELECT :'run_id', 'Sales.InvoiceLines.csv', 'oltp.invoice_lines',
       count(*),
       count(*) FILTER (WHERE reject_reason IS NULL),
       count(*) FILTER (WHERE reject_reason IS NOT NULL)
FROM tmp_il;

COMMIT;