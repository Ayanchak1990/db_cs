CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.watermark_control (
    object_id       STRING        NOT NULL COMMENT 'FK to source_object_config.object_id',
    last_run_ts     TIMESTAMP     COMMENT 'Timestamp of last successful ingestion run for this object'
)
USING DELTA
COMMENT 'Tracks last successful run timestamp per ingestion object for batch control';
