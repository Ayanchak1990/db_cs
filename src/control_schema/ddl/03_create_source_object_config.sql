CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.source_object_config (
    object_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    pipeline_id         STRING        NOT NULL    COMMENT 'Owning pipeline e.g. raw_employee_pipeline',
    source_system       STRING        NOT NULL    COMMENT 'Source system name e.g. sql_server',
    source_type         STRING        NOT NULL    COMMENT 'Source type: databricks_native, jdbc, cloud_storage',
    source_schema       STRING        NOT NULL    COMMENT 'Source schema e.g. dbo',
    source_object       STRING        NOT NULL    COMMENT 'Source view or table name e.g. v_ESA_TalentBridge_Employee',
    target_catalog      STRING        NOT NULL    COMMENT 'Unity Catalog target catalog e.g. dev',
    target_schema       STRING        NOT NULL    COMMENT 'Target schema e.g. raw',
    target_table        STRING        NOT NULL    COMMENT 'Target Delta table name e.g. deltek_employee',
    staging_table       STRING                    COMMENT 'Staging Delta table for merge operations e.g. <catalog>.staging.deltek_employee. NULL for full_load objects',
    load_type           STRING        NOT NULL    COMMENT 'Ingestion strategy: full_load or hash_incremental',
    write_mode          STRING        NOT NULL    COMMENT 'Write behaviour: overwrite (full_load) or merge (hash_incremental)',
    primary_key         STRING        NOT NULL    COMMENT 'Comma-separated primary key columns e.g. employee_id',
    watermark_column    STRING                    COMMENT 'Incremental watermark column. NULL = use hash comparison',
    hash_columns        STRING                    COMMENT 'Comma-separated columns to hash. NULL = hash all columns',
    active_flag         BOOLEAN       NOT NULL    COMMENT 'false = skip this object during pipeline runs',
    load_order          INT           NOT NULL    COMMENT 'Execution order within pipeline (1, 2, 3...)',
    created_at          TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)',
    updated_at          TIMESTAMP     NOT NULL    COMMENT 'Row last updated timestamp (UTC)',
    created_by          STRING        NOT NULL    COMMENT 'Identity that created this row',
    updated_by          STRING        NOT NULL    COMMENT 'Identity that last updated this row'
)
USING DELTA
COMMENT 'Master config table. One row per source object per pipeline. Defines WHAT to ingest, WHERE to write it, and HOW to write it.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
