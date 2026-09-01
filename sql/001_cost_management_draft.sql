-- id: CNX-COST-DDL-001
-- version: 0.2 (2026-09-01)
-- estado: borrador alineado con decisiones funcionales 1-20
-- NO EJECUTAR: estructura conceptual sujeta a diseño técnico, revisión contable,
-- fiscal, seguridad, performance y migraciones Flyway.
-- Este archivo no es una migración Flyway. El script desplegable debe surgir de
-- una solicitud formal, ser revisado por Arquitectura y ser aplicado únicamente
-- por CORE mediante promoción escalonada.

CREATE SCHEMA IF NOT EXISTS cost_management;

CREATE TABLE cost_management.cst_cost_policy (
    company_id uuid NOT NULL,
    event_type varchar(50) NOT NULL,
    version varchar(40) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NULL,
    affects_quantity boolean NOT NULL,
    affects_inventory_value boolean NOT NULL,
    affects_commercial_cost boolean NOT NULL,
    valuation_method varchar(50) NOT NULL,
    parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (company_id, event_type, version)
);

CREATE TABLE cost_management.cst_cost_event (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    event_type varchar(50) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('PENDING', 'POSTED', 'REVERSED', 'REJECTED')),
    source_service varchar(80) NOT NULL,
    source_event_id varchar(160) NOT NULL,
    source_document_type varchar(80) NOT NULL,
    source_document_id varchar(160) NOT NULL,
    effective_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    currency_code char(3) NOT NULL,
    original_currency_code char(3) NOT NULL DEFAULT 'ARS',
    original_amount numeric(20,4) NULL,
    exchange_rate numeric(20,10) NULL,
    exchange_rate_date date NULL,
    exchange_rate_source varchar(80) NULL,
    policy_version varchar(40) NOT NULL,
    reversal_of_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    correlation_id uuid NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (source_service, source_event_id)
);

CREATE TABLE cost_management.cst_cost_event_line (
    id uuid PRIMARY KEY,
    event_id uuid NOT NULL REFERENCES cost_management.cst_cost_event(id),
    line_number integer NOT NULL,
    source_line_id varchar(160) NULL,
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    counterpart_site_id uuid NULL,
    base_uom_id varchar(40) NOT NULL,
    source_uom_id varchar(40) NULL,
    source_quantity numeric(20,6) NULL,
    uom_conversion_factor numeric(20,8) NULL,
    quantity_delta numeric(20,6) NOT NULL,
    unit_cost numeric(20,8) NULL,
    value_delta numeric(20,4) NOT NULL,
    quantity_before numeric(20,6) NOT NULL,
    quantity_after numeric(20,6) NOT NULL,
    value_before numeric(20,4) NOT NULL,
    value_after numeric(20,4) NOT NULL,
    wac_before numeric(20,8) NULL,
    wac_after numeric(20,8) NULL,
    provisional boolean NOT NULL DEFAULT false,
    UNIQUE (event_id, line_number)
);

CREATE TABLE cost_management.cst_cost_component (
    id uuid PRIMARY KEY,
    event_line_id uuid NOT NULL REFERENCES cost_management.cst_cost_event_line(id),
    component_type varchar(50) NOT NULL,
    amount numeric(20,4) NOT NULL,
    rate numeric(12,8) NULL,
    capitalizes_inventory boolean NOT NULL,
    affects_commercial_cost boolean NOT NULL,
    posts_to_profit_and_loss boolean NOT NULL,
    agreement_id uuid NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE cost_management.cst_site_cost_position (
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    quantity_on_hand numeric(20,6) NOT NULL,
    inventory_value numeric(20,4) NOT NULL,
    local_inventory_wac numeric(20,8) NULL,
    last_stock_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    last_cost_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    last_effective_at timestamptz NULL,
    provisional boolean NOT NULL DEFAULT false,
    version bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (company_id, product_id, site_id, base_uom_id, currency_code)
);

CREATE TABLE cost_management.cst_company_cost_position (
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    quantity_on_hand numeric(20,6) NOT NULL,
    inventory_value numeric(20,4) NOT NULL,
    company_inventory_wac numeric(20,8) NULL,
    company_commercial_net_cost numeric(20,8) NULL,
    commercial_cost_version_id uuid NULL,
    last_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    version bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (company_id, product_id, base_uom_id, currency_code)
);

CREATE TABLE cost_management.cst_site_daily_close (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    site_id uuid NOT NULL,
    business_date date NOT NULL,
    timezone_name varchar(80) NOT NULL DEFAULT 'America/Argentina/Buenos_Aires',
    cutoff_at timestamptz NOT NULL,
    close_version bigint NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN (
        'CALCULATING', 'PROVISIONAL', 'CLOSED',
        'SUPERSEDED', 'FAILED'
    )),
    last_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    events_recorded_through timestamptz NOT NULL,
    expected_position_count bigint NULL,
    generated_position_count bigint NOT NULL DEFAULT 0,
    quantity_control_by_uom jsonb NOT NULL DEFAULT '{}'::jsonb,
    total_inventory_value_control numeric(24,4) NULL,
    calculation_hash varchar(128) NULL,
    supersedes_close_id uuid NULL
        REFERENCES cost_management.cst_site_daily_close(id),
    started_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz NULL,
    reopened_at timestamptz NULL,
    failure_detail jsonb NULL,
    UNIQUE (company_id, site_id, business_date, close_version),
    UNIQUE (id, company_id, site_id, business_date)
);

CREATE TABLE cost_management.cst_site_daily_balance (
    id uuid PRIMARY KEY,
    daily_close_id uuid NOT NULL
        REFERENCES cost_management.cst_site_daily_close(id),
    company_id uuid NOT NULL,
    site_id uuid NOT NULL,
    business_date date NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    closing_quantity numeric(20,6) NOT NULL,
    closing_inventory_value numeric(20,4) NOT NULL,
    closing_local_wac numeric(20,8) NULL,
    last_stock_event_id uuid NULL
        REFERENCES cost_management.cst_cost_event(id),
    last_cost_event_id uuid NULL
        REFERENCES cost_management.cst_cost_event(id),
    ledger_position_version bigint NOT NULL,
    provisional boolean NOT NULL DEFAULT false,
    calculation_hash varchar(128) NOT NULL,
    generated_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (daily_close_id, company_id, site_id, business_date)
        REFERENCES cost_management.cst_site_daily_close
            (id, company_id, site_id, business_date),
    UNIQUE (daily_close_id, product_id, base_uom_id, currency_code)
);

CREATE TABLE cost_management.cst_commercial_cost_version (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NULL,
    method varchar(50) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('DRAFT', 'CALCULATED', 'UNDER_REVIEW', 'APPROVED', 'PUBLISHED', 'SUPERSEDED')),
    base_cost numeric(20,8) NOT NULL,
    commercial_net_cost numeric(20,8) NOT NULL,
    calculation_hash varchar(128) NOT NULL,
    inputs jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    approved_at timestamptz NULL,
    published_at timestamptz NULL,
    UNIQUE (company_id, product_id, base_uom_id, currency_code, valid_from)
);

ALTER TABLE cost_management.cst_company_cost_position
    ADD CONSTRAINT fk_cst_company_commercial_version
    FOREIGN KEY (commercial_cost_version_id)
    REFERENCES cost_management.cst_commercial_cost_version(id);

CREATE TABLE cost_management.cst_adjustment_allocation (
    id uuid PRIMARY KEY,
    adjustment_event_line_id uuid NOT NULL REFERENCES cost_management.cst_cost_event_line(id),
    target_event_line_id uuid NULL REFERENCES cost_management.cst_cost_event_line(id),
    product_id uuid NOT NULL,
    site_id uuid NULL,
    allocation_method varchar(40) NOT NULL,
    allocation_scope varchar(40) NOT NULL,
    allocation_basis numeric(20,8) NULL,
    allocated_amount numeric(20,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cost_management.cst_tax_treatment_policy (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    tax_type varchar(50) NOT NULL,
    jurisdiction_code varchar(40) NULL,
    product_id uuid NULL,
    category_id uuid NULL,
    supplier_id uuid NULL,
    operation_type varchar(50) NOT NULL,
    scope_key varchar(200) NOT NULL,
    recoverable_rate numeric(12,8) NOT NULL,
    valid_from date NOT NULL,
    valid_to date NULL,
    version varchar(40) NOT NULL,
    approved_by varchar(160) NOT NULL,
    approved_at timestamptz NOT NULL,
    UNIQUE (company_id, tax_type, operation_type, scope_key, version)
);

CREATE TABLE cost_management.cst_in_transit_position (
    company_id uuid NOT NULL,
    transfer_id uuid NOT NULL,
    transfer_line_id uuid NOT NULL,
    product_id uuid NOT NULL,
    origin_site_id uuid NOT NULL,
    destination_site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    quantity numeric(20,6) NOT NULL,
    transported_value numeric(20,4) NOT NULL,
    freight_value numeric(20,4) NOT NULL DEFAULT 0,
    dispatched_at timestamptz NOT NULL,
    received_at timestamptz NULL,
    last_event_id uuid NOT NULL REFERENCES cost_management.cst_cost_event(id),
    PRIMARY KEY (company_id, transfer_line_id)
);

CREATE TABLE cost_management.cst_cost_approval (
    id uuid PRIMARY KEY,
    commercial_cost_version_id uuid NOT NULL
        REFERENCES cost_management.cst_commercial_cost_version(id),
    stage varchar(40) NOT NULL,
    decision varchar(20) NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED')),
    actor_id varchar(160) NOT NULL,
    actor_role varchar(80) NOT NULL,
    reason text NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    decided_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cost_management.cst_audit_entry (
    id uuid PRIMARY KEY,
    aggregate_type varchar(60) NOT NULL,
    aggregate_id varchar(160) NOT NULL,
    action varchar(60) NOT NULL,
    actor_id varchar(160) NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    policy_version varchar(40) NULL,
    document_hash varchar(128) NULL,
    correlation_id uuid NULL,
    before_state jsonb NULL,
    after_state jsonb NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE cost_management.cst_reconciliation (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    site_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    compared_at timestamptz NOT NULL DEFAULT now(),
    stock_quantity numeric(20,6) NOT NULL,
    costing_quantity numeric(20,6) NOT NULL,
    quantity_difference numeric(20,6) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('MATCHED', 'DIFFERENCE', 'RESOLVED')),
    resolution_event_id uuid NULL REFERENCES cost_management.cst_cost_event(id),
    details jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE cost_management.cst_inbox_event (
    id uuid PRIMARY KEY,
    source_service varchar(80) NOT NULL,
    source_event_id varchar(160) NOT NULL,
    event_type varchar(80) NOT NULL,
    payload_hash varchar(128) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'RECEIVED'
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'REJECTED', 'FAILED')),
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz NULL,
    error_detail text NULL,
    UNIQUE (source_service, source_event_id)
);

CREATE TABLE cost_management.cst_outbox_event (
    id uuid PRIMARY KEY,
    aggregate_type varchar(60) NOT NULL,
    aggregate_id varchar(160) NOT NULL,
    event_type varchar(80) NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz NULL,
    attempts integer NOT NULL DEFAULT 0
);

CREATE INDEX ix_cst_event_effective
    ON cost_management.cst_cost_event (company_id, effective_at, id)
    WHERE status = 'POSTED';

CREATE UNIQUE INDEX ux_cst_site_daily_close_current
    ON cost_management.cst_site_daily_close
       (company_id, site_id, business_date)
    WHERE status = 'CLOSED';

CREATE INDEX ix_cst_site_daily_close_processing
    ON cost_management.cst_site_daily_close
       (company_id, site_id, business_date, close_version DESC)
    WHERE status IN ('CALCULATING', 'PROVISIONAL');

CREATE INDEX ix_cst_site_daily_balance_lookup
    ON cost_management.cst_site_daily_balance
       (company_id, site_id, product_id, business_date DESC);

CREATE INDEX ix_cst_event_line_product_site
    ON cost_management.cst_cost_event_line (product_id, site_id, event_id);

CREATE INDEX ix_cst_commercial_cost_published
    ON cost_management.cst_commercial_cost_version
       (company_id, product_id, valid_from DESC)
    WHERE status = 'PUBLISHED';

CREATE INDEX ix_cst_reconciliation_open
    ON cost_management.cst_reconciliation (company_id, site_id, compared_at DESC)
    WHERE status = 'DIFFERENCE';

CREATE INDEX ix_cst_outbox_pending
    ON cost_management.cst_outbox_event (created_at, id)
    WHERE published_at IS NULL;

CREATE INDEX ix_cst_inbox_pending
    ON cost_management.cst_inbox_event (received_at, id)
    WHERE status = 'RECEIVED';

CREATE INDEX ix_cst_in_transit_open
    ON cost_management.cst_in_transit_position
       (company_id, destination_site_id, dispatched_at)
    WHERE received_at IS NULL;

CREATE INDEX ix_cst_audit_aggregate
    ON cost_management.cst_audit_entry
       (aggregate_type, aggregate_id, occurred_at, id);
