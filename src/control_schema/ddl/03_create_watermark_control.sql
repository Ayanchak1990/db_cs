CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.watermark_control (
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to source_object_config.pipeline_id',
    last_run_ts         TIMESTAMP                 COMMENT 'Timestamp of last successful ingestion run (UTC). NULL = never run',
    last_run_id         STRING                    COMMENT 'FK to job_run_audit.run_id — traces which run set this watermark',
    rows_last_loaded    BIGINT                    COMMENT 'Row count from last successful run',
    updated_at          TIMESTAMP     NOT NULL    COMMENT 'Row last updated timestamp (UTC)'
)
USING DELTA
COMMENT 'Tracks last successful extraction point per object per pipeline. Drives incremental load window. NULL last_run_ts = object has never been successfully loaded.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
