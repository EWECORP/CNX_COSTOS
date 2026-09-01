"""Metadatos estructurales del núcleo de stock, compras y acuerdos en DESA."""

from __future__ import annotations

import json

from inspect_connexa import connect


CORE_RELATIONS = (
    "inventory.inv_product",
    "inventory.inv_product_supplier",
    "inventory.inv_site",
    "procurement_and_sourcing.pas_product",
    "procurement_and_sourcing.pas_product_site",
    "procurement_and_sourcing.pas_purchase_order",
    "procurement_and_sourcing.pas_purchase_order_line",
    "procurement_and_sourcing.pas_purchase_order_reception",
    "procurement_and_sourcing.pas_purchase_order_reception_line",
    "procurement_and_sourcing.pas_stock_adjustment",
    "procurement_and_sourcing.pas_stock_adjustment_detail",
    "procurement_and_sourcing.pas_stock_movement",
    "procurement_and_sourcing.pas_stock_movement_type",
    "procurement_and_sourcing.pas_transfer_order",
    "procurement_and_sourcing.pas_transfer_order_line",
    "procurement_and_sourcing.pas_transfer_order_reception",
    "procurement_and_sourcing.pas_transfer_order_reception_line",
    "stock_management.stk_stock",
    "stock_management.stk_stock_movement",
    "stock_management.stk_stock_movement_type",
    "stock_management.stk_stock_snapshot",
    "stock_management.stk_stock_product",
    "stock_management.stk_stock_site",
    "commercial_agreements.cag_account_agreement",
    "commercial_agreements.cag_account_agreement_installment",
    "commercial_agreements.cag_account_agreement_scope_item",
    "commercial_agreements.cag_account_agreement_scope_store",
    "commercial_agreements.cag_installment_rappel_scale",
    "commercial_agreements.account_agreement_counterprestation",
)


def main() -> None:
    pairs = tuple(tuple(name.split(".", 1)) for name in CORE_RELATIONS)
    with connect() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT c.table_schema, c.table_name, c.ordinal_position,
                   c.column_name, c.data_type, c.udt_name, c.is_nullable
            FROM information_schema.columns c
            WHERE (c.table_schema, c.table_name) IN %s
            ORDER BY c.table_schema, c.table_name, c.ordinal_position
            """,
            (pairs,),
        )
        relation_columns: dict[str, list[str]] = {}
        for schema, table, _, column, data_type, udt_name, nullable in cursor.fetchall():
            type_name = udt_name if data_type == "USER-DEFINED" else data_type
            null_mark = "?" if nullable == "YES" else ""
            relation_columns.setdefault(f"{schema}.{table}", []).append(
                f"{column}:{type_name}{null_mark}"
            )

        cursor.execute(
            """
            SELECT ns.nspname, cls.relname, con.conname, con.contype,
                   pg_get_constraintdef(con.oid, true)
            FROM pg_constraint con
            JOIN pg_class cls ON cls.oid = con.conrelid
            JOIN pg_namespace ns ON ns.oid = cls.relnamespace
            WHERE (ns.nspname, cls.relname) IN %s
            ORDER BY ns.nspname, cls.relname, con.contype, con.conname
            """,
            (pairs,),
        )
        constraints = [
            {
                "relation": f"{schema}.{table}",
                "name": name,
                "type": constraint_type,
                "definition": definition,
            }
            for schema, table, name, constraint_type, definition in cursor.fetchall()
        ]

        cursor.execute(
            """
            SELECT schemaname, relname, n_live_tup, n_dead_tup,
                   last_analyze, last_autoanalyze
            FROM pg_stat_user_tables
            WHERE (schemaname, relname) IN %s
            ORDER BY schemaname, relname
            """,
            (pairs,),
        )
        statistics = [
            {
                "relation": f"{schema}.{table}",
                "live_rows": live,
                "dead_rows": dead,
                "last_analyze": analyzed,
                "last_autoanalyze": autoanalyzed,
            }
            for schema, table, live, dead, analyzed, autoanalyzed in cursor.fetchall()
        ]

    print(
        json.dumps(
            {
                "columns": relation_columns,
                "constraints": constraints,
                "statistics": statistics,
            },
            ensure_ascii=False,
            indent=2,
            default=str,
        )
    )


if __name__ == "__main__":
    main()
