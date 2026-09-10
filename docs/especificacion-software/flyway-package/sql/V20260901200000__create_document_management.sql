-- CNX-COST-CR-001 / migracion 3 de 4
-- VERSION PROVISIONAL. CORE debe confirmar o renombrar.
-- Alcance inicial: Desarrollo (PGD_HOST). NO EJECUTAR fuera de CORE.

SET lock_timeout = '5s';
SET statement_timeout = '60s';

DO $guard$
BEGIN
    IF current_database() NOT IN (
        'connexa_platform', 'connexa_platform_test', 'connexa_platform_ms'
    ) THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: base no autorizada (%)', current_database();
    END IF;
    IF to_regclass('document_management.doc_document') IS NOT NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: document_management ya existe';
    END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS document_management;

COMMENT ON SCHEMA document_management IS
'Documentos originales, archivos y extracciones OCR versionadas.';

CREATE TABLE document_management.doc_document (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    supplier_id uuid,
    supplier_tax_id varchar(20),
    document_type varchar(30) NOT NULL,
    point_of_sale varchar(10),
    document_number varchar(30),
    issue_date date,
    due_date date,
    authorization_code varchar(40),
    authorization_due_date date,
    service_period_from date,
    service_period_to date,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    exchange_rate numeric(20,10),
    net_amount numeric(20,4),
    exempt_amount numeric(20,4),
    non_taxed_amount numeric(20,4),
    tax_amount numeric(20,4),
    other_tax_amount numeric(20,4),
    total_amount numeric(20,4),
    status varchar(30) NOT NULL DEFAULT 'RECEIVED',
    document_version integer NOT NULL DEFAULT 1,
    source_system varchar(80) NOT NULL,
    source_reference varchar(160),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    validated_at timestamptz,
    CONSTRAINT pk_doc_document PRIMARY KEY (id),
    CONSTRAINT ck_doc_document_type
        CHECK (document_type IN (
            'INVOICE', 'CREDIT_NOTE', 'DEBIT_NOTE', 'DELIVERY_NOTE', 'OTHER'
        )),
    CONSTRAINT ck_doc_document_status
        CHECK (status IN (
            'RECEIVED', 'EXTRACTED', 'VALIDATED', 'IDENTIFIED',
            'MANUAL_REVIEW', 'DUPLICATE', 'REJECTED', 'SUPERSEDED'
        )),
    CONSTRAINT ck_doc_document_version CHECK (document_version > 0),
    CONSTRAINT ck_doc_document_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_doc_document_exchange_rate
        CHECK (exchange_rate IS NULL OR exchange_rate > 0),
    CONSTRAINT ck_doc_document_dates
        CHECK (due_date IS NULL OR issue_date IS NULL OR due_date >= issue_date),
    CONSTRAINT ck_doc_document_service_period
        CHECK (
            service_period_to IS NULL OR service_period_from IS NULL
            OR service_period_to >= service_period_from
        )
);

CREATE TABLE document_management.doc_binary (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    binary_version integer NOT NULL DEFAULT 1,
    original_filename varchar(500),
    mime_type varchar(150) NOT NULL,
    byte_size bigint NOT NULL,
    content_hash varchar(128) NOT NULL,
    storage_uri text NOT NULL,
    source_channel varchar(40) NOT NULL,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    supersedes_binary_id uuid,
    CONSTRAINT pk_doc_binary PRIMARY KEY (id),
    CONSTRAINT fk_doc_binary_document
        FOREIGN KEY (document_id)
        REFERENCES document_management.doc_document(id) ON DELETE RESTRICT,
    CONSTRAINT fk_doc_binary_supersedes
        FOREIGN KEY (supersedes_binary_id)
        REFERENCES document_management.doc_binary(id) ON DELETE RESTRICT,
    CONSTRAINT uq_doc_binary_version UNIQUE (document_id, binary_version),
    CONSTRAINT ck_doc_binary_version CHECK (binary_version > 0),
    CONSTRAINT ck_doc_binary_size CHECK (byte_size >= 0)
);

CREATE TABLE document_management.doc_extraction_run (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    binary_id uuid NOT NULL,
    run_number integer NOT NULL,
    engine varchar(100) NOT NULL,
    model_version varchar(100),
    status varchar(20) NOT NULL,
    overall_confidence numeric(7,6),
    raw_result_uri text,
    started_at timestamptz NOT NULL,
    finished_at timestamptz,
    error_detail text,
    CONSTRAINT pk_doc_extraction_run PRIMARY KEY (id),
    CONSTRAINT fk_doc_extraction_document
        FOREIGN KEY (document_id)
        REFERENCES document_management.doc_document(id) ON DELETE RESTRICT,
    CONSTRAINT fk_doc_extraction_binary
        FOREIGN KEY (binary_id)
        REFERENCES document_management.doc_binary(id) ON DELETE RESTRICT,
    CONSTRAINT uq_doc_extraction_run UNIQUE (document_id, run_number),
    CONSTRAINT ck_doc_extraction_run_number CHECK (run_number > 0),
    CONSTRAINT ck_doc_extraction_status
        CHECK (status IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'FAILED', 'REJECTED')),
    CONSTRAINT ck_doc_extraction_confidence
        CHECK (overall_confidence IS NULL OR
               (overall_confidence >= 0 AND overall_confidence <= 1)),
    CONSTRAINT ck_doc_extraction_dates
        CHECK (finished_at IS NULL OR finished_at >= started_at)
);

CREATE TABLE document_management.doc_extracted_field (
    id uuid NOT NULL,
    extraction_run_id uuid NOT NULL,
    field_path varchar(200) NOT NULL,
    occurrence integer NOT NULL DEFAULT 1,
    raw_value text,
    normalized_value jsonb,
    page_number integer,
    bounding_box jsonb,
    confidence numeric(7,6),
    corrected_value jsonb,
    corrected_by varchar(160),
    corrected_at timestamptz,
    CONSTRAINT pk_doc_extracted_field PRIMARY KEY (id),
    CONSTRAINT fk_doc_extracted_field_run
        FOREIGN KEY (extraction_run_id)
        REFERENCES document_management.doc_extraction_run(id) ON DELETE RESTRICT,
    CONSTRAINT uq_doc_extracted_field
        UNIQUE (extraction_run_id, field_path, occurrence),
    CONSTRAINT ck_doc_extracted_occurrence CHECK (occurrence > 0),
    CONSTRAINT ck_doc_extracted_page
        CHECK (page_number IS NULL OR page_number > 0),
    CONSTRAINT ck_doc_extracted_confidence
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
    CONSTRAINT ck_doc_extracted_correction
        CHECK (
            corrected_value IS NULL
            OR (corrected_by IS NOT NULL AND corrected_at IS NOT NULL)
        )
);

CREATE UNIQUE INDEX ux_doc_document_natural_key
    ON document_management.doc_document
        (company_id, supplier_tax_id, document_type, point_of_sale, document_number)
    WHERE supplier_tax_id IS NOT NULL
      AND point_of_sale IS NOT NULL
      AND document_number IS NOT NULL
      AND status NOT IN ('DUPLICATE', 'REJECTED', 'SUPERSEDED');
CREATE INDEX ix_doc_document_work
    ON document_management.doc_document (status, created_at, company_id);
CREATE INDEX ix_doc_binary_hash
    ON document_management.doc_binary (content_hash);
CREATE INDEX ix_doc_extraction_work
    ON document_management.doc_extraction_run (status, started_at);

DO $verify$
BEGIN
    IF to_regclass('document_management.doc_document') IS NULL
       OR to_regclass('document_management.doc_extracted_field') IS NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: verificacion documental fallida';
    END IF;
END
$verify$;
