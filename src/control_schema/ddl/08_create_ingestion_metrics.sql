CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.ingestion_metrics (
    metric_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    run_id              STRING        NOT NULL    COMMENT 'FK to job_run_audit.run_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to job_run_audit.pipeline_id',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    source_object       STRING        NOT NULL    COMMENT 'Source view name — denormalised for quick lookup without join',
    target_table        STRING        NOT NULL    COMMENT 'Target Delta table name',
    load_type           STRING        NOT NULL    COMMENT 'full_load or hash_incremental',
    write_mode          STRING        NOT NULL    COMMENT 'overwrite or merge',
    rows_read           BIGINT                    COMMENT 'Rows read from source view',
    rows_inserted       BIGINT                    COMMENT 'New rows inserted into target table',
    rows_updated        BIGINT                    COMMENT 'Existing rows updated due to hash mismatch',
    rows_deleted        BIGINT                    COMMENT 'Rows soft-deleted if applicable',
    rows_rejected       BIGINT                    COMMENT 'Rows that failed DQ validation',
    duration_seconds    BIGINT                    COMMENT 'Time taken to process this object in seconds',
    status              STRING        NOT NULL    COMMENT 'Object-level outcome: SUCCESS or FAILED',
    metric_ts           TIMESTAMP     NOT NULL    COMMENT 'Timestamp when metrics were recorded (UTC)',
    environment         STRING        NOT NULL    COMMENT 'Deployment environment: dev, qa, prod'
)
USING DELTA
PARTITIONED BY (environment)
COMMENT 'Row-level observability metrics per source object per run. One row per object per run.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
