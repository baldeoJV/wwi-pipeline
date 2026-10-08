INSERT INTO etl.dq_results (run_id, check_name, severity, violations, passed)
SELECT :'run_id', check_name, severity, violations, violations = 0
FROM (
    SELECT 'orders: raw = loaded + rejected' AS check_name, 'CRITICAL' AS severity,
        abs((SELECT count(*) FROM raw.orders)
          - (SELECT count(*) FROM oltp.orders)
          - (SELECT coalesce(sum(1),0) FROM etl.rejected_rows
              WHERE run_id = :'run_id' AND target_table = 'oltp.orders')) AS violations
    UNION ALL
    SELECT 'order_lines: raw = loaded + rejected', 'CRITICAL',
        abs((SELECT count(*) FROM raw.orderlines)
          - (SELECT count(*) FROM oltp.order_lines)
          - (SELECT coalesce(sum(1),0) FROM etl.rejected_rows
              WHERE run_id = :'run_id' AND target_table = 'oltp.order_lines'))
    UNION ALL
    SELECT 'invoices: raw = loaded + rejected', 'CRITICAL',
        abs((SELECT count(*) FROM raw.invoices)
          - (SELECT count(*) FROM oltp.invoices)
          - (SELECT coalesce(sum(1),0) FROM etl.rejected_rows
              WHERE run_id = :'run_id' AND target_table = 'oltp.invoices'))
    UNION ALL
    SELECT 'invoice_lines: raw = loaded + rejected', 'CRITICAL',
        abs((SELECT count(*) FROM raw.invoicelines)
          - (SELECT count(*) FROM oltp.invoice_lines)
          - (SELECT coalesce(sum(1),0) FROM etl.rejected_rows
              WHERE run_id = :'run_id' AND target_table = 'oltp.invoice_lines'))
    UNION ALL
    SELECT 'invoices dated before order', 'CRITICAL', count(*)
    FROM oltp.invoices i JOIN oltp.orders o ON o.order_id = i.order_id
    WHERE i.invoice_date < o.order_date
    UNION ALL
    SELECT 'order_lines quantity <= 0', 'WARNING', count(*)
    FROM oltp.order_lines WHERE quantity <= 0
    UNION ALL
    SELECT 'invoice_lines quantity <= 0', 'WARNING', count(*)
    FROM oltp.invoice_lines WHERE quantity <= 0
) checks;