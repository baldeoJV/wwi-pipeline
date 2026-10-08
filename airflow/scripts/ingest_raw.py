import csv
import io
import os
import sys
import uuid
from pathlib import Path

import psycopg2

DATA_ROOT = Path(os.environ.get("DATA_ROOT", "/opt/airflow/data"))

# (folder, table) in load order
FILES = [
    ("Application", "Countries"), ("Application", "StateProvinces"), ("Application", "Cities"),
    ("Application", "People"), ("Application", "DeliveryMethods"),
    ("Sales", "BuyingGroups"), ("Sales", "CustomerCategories"), ("Sales", "Customers"),
    ("Warehouse", "Colors"), ("Warehouse", "PackageTypes"),
    ("Purchasing", "SupplierCategories"), ("Purchasing", "Suppliers"),
    ("Warehouse", "StockItems"), ("Warehouse", "StockGroups"), ("Warehouse", "StockItemStockGroups"),
    ("Sales", "Orders"), ("Sales", "OrderLines"), ("Sales", "Invoices"), ("Sales", "InvoiceLines"),
]


def connect():
    return psycopg2.connect(
        host=os.environ.get("POSTGRES_HOST", "postgres"),
        dbname="wwi",
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )


def load_file(cur, run_id, batch_dir, folder, table):
    path = DATA_ROOT / batch_dir / folder / f"{folder}.{table}.csv"
    if not path.exists():
        raise FileNotFoundError(path)

    raw_table = f"raw.{table.lower()}"
    with open(path, encoding="utf-8-sig", newline="") as f:
        header = next(csv.reader(f, delimiter=";"))
        cols = [h.strip() for h in header]

        col_defs = ", ".join(f'"{c}" TEXT' for c in cols)
        cur.execute(f"DROP TABLE IF EXISTS {raw_table}")
        cur.execute(
            f"CREATE TABLE {raw_table} ({col_defs}, "
            f"_run_id TEXT, _source_file TEXT, _ingested_at TIMESTAMP DEFAULT now())"
        )

        col_list = ", ".join(f'"{c}"' for c in cols)
        # NULL '' keeps the literal text NULL as text in raw
        cur.copy_expert(
            f"COPY {raw_table} ({col_list}) FROM STDIN "
            f"WITH (FORMAT csv, DELIMITER ';', NULL '__never__', QUOTE '\"')",
            f,
        )

    cur.execute(
        f"UPDATE {raw_table} SET _run_id=%s, _source_file=%s", (run_id, str(path.name))
    )
    cur.execute(f"SELECT count(*) FROM {raw_table}")
    n = cur.fetchone()[0]

    with open(path, encoding="utf-8-sig", newline="") as f:
        rows_read = sum(1 for _ in csv.reader(f, delimiter=";")) - 1

    cur.execute(
        "INSERT INTO etl.ingestion_log (run_id, source_file, target_table, rows_read, rows_loaded, rows_rejected) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (run_id, path.name, raw_table, rows_read, n, rows_read - n),
    )
    return rows_read, n


def main(batch=1, run_id=None):
    run_id = run_id or f"manual_{uuid.uuid4().hex[:8]}"
    batch_dir = "raw" if int(batch) == 1 else "batch2"
    conn = connect()
    try:
        with conn.cursor() as cur:
            for folder, table in FILES:
                read, loaded = load_file(cur, run_id, batch_dir, folder, table)
                print(f"{folder}.{table}: read={read} loaded={loaded}")
                if read != loaded:
                    raise RuntimeError(f"Row count mismatch for {table}")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    print(f"raw load complete, run_id={run_id}")


if __name__ == "__main__":
    main(batch=sys.argv[1] if len(sys.argv) > 1 else 1)
