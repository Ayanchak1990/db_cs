CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.object_schema_registry (
    schema_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to source_object_config.pipeline_id',
    column_name         STRING        NOT NULL    COMMENT 'Column name as it appears in the source',
    data_type           STRING        NOT NULL    COMMENT 'Expected data type e.g. STRING, INT, TIMESTAMP',
    is_nullable         BOOLEAN       NOT NULL    COMMENT 'Whether this column is nullable in the source schema',
    is_primary_key      BOOLEAN       NOT NULL    COMMENT 'Whether this column is part of the primary key',
    column_order        INT           NOT NULL    COMMENT 'Column position in source schema (1-based)',
    registered_at       TIMESTAMP     NOT NULL    COMMENT 'Timestamp when this column was first registered (UTC)',
    updated_at          TIMESTAMP     NOT NULL    COMMENT 'Timestamp when registration was last updated (UTC)',
    active_flag         BOOLEAN       NOT NULL    COMMENT 'false = column has been dropped from the source schema'
)
USING DELTA
COMMENT 'Stores the registered (expected) schema per source object, one row per column. Used to detect schema drift on every pipeline run. Drift types: NEW_COLUMN, DROPPED_COLUMN, TYPE_CHANGE, NULLABLE_CHANGE.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
