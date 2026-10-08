BEGIN;
-- Load oltp tables from raw. Parents before children.

-- 1. Geography
INSERT INTO oltp.countries
SELECT "CountryID"::int, "CountryName", etl.clean("FormalName"),
       etl.clean("LatestRecordedPopulation")::bigint,
       etl.clean("Continent"), etl.clean("Region"), etl.clean("Subregion")
FROM raw.countries;

INSERT INTO oltp.state_provinces
SELECT "StateProvinceID"::int, etl.clean("StateProvinceCode"), "StateProvinceName",
       "CountryID"::int, etl.clean("SalesTerritory"),
       etl.clean("LatestRecordedPopulation")::bigint
FROM raw.stateprovinces;

INSERT INTO oltp.cities
SELECT "CityID"::int, "CityName", "StateProvinceID"::int,
       REPLACE(etl.clean("Latitude"), ',', '.')::numeric,
       REPLACE(etl.clean("Longitude"), ',', '.')::numeric,
       etl.clean("LatestRecordedPopulation")::bigint
FROM raw.cities;

-- 2. People and simple lookups
INSERT INTO oltp.people
SELECT "PersonID"::int, "FullName", etl.clean("PreferredName"), etl.clean("SearchName"),
       ("IsEmployee" = '1'), ("IsSalesperson" = '1')
FROM raw.people;

INSERT INTO oltp.delivery_methods
SELECT "DeliveryMethodID"::int, "DeliveryMethodName" FROM raw.deliverymethods;

INSERT INTO oltp.buying_groups
SELECT "BuyingGroupID"::int, "BuyingGroupName" FROM raw.buyinggroups;

INSERT INTO oltp.customer_categories
SELECT "CustomerCategoryID"::int, "CustomerCategoryName" FROM raw.customercategories;

INSERT INTO oltp.colors
SELECT "ColorID"::int, "ColorName" FROM raw.colors;

INSERT INTO oltp.package_types
SELECT "PackageTypeID"::int, "PackageTypeName" FROM raw.packagetypes;

INSERT INTO oltp.supplier_categories
SELECT "SupplierCategoryID"::int, "SupplierCategoryName" FROM raw.suppliercategories;

INSERT INTO oltp.stock_groups
SELECT "StockGroupID"::int, "StockGroupName" FROM raw.stockgroups;

-- 3. Customers, suppliers, stock items
INSERT INTO oltp.customers
SELECT "CustomerID"::int, "CustomerName", etl.clean("BillToCustomerID")::int,
       "CustomerCategoryID"::int, etl.clean("BuyingGroupID")::int,
       etl.clean("PrimaryContactPersonID")::int, etl.clean("AlternateContactPersonID")::int,
       etl.clean("DeliveryMethodID")::int, etl.clean("DeliveryCityID")::int,
       REPLACE(etl.clean("CreditLimit"), ',', '.')::numeric,
       TO_DATE(etl.clean("AccountOpenedDate"), 'DD/MM/YYYY'),
       REPLACE(etl.clean("StandardDiscountPercentage"), ',', '.')::numeric,
       ("IsStatementSent" = '1'), ("IsOnCreditHold" = '1'),
       etl.clean("PaymentDays")::int, etl.clean("PhoneNumber"), etl.clean("WebsiteURL"),
       etl.clean("DeliveryAddressLine"),
       REPLACE(etl.clean("DeliveryLocationLat"), ',', '.')::numeric,
       REPLACE(etl.clean("DeliveryLocationLong"), ',', '.')::numeric
FROM raw.customers;

INSERT INTO oltp.suppliers
SELECT "SupplierID"::int, "SupplierName", etl.clean("SupplierCategoryID")::int,
       etl.clean("PrimaryContactPersonID")::int, etl.clean("AlternateContactPersonID")::int,
       etl.clean("DeliveryMethodID")::int, etl.clean("DeliveryCityID")::int,
       etl.clean("PostalCityID")::int, etl.clean("SupplierReference"),
       etl.clean("PaymentDays")::int, etl.clean("PhoneNumber"), etl.clean("WebsiteURL"),
       etl.clean("DeliveryAddressLine"),
       REPLACE(etl.clean("DeliveryLocationLat"), ',', '.')::numeric,
       REPLACE(etl.clean("DeliveryLocationLong"), ',', '.')::numeric
FROM raw.suppliers;

INSERT INTO oltp.stock_items
SELECT "StockItemID"::int, "StockItemName", etl.clean("SupplierID")::int,
       etl.clean("ColorID")::int, etl.clean("UnitPackageID")::int,
       etl.clean("OuterPackageID")::int, etl.clean("Brand"), etl.clean("Size"),
       etl.clean("LeadTimeDays")::int, etl.clean("QuantityPerOuter")::int,
       ("IsChillerStock" = '1'), etl.clean("Barcode"),
       REPLACE(etl.clean("TaxRate"), ',', '.')::numeric,
       REPLACE(etl.clean("UnitPrice"), ',', '.')::numeric,
       REPLACE(etl.clean("RecommendedRetailPrice"), ',', '.')::numeric,
       REPLACE(etl.clean("TypicalWeightPerUnit"), ',', '.')::numeric
FROM raw.stockitems;

INSERT INTO oltp.stock_item_stock_groups
SELECT "StockItemStockGroupID"::int, "StockItemID"::int, "StockGroupID"::int
FROM raw.stockitemstockgroups;

-- 4. Orders and invoices
INSERT INTO oltp.orders
SELECT "OrderID"::int, "CustomerID"::int, "SalespersonPersonID"::int,
       etl.clean("PickedByPersonID")::int, etl.clean("ContactPersonID")::int,
       etl.clean("BackorderOrderID")::int,
       TO_DATE(etl.clean("OrderDate"), 'DD/MM/YYYY'),
       TO_DATE(etl.clean("ExpectedDeliveryDate"), 'DD/MM/YYYY'),
       etl.clean("CustomerPurchaseOrderNumber"), ("IsUndersupplyBackordered" = '1'),
       etl.clean("PickingCompletedWhen")::timestamp
FROM raw.orders;



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