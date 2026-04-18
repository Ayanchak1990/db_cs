CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.schema_drift_log (
    drift_id            STRING        NOT NULL    COMMENT 'UUID — primary key',
    run_id              STRING        NOT NULL    COMMENT 'FK to job_run_audit.run_id',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to source_object_config.pipeline_id',
    source_object       STRING        NOT NULL    COMMENT 'Source view name — denormalised for quick lookup without join',
    column_name         STRING        NOT NULL    COMMENT 'Column where drift was detected',
    drift_type          STRING        NOT NULL    COMMENT 'Drift category: NEW_COLUMN, DROPPED_COLUMN, TYPE_CHANGE, NULLABLE_CHANGE',
    old_value           STRING                    COMMENT 'Previous schema definition. NULL for NEW_COLUMN',
    new_value           STRING                    COMMENT 'New schema definition. NULL for DROPPED_COLUMN',
    action_taken        STRING        NOT NULL    COMMENT 'Response taken by the pipeline: EVOLVED, HALTED, WARNED, IGNORED',
    detected_at         TIMESTAMP     NOT NULL    COMMENT 'Timestamp when drift was detected (UTC)',
    environment         STRING        NOT NULL    COMMENT 'Deployment environment: dev, qa, prod'
)
USING DELTA
COMMENT 'Audit log of every schema change detected on any source object during pipeline runs.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
