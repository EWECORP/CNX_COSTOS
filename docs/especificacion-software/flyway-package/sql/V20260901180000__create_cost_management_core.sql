-- CNX-COST-CR-001 / migracion 1 de 4
-- VERSION PROVISIONAL. CORE debe confirmar o renombrar.
-- Alcance inicial: Desarrollo (PGD_HOST). NO EJECUTAR fuera de CORE.
-- Cambio aditivo, sin backfill ni datos de prueba.

SET lock_timeout = '5s';
SET statement_timeout = '60s';

DO $guard$
BEGIN
    IF current_database() NOT IN (
        'connexa_platform', 'connexa_platform_test', 'connexa_platform_ms'
    ) THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: base no autorizada (%)', current_database();
    END IF;
    IF current_setting('server_version_num')::integer < 140000 THEN
        RAISE EXCEPTION 'CNX-COST-CR-001 requiere PostgreSQL 14 o superior';
    END IF;
    IF to_regclass('cost_management.cst_cost_event') IS NOT NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: cost_management ya contiene el nucleo';
    END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS cost_management;

COMMENT ON SCHEMA cost_management IS
'Ledger, posiciones y proyecciones de costos comerciales de CONNEXA.';

CREATE TABLE cost_management.cst_cost_policy (
    company_id uuid NOT NULL,
    event_type varchar(50) NOT NULL,
    version varchar(40) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    affects_quantity boolean NOT NULL,
    affects_inventory_value boolean NOT NULL,
    affects_commercial_cost boolean NOT NULL,
    valuation_method varchar(50) NOT NULL,
    parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_cst_cost_policy PRIMARY KEY (company_id, event_type, version),
    CONSTRAINT ck_cst_cost_policy_validity
        CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_cst_cost_policy_parameters
        CHECK (jsonb_typeof(parameters) = 'object')
);

CREATE TABLE cost_management.cst_cost_event (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    event_type varchar(50) NOT NULL,
    status varchar(20) NOT NULL,
    source_service varchar(80) NOT NULL,
    source_event_id varchar(160) NOT NULL,
    source_document_type varchar(80) NOT NULL,
    source_document_id varchar(160) NOT NULL,
    effective_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    original_currency_code char(3) NOT NULL DEFAULT 'ARS',
    original_amount numeric(20,4),
    exchange_rate numeric(20,10),
    exchange_rate_date date,
    exchange_rate_source varchar(80),
    policy_version varchar(40) NOT NULL,
    reversal_of_event_id uuid,
    correlation_id uuid,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_cst_cost_event PRIMARY KEY (id),
    CONSTRAINT uq_cst_cost_event_source
        UNIQUE (company_id, source_service, source_event_id),
    CONSTRAINT fk_cst_cost_event_reversal
        FOREIGN KEY (reversal_of_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_cost_event_status
        CHECK (status IN ('PENDING', 'POSTED', 'REVERSED', 'REJECTED')),
    CONSTRAINT ck_cst_cost_event_currency
        CHECK (currency_code ~ '^[A-Z]{3}$' AND original_currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_cst_cost_event_exchange_rate
        CHECK (exchange_rate IS NULL OR exchange_rate > 0),
    CONSTRAINT ck_cst_cost_event_metadata
        CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE cost_management.cst_cost_event_line (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    line_number integer NOT NULL,
    source_line_id varchar(160),
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    counterpart_site_id uuid,
    base_uom_id varchar(40) NOT NULL,
    source_uom_id varchar(40),
    source_quantity numeric(20,6),
    uom_conversion_factor numeric(20,8),
    quantity_delta numeric(20,6) NOT NULL,
    unit_cost numeric(20,8),
    value_delta numeric(20,4) NOT NULL,
    quantity_before numeric(20,6) NOT NULL,
    quantity_after numeric(20,6) NOT NULL,
    value_before numeric(20,4) NOT NULL,
    value_after numeric(20,4) NOT NULL,
    wac_before numeric(20,8),
    wac_after numeric(20,8),
    provisional boolean NOT NULL DEFAULT false,
    CONSTRAINT pk_cst_cost_event_line PRIMARY KEY (id),
    CONSTRAINT fk_cst_cost_event_line_event
        FOREIGN KEY (event_id) REFERENCES cost_management.cst_cost_event(id)
        ON DELETE RESTRICT,
    CONSTRAINT uq_cst_cost_event_line_number UNIQUE (event_id, line_number),
    CONSTRAINT ck_cst_cost_event_line_number CHECK (line_number > 0),
    CONSTRAINT ck_cst_cost_event_line_uom_factor
        CHECK (uom_conversion_factor IS NULL OR uom_conversion_factor > 0),
    CONSTRAINT ck_cst_cost_event_line_quantity
        CHECK (quantity_after = quantity_before + quantity_delta),
    CONSTRAINT ck_cst_cost_event_line_value
        CHECK (value_after = value_before + value_delta)
);

CREATE TABLE cost_management.cst_cost_component (
    id uuid NOT NULL,
    event_line_id uuid NOT NULL,
    component_type varchar(50) NOT NULL,
    amount numeric(20,4) NOT NULL,
    rate numeric(12,8),
    capitalizes_inventory boolean NOT NULL,
    affects_commercial_cost boolean NOT NULL,
    posts_to_profit_and_loss boolean NOT NULL,
    agreement_id uuid,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_cst_cost_component PRIMARY KEY (id),
    CONSTRAINT fk_cst_cost_component_line
        FOREIGN KEY (event_line_id)
        REFERENCES cost_management.cst_cost_event_line(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_cost_component_evidence
        CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE cost_management.cst_commercial_cost_version (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    method varchar(50) NOT NULL,
    status varchar(20) NOT NULL,
    base_cost numeric(20,8) NOT NULL,
    commercial_net_cost numeric(20,8) NOT NULL,
    calculation_hash varchar(128) NOT NULL,
    inputs jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    approved_at timestamptz,
    published_at timestamptz,
    CONSTRAINT pk_cst_commercial_cost_version PRIMARY KEY (id),
    CONSTRAINT uq_cst_commercial_cost_version
        UNIQUE (company_id, product_id, base_uom_id, currency_code, valid_from),
    CONSTRAINT ck_cst_commercial_cost_status
        CHECK (status IN (
            'DRAFT', 'CALCULATED', 'UNDER_REVIEW', 'APPROVED',
            'PUBLISHED', 'SUPERSEDED'
        )),
    CONSTRAINT ck_cst_commercial_cost_validity
        CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_cst_commercial_cost_inputs CHECK (jsonb_typeof(inputs) = 'object')
);

CREATE TABLE cost_management.cst_site_cost_position (
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    quantity_on_hand numeric(20,6) NOT NULL,
    inventory_value numeric(20,4) NOT NULL,
    local_inventory_wac numeric(20,8),
    last_stock_event_id uuid,
    last_cost_event_id uuid,
    last_effective_at timestamptz,
    provisional boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_cst_site_cost_position
        PRIMARY KEY (company_id, product_id, site_id, base_uom_id, currency_code),
    CONSTRAINT fk_cst_site_position_stock_event
        FOREIGN KEY (last_stock_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cst_site_position_cost_event
        FOREIGN KEY (last_cost_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_site_cost_position_version CHECK (version >= 0)
);

CREATE TABLE cost_management.cst_company_cost_position (
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    quantity_on_hand numeric(20,6) NOT NULL,
    inventory_value numeric(20,4) NOT NULL,
    company_inventory_wac numeric(20,8),
    company_commercial_net_cost numeric(20,8),
    commercial_cost_version_id uuid,
    last_event_id uuid,
    version bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_cst_company_cost_position
        PRIMARY KEY (company_id, product_id, base_uom_id, currency_code),
    CONSTRAINT fk_cst_company_position_version
        FOREIGN KEY (commercial_cost_version_id)
        REFERENCES cost_management.cst_commercial_cost_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cst_company_position_event
        FOREIGN KEY (last_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_company_cost_position_version CHECK (version >= 0)
);

COMMENT ON COLUMN cost_management.cst_commercial_cost_version.commercial_net_cost IS
'Costo Neto Comercial Unificado de compania/cadena para Pricing y margen objetivo.';
COMMENT ON COLUMN cost_management.cst_site_cost_position.local_inventory_wac IS
'CPP local vigente; valoriza inventario y nuevas salidas de la sucursal.';
COMMENT ON COLUMN cost_management.cst_cost_event_line.unit_cost IS
'Costo local congelado en el evento; base historica de costo de venta y rentabilidad de sucursal.';
COMMENT ON COLUMN cost_management.cst_company_cost_position.company_commercial_net_cost IS
'Proyeccion vigente del Costo Neto Comercial Unificado publicado para la compania/cadena.';

CREATE TABLE cost_management.cst_adjustment_allocation (
    id uuid NOT NULL,
    adjustment_event_line_id uuid NOT NULL,
    target_event_line_id uuid,
    product_id uuid NOT NULL,
    site_id uuid,
    allocation_method varchar(40) NOT NULL,
    allocation_scope varchar(40) NOT NULL,
    allocation_basis numeric(20,8),
    allocated_amount numeric(20,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_cst_adjustment_allocation PRIMARY KEY (id),
    CONSTRAINT fk_cst_adjustment_source
        FOREIGN KEY (adjustment_event_line_id)
        REFERENCES cost_management.cst_cost_event_line(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cst_adjustment_target
        FOREIGN KEY (target_event_line_id)
        REFERENCES cost_management.cst_cost_event_line(id) ON DELETE RESTRICT
);

CREATE TABLE cost_management.cst_tax_treatment_policy (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    tax_type varchar(50) NOT NULL,
    jurisdiction_code varchar(40),
    product_id uuid,
    category_id uuid,
    supplier_id uuid,
    operation_type varchar(50) NOT NULL,
    scope_key varchar(200) NOT NULL,
    recoverable_rate numeric(12,8) NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    version varchar(40) NOT NULL,
    approved_by varchar(160) NOT NULL,
    approved_at timestamptz NOT NULL,
    CONSTRAINT pk_cst_tax_treatment_policy PRIMARY KEY (id),
    CONSTRAINT uq_cst_tax_treatment_policy
        UNIQUE (company_id, tax_type, operation_type, scope_key, version),
    CONSTRAINT ck_cst_tax_recoverable_rate
        CHECK (recoverable_rate >= 0 AND recoverable_rate <= 1),
    CONSTRAINT ck_cst_tax_policy_validity
        CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE cost_management.cst_in_transit_position (
    company_id uuid NOT NULL,
    transfer_id uuid NOT NULL,
    transfer_line_id uuid NOT NULL,
    product_id uuid NOT NULL,
    origin_site_id uuid NOT NULL,
    destination_site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    quantity numeric(20,6) NOT NULL,
    transported_value numeric(20,4) NOT NULL,
    freight_value numeric(20,4) NOT NULL DEFAULT 0,
    dispatched_at timestamptz NOT NULL,
    received_at timestamptz,
    last_event_id uuid NOT NULL,
    CONSTRAINT pk_cst_in_transit_position
        PRIMARY KEY (company_id, transfer_line_id),
    CONSTRAINT fk_cst_in_transit_event
        FOREIGN KEY (last_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_in_transit_sites
        CHECK (origin_site_id <> destination_site_id),
    CONSTRAINT ck_cst_in_transit_quantity CHECK (quantity >= 0),
    CONSTRAINT ck_cst_in_transit_freight CHECK (freight_value >= 0),
    CONSTRAINT ck_cst_in_transit_dates
        CHECK (received_at IS NULL OR received_at >= dispatched_at)
);

CREATE TABLE cost_management.cst_cost_approval (
    id uuid NOT NULL,
    commercial_cost_version_id uuid NOT NULL,
    stage varchar(40) NOT NULL,
    decision varchar(20) NOT NULL,
    actor_id varchar(160) NOT NULL,
    actor_role varchar(80) NOT NULL,
    reason text,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    decided_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_cst_cost_approval PRIMARY KEY (id),
    CONSTRAINT fk_cst_cost_approval_version
        FOREIGN KEY (commercial_cost_version_id)
        REFERENCES cost_management.cst_commercial_cost_version(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_cost_approval_decision
        CHECK (decision IN ('APPROVED', 'REJECTED')),
    CONSTRAINT ck_cst_cost_approval_evidence
        CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE cost_management.cst_audit_entry (
    id uuid NOT NULL,
    aggregate_type varchar(60) NOT NULL,
    aggregate_id varchar(160) NOT NULL,
    action varchar(60) NOT NULL,
    actor_id varchar(160) NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    policy_version varchar(40),
    document_hash varchar(128),
    correlation_id uuid,
    before_state jsonb,
    after_state jsonb,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_cst_audit_entry PRIMARY KEY (id),
    CONSTRAINT ck_cst_audit_evidence CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE cost_management.cst_reconciliation (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    compared_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    stock_quantity numeric(20,6) NOT NULL,
    costing_quantity numeric(20,6) NOT NULL,
    quantity_difference numeric(20,6) NOT NULL,
    status varchar(20) NOT NULL,
    resolution_event_id uuid,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_cst_reconciliation PRIMARY KEY (id),
    CONSTRAINT fk_cst_reconciliation_resolution
        FOREIGN KEY (resolution_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_reconciliation_status
        CHECK (status IN ('MATCHED', 'DIFFERENCE', 'RESOLVED')),
    CONSTRAINT ck_cst_reconciliation_quantity
        CHECK (quantity_difference = stock_quantity - costing_quantity),
    CONSTRAINT ck_cst_reconciliation_details CHECK (jsonb_typeof(details) = 'object')
);

CREATE TABLE cost_management.cst_inbox_event (
    id uuid NOT NULL,
    source_service varchar(80) NOT NULL,
    source_event_id varchar(160) NOT NULL,
    event_type varchar(80) NOT NULL,
    payload_hash varchar(128) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'RECEIVED',
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    processed_at timestamptz,
    error_detail text,
    CONSTRAINT pk_cst_inbox_event PRIMARY KEY (id),
    CONSTRAINT uq_cst_inbox_event_source UNIQUE (source_service, source_event_id),
    CONSTRAINT ck_cst_inbox_event_status
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'REJECTED', 'FAILED'))
);

CREATE TABLE cost_management.cst_outbox_event (
    id uuid NOT NULL,
    aggregate_type varchar(60) NOT NULL,
    aggregate_id varchar(160) NOT NULL,
    event_type varchar(80) NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    published_at timestamptz,
    attempts integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_cst_outbox_event PRIMARY KEY (id),
    CONSTRAINT ck_cst_outbox_attempts CHECK (attempts >= 0),
    CONSTRAINT ck_cst_outbox_payload CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX ix_cst_event_effective
    ON cost_management.cst_cost_event (company_id, effective_at, id)
    WHERE status = 'POSTED';
CREATE INDEX ix_cst_event_document
    ON cost_management.cst_cost_event
        (company_id, source_document_type, source_document_id);
CREATE INDEX ix_cst_event_line_product_site
    ON cost_management.cst_cost_event_line (product_id, site_id, event_id);
CREATE INDEX ix_cst_component_line
    ON cost_management.cst_cost_component (event_line_id, component_type);
CREATE UNIQUE INDEX ux_cst_commercial_cost_published
    ON cost_management.cst_commercial_cost_version
        (company_id, product_id, base_uom_id, currency_code)
    WHERE status = 'PUBLISHED' AND valid_to IS NULL;
CREATE INDEX ix_cst_adjustment_target
    ON cost_management.cst_adjustment_allocation (target_event_line_id)
    WHERE target_event_line_id IS NOT NULL;
CREATE INDEX ix_cst_in_transit_open
    ON cost_management.cst_in_transit_position
        (company_id, destination_site_id, dispatched_at)
    WHERE received_at IS NULL;
CREATE INDEX ix_cst_approval_version
    ON cost_management.cst_cost_approval
        (commercial_cost_version_id, stage, decided_at);
CREATE INDEX ix_cst_audit_aggregate
    ON cost_management.cst_audit_entry
        (aggregate_type, aggregate_id, occurred_at, id);
CREATE INDEX ix_cst_reconciliation_open
    ON cost_management.cst_reconciliation
        (company_id, site_id, compared_at DESC)
    WHERE status = 'DIFFERENCE';
CREATE INDEX ix_cst_inbox_pending
    ON cost_management.cst_inbox_event (received_at, id)
    WHERE status = 'RECEIVED';
CREATE INDEX ix_cst_outbox_pending
    ON cost_management.cst_outbox_event (created_at, id)
    WHERE published_at IS NULL;

DO $verify$
BEGIN
    IF to_regclass('cost_management.cst_cost_event') IS NULL
       OR to_regclass('cost_management.cst_site_cost_position') IS NULL
       OR to_regclass('cost_management.cst_outbox_event') IS NULL THEN
        RAISE EXCEPTION 'CNX-COST-CR-001: verificacion del nucleo fallida';
    END IF;
END
$verify$;
