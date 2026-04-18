# db_cs — Deltek Control Schema Bundle

A Databricks Asset Bundle that creates and seeds the central control schema used by all ingestion pipelines. Deploy once per environment — the 12 Delta tables and seed data form the infrastructure layer that every pipeline reads from and writes to.

---

## Project structure

```
db_cs/
├── databricks.yml                  # Bundle config (workspace, targets, jobs, variables)
├── src/
│   ├── run_ddl.py                  # Task 1: Executes 13 SQL files → creates 12 Delta tables
│   ├── seed_source_object_config.py # Task 2: Seeds 5 config tables from seed_config.json
│   ├── seed_config.json            # Client-specific seed data (source objects, connections, DQ rules)
│   ├── 01_source_object_config.sql
│   ├── 02_watermark_control.sql
│   ├── ...                         # 13 DDL files total
│   └── 13_connection_config.sql
├── resources/                      # Resource configurations (jobs, pipelines)
├── tests/                          # Integration tests (require live Databricks cluster)
├── fixtures/                       # Test data fixtures
└── context/
    ├── coding_standards.md
    ├── implementation_standards.md
    └── prompt.md
```

---

## What it creates

### 12 Delta tables in `{catalog}.{control_schema}`

**Config tables (5) — seeded by Task 2:**

| Table | Purpose |
|---|---|
| `source_object_config` | What to ingest — source objects, target tables, load strategy, primary keys |
| `connection_config` | JDBC/API secret scope and key references per pipeline |
| `pipeline_config` | Key-value runtime settings per pipeline (batch_size, retry_count, etc.) |
| `metadata_column_config` | Metadata columns to inject into every row (_ingested_at, _pipeline_id, etc.) |
| `dq_rule_config` | Data quality rules per source object (NOT_NULL, UNIQUE, thresholds) |

**Runtime tables (7) — populated during pipeline runs:**

| Table | Purpose |
|---|---|
| `watermark_control` | Last successful watermark per object (composite PK: object_id + pipeline_id) |
| `job_run_audit` | Full run lifecycle (RUNNING → SUCCESS / FAILED / PARTIAL) |
| `job_run_error` | Granular error details per object per run |
| `ingestion_metrics` | Rows read, inserted, updated, rejected per object per run |
| `object_schema_registry` | Registered source schema snapshots for drift detection |
| `schema_drift_log` | Every schema change detected (column added, removed, type changed) |
| `dq_check_results` | DQ check outcomes per rule per run |

---

## Prerequisites

- Databricks CLI installed and configured
- OAuth profile set up (no PAT)
- Access to the target Databricks workspace
- Unity Catalog enabled on the workspace
- `uv` package manager (for local testing): https://docs.astral.sh/uv/getting-started/installation/

---

## Getting started

### 1. Authenticate to your Databricks workspace

```bash
databricks configure --profile <your-profile-name>
```

Verify authentication:

```bash
databricks auth token --profile <your-profile-name>
```

### 2. Review and update `databricks.yml`

Open `databricks.yml` and confirm these values match your environment:

| Variable | What to set |
|---|---|
| `workspace.host` | Your Databricks workspace URL |
| `variables.catalog` | Target Unity Catalog name (`dev`, `qa`, `prod`) |
| `variables.control_schema` | Control schema name (default: `deltek_cdm`) |
| `run_as.service_principal` | Service principal ID for the target environment |

### 3. Update `seed_config.json`

This file contains all client-specific seed data. Update it with your source objects, connections, DQ rules, etc. The seed script reads this file and inserts the data — no Python code changes needed.

Structure:

```json
{
  "source_object_config": [ ... ],
  "connection_config": [ ... ],
  "pipeline_config": [ ... ],
  "metadata_column_config": [ ... ],
  "dq_rule_config": [ ... ]
}
```

---

## Deployment

### Deploy to dev (default target)

```bash
databricks bundle deploy --profile <your-profile-name> --target dev
```

### Deploy to production

```bash
databricks bundle deploy --profile <your-profile-name> --target prod
```

---

## Running the job

### Run via CLI

```bash
databricks bundle run --profile <your-profile-name> --target dev
```

This triggers a Databricks Workflow job with two sequential tasks:

```
Task 1: run_ddl.py
  → Executes 13 SQL files
  → Creates 12 Delta tables in {catalog}.{control_schema}
  → Verifies all tables exist
  → Exits 0 (success) or 1 (failure)
        │
        ▼ (on success)
Task 2: seed_source_object_config.py
  → Reads seed_config.json
  → Idempotently inserts config rows into 5 tables
  → Uses check-then-insert (safe to re-run)
  → Logs success/skip/failure per row
```

### Run via Databricks UI

1. Open your workspace
2. Go to **Workflows**
3. Find the `db_cs` job
4. Click **Run now**

---

## Validation

After the job completes, verify everything landed correctly.

### Check all 12 tables exist

```sql
SHOW TABLES IN {catalog}.{control_schema};
```

### Check seed data in config tables

```sql
SELECT * FROM {catalog}.{control_schema}.source_object_config;
SELECT * FROM {catalog}.{control_schema}.connection_config;
SELECT * FROM {catalog}.{control_schema}.pipeline_config;
SELECT * FROM {catalog}.{control_schema}.metadata_column_config;
SELECT * FROM {catalog}.{control_schema}.dq_rule_config;
```

### Check runtime tables are empty (expected)

```sql
SELECT COUNT(*) FROM {catalog}.{control_schema}.watermark_control;       -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.job_run_audit;           -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.job_run_error;           -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.ingestion_metrics;       -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.object_schema_registry;  -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.schema_drift_log;        -- 0
SELECT COUNT(*) FROM {catalog}.{control_schema}.dq_check_results;        -- 0
```

---

## Using with the utils library (`quper_control_schema_utils`)

Once the control schema is deployed and seeded, any ingestion pipeline uses the wheel library to interact with these tables.

### Install the wheel

```bash
pip install quper_control_schema_utils-0.1.0-py3-none-any.whl
```

Or upload the `.whl` to DBFS / Unity Catalog volume and add it to the cluster library list.

### Initialize the client

```python
from quper_control_schema_utils.client import ControlSchemaClient

client = ControlSchemaClient(
    spark=spark,
    catalog="dev",                      # same catalog used by the bundle
    schema="deltek_cdm",                # same control_schema used by the bundle
    pipeline_id="raw_employee_pipeline" # must match a pipeline_id in seed data
)
```

### Read configuration

```python
# What to ingest
objects = client.get_source_objects()

# Runtime settings
config = client.get_pipeline_config()

# Connection secrets
connection = client.get_connection_config()

# Metadata columns to inject
metadata_cols = client.get_metadata_columns()

# DQ rules for a specific object
dq_rules = client.get_dq_rules(object_id="v_ESA_TalentBridge_Employee")
```

### Pipeline lifecycle methods

```python
# Start a run
run_id = client.log_run_start()

# Get watermark (None on first run → full extract)
watermark = client.get_watermark(object_id="v_ESA_TalentBridge_Employee")

# Register schema and detect drift
client.register_schema(object_id="v_ESA_TalentBridge_Employee", schema=df.schema)
drift = client.detect_drift(object_id="v_ESA_TalentBridge_Employee", schema=df.schema)

# If drift detected
if drift:
    client.log_drift(drift_events=drift)
    client.evolve_table(target_table="dev.deltek_raw.employee", drift_events=drift)

# Run DQ checks
results = client.run_dq_checks(df=source_df, rules=dq_rules)
client.log_dq_results(run_id=run_id, results=results)

# Log metrics
client.log_metrics(
    run_id=run_id,
    object_id="v_ESA_TalentBridge_Employee",
    rows_read=500,
    rows_inserted=450,
    rows_updated=50,
    rows_rejected=0
)

# Update watermark (only on success)
client.update_watermark(
    object_id="v_ESA_TalentBridge_Employee",
    watermark_value="2025-04-17T15:30:00Z"
)

# End the run
client.log_run_end(run_id=run_id, status="SUCCESS")
```

### Error handling

```python
try:
    # ... extraction / transformation logic
except Exception as e:
    client.log_error(
        run_id=run_id,
        object_id="v_ESA_TalentBridge_Employee",
        error_type="EXTRACT_FAILED",
        error_message=str(e),
        stack_trace=traceback.format_exc()
    )
    client.log_run_end(run_id=run_id, status="FAILED")
```

---

## New client onboarding

To use this bundle for a different client:

1. Copy the bundle folder
2. Update `databricks.yml` — workspace host, service principal, catalog
3. Update `seed_config.json` — source objects, connections, DQ rules for the new client
4. Deploy and run — the Python scripts and SQL files stay the same

The wheel library (`quper_control_schema_utils`) does not change per client. Same `.whl`, different `catalog`, `schema`, and `pipeline_id` at init time.

---

## Running tests locally

Install dependencies and run:

```bash
uv sync --dev
uv run pytest tests/ -v
```

Note: Integration tests require a live Databricks cluster connection via Databricks Connect.

---

## Targets

| Target | Catalog | Usage |
|---|---|---|
| `dev` (default) | `dev` | Development and testing |
| `qa` | `qa` | Pre-production validation |
| `prod` | `prod` | Production |

Deploy to a specific target:

```bash
databricks bundle deploy --target prod
databricks bundle run --target prod
```

---

## Key design decisions

| Decision | Detail |
|---|---|
| Hash-based incremental | SHA-256 on source columns — no native CDC needed from source systems |
| Idempotent seeding | Check-then-insert — safe to re-run the seed job multiple times |
| Metadata column defaults | `pipeline_id='default'` rows are shared across all pipelines; pipeline-specific rows override |
| Library never crashes on logging | error_logger, metrics_logger, drift_logger all swallow exceptions — logging must never crash a pipeline |
| Client-agnostic seed script | Seed data lives in `seed_config.json`, not hardcoded in Python |
| SQL injection prevention | `_validate_identifier()` on catalog/schema, `_escape_sql()` on all values |