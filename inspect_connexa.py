"""Relevamiento de solo lectura del esquema de Connexa PROD.

Usa `PGP_*`, fuerza la sesión PostgreSQL en modo read-only y no imprime secretos.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import psycopg2
from dotenv import dotenv_values


ENV_PATH = Path(r"C:\ETL\ETL_DIARCO\.env")
DATABASE = "connexa_platform_ms"
NAME_PATTERN = re.compile(
    r"cost|stock|invent|product|article|item|receipt|reception|purchase|supplier|"
    r"transfer|movement|warehouse|branch|location|credit|agreement|rebate|price",
    re.IGNORECASE,
)


def connect():
    settings = dotenv_values(ENV_PATH)
    return psycopg2.connect(
        dbname=DATABASE,
        user=settings["PGP_USER"],
        password=settings["PGP_PASSWORD"],
        host=settings["PGP_HOST"],
        port=settings["PGP_PORT"],
        connect_timeout=10,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    )


def main() -> None:
    with connect() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT n.nspname AS schema_name,
                   c.relname AS relation_name,
                   CASE c.relkind
                       WHEN 'r' THEN 'table'
                       WHEN 'p' THEN 'partitioned_table'
                       WHEN 'v' THEN 'view'
                       WHEN 'm' THEN 'materialized_view'
                   END AS relation_type,
                   c.reltuples::bigint AS estimated_rows
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind IN ('r', 'p', 'v', 'm')
              AND n.nspname NOT IN ('pg_catalog', 'information_schema')
            ORDER BY n.nspname, c.relname
            """
        )
        relations = [
            {
                "schema": schema,
                "relation": relation,
                "type": relation_type,
                "estimated_rows": estimated_rows,
            }
            for schema, relation, relation_type, estimated_rows in cursor.fetchall()
        ]
        matches = [
            row
            for row in relations
            if NAME_PATTERN.search(f"{row['schema']}.{row['relation']}")
        ]

        matched_names = [(row["schema"], row["relation"]) for row in matches]
        columns = []
        if matched_names:
            cursor.execute(
                """
                SELECT table_schema, table_name, ordinal_position, column_name,
                       data_type, is_nullable, column_default
                FROM information_schema.columns
                WHERE (table_schema, table_name) IN %s
                ORDER BY table_schema, table_name, ordinal_position
                """,
                (tuple(matched_names),),
            )
            columns = [
                {
                    "schema": schema,
                    "relation": relation,
                    "position": position,
                    "column": column,
                    "data_type": data_type,
                    "nullable": nullable,
                    "default": default,
                }
                for schema, relation, position, column, data_type, nullable, default
                in cursor.fetchall()
            ]

        print(
            json.dumps(
                {
                    "database": DATABASE,
                    "relation_count": len(relations),
                    "relations_by_schema": {
                        schema: sum(row["schema"] == schema for row in relations)
                        for schema in sorted({row["schema"] for row in relations})
                    },
                    "matched_relations": matches,
                    "matched_columns": columns,
                },
                ensure_ascii=False,
                indent=2,
                default=str,
            )
        )


if __name__ == "__main__":
    main()
