CREATE TABLE oltp.orders (
    order_id                    INT PRIMARY KEY,
    customer_id                 INT NOT NULL REFERENCES oltp.customers(customer_id),
    salesperson_person_id       INT NOT NULL REFERENCES oltp.people(person_id),
    picked_by_person_id         INT REFERENCES oltp.people(person_id),
    contact_person_id           INT REFERENCES oltp.people(person_id),
    backorder_order_id          INT,   -- no FK: may point to an order loaded later
    order_date                  DATE NOT NULL,
    expected_delivery_date      DATE,
    customer_purchase_order_number TEXT,
    is_undersupply_backordered  BOOLEAN,
    picking_completed_when      TIMESTAMP
);

CREATE TABLE oltp.order_lines (
    order_line_id       INT PRIMARY KEY,
    order_id            INT NOT NULL REFERENCES oltp.orders(order_id),
    stock_item_id       INT NOT NULL REFERENCES oltp.stock_items(stock_item_id),
    description         TEXT,
    package_type_id     INT REFERENCES oltp.package_types(package_type_id),
    quantity            INT NOT NULL,
    unit_price          NUMERIC(18,2),
    tax_rate            NUMERIC(18,3),
    picked_quantity     INT,
    picking_completed_when TIMESTAMP
);

CREATE TABLE oltp.invoices (
    invoice_id              INT PRIMARY KEY,
    customer_id             INT NOT NULL REFERENCES oltp.customers(customer_id),
    bill_to_customer_id     INT REFERENCES oltp.customers(customer_id),
    order_id                INT REFERENCES oltp.orders(order_id),
    delivery_method_id      INT REFERENCES oltp.delivery_methods(delivery_method_id),
    contact_person_id       INT REFERENCES oltp.people(person_id),
    accounts_person_id      INT REFERENCES oltp.people(person_id),
    salesperson_person_id   INT NOT NULL REFERENCES oltp.people(person_id),
    packed_by_person_id     INT REFERENCES oltp.people(person_id),
    invoice_date            DATE NOT NULL,
    customer_purchase_order_number TEXT,
    delivery_instructions   TEXT,
    total_dry_items         INT,
    total_chiller_items     INT,
    confirmed_delivery_time TIMESTAMP,
    confirmed_received_by   TEXT
);

CREATE TABLE oltp.invoice_lines (
    invoice_line_id INT PRIMARY KEY,
    invoice_id      INT NOT NULL REFERENCES oltp.invoices(invoice_id),
    stock_item_id   INT NOT NULL REFERENCES oltp.stock_items(stock_item_id),
    description     TEXT,
    package_type_id INT REFERENCES oltp.package_types(package_type_id),
    quantity        INT NOT NULL,
    unit_price      NUMERIC(18,2),
    tax_rate        NUMERIC(18,3),
    tax_amount      NUMERIC(18,2),
    line_profit     NUMERIC(18,2),
    extended_price  NUMERIC(18,2)
);
