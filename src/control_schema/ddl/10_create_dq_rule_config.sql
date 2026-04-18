CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.dq_rule_config (
    rule_id             STRING        NOT NULL    COMMENT 'UUID — primary key',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to source_object_config.pipeline_id',
    rule_name           STRING        NOT NULL    COMMENT 'Human-readable rule identifier e.g. employee_id_not_null',
    rule_type           STRING        NOT NULL    COMMENT 'Rule category: NOT_NULL, UNIQUE, ROW_COUNT, VALUE_RANGE, REGEX, REFERENTIAL',
    column_name         STRING                    COMMENT 'Column this rule applies to. NULL = table-level rule',
    rule_expression     STRING        NOT NULL    COMMENT 'The DQ check expression e.g. employee_id IS NOT NULL',
    expected_value      STRING                    COMMENT 'For ROW_COUNT: minimum expected rows. For VALUE_RANGE: min|max.',
    severity            STRING        NOT NULL    COMMENT 'Failure severity: ERROR (halt pipeline) or WARN (log and continue)',
    active_flag         BOOLEAN       NOT NULL    COMMENT 'false = this rule is disabled and will not be evaluated',
    created_at          TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)',
    updated_at          TIMESTAMP     NOT NULL    COMMENT 'Row last updated timestamp (UTC)'
)
USING DELTA
COMMENT 'Defines data quality rules per source object. Rules are evaluated on every pipeline run before writing to the target table.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
