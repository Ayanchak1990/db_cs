import argparse
import os
from pyspark.sql import SparkSession


def run_ddl(catalog: str, control_schema: str):
    spark = SparkSession.builder.getOrCreate()

    sql_dir = os.path.dirname(os.path.abspath(__file__))
    sql_files = sorted([
        f for f in os.listdir(sql_dir) if f.endswith(".sql")
    ])

    print(f"Running control schema DDL | catalog={catalog} | schema={control_schema}")
    print(f"Found {len(sql_files)} SQL files: {sql_files}")

    for sql_file in sql_files:
        path = os.path.join(sql_dir, sql_file)
        with open(path, "r") as f:
            statement = f.read().strip()

        # Substitute variables
        statement = statement.replace("${catalog}", catalog)
        statement = statement.replace("${control_schema}", control_schema)

        print(f"\n>>> Executing: {sql_file}")
        print(statement)
        spark.sql(statement)
        print(f"✓ Done: {sql_file}")

    print("\n✅ All control schema tables created successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True, help="Unity Catalog name")
    parser.add_argument("--control_schema", required=True, help="Control schema name")
    args = parser.parse_args()
    run_ddl(args.catalog, args.control_schema)
