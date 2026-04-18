CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.pipeline_config (
    config_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    pipeline_id         STRING        NOT NULL    COMMENT 'Owning pipeline e.g. raw_employee_pipeline',
    config_key          STRING        NOT NULL    COMMENT 'Config parameter name e.g. max_retry, batch_size, schema_drift_action',
    config_value        STRING        NOT NULL    COMMENT 'Config value as string. Pipeline is responsible for casting to the correct type.',
    description         STRING                    COMMENT 'Human-readable explanation of this config parameter',
    active_flag         BOOLEAN       NOT NULL    COMMENT 'false = this config entry is ignored at runtime',
    created_at          TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)',
    updated_at          TIMESTAMP     NOT NULL    COMMENT 'Row last updated timestamp (UTC)'
)
USING DELTA
COMMENT 'Generic key-value config store per pipeline. Allows pipelines to read dynamic runtime config without hardcoding values in code.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
