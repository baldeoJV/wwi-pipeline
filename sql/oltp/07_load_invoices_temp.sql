BEGIN; 


-- INSERT INTO oltp.orders
-- SELECT "OrderID"::int, "CustomerID"::int, "SalespersonPersonID"::int,
--        etl.clean("PickedByPersonID")::int, etl.clean("ContactPersonID")::int,
--        etl.clean("BackorderOrderID")::int,
--        TO_DATE(etl.clean("OrderDate"), 'DD/MM/YYYY'),
--        TO_DATE(etl.clean("ExpectedDeliveryDate"), 'DD/MM/YYYY'),
--        etl.clean("CustomerPurchaseOrderNumber"), ("IsUndersupplyBackordered" = '1'),
--        etl.clean("PickingCompletedWhen")::timestamp
-- FROM raw.orders;



INSERT INTO oltp.invoices
SELECT "InvoiceID"::int, "CustomerID"::int, etl.clean("BillToCustomerID")::int,
       etl.clean("OrderID")::int, etl.clean("DeliveryMethodID")::int,
       etl.clean("ContactPersonID")::int, etl.clean("AccountsPersonID")::int,
       "SalespersonPersonID"::int, etl.clean("PackedByPersonID")::int,
       TO_DATE(etl.clean("InvoiceDate"), 'DD/MM/YYYY'),
       etl.clean("CustomerPurchaseOrderNumber"), etl.clean("DeliveryInstructions"),
       etl.clean("TotalDryItems")::int, etl.clean("TotalChillerItems")::int,
       etl.clean("ConfirmedDeliveryTime")::timestamp, etl.clean("ConfirmedReceivedBy")
FROM raw.invoices;

INSERT INTO oltp.invoice_lines
SELECT "InvoiceLineID"::int, "InvoiceID"::int, "StockItemID"::int, etl.clean("Description"),
       etl.clean("PackageTypeID")::int, "Quantity"::int,
       REPLACE(etl.clean("UnitPrice"), ',', '.')::numeric,
       REPLACE(etl.clean("TaxRate"), ',', '.')::numeric,
       REPLACE(etl.clean("TaxAmount"), ',', '.')::numeric,
       REPLACE(etl.clean("LineProfit"), ',', '.')::numeric,
       REPLACE(etl.clean("ExtendedPrice"), ',', '.')::numeric
FROM raw.invoicelines;


COMMIT; 