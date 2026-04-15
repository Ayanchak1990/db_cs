CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.ingestion_metrics (
    run_id          STRING        NOT NULL COMMENT 'FK to job_run_audit.run_id',
    object_id       STRING        NOT NULL COMMENT 'FK to source_object_config.object_id',
    rows_read       BIGINT        COMMENT 'Rows read from source view',
    rows_inserted   BIGINT        COMMENT 'Net new rows inserted into target table',
    rows_updated    BIGINT        COMMENT 'Existing rows updated due to hash mismatch'
)
USING DELTA
COMMENT 'Row-level observability metrics per object per run';
