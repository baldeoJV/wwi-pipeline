#!/bin/bash
# Usage: sql/run_oltp.sh <run_id>
set -euo pipefail
RUN_ID="${1:-manual}"
for f in sql/oltp/01_*.sql sql/oltp/02_*.sql sql/oltp/03_*.sql sql/oltp/04_*.sql \
         sql/oltp/05_*.sql sql/oltp/06_*.sql sql/oltp/07_*.sql sql/oltp/08_*.sql ; do
  echo "== $f"
  docker compose exec -T postgres psql -U vernon -d wwi -v ON_ERROR_STOP=1 \
      -v run_id="$RUN_ID" < "$f" 2>&1 | grep -v NOTICE
done