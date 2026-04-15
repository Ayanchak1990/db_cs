CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.job_run_error (
    run_id          STRING        NOT NULL COMMENT 'FK to job_run_audit.run_id',
    object_id       STRING        NOT NULL COMMENT 'FK to source_object_config.object_id',
    error_message   STRING        COMMENT 'Full error message or stack trace',
    error_ts        TIMESTAMP     NOT NULL COMMENT 'Timestamp when the error was captured'
)
USING DELTA
COMMENT 'Captures failure details per object per run';
