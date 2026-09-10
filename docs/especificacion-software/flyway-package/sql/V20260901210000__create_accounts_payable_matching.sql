-- CNX-COST-CR-001 / migracion 4 de 4
-- VERSION PROVISIONAL. CORE debe confirmar o renombrar.
-- Alcance inicial: Desarrollo (PGD_HOST). NO EJECUTAR fuera de CORE.
-- Capacidad operativa propia de CONNEXA, agnostica del sistema contable.
-- Los adaptadores externos se habilitan por cliente conforme a CNX-COST-ADR-002.
-- Estas tablas no constituyen subledger contable, fiscal ni de proveedores.

SET lock_timeout = '5s';
SET statement_timeout = '60s';

DO $guard$
BEGIN
    IF current_database() NOT IN (
        'connexa_platform', 'connexa_platform_test', 'connexa_platform_ms'
    ) THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: base no autorizada (%)', current_database();
    END IF;
    IF to_regclass('document_management.doc_document') IS NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: aplicar primero document_management';
    END IF;
    IF to_regclass('cost_management.cst_tax_treatment_policy') IS NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: aplicar primero cost_management core';
    END IF;
    IF to_regclass('accounts_payable.ap_invoice') IS NOT NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: accounts_payable ya existe';
    END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS accounts_payable;

COMMENT ON SCHEMA accounts_payable IS
'Documento comercial canonico, conciliacion y comunicacion externa de compras.';

CREATE TABLE accounts_payable.ap_invoice (
    id uuid NOT NULL,
    document_id uuid NOT NULL,
    company_id uuid NOT NULL,
    supplier_id uuid,
    supplier_tax_id varchar(20) NOT NULL,
    invoice_type varchar(30) NOT NULL,
    point_of_sale varchar(10) NOT NULL,
    invoice_number varchar(30) NOT NULL,
    issue_date date NOT NULL,
    due_date date,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    exchange_rate numeric(20,10),
    net_amount numeric(20,4) NOT NULL,
    exempt_amount numeric(20,4) NOT NULL DEFAULT 0,
    non_taxed_amount numeric(20,4) NOT NULL DEFAULT 0,
    tax_amount numeric(20,4) NOT NULL DEFAULT 0,
    other_tax_amount numeric(20,4) NOT NULL DEFAULT 0,
    discount_amount numeric(20,4) NOT NULL DEFAULT 0,
    total_amount numeric(20,4) NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'VALIDATED',
    invoice_version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    external_accepted_at timestamptz,
    CONSTRAINT pk_ap_invoice PRIMARY KEY (id),
    CONSTRAINT fk_ap_invoice_document
        FOREIGN KEY (document_id)
        REFERENCES document_management.doc_document(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_invoice_document UNIQUE (document_id),
    CONSTRAINT uq_ap_invoice_natural_version
        UNIQUE (
            company_id, supplier_tax_id, invoice_type,
            point_of_sale, invoice_number, invoice_version
        ),
    CONSTRAINT ck_ap_invoice_type
        CHECK (invoice_type IN ('INVOICE', 'CREDIT_NOTE', 'DEBIT_NOTE')),
    CONSTRAINT ck_ap_invoice_status
        CHECK (status IN (
            'VALIDATED', 'MATCH_PENDING', 'MATCHED', 'APPROVED',
            'READY_FOR_EXPORT', 'EXPORTED', 'EXTERNAL_ACCEPTED',
            'REJECTED', 'SUPERSEDED'
        )),
    CONSTRAINT ck_ap_invoice_version CHECK (invoice_version > 0),
    CONSTRAINT ck_ap_invoice_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_ap_invoice_exchange_rate
        CHECK (exchange_rate IS NULL OR exchange_rate > 0),
    CONSTRAINT ck_ap_invoice_dates
        CHECK (due_date IS NULL OR due_date >= issue_date)
);

CREATE TABLE accounts_payable.ap_invoice_line (
    id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    line_number integer NOT NULL,
    supplier_item_code varchar(100),
    sku varchar(100),
    ean varchar(30),
    product_id uuid,
    description text,
    quantity numeric(20,6) NOT NULL,
    uom_id varchar(40) NOT NULL,
    uom_conversion_factor numeric(20,8),
    unit_price numeric(20,8),
    gross_amount numeric(20,4),
    discount_amount numeric(20,4) NOT NULL DEFAULT 0,
    net_amount numeric(20,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_invoice_line PRIMARY KEY (id),
    CONSTRAINT fk_ap_invoice_line_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_invoice_line_number UNIQUE (invoice_id, line_number),
    CONSTRAINT ck_ap_invoice_line_number CHECK (line_number > 0),
    CONSTRAINT ck_ap_invoice_line_factor
        CHECK (uom_conversion_factor IS NULL OR uom_conversion_factor > 0)
);

CREATE TABLE accounts_payable.ap_invoice_tax (
    id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    invoice_line_id uuid,
    tax_type varchar(50) NOT NULL,
    regime_code varchar(50),
    jurisdiction_code varchar(40),
    rate numeric(12,8),
    taxable_base numeric(20,4),
    amount numeric(20,4) NOT NULL,
    recoverable_rate numeric(12,8),
    recoverable_amount numeric(20,4),
    capitalizable_amount numeric(20,4),
    treatment_policy_id uuid,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_invoice_tax PRIMARY KEY (id),
    CONSTRAINT fk_ap_invoice_tax_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_invoice_tax_line
        FOREIGN KEY (invoice_line_id)
        REFERENCES accounts_payable.ap_invoice_line(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_invoice_tax_policy
        FOREIGN KEY (treatment_policy_id)
        REFERENCES cost_management.cst_tax_treatment_policy(id) ON DELETE RESTRICT,
    CONSTRAINT ck_ap_invoice_tax_recoverable
        CHECK (recoverable_rate IS NULL OR
               (recoverable_rate >= 0 AND recoverable_rate <= 1))
);

CREATE TABLE accounts_payable.ap_document_relation (
    id uuid NOT NULL,
    source_invoice_id uuid NOT NULL,
    target_invoice_id uuid NOT NULL,
    relation_type varchar(40) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_document_relation PRIMARY KEY (id),
    CONSTRAINT fk_ap_document_relation_source
        FOREIGN KEY (source_invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_document_relation_target
        FOREIGN KEY (target_invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_document_relation
        UNIQUE (source_invoice_id, target_invoice_id, relation_type),
    CONSTRAINT ck_ap_document_relation_distinct
        CHECK (source_invoice_id <> target_invoice_id),
    CONSTRAINT ck_ap_document_relation_type
        CHECK (relation_type IN (
            'CORRECTS', 'CREDITS', 'DEBITS', 'REPLACES', 'REFERENCES'
        ))
);

CREATE TABLE accounts_payable.ap_match (
    id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    match_version integer NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'PENDING',
    tolerance_policy_version varchar(40),
    purchase_order_id uuid,
    reception_id uuid,
    matched_quantity numeric(20,6) NOT NULL DEFAULT 0,
    matched_amount numeric(20,4) NOT NULL DEFAULT 0,
    result_hash varchar(128),
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    CONSTRAINT pk_ap_match PRIMARY KEY (id),
    CONSTRAINT fk_ap_match_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_match_version UNIQUE (invoice_id, match_version),
    CONSTRAINT ck_ap_match_version CHECK (match_version > 0),
    CONSTRAINT ck_ap_match_status
        CHECK (status IN (
            'PENDING', 'AUTO_MATCHED', 'PARTIAL_MATCH', 'EXCEPTION',
            'MANUAL_MATCH', 'APPROVED', 'READY_FOR_EXPORT', 'EXPORTED',
            'EXTERNAL_ACCEPTED', 'REJECTED', 'SUPERSEDED'
        )),
    CONSTRAINT ck_ap_match_dates
        CHECK (completed_at IS NULL OR completed_at >= started_at)
);

CREATE TABLE accounts_payable.ap_match_allocation (
    id uuid NOT NULL,
    match_id uuid NOT NULL,
    invoice_line_id uuid NOT NULL,
    purchase_order_id uuid,
    purchase_order_line_id uuid,
    reception_id uuid,
    reception_line_id uuid,
    product_id uuid NOT NULL,
    site_id uuid,
    allocated_quantity numeric(20,6) NOT NULL,
    uom_id varchar(40) NOT NULL,
    allocated_net_amount numeric(20,4) NOT NULL,
    allocated_tax_amount numeric(20,4) NOT NULL DEFAULT 0,
    allocation_method varchar(40) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_match_allocation PRIMARY KEY (id),
    CONSTRAINT fk_ap_match_allocation_match
        FOREIGN KEY (match_id)
        REFERENCES accounts_payable.ap_match(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_match_allocation_invoice_line
        FOREIGN KEY (invoice_line_id)
        REFERENCES accounts_payable.ap_invoice_line(id) ON DELETE RESTRICT,
    CONSTRAINT ck_ap_match_allocation_reference
        CHECK (
            purchase_order_line_id IS NOT NULL
            OR reception_line_id IS NOT NULL
        )
);

CREATE TABLE accounts_payable.ap_match_exception (
    id uuid NOT NULL,
    match_id uuid NOT NULL,
    allocation_id uuid,
    exception_type varchar(50) NOT NULL,
    severity varchar(20) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'OPEN',
    expected_value jsonb,
    actual_value jsonb,
    tolerance_value jsonb,
    resolution_code varchar(50),
    resolution_reason text,
    resolved_by varchar(160),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    resolved_at timestamptz,
    CONSTRAINT pk_ap_match_exception PRIMARY KEY (id),
    CONSTRAINT fk_ap_match_exception_match
        FOREIGN KEY (match_id)
        REFERENCES accounts_payable.ap_match(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_match_exception_allocation
        FOREIGN KEY (allocation_id)
        REFERENCES accounts_payable.ap_match_allocation(id) ON DELETE RESTRICT,
    CONSTRAINT ck_ap_match_exception_severity
        CHECK (severity IN ('INFO', 'WARNING', 'BLOCKING')),
    CONSTRAINT ck_ap_match_exception_status
        CHECK (status IN ('OPEN', 'ACCEPTED', 'CORRECTED', 'REJECTED')),
    CONSTRAINT ck_ap_match_exception_resolution
        CHECK (
            status = 'OPEN'
            OR (resolved_by IS NOT NULL AND resolved_at IS NOT NULL
                AND resolution_code IS NOT NULL)
        )
);

CREATE TABLE accounts_payable.ap_match_approval (
    id uuid NOT NULL,
    match_id uuid NOT NULL,
    stage varchar(40) NOT NULL,
    decision varchar(20) NOT NULL,
    actor_id varchar(160) NOT NULL,
    actor_role varchar(80) NOT NULL,
    reason text,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    decided_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_match_approval PRIMARY KEY (id),
    CONSTRAINT fk_ap_match_approval_match
        FOREIGN KEY (match_id)
        REFERENCES accounts_payable.ap_match(id) ON DELETE RESTRICT,
    CONSTRAINT ck_ap_match_approval_decision
        CHECK (decision IN ('APPROVED', 'REJECTED')),
    CONSTRAINT ck_ap_match_approval_evidence CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE accounts_payable.ap_credit_note_request (
    id uuid NOT NULL,
    match_id uuid NOT NULL,
    source_invoice_id uuid NOT NULL,
    match_exception_id uuid,
    resulting_credit_note_invoice_id uuid,
    company_id uuid NOT NULL,
    supplier_id uuid,
    supplier_tax_id varchar(20) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    requested_amount numeric(20,4) NOT NULL,
    reason_code varchar(50) NOT NULL,
    reason_detail text NOT NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    status varchar(30) NOT NULL DEFAULT 'DRAFT',
    external_system varchar(80),
    external_reference varchar(160),
    requested_by varchar(160) NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    approved_at timestamptz,
    sent_at timestamptz,
    acknowledged_at timestamptz,
    closed_at timestamptz,
    CONSTRAINT pk_ap_credit_note_request PRIMARY KEY (id),
    CONSTRAINT fk_ap_credit_note_request_match
        FOREIGN KEY (match_id)
        REFERENCES accounts_payable.ap_match(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_credit_note_request_invoice
        FOREIGN KEY (source_invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_credit_note_request_exception
        FOREIGN KEY (match_exception_id)
        REFERENCES accounts_payable.ap_match_exception(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_credit_note_request_result
        FOREIGN KEY (resulting_credit_note_invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_credit_note_request_origin
        UNIQUE (match_id, match_exception_id, reason_code),
    CONSTRAINT ck_ap_credit_note_request_amount CHECK (requested_amount > 0),
    CONSTRAINT ck_ap_credit_note_request_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_ap_credit_note_request_evidence CHECK (jsonb_typeof(evidence) = 'object'),
    CONSTRAINT ck_ap_credit_note_request_status
        CHECK (status IN (
            'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'SENT',
            'ACKNOWLEDGED', 'CREDIT_NOTE_RECEIVED', 'REJECTED',
            'CANCELLED', 'CLOSED'
        )),
    CONSTRAINT ck_ap_credit_note_request_result_status
        CHECK (
            resulting_credit_note_invoice_id IS NULL
            OR status IN ('CREDIT_NOTE_RECEIVED', 'CLOSED')
        )
);

CREATE TABLE accounts_payable.ap_external_exchange (
    id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    match_id uuid,
    credit_note_request_id uuid,
    external_system varchar(80) NOT NULL,
    direction varchar(10) NOT NULL,
    correlation_id varchar(160) NOT NULL,
    payload_hash varchar(128) NOT NULL,
    payload_uri text NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'PENDING',
    attempt_count integer NOT NULL DEFAULT 0,
    sent_at timestamptz,
    responded_at timestamptz,
    response_hash varchar(128),
    response_uri text,
    error_detail text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_ap_external_exchange PRIMARY KEY (id),
    CONSTRAINT fk_ap_external_exchange_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES accounts_payable.ap_invoice(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_external_exchange_match
        FOREIGN KEY (match_id)
        REFERENCES accounts_payable.ap_match(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_external_exchange_credit_note_request
        FOREIGN KEY (credit_note_request_id)
        REFERENCES accounts_payable.ap_credit_note_request(id) ON DELETE RESTRICT,
    CONSTRAINT uq_ap_external_exchange_correlation
        UNIQUE (external_system, direction, correlation_id),
    CONSTRAINT ck_ap_external_exchange_direction
        CHECK (direction IN ('OUTBOUND', 'INBOUND')),
    CONSTRAINT ck_ap_external_exchange_status
        CHECK (status IN (
            'PENDING', 'SENT', 'ACKNOWLEDGED', 'PARTIAL',
            'SUCCEEDED', 'FAILED', 'REJECTED'
        )),
    CONSTRAINT ck_ap_external_exchange_attempts CHECK (attempt_count >= 0)
);

CREATE TABLE accounts_payable.ap_external_exchange_line (
    id uuid NOT NULL,
    exchange_id uuid NOT NULL,
    allocation_id uuid,
    external_line_reference varchar(160),
    status varchar(30) NOT NULL,
    response_code varchar(80),
    response_detail jsonb,
    processed_at timestamptz,
    CONSTRAINT pk_ap_external_exchange_line PRIMARY KEY (id),
    CONSTRAINT fk_ap_external_exchange_line_exchange
        FOREIGN KEY (exchange_id)
        REFERENCES accounts_payable.ap_external_exchange(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ap_external_exchange_line_allocation
        FOREIGN KEY (allocation_id)
        REFERENCES accounts_payable.ap_match_allocation(id) ON DELETE RESTRICT,
    CONSTRAINT ck_ap_external_exchange_line_status
        CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'FAILED'))
);

CREATE INDEX ix_ap_invoice_work
    ON accounts_payable.ap_invoice (status, issue_date, company_id);
CREATE UNIQUE INDEX ux_ap_invoice_natural_current
    ON accounts_payable.ap_invoice
        (company_id, supplier_tax_id, invoice_type, point_of_sale, invoice_number)
    WHERE status NOT IN ('REJECTED', 'SUPERSEDED');
CREATE INDEX ix_ap_invoice_line_product
    ON accounts_payable.ap_invoice_line (product_id, invoice_id)
    WHERE product_id IS NOT NULL;
CREATE INDEX ix_ap_invoice_tax_invoice
    ON accounts_payable.ap_invoice_tax (invoice_id, tax_type, jurisdiction_code);
CREATE INDEX ix_ap_match_work
    ON accounts_payable.ap_match (status, started_at, invoice_id);
CREATE INDEX ix_ap_match_allocation_reception
    ON accounts_payable.ap_match_allocation (reception_line_id)
    WHERE reception_line_id IS NOT NULL;
CREATE INDEX ix_ap_match_exception_open
    ON accounts_payable.ap_match_exception (severity, created_at, match_id)
    WHERE status = 'OPEN';
CREATE INDEX ix_ap_credit_note_request_work
    ON accounts_payable.ap_credit_note_request
        (status, company_id, supplier_tax_id, requested_at);
CREATE INDEX ix_ap_credit_note_request_external
    ON accounts_payable.ap_credit_note_request
        (external_system, external_reference)
    WHERE external_reference IS NOT NULL;
CREATE INDEX ix_ap_external_exchange_pending
    ON accounts_payable.ap_external_exchange (external_system, created_at, id)
    WHERE status IN ('PENDING', 'FAILED');

DO $verify$
BEGIN
    IF to_regclass('accounts_payable.ap_invoice') IS NULL
       OR to_regclass('accounts_payable.ap_match_allocation') IS NULL
       OR to_regclass('accounts_payable.ap_credit_note_request') IS NULL
       OR to_regclass('accounts_payable.ap_external_exchange_line') IS NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: verificacion de conciliacion fallida';
    END IF;
END
$verify$;
