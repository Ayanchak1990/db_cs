"""
Seed script for Control Schema reference data.

Reads seed data from an external JSON config file and idempotently inserts
rows into:
  - source_object_config
  - pipeline_config
  - metadata_column_config
  - connection_config
  - dq_rule_config

Idempotency contract: each table is checked for its natural key before
inserting. If the row already exists it is skipped and logged. Safe to
re-run at any time — existing rows are never overwritten.

Runtime-injected values (not in JSON):
  - target_catalog   → from --catalog CLI arg (source_object_config only)
  - object_id        → UUID generated at insert time (source_object_config)
  - config_id        → UUID generated at insert time (pipeline_config, metadata_column_config)
  - connection_id    → UUID generated at insert time (connection_config)
  - created_at       → current_timestamp() at insert time
  - updated_at       → current_timestamp() at insert time (where applicable)

Exits with code 0 if all rows were either inserted or already present.
Exits with code 1 if any insert failed.
"""

import argparse
import json
import logging
import re
import sys
import traceback
import uuid
from typing import Any

from pyspark.sql import SparkSession


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logger = logging.getLogger("seed_source_object_config")
if not logger.handlers:
    _handler = logging.StreamHandler()
    _handler.setFormatter(
        logging.Formatter(
            "[%(asctime)s UTC] [%(levelname)-7s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    )
    logger.addHandler(_handler)
    logger.setLevel(logging.DEBUG)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _validate_identifier(value: str, arg_name: str) -> None:
    """Raise ValueError if value is not a safe Unity Catalog identifier.

    Args:
        value:    The identifier string to validate.
        arg_name: Name of the argument (used in error message).

    Raises:
        ValueError: If value contains characters outside [a-zA-Z0-9_].
    """
    if not re.fullmatch(r"[a-zA-Z0-9_]+", value):
        raise ValueError(
            f"Invalid {arg_name} '{value}': only alphanumeric characters and underscores are allowed."
        )


# ---------------------------------------------------------------------------
# Table metadata — natural keys, auto-generated IDs, timestamp columns
# ---------------------------------------------------------------------------

NATURAL_KEYS: dict[str, list[str]] = {
    "source_object_config":  ["pipeline_id", "source_object"],
    "pipeline_config":       ["pipeline_id", "config_key"],
    "metadata_column_config": ["pipeline_id", "column_name"],
    "connection_config":     ["pipeline_id", "connection_name"],
    "dq_rule_config":        ["rule_id"],
}

AUTO_ID_COLUMN: dict[str, str | None] = {
    "source_object_config":  "object_id",
    "pipeline_config":       "config_id",
    "metadata_column_config": "config_id",
    "connection_config":     "connection_id",
    "dq_rule_config":        None,
}

TIMESTAMP_COLUMNS: dict[str, list[str]] = {
    "source_object_config":  ["created_at", "updated_at"],
    "pipeline_config":       ["created_at", "updated_at"],
    "metadata_column_config": ["created_at"],
    "connection_config":     ["created_at", "updated_at"],
    "dq_rule_config":        ["created_at", "updated_at"],
}

SEED_ORDER: list[str] = [
    "source_object_config",
    "pipeline_config",
    "metadata_column_config",
    "connection_config",
    "dq_rule_config",
]


# ---------------------------------------------------------------------------
# Config loader
# ---------------------------------------------------------------------------

def _load_seed_config(config_path: str) -> dict[str, list[dict[str, Any]]]:
    """Load and validate the seed configuration JSON file.

    Args:
        config_path: Filesystem path to the seed_config.json file.

    Returns:
        Parsed JSON as a dict keyed by table name, each value a list of row dicts.

    Raises:
        FileNotFoundError: If config_path does not exist.
        ValueError:        If JSON is malformed or missing required table sections.
    """
    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            config = json.load(fh)
    except FileNotFoundError:
        raise FileNotFoundError(f"Seed config file not found: {config_path}")
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in seed config '{config_path}': {exc}")

    missing_tables = set(NATURAL_KEYS.keys()) - set(config.keys())
    if missing_tables:
        raise ValueError(
            f"Seed config missing table sections: {', '.join(sorted(missing_tables))}"
        )

    for table_name, rows in config.items():
        if not isinstance(rows, list):
            raise ValueError(f"Seed config section '{table_name}' must be a JSON array")

    return config


# ---------------------------------------------------------------------------
# SQL value formatting
# ---------------------------------------------------------------------------

def _format_sql_value(value: Any) -> str:
    """Convert a Python value to a SQL literal string safe for INSERT VALUES.

    Args:
        value: The Python value to convert.

    Returns:
        SQL literal: NULL, true/false, numeric literal, or single-quoted string.
    """
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    escaped = str(value).replace("'", "''")
    return f"'{escaped}'"


# ---------------------------------------------------------------------------
# DQ rule pre-processing — resolve object_id from source_object_config
# ---------------------------------------------------------------------------

def _resolve_dq_object_ids(
    spark: SparkSession,
    catalog: str,
    control_schema: str,
    rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Resolve object_id for each dq_rule_config row from source_object_config.

    Uses (pipeline_id + source_object) to look up the object_id, then removes
    source_object from the row dict (it is not a column in dq_rule_config).

    Rows whose source_object cannot be found are dropped with a WARNING log.

    Args:
        spark:          Active SparkSession.
        catalog:        Unity Catalog name.
        control_schema: Control schema name.
        rows:           List of dq_rule_config row dicts from JSON (includes source_object).

    Returns:
        List of row dicts with object_id added and source_object removed.
    """
    soc_table = f"{catalog}.{control_schema}.source_object_config"
    resolved: list[dict[str, Any]] = []

    for row in rows:
        pipeline_id = row["pipeline_id"]
        source_object = row["source_object"]
        seed_key = f"{source_object}|{row['rule_name']}"

        safe_pipeline_id = str(pipeline_id).replace("'", "''")
        safe_source_object = str(source_object).replace("'", "''")

        try:
            obj_rows = spark.sql(f"""
                SELECT object_id
                FROM   {soc_table}
                WHERE  pipeline_id   = '{safe_pipeline_id}'
                  AND  source_object = '{safe_source_object}'
                LIMIT  1
            """).collect()
        except Exception as exc:
            logger.error(f"dq_rule_config | {seed_key} | object_id lookup FAILED: {exc}")
            logger.error(f"dq_rule_config | {seed_key} | traceback: {traceback.format_exc()}")
            continue

        if not obj_rows:
            logger.warning(
                f"dq_rule_config | {seed_key} | skipped "
                f"(source_object '{source_object}' not found — seed source_object_config first)",
            )
            continue

        resolved_row = dict(row)
        resolved_row["object_id"] = obj_rows[0]["object_id"]
        del resolved_row["source_object"]
        resolved.append(resolved_row)

    return resolved


# ---------------------------------------------------------------------------
# Generic table seeder
# ---------------------------------------------------------------------------

def _seed_table(
    spark: SparkSession,
    catalog: str,
    control_schema: str,
    table_name: str,
    rows: list[dict[str, Any]],
) -> int:
    """Idempotently seed rows into a single control schema table.

    For each row: checks the natural key via EXISTS, skips if present,
    otherwise generates the auto-ID (UUID) and inserts with timestamps.

    Args:
        spark:          Active SparkSession.
        catalog:        Unity Catalog name.
        control_schema: Control schema name.
        table_name:     Unqualified table name (must be a key in NATURAL_KEYS).
        rows:           List of row dicts to seed (from JSON, post-enrichment).

    Returns:
        Number of rows that failed to insert (0 = fully successful).
    """
    fq_table = f"{catalog}.{control_schema}.{table_name}"
    natural_keys = NATURAL_KEYS[table_name]
    id_column = AUTO_ID_COLUMN[table_name]
    ts_columns = TIMESTAMP_COLUMNS[table_name]
    failures = 0

    for row in rows:
        seed_key = "|".join(str(row[k]) for k in natural_keys)

        try:
            where_clauses = " AND ".join(
                f"{col} = {_format_sql_value(row[col])}" for col in natural_keys
            )

            exists = spark.sql(f"""
                SELECT 1
                FROM   {fq_table}
                WHERE  {where_clauses}
                LIMIT  1
            """).count() > 0

            if exists:
                logger.info(f"{table_name} | {seed_key} | skipped (already exists)")
                continue

            insert_row = dict(row)

            generated_id = None
            if id_column:
                generated_id = str(uuid.uuid4())
                insert_row[id_column] = generated_id

            columns = list(insert_row.keys()) + ts_columns
            values = [_format_sql_value(insert_row[col]) for col in insert_row]
            values += ["current_timestamp()"] * len(ts_columns)

            columns_sql = ", ".join(columns)
            values_sql = ", ".join(values)

            spark.sql(f"""
                INSERT INTO {fq_table}
                    ({columns_sql})
                VALUES (
                    {values_sql}
                )
            """)

            if id_column and generated_id:
                id_label = f"{id_column}={generated_id}"
            else:
                id_label = f"rule_id={row.get('rule_id', 'N/A')}"

            logger.info(f"{table_name} | {seed_key} | inserted ({id_label})")

        except Exception as exc:
            logger.error(f"{table_name} | {seed_key} | FAILED: {exc}")
            logger.error(f"{table_name} | {seed_key} | traceback: {traceback.format_exc()}")
            failures += 1

    return failures


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Parse CLI arguments, validate inputs, and execute all seed operations in order.

    Execution order:
      1. source_object_config   — must run first (dq_rule_config depends on it)
      2. pipeline_config
      3. metadata_column_config
      4. connection_config
      5. dq_rule_config         — must run last (resolves object_id from source_object_config)

    Exits with code 0 on full success, code 1 if any insert failed.
    """
    parser = argparse.ArgumentParser(description="Seed Control Schema reference data.")
    parser.add_argument("--catalog",        required=True, help="Unity Catalog name e.g. dev")
    parser.add_argument("--control_schema", required=True, help="Control schema name e.g. deltek_cdm")
    parser.add_argument("--environment",    required=True, help="Deployment environment: dev, qa, prod")
    parser.add_argument("--config_path",    required=True, help="Path to seed_config.json file")
    args = parser.parse_args()

    try:
        _validate_identifier(args.catalog,        "catalog")
        _validate_identifier(args.control_schema, "control_schema")
        _validate_identifier(args.environment,    "environment")
    except ValueError as exc:
        logger.error(str(exc))
        raise SystemError("Seed failed. Check logs above.")

    try:
        config = _load_seed_config(args.config_path)
    except (FileNotFoundError, ValueError) as exc:
        logger.error(f"Failed to load seed config: {exc}")
        raise SystemError("Seed failed. Check logs above.")

    spark = SparkSession.builder.getOrCreate()

    logger.info(
        f"Starting seed | catalog={args.catalog} | schema={args.control_schema} "
        f"| environment={args.environment} | config_path={args.config_path}",
    )

    total_failures = 0

    for table_name in SEED_ORDER:
        rows = config[table_name]

        if table_name == "source_object_config":
            for row in rows:
                row["target_catalog"] = args.catalog

        if table_name == "dq_rule_config":
            rows = _resolve_dq_object_ids(spark, args.catalog, args.control_schema, rows)

        logger.info(f"{table_name} | seeding {len(rows)} row(s)")
        total_failures += _seed_table(spark, args.catalog, args.control_schema, table_name, rows)

    if total_failures > 0:
        logger.error(f"Seed completed with {total_failures} failure(s). Review errors above.")
        raise SystemError("Seed failed. Check logs above.")

    logger.info("Seed completed successfully.")
    


if __name__ == "__main__":
    main()
