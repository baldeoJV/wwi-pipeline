BEGIN;

CREATE TEMP TABLE tmp_inv ON COMMIT DROP AS
WITH conv AS (
    SELECT
        to_jsonb(r)                              AS row_data,
        etl.try_int(r."InvoiceID")               AS invoice_id,
        etl.try_int(r."CustomerID")              AS customer_id,
        etl.try_int(r."BillToCustomerID")        AS bill_to_customer_id,
        etl.try_int(r."OrderID")                 AS order_id,
        etl.try_int(r."DeliveryMethodID")        AS delivery_method_id,
        etl.try_int(r."ContactPersonID")         AS contact_person_id,
        etl.try_int(r."AccountsPersonID")        AS accounts_person_id,
        etl.try_int(r."SalespersonPersonID")     AS salesperson_person_id,
        etl.try_int(r."PackedByPersonID")        AS packed_by_person_id,
        etl.try_date(r."InvoiceDate")            AS invoice_date,
        etl.clean(r."CustomerPurchaseOrderNumber") AS customer_po_number,
        etl.clean(r."DeliveryInstructions")      AS delivery_instructions,
        etl.try_int(r."TotalDryItems")           AS total_dry_items,
        etl.try_int(r."TotalChillerItems")       AS total_chiller_items,
        etl.try_ts(r."ConfirmedDeliveryTime")    AS confirmed_delivery_time,
        etl.clean(r."ConfirmedReceivedBy")       AS confirmed_received_by,
        etl.clean(r."OrderID")                   AS order_raw
    FROM raw.invoices r
), flagged AS (
    SELECT c.*, o.order_date,
           row_number() OVER (PARTITION BY c.invoice_id ORDER BY c.customer_id) AS rn
    FROM conv c
    LEFT JOIN oltp.orders o ON o.order_id = c.order_id
)
SELECT *,
    CASE
        WHEN invoice_id IS NULL THEN 'invoice_id missing or not a number'
        WHEN rn > 1 THEN 'duplicate invoice_id'
        WHEN customer_id IS NULL THEN 'customer_id missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.customers x WHERE x.customer_id = flagged.customer_id)
            THEN 'customer_id not found in customers'
        WHEN salesperson_person_id IS NULL THEN 'salesperson missing or not a number'
        WHEN NOT EXISTS (SELECT 1 FROM oltp.people p WHERE p.person_id = flagged.salesperson_person_id)
            THEN 'salesperson not found in people'
        WHEN invoice_date IS NULL THEN 'invoice_date missing or invalid'
        WHEN order_raw IS NOT NULL AND order_date IS NULL
            THEN 'order_id not found in orders'
        WHEN order_date IS NOT NULL AND invoice_date < order_date
            THEN 'invoice_date before order_date'
    END AS reject_reason
FROM flagged;

INSERT INTO etl.rejected_rows (run_id, source_file, target_table, reason, row_data)
SELECT :'run_id', 'Sales.Invoices.csv', 'oltp.invoices', reject_reason, row_data
FROM tmp_inv WHERE reject_reason IS NOT NULL;

INSERT INTO oltp.invoices (invoice_id, customer_id, bill_to_customer_id, order_id,
    delivery_method_id, contact_person_id, accounts_person_id, salesperson_person_id,
    packed_by_person_id, invoice_date, customer_purchase_order_number, delivery_instructions,
    total_dry_items, total_chiller_items, confirmed_delivery_time, confirmed_received_by)
SELECT invoice_id, customer_id, bill_to_customer_id, order_id,
    delivery_method_id, contact_person_id, accounts_person_id, salesperson_person_id,
    packed_by_person_id, invoice_date, customer_po_number, delivery_instructions,
    total_dry_items, total_chiller_items, confirmed_delivery_time, confirmed_received_by
FROM tmp_inv WHERE reject_reason IS NULL;

INSERT INTO etl.ingestion_log (run_id, source_file, target_table, rows_read, rows_loaded, rows_rejected)
SELECT :'run_id', 'Sales.Invoices.csv', 'oltp.invoices',
       count(*),
       count(*) FILTER (WHERE reject_reason IS NULL),
       count(*) FILTER (WHERE reject_reason IS NOT NULL)
FROM tmp_inv;

COMMIT;