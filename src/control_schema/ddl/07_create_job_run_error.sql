CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.job_run_error (
    error_id            STRING        NOT NULL    COMMENT 'UUID — primary key',
    run_id              STRING        NOT NULL    COMMENT 'FK to job_run_audit.run_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to job_run_audit.pipeline_id',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    source_object       STRING        NOT NULL    COMMENT 'Source view name — denormalised for quick lookup without join',
    error_type          STRING        NOT NULL    COMMENT 'Error category: JDBC_ERROR, SCHEMA_MISMATCH, MERGE_ERROR, VALIDATION_ERROR, DQ_ERROR, UNKNOWN',
    error_message       STRING                    COMMENT 'Full error message text',
    stack_trace         STRING                    COMMENT 'Full stack trace',
    retry_attempt       INT           NOT NULL    COMMENT 'Which retry attempt this error occurred on (1, 2, 3)',
    error_ts            TIMESTAMP     NOT NULL    COMMENT 'Timestamp when error was captured (UTC)',
    environment         STRING        NOT NULL    COMMENT 'Deployment environment: dev, qa, prod'
)
USING DELTA
PARTITIONED BY (environment)
COMMENT 'Granular error capture per source object per run. Multiple rows per run if multiple objects fail.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
