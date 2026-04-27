CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.job_run_audit (
    run_id              STRING        NOT NULL    COMMENT 'UUID — primary key for this pipeline run',
    pipeline_id         STRING        NOT NULL    COMMENT 'Owning pipeline e.g. raw_employee_pipeline',
    job_id              STRING                    COMMENT 'Databricks job ID',
    job_run_id          STRING                    COMMENT 'Databricks job run ID — use for UI deep-link',
    triggered_by        STRING        NOT NULL    COMMENT 'Who triggered: User, Service Principal, api',
    triggered_mode      STRING        NOT NULL    COMMENT 'How this run was triggered: schedule, manual',
    start_time          TIMESTAMP     NOT NULL    COMMENT 'Run start timestamp (UTC)',
    end_time            TIMESTAMP                 COMMENT 'Run end timestamp (UTC). NULL if still running',
    duration_seconds    BIGINT                    COMMENT 'Total run duration in seconds. NULL if still running',
    status              STRING        NOT NULL    COMMENT 'Run lifecycle status: RUNNING, SUCCESS, FAILED, PARTIAL',
    total_objects       INT                       COMMENT 'Total source objects attempted in this run',
    success_objects     INT                       COMMENT 'Source objects that completed successfully',
    failed_objects      INT                       COMMENT 'Source objects that failed',
    environment         STRING        NOT NULL    COMMENT 'Deployment environment: dev, qa, prod',
    created_at          TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)'
)
USING DELTA
PARTITIONED BY (environment)
COMMENT 'Audit log for every pipeline execution run. One row per run. Tracks full lifecycle from RUNNING to SUCCESS or FAILED.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
