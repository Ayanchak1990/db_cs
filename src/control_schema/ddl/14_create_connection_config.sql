CREATE TABLE IF NOT EXISTS ${catalog}.${control_schema}.connection_config (
    connection_id            STRING        NOT NULL    COMMENT 'UUID — primary key',
    pipeline_id              STRING        NOT NULL    COMMENT 'Which pipeline uses this connection',
    source_system            STRING        NOT NULL    COMMENT 'Source system identifier e.g. sql_server',
    connection_name          STRING        NOT NULL    COMMENT 'Friendly name for this connection e.g. deltek_sqlserver_dev',
    secret_scope             STRING        NOT NULL    COMMENT 'Databricks secret scope name that holds credentials for this connection',
    jdbc_url_secret_key      STRING        NOT NULL    COMMENT 'Secret key name for the JDBC URL',
    jdbc_user_secret_key     STRING        NOT NULL    COMMENT 'Secret key name for the database username',
    jdbc_password_secret_key STRING        NOT NULL    COMMENT 'Secret key name for the database password',
    driver_class             STRING        NOT NULL    COMMENT 'Fully qualified JDBC driver class e.g. com.microsoft.sqlserver.jdbc.SQLServerDriver',
    extra_jdbc_options       STRING                    COMMENT 'Additional JDBC options as a JSON string. NULL if none.',
    active_flag              BOOLEAN       NOT NULL    COMMENT 'false = do not use this connection',
    created_at               TIMESTAMP     NOT NULL    COMMENT 'Row creation timestamp (UTC)',
    updated_at               TIMESTAMP     NOT NULL    COMMENT 'Row last updated timestamp (UTC)'
)
USING DELTA
COMMENT 'Stores JDBC secret key references per source system per pipeline. Ingestion engine reads this to dynamically build JDBC connections. Zero credentials or URLs hardcoded anywhere in pipeline code.'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);
