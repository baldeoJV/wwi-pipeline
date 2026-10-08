DROP TABLE IF EXISTS oltp.stock_item_stock_groups, oltp.stock_items, oltp.stock_groups,
    oltp.suppliers, oltp.supplier_categories, oltp.package_types, oltp.colors,
    oltp.customers, oltp.customer_categories, oltp.buying_groups,
    oltp.delivery_methods, oltp.people, oltp.cities, oltp.state_provinces,
    oltp.countries, oltp.order_lines, oltp.orders, oltp.invoice_lines, oltp.invoices CASCADE;

CREATE TABLE oltp.countries (
    country_id      INT PRIMARY KEY,
    country_name    TEXT NOT NULL,
    formal_name     TEXT,
    latest_recorded_population BIGINT,
    continent       TEXT,
    region          TEXT,
    subregion       TEXT
);

CREATE TABLE oltp.state_provinces (
    state_province_id   INT PRIMARY KEY,
    state_province_code TEXT,
    state_province_name TEXT NOT NULL,
    country_id          INT NOT NULL REFERENCES oltp.countries(country_id),
    sales_territory     TEXT,
    latest_recorded_population BIGINT
);

CREATE TABLE oltp.cities (
    city_id             INT PRIMARY KEY,
    city_name           TEXT NOT NULL,
    state_province_id   INT NOT NULL REFERENCES oltp.state_provinces(state_province_id),
    latitude            NUMERIC(10,7),
    longitude           NUMERIC(10,7),
    latest_recorded_population BIGINT
);

CREATE TABLE oltp.people (
    person_id       INT PRIMARY KEY,
    full_name       TEXT NOT NULL,
    preferred_name  TEXT,
    search_name     TEXT,
    is_employee     BOOLEAN NOT NULL,
    is_salesperson  BOOLEAN NOT NULL
);

CREATE TABLE oltp.delivery_methods (
    delivery_method_id   INT PRIMARY KEY,
    delivery_method_name TEXT NOT NULL
);

CREATE TABLE oltp.buying_groups (
    buying_group_id   INT PRIMARY KEY,
    buying_group_name TEXT NOT NULL
);

CREATE TABLE oltp.customer_categories (
    customer_category_id   INT PRIMARY KEY,
    customer_category_name TEXT NOT NULL
);

CREATE TABLE oltp.customers (
    customer_id             INT PRIMARY KEY,
    customer_name           TEXT NOT NULL,
    bill_to_customer_id     INT,
    customer_category_id    INT NOT NULL REFERENCES oltp.customer_categories(customer_category_id),
    buying_group_id         INT REFERENCES oltp.buying_groups(buying_group_id),
    primary_contact_person_id   INT REFERENCES oltp.people(person_id),
    alternate_contact_person_id INT REFERENCES oltp.people(person_id),
    delivery_method_id      INT REFERENCES oltp.delivery_methods(delivery_method_id),
    delivery_city_id        INT REFERENCES oltp.cities(city_id),
    credit_limit            NUMERIC(18,2),
    account_opened_date     DATE,
    standard_discount_percentage NUMERIC(18,3),
    is_statement_sent       BOOLEAN,
    is_on_credit_hold       BOOLEAN,
    payment_days            INT,
    phone_number            TEXT,
    website_url             TEXT,
    delivery_address_line   TEXT,
    delivery_location_lat   NUMERIC(10,7),
    delivery_location_long  NUMERIC(10,7)
);

CREATE TABLE oltp.colors (
    color_id    INT PRIMARY KEY,
    color_name  TEXT NOT NULL
);

CREATE TABLE oltp.package_types (
    package_type_id   INT PRIMARY KEY,
    package_type_name TEXT NOT NULL
);

CREATE TABLE oltp.supplier_categories (
    supplier_category_id   INT PRIMARY KEY,
    supplier_category_name TEXT NOT NULL
);

CREATE TABLE oltp.suppliers (
    supplier_id             INT PRIMARY KEY,
    supplier_name           TEXT NOT NULL,
    supplier_category_id    INT REFERENCES oltp.supplier_categories(supplier_category_id),
    primary_contact_person_id   INT REFERENCES oltp.people(person_id),
    alternate_contact_person_id INT REFERENCES oltp.people(person_id),
    delivery_method_id      INT REFERENCES oltp.delivery_methods(delivery_method_id),
    delivery_city_id        INT REFERENCES oltp.cities(city_id),
    postal_city_id          INT REFERENCES oltp.cities(city_id),
    supplier_reference      TEXT,
    payment_days            INT,
    phone_number            TEXT,
    website_url             TEXT,
    delivery_address_line   TEXT,
    delivery_location_lat   NUMERIC(10,7),
    delivery_location_long  NUMERIC(10,7)
);

CREATE TABLE oltp.stock_items (
    stock_item_id           INT PRIMARY KEY,
    stock_item_name         TEXT NOT NULL,
    supplier_id             INT REFERENCES oltp.suppliers(supplier_id),
    color_id                INT REFERENCES oltp.colors(color_id),
    unit_package_id         INT REFERENCES oltp.package_types(package_type_id),
    outer_package_id        INT REFERENCES oltp.package_types(package_type_id),
    brand                   TEXT,
    size                    TEXT,
    lead_time_days          INT,
    quantity_per_outer      INT,
    is_chiller_stock        BOOLEAN,
    barcode                 TEXT,
    tax_rate                NUMERIC(18,3),
    unit_price              NUMERIC(18,2),
    recommended_retail_price NUMERIC(18,2),
    typical_weight_per_unit NUMERIC(18,3)
);

CREATE TABLE oltp.stock_groups (
    stock_group_id   INT PRIMARY KEY,
    stock_group_name TEXT NOT NULL
);

CREATE TABLE oltp.stock_item_stock_groups (
    stock_item_stock_group_id INT PRIMARY KEY,
    stock_item_id   INT NOT NULL REFERENCES oltp.stock_items(stock_item_id),
    stock_group_id  INT NOT NULL REFERENCES oltp.stock_groups(stock_group_id)
);
