CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.source_object_config (
    object_id       STRING        NOT NULL COMMENT 'Unique identifier for this config entry',
    source_system   STRING        NOT NULL COMMENT 'Source system name e.g. sql_server',
    source_schema   STRING        NOT NULL COMMENT 'Source schema e.g. dbo',
    source_view     STRING        NOT NULL COMMENT 'Source view name e.g. pipeline_view',
    target_table    STRING        NOT NULL COMMENT 'Target Delta table e.g. raw.pipeline_view',
    load_type       STRING        NOT NULL COMMENT 'Ingestion strategy e.g. hash_incremental',
    primary_key     STRING        NOT NULL COMMENT 'Comma-separated PK columns e.g. D_number',
    active_flag     BOOLEAN       NOT NULL COMMENT 'If false, this object is skipped during pipeline runs'
)
USING DELTA
COMMENT 'Defines all source views to be ingested and their configuration';
