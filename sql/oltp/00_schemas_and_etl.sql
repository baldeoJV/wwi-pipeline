-- Schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS oltp;
CREATE SCHEMA IF NOT EXISTS etl;

-- One row per pipeline run (written by the orchestrator)
CREATE TABLE IF NOT EXISTS etl.pipeline_run_log (
    run_id        TEXT PRIMARY KEY,
    batch         INT         NOT NULL,
    status        TEXT        NOT NULL,   -- RUNNING / SUCCESS / FAILED
    started_at    TIMESTAMP   NOT NULL DEFAULT now(),
    finished_at   TIMESTAMP,
    message       TEXT
);

-- One row per file loaded into raw/oltp
CREATE TABLE IF NOT EXISTS etl.ingestion_log (
    log_id          BIGSERIAL PRIMARY KEY,
    run_id          TEXT        NOT NULL,
    source_file     TEXT        NOT NULL,
    target_table    TEXT        NOT NULL,
    rows_read       BIGINT,
    rows_loaded     BIGINT,
    rows_rejected   BIGINT,
    ingested_at     TIMESTAMP   NOT NULL DEFAULT now()
);

-- Rows that failed typed conversion or constraints
CREATE TABLE IF NOT EXISTS etl.rejected_rows (
    reject_id     BIGSERIAL PRIMARY KEY,
    run_id        TEXT        NOT NULL,
    source_file   TEXT        NOT NULL,
    target_table  TEXT        NOT NULL,
    reason        TEXT        NOT NULL,
    row_data      JSONB,
    rejected_at   TIMESTAMP   NOT NULL DEFAULT now()
);

-- Data-quality results, one row per check per run
CREATE TABLE IF NOT EXISTS etl.dq_results (
    dq_id        BIGSERIAL PRIMARY KEY,
    run_id       TEXT        NOT NULL,
    check_name   TEXT        NOT NULL,
    severity     TEXT        NOT NULL,   -- CRITICAL / WARNING
    violations   BIGINT      NOT NULL,
    passed       BOOLEAN     NOT NULL,
    checked_at   TIMESTAMP   NOT NULL DEFAULT now()
);
