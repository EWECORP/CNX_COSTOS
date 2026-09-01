"""Perfil de datos, calidad de enlaces y cobertura del modelo de costos actual."""

from __future__ import annotations

import json

from inspect_connexa import connect


QUERIES = {
    "stock_position": """
        SELECT count(*) AS rows,
               count(DISTINCT product_id) AS products,
               count(DISTINCT site_id) AS sites,
               count(*) FILTER (WHERE quantity < 0) AS negative_rows,
               count(*) FILTER (WHERE quantity = 0) AS zero_rows,
               min(created_at) AS first_created_at,
               max(created_at) AS last_created_at,
               count(*) FILTER (WHERE date IS NOT NULL OR time IS NOT NULL) AS with_source_datetime
        FROM stock_management.stk_stock
    """,
    "stock_movements": """
        SELECT count(*) AS rows,
               count(DISTINCT (product_id, site_id)) AS product_sites,
               min(date_and_time) AS first_event,
               max(date_and_time) AS last_event,
               max(timestamp) AS last_timestamp
        FROM stock_management.stk_stock_movement
    """,
    "stock_movement_types": """
        SELECT id, ext_code, name, impact, overrides_existing_stock
        FROM stock_management.stk_stock_movement_type
        ORDER BY id
    """,
    "purchase_orders": """
        SELECT count(*) AS orders,
               min(purchase_order_date) AS first_order,
               max(purchase_order_date) AS last_order,
               count(*) FILTER (WHERE trade_agreement_id IS NOT NULL) AS with_trade_agreement,
               count(*) FILTER (WHERE total_amount_whith_tax_excluded IS NOT NULL) AS with_net_total
        FROM procurement_and_sourcing.pas_purchase_order
    """,
    "purchase_lines": """
        SELECT count(*) AS lines,
               count(*) FILTER (WHERE unit_price IS NOT NULL) AS with_unit_price,
               count(*) FILTER (WHERE unit_price > 0) AS with_positive_unit_price,
               count(*) FILTER (WHERE discount_rate IS NOT NULL AND discount_rate <> 0) AS with_discount_rate,
               count(*) FILTER (WHERE quantity_received IS NOT NULL AND quantity_received <> 0) AS with_received_qty,
               min(unit_price) FILTER (WHERE unit_price > 0) AS min_positive_unit_price,
               max(unit_price) AS max_unit_price
        FROM procurement_and_sourcing.pas_purchase_order_line
    """,
    "purchase_receptions": """
        SELECT count(*) AS receptions,
               min(start_date) AS first_start,
               max(end_date) AS last_end,
               count(*) FILTER (WHERE closed_on_web) AS closed_on_web
        FROM procurement_and_sourcing.pas_purchase_order_reception
    """,
    "purchase_reception_lines": """
        SELECT count(*) AS lines,
               count(*) FILTER (WHERE quantity IS NOT NULL AND quantity <> 0) AS with_quantity,
               min(creation_date) AS first_line,
               max(creation_date) AS last_line
        FROM procurement_and_sourcing.pas_purchase_order_reception_line
    """,
    "purchase_reception_join_quality": """
        WITH candidates AS (
            SELECT rl.id AS reception_line_id, count(pol.id) AS candidate_lines
            FROM procurement_and_sourcing.pas_purchase_order_reception_line rl
            JOIN procurement_and_sourcing.pas_purchase_order_reception r
              ON r.id = rl.purchase_order_reception_id
            LEFT JOIN procurement_and_sourcing.pas_purchase_order_line pol
              ON pol.purchase_order_id = r.purchase_order_id
             AND pol.sku = rl.sku
            GROUP BY rl.id
        )
        SELECT count(*) AS reception_lines,
               count(*) FILTER (WHERE candidate_lines = 0) AS without_po_line,
               count(*) FILTER (WHERE candidate_lines = 1) AS unambiguous,
               count(*) FILTER (WHERE candidate_lines > 1) AS ambiguous
        FROM candidates
    """,
    "duplicate_sku_in_purchase_order": """
        SELECT count(*) AS duplicated_order_skus,
               coalesce(sum(qty - 1), 0) AS extra_lines
        FROM (
            SELECT purchase_order_id, sku, count(*) AS qty
            FROM procurement_and_sourcing.pas_purchase_order_line
            GROUP BY purchase_order_id, sku
            HAVING count(*) > 1
        ) duplicates
    """,
    "transfers": """
        SELECT count(*) AS orders,
               count(*) FILTER (WHERE total_transfer_valuation IS NOT NULL) AS with_total_valuation,
               count(*) FILTER (WHERE total_transfer_valuation > 0) AS with_positive_valuation,
               min(creation_date) AS first_order,
               max(creation_date) AS last_order
        FROM procurement_and_sourcing.pas_transfer_order
    """,
    "transfer_lines": """
        SELECT count(*) AS lines,
               count(*) FILTER (WHERE quantity_received <> 0) AS with_received_quantity,
               count(*) FILTER (WHERE purchase_unit IS NOT NULL) AS with_purchase_unit
        FROM procurement_and_sourcing.pas_transfer_order_line
    """,
    "transfer_reception_lines": """
        SELECT count(*) AS lines,
               min(creation_date) AS first_line,
               max(creation_date) AS last_line
        FROM procurement_and_sourcing.pas_transfer_order_reception_line
    """,
    "agreements": """
        SELECT
          (SELECT count(*) FROM commercial_agreements.cag_account_agreement) AS agreements,
          (SELECT count(*) FROM commercial_agreements.cag_account_agreement_installment) AS installments,
          (SELECT count(*) FROM commercial_agreements.cag_installment_rappel_scale) AS rappel_scales,
          (SELECT count(*) FROM commercial_agreements.cag_account_agreement_scope_item) AS item_scopes,
          (SELECT count(*) FROM commercial_agreements.cag_account_agreement_scope_store) AS store_scopes,
          (SELECT count(*) FROM commercial_agreements.account_agreement_counterprestation) AS counterprestations
    """,
    "base_prices": """
        SELECT
          (SELECT count(*) FROM inventory.inv_product) AS products,
          (SELECT count(*) FROM inventory.inv_product WHERE base_price > 0) AS products_positive_price,
          (SELECT count(*) FROM inventory.inv_product_supplier) AS product_suppliers,
          (SELECT count(*) FROM inventory.inv_product_supplier WHERE base_price > 0) AS product_suppliers_positive_price,
          (SELECT max(timestamp) FROM inventory.inv_product) AS latest_product_timestamp,
          (SELECT max(timestamp) FROM inventory.inv_product_supplier) AS latest_product_supplier_timestamp
    """,
    "replica_identity": """
        SELECT
          (SELECT count(*) FROM stock_management.stk_stock_product sp JOIN inventory.inv_product ip USING (id)) AS stock_inventory_product_id_matches,
          (SELECT count(*) FROM stock_management.stk_stock_product) AS stock_products,
          (SELECT count(*) FROM procurement_and_sourcing.pas_product pp JOIN inventory.inv_product ip USING (id)) AS pas_inventory_product_id_matches,
          (SELECT count(*) FROM procurement_and_sourcing.pas_product) AS pas_products,
          (SELECT count(*) FROM stock_management.stk_stock_site ss JOIN procurement_and_sourcing.pas_site ps USING (id)) AS stock_pas_site_id_matches,
          (SELECT count(*) FROM stock_management.stk_stock_site) AS stock_sites,
          (SELECT count(*) FROM procurement_and_sourcing.pas_site) AS pas_sites
    """,
    "last_movement_coverage": """
        SELECT count(*) AS stock_positions,
               count(*) FILTER (WHERE m.last_event IS NOT NULL) AS positions_with_movement,
               count(*) FILTER (WHERE m.last_event IS NULL) AS positions_without_movement
        FROM stock_management.stk_stock s
        LEFT JOIN (
            SELECT product_id, site_id, max(coalesce(date_and_time, timestamp)) AS last_event
            FROM stock_management.stk_stock_movement
            GROUP BY product_id, site_id
        ) m USING (product_id, site_id)
    """,
    "replicator_movements": """
        SELECT count(*) AS rows,
               count(DISTINCT (product_id, site_id)) AS product_sites,
               min(date_and_time) AS first_event,
               max(date_and_time) AS last_event,
               min(timestamp) AS first_timestamp,
               max(timestamp) AS last_timestamp,
               count(*) FILTER (WHERE custom_1 IS NOT NULL) AS with_custom_1,
               count(*) FILTER (WHERE custom_2 IS NOT NULL) AS with_custom_2,
               count(*) FILTER (WHERE custom_3 IS NOT NULL) AS with_custom_3,
               count(*) FILTER (WHERE custom_4 IS NOT NULL) AS with_custom_4
        FROM procurement_and_sourcing.pas_stock_movement_replicator
    """,
    "replicator_statuses": """
        SELECT status, stock_movement_type_id, count(*) AS rows
        FROM procurement_and_sourcing.pas_stock_movement_replicator
        GROUP BY status, stock_movement_type_id
        ORDER BY rows DESC, status, stock_movement_type_id
    """,
    "replicator_to_stock_service": """
        SELECT count(*) AS replicator_rows,
               count(sm.id) AS matched_stk_movement_id
        FROM procurement_and_sourcing.pas_stock_movement_replicator r
        LEFT JOIN stock_management.stk_stock_movement sm ON sm.id = r.id
    """,
    "replicator_position_coverage": """
        SELECT count(*) AS stock_positions,
               count(*) FILTER (WHERE m.last_event IS NOT NULL) AS positions_with_replicator_movement,
               count(*) FILTER (WHERE m.last_event IS NULL) AS positions_without_replicator_movement
        FROM stock_management.stk_stock s
        LEFT JOIN (
            SELECT product_id, site_id, max(coalesce(date_and_time::timestamp, timestamp)) AS last_event
            FROM procurement_and_sourcing.pas_stock_movement_replicator
            GROUP BY product_id, site_id
        ) m USING (product_id, site_id)
    """,
    "reception_outbox": """
        SELECT status, count(*) AS rows, min(timestamp) AS first_timestamp,
               max(timestamp) AS last_timestamp, max(attempts) AS max_attempts
        FROM procurement_and_sourcing.pas_reception_output
        GROUP BY status
        ORDER BY status
    """,
}


def rows_as_dicts(cursor):
    names = [column.name for column in cursor.description]
    return [dict(zip(names, row)) for row in cursor.fetchall()]


def main() -> None:
    report = {}
    with connect() as connection, connection.cursor() as cursor:
        for name, query in QUERIES.items():
            cursor.execute(query)
            report[name] = rows_as_dicts(cursor)
    print(json.dumps(report, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
