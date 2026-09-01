"""Busca estructuras existentes que puedan actuar como Kardex valorizado."""

from __future__ import annotations

import json

from inspect_connexa import connect


def rows(cursor):
    names = [column.name for column in cursor.description]
    return [dict(zip(names, row)) for row in cursor.fetchall()]


def main() -> None:
    report = {}
    with connect() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT table_schema, table_name,
                   array_agg(column_name ORDER BY ordinal_position) FILTER (
                       WHERE column_name ~* '(cost|costo|value|valor|amount|importe|price|precio)'
                   ) AS value_columns,
                   array_agg(column_name ORDER BY ordinal_position) FILTER (
                       WHERE column_name ~* '(quantity|cantidad|stock|movement|movimiento)'
                   ) AS stock_columns
            FROM information_schema.columns
            WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
            GROUP BY table_schema, table_name
            HAVING count(*) FILTER (
                       WHERE column_name ~* '(cost|costo|value|valor|amount|importe|price|precio)'
                   ) > 0
               AND count(*) FILTER (
                       WHERE column_name ~* '(quantity|cantidad|stock|movement|movimiento)'
                   ) > 0
            ORDER BY table_schema, table_name
            """
        )
        report["relations_with_value_and_quantity_semantics"] = rows(cursor)

        cursor.execute(
            """
            SELECT event_object_schema, event_object_table, trigger_name,
                   action_timing, event_manipulation, action_statement
            FROM information_schema.triggers
            WHERE event_object_schema IN ('stock_management', 'procurement_and_sourcing')
            ORDER BY event_object_schema, event_object_table, trigger_name
            """
        )
        report["stock_and_procurement_triggers"] = rows(cursor)

        cursor.execute(
            """
            SELECT n.nspname AS schema_name, p.proname AS routine_name,
                   pg_get_function_result(p.oid) AS result_type
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
              AND (p.proname ~* '(cost|costo|stock|movement|movimiento|kardex|valuation)')
            ORDER BY n.nspname, p.proname
            """
        )
        report["candidate_routines"] = rows(cursor)

        cursor.execute(
            """
            SELECT schemaname, viewname
            FROM pg_views
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
              AND (viewname ~* '(cost|costo|stock|movement|movimiento|kardex|valuation)')
            ORDER BY schemaname, viewname
            """
        )
        report["candidate_views"] = rows(cursor)

    print(json.dumps(report, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
