import argparse
import logging
import os
import re
import sys
import traceback

from pyspark.sql import SparkSession

logger = logging.getLogger("run_ddl")
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


def run_ddl(catalog: str, control_schema: str) -> int:
    """Execute all SQL DDL files to create control schema tables.

    Args:
        catalog:        Unity Catalog name.
        control_schema: Control schema name.

    Returns:
        Number of DDL files that failed to execute (0 = fully successful).
    """
    _validate_identifier(catalog, "catalog")
    _validate_identifier(control_schema, "control_schema")

    spark = SparkSession.builder.getOrCreate()

    sql_dir = os.path.dirname(os.path.abspath(__file__))
    sql_files = sorted([
        f for f in os.listdir(sql_dir) if f.endswith(".sql")
    ])

    logger.info(f"Starting DDL execution | catalog={catalog} | schema={control_schema}")
    logger.info(f"Found {len(sql_files)} SQL file(s): {sql_files}")

    failures = 0

    for sql_file in sql_files:
        path = os.path.join(sql_dir, sql_file)
        with open(path, "r") as f:
            statement = f.read().strip()

        # Substitute variables
        statement = statement.replace("${catalog}", catalog)
        statement = statement.replace("${control_schema}", control_schema)

        try:
            logger.info(f"Executing: {sql_file}")
            spark.sql(statement)
            logger.info(f"Completed: {sql_file}")
        except Exception as exc:
            logger.error(f"Failed: {sql_file} | {exc}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            failures += 1

    if failures > 0:
        logger.error(f"DDL execution finished with {failures} failure(s). Review errors above.")
    else:
        logger.info("All control schema tables created successfully.")

    return failures


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Execute control schema DDL statements.")
    parser.add_argument("--catalog", required=True, help="Unity Catalog name")
    parser.add_argument("--control_schema", required=True, help="Control schema name")
    args = parser.parse_args()
    failures = run_ddl(args.catalog, args.control_schema)
    sys.exit(1 if failures > 0 else 0)
