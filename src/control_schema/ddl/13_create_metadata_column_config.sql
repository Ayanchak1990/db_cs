CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.metadata_column_config (
    config_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    pipeline_id         STRING        NOT NULL    COMMENT 'default = shared by all pipelines. pipeline name = pipeline-specific override',
    column_name         STRING        NOT NULL    COMMENT 'Metadata column to inject into every RAW table row e.g. record_hash',
    data_type           STRING        NOT NULL    COMMENT 'Column data type e.g. STRING, TIMESTAMP',
    applies_to          STRING        NOT NULL    COMMENT 'all = inject for every load type. hash_incremental = incremental only. full_load = full load only',
    computation         STRING        NOT NULL    COMMENT 'How to compute this column e.g. sha2(concat_ws(|, hash_columns), 256) or current_timestamp() or load_run_id',
    column_order        INT           NOT NULL    COMMENT 'Order in which this column is appended to the DataFrame (1-based)',
    is_merge_key        BOOLEAN       NOT NULL    COMMENT 'false for all metadata columns — merge key is always primary_key from source_object_config',
    active_flag         BOOLEAN       NOT NULL    COMMENT 'false = do not inject this column',
    created_at          TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)'
)
USING DELTA
COMMENT 'Defines metadata columns to be injected into every RAW table row. Use pipeline_id=default for shared columns. Pipeline-specific rows override defaults. New pipelines inherit all defaults with zero setup.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
