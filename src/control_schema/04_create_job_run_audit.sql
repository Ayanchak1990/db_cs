CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.job_run_audit (
    run_id          STRING        NOT NULL COMMENT 'UUID for this pipeline run',
    job_name        STRING        NOT NULL COMMENT 'Name of the Databricks job or task',
    start_time      TIMESTAMP     NOT NULL COMMENT 'Run start timestamp',
    end_time        TIMESTAMP     COMMENT 'Run end timestamp, null if still running',
    status          STRING        NOT NULL COMMENT 'Run status: RUNNING, SUCCESS, FAILED'
)
USING DELTA
COMMENT 'Audit log for every pipeline execution run';
