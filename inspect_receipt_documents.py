"""Metadatos y perfil agregado del circuito documental de recepciones/OCR."""

from __future__ import annotations

import json

from inspect_connexa import connect


SCHEMAS_TABLES = (
    ("mail_processor", "mail_inbox"),
    ("mail_processor", "mail_attachment"),
    ("mail_processor", "attachment_data"),
    ("mail_processor", "attachment_product_line"),
    ("mail_processor", "attachment_product_line_discount_rate"),
    ("mail_processor", "attachment_header_discount_value"),
    ("mail_processor", "attachment_iibb_value"),
    ("mail_processor", "attachment_custom_tax"),
    ("mail_processor", "processing_log"),
    ("mail_processor", "pending_to_reprocess_attachments"),
    ("procurement_and_sourcing", "pas_purchase_order_reception_document"),
    ("procurement_and_sourcing", "pas_purchase_order_reception"),
    ("procurement_and_sourcing", "pas_purchase_order_reception_line"),
    ("diarco_prod_connexa_public_link", "acp_purchase_invoice"),
    ("diarco_prod_connexa_public_link", "acp_purchase_invoice_line"),
)


def dict_rows(cursor):
    names = [column.name for column in cursor.description]
    return [dict(zip(names, row)) for row in cursor.fetchall()]


def main() -> None:
    report = {}
    with connect() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT table_schema, table_name, ordinal_position, column_name,
                   data_type, is_nullable
            FROM information_schema.columns
            WHERE (table_schema, table_name) IN %s
            ORDER BY table_schema, table_name, ordinal_position
            """,
            (SCHEMAS_TABLES,),
        )
        columns = {}
        for row in dict_rows(cursor):
            key = f"{row['table_schema']}.{row['table_name']}"
            columns.setdefault(key, []).append(
                f"{row['column_name']}:{row['data_type']}"
                + ("?" if row["is_nullable"] == "YES" else "")
            )
        report["columns"] = columns

        cursor.execute(
            """
            SELECT schemaname, relname, n_live_tup
            FROM pg_stat_user_tables
            WHERE schemaname = 'mail_processor'
               OR (schemaname = 'procurement_and_sourcing'
                   AND relname = 'pas_purchase_order_reception_document')
            ORDER BY schemaname, relname
            """
        )
        report["estimated_rows"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT
              (SELECT count(*) FROM mail_processor.mail_inbox) AS mails,
              (SELECT count(*) FROM mail_processor.mail_attachment) AS attachments,
              (SELECT count(*) FROM mail_processor.attachment_data) AS extracted_documents,
              (SELECT count(*) FROM mail_processor.attachment_product_line) AS extracted_lines,
              (SELECT count(*) FROM mail_processor.attachment_iibb_value) AS iibb_values,
              (SELECT count(*) FROM mail_processor.attachment_custom_tax) AS custom_taxes,
              (SELECT count(*) FROM mail_processor.pending_to_reprocess_attachments) AS pending_reprocess,
              (SELECT count(*) FROM procurement_and_sourcing.pas_purchase_order_reception_document) AS reception_documents
            """
        )
        report["counts"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT is_processed,
                   (error_message IS NOT NULL) AS has_error,
                   data_updated_manually,
                   supplier_sends_edi,
                   count(*) AS rows
            FROM mail_processor.mail_attachment
            GROUP BY is_processed, (error_message IS NOT NULL),
                     data_updated_manually, supplier_sends_edi
            ORDER BY rows DESC
            """
        )
        report["attachment_statuses"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT count(*) AS documents,
                   count(*) FILTER (WHERE supplier_tax_id IS NOT NULL) AS with_supplier_tax_id,
                   count(*) FILTER (WHERE invoice_type IS NOT NULL) AS with_invoice_type,
                   count(*) FILTER (WHERE point_of_sale IS NOT NULL) AS with_point_of_sale,
                   count(*) FILTER (WHERE invoice_number IS NOT NULL) AS with_invoice_number,
                   count(*) FILTER (WHERE invoice_date IS NOT NULL) AS with_invoice_date,
                   count(*) FILTER (WHERE cae_number IS NOT NULL) AS with_cae,
                   count(*) FILTER (WHERE document_reference_pc IS NOT NULL) AS with_purchase_reference,
                   count(*) FILTER (WHERE document_reference_re IS NOT NULL) AS with_reception_reference,
                   count(*) FILTER (WHERE net_amount IS NOT NULL) AS with_net_amount,
                   count(*) FILTER (WHERE total_amount IS NOT NULL) AS with_total_amount,
                   count(*) FILTER (WHERE vat_21_amount IS NOT NULL OR vat_105_amount IS NOT NULL) AS with_vat,
                   count(*) FILTER (WHERE iibb_total_amount IS NOT NULL) AS with_iibb
            FROM mail_processor.attachment_data
            """
        )
        report["extraction_coverage"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT invoice_type, count(*) AS rows
            FROM mail_processor.attachment_data
            GROUP BY invoice_type
            ORDER BY rows DESC
            """
        )
        report["document_types"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT count(*) AS duplicate_natural_keys,
                   coalesce(sum(rows - 1), 0) AS extra_documents
            FROM (
                SELECT supplier_tax_id, invoice_type, point_of_sale, invoice_number,
                       count(*) AS rows
                FROM mail_processor.attachment_data
                WHERE supplier_tax_id IS NOT NULL
                  AND invoice_type IS NOT NULL
                  AND point_of_sale IS NOT NULL
                  AND invoice_number IS NOT NULL
                GROUP BY supplier_tax_id, invoice_type, point_of_sale, invoice_number
                HAVING count(*) > 1
            ) duplicates
            """
        )
        report["natural_key_duplicates"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT count(*) AS lines,
                   count(*) FILTER (WHERE item_code IS NOT NULL) AS with_item_code,
                   count(*) FILTER (WHERE ean_13 IS NOT NULL) AS with_ean,
                   count(*) FILTER (WHERE quantity IS NOT NULL) AS with_quantity,
                   count(*) FILTER (WHERE unit_price IS NOT NULL) AS with_unit_price,
                   count(*) FILTER (WHERE subtotal IS NOT NULL) AS with_subtotal,
                   count(*) FILTER (WHERE vat_rate IS NOT NULL) AS with_vat_rate,
                   count(*) FILTER (WHERE unit_price_with_discounts IS NOT NULL) AS with_net_unit_price,
                   count(*) FILTER (WHERE unit_price_with_discounts_and_internal_taxes IS NOT NULL)
                       AS with_net_unit_price_and_internal_taxes
            FROM mail_processor.attachment_product_line
            """
        )
        report["line_extraction_coverage"] = dict_rows(cursor)

        cursor.execute(
            """
            SELECT to_jsonb(t) AS document_type
            FROM procurement_and_sourcing.pas_purchase_order_reception_type_document t
            ORDER BY id
            """
        )
        report["reception_document_type_catalog"] = dict_rows(cursor)

    print(json.dumps(report, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
