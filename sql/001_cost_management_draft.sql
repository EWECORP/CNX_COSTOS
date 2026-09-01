-- id: CNX-COST-DDL-001
-- estado: borrador
-- NO EJECUTAR: estructura conceptual sujeta a decisiones funcionales.

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

CREATE TABLE cost_management.cst_commercial_cost_version (
    id uuid PRIMARY KEY,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz NULL,
    method varchar(50) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('DRAFT', 'APPROVED', 'PUBLISHED', 'SUPERSEDED')),
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
    allocation_basis numeric(20,8) NULL,
    allocated_amount numeric(20,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
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
