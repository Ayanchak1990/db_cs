CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.dq_check_results (
    result_id           STRING        NOT NULL    COMMENT 'UUID — primary key',
    run_id              STRING        NOT NULL    COMMENT 'FK to job_run_audit.run_id',
    object_id           STRING        NOT NULL    COMMENT 'FK to source_object_config.object_id',
    rule_id             STRING        NOT NULL    COMMENT 'FK to dq_rule_config.rule_id',
    pipeline_id         STRING        NOT NULL    COMMENT 'FK to job_run_audit.pipeline_id',
    rule_name           STRING        NOT NULL    COMMENT 'Rule name — denormalised for quick lookup without join',
    rule_type           STRING        NOT NULL    COMMENT 'Rule category — denormalised for quick lookup without join',
    column_name         STRING                    COMMENT 'Column name for column-level rules. NULL for table-level rules',
    rows_checked        BIGINT                    COMMENT 'Total rows evaluated by this rule',
    rows_passed         BIGINT                    COMMENT 'Rows that passed the rule',
    rows_failed         BIGINT                    COMMENT 'Rows that failed the rule',
    pass_rate           DOUBLE                    COMMENT 'Pass percentage: rows_passed / rows_checked * 100',
    status              STRING        NOT NULL    COMMENT 'Rule evaluation result: PASSED, FAILED, WARNING',
    action_taken        STRING        NOT NULL    COMMENT 'Pipeline response to this result: CONTINUED or HALTED',
    checked_at          TIMESTAMP     NOT NULL    COMMENT 'Timestamp when rule was evaluated (UTC)',
    environment         STRING        NOT NULL    COMMENT 'Deployment environment: dev, qa, prod'
)
USING DELTA
PARTITIONED BY (environment)
COMMENT 'Logs the result of every DQ rule check per source object per run. One row per rule per object per run.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
