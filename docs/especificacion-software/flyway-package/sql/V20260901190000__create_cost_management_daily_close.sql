-- CNX-COST-CR-001
-- Migracion Flyway candidata. VERSION PROVISIONAL: CORE debe confirmar o renombrar.
-- Alcance inicial solicitado: Desarrollo (PGD_HOST / connexa_platform).
-- PGT_HOST es Testing. PGP_HOST es Produccion.
-- NO EJECUTAR fuera del proceso controlado de CORE.
-- Migracion 2 de 4. Requiere el nucleo cost_management.
-- Cambio aditivo: crea estructura vacia, sin backfill ni datos de prueba.

SET lock_timeout = '5s';
SET statement_timeout = '60s';

DO $guard$
BEGIN
    IF current_database() NOT IN (
        'connexa_platform',
        'connexa_platform_test',
        'connexa_platform_ms'
    ) THEN
        RAISE EXCEPTION
            'CNX-COST-CR-001: base no autorizada (%)', current_database();
    END IF;

    IF current_setting('server_version_num')::integer < 140000 THEN
        RAISE EXCEPTION
            'CNX-COST-CR-001 requiere PostgreSQL 14 o superior';
    END IF;

    IF to_regclass('cost_management.cst_cost_event') IS NULL THEN
        RAISE EXCEPTION
            'CNX-COST-CR-001: aplicar primero create_cost_management_core';
    END IF;

    IF to_regclass('cost_management.cst_site_daily_close') IS NOT NULL
       OR to_regclass('cost_management.cst_site_daily_balance') IS NOT NULL THEN
        RAISE EXCEPTION
            'CNX-COST-CR-001: existen objetos destino; revisar drift antes de continuar';
    END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS cost_management;

COMMENT ON SCHEMA cost_management IS
'Ledger y proyecciones de costos comerciales de CONNEXA.';

CREATE TABLE cost_management.cst_site_daily_close (
    id uuid NOT NULL,
    company_id uuid NOT NULL,
    site_id uuid NOT NULL,
    business_date date NOT NULL,
    timezone_name varchar(80) NOT NULL
        DEFAULT 'America/Argentina/Buenos_Aires',
    cutoff_at timestamptz NOT NULL,
    close_version bigint NOT NULL,
    status varchar(20) NOT NULL,
    last_stock_event_id uuid,
    last_cost_event_id uuid,
    events_recorded_through timestamptz NOT NULL,
    expected_position_count bigint,
    generated_position_count bigint NOT NULL DEFAULT 0,
    quantity_control_by_uom jsonb NOT NULL DEFAULT '{}'::jsonb,
    total_inventory_value_control numeric(24,4),
    calculation_hash varchar(128),
    supersedes_close_id uuid,
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    closed_at timestamptz,
    reopened_at timestamptz,
    failure_code varchar(80),
    failure_detail jsonb,

    CONSTRAINT pk_cst_site_daily_close
        PRIMARY KEY (id),
    CONSTRAINT uq_cst_site_daily_close_version
        UNIQUE (company_id, site_id, business_date, close_version),
    CONSTRAINT uq_cst_site_daily_close_identity
        UNIQUE (id, company_id, site_id, business_date),
    CONSTRAINT fk_cst_site_daily_close_supersedes
        FOREIGN KEY (supersedes_close_id)
        REFERENCES cost_management.cst_site_daily_close(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_cst_site_daily_close_stock_event
        FOREIGN KEY (last_stock_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cst_site_daily_close_cost_event
        FOREIGN KEY (last_cost_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT ck_cst_site_daily_close_version
        CHECK (close_version > 0),
    CONSTRAINT ck_cst_site_daily_close_status
        CHECK (status IN (
            'CALCULATING', 'PROVISIONAL', 'CLOSED', 'SUPERSEDED', 'FAILED'
        )),
    CONSTRAINT ck_cst_site_daily_close_expected_count
        CHECK (expected_position_count IS NULL OR expected_position_count >= 0),
    CONSTRAINT ck_cst_site_daily_close_generated_count
        CHECK (generated_position_count >= 0),
    CONSTRAINT ck_cst_site_daily_close_quantity_control
        CHECK (jsonb_typeof(quantity_control_by_uom) = 'object'),
    CONSTRAINT ck_cst_site_daily_close_supersedes
        CHECK (supersedes_close_id IS NULL OR close_version > 1),
    CONSTRAINT ck_cst_site_daily_close_failure
        CHECK (
            status <> 'FAILED'
            OR (failure_code IS NOT NULL AND failure_detail IS NOT NULL)
        ),
    CONSTRAINT ck_cst_site_daily_close_completed
        CHECK (
            status <> 'CLOSED'
            OR (
                closed_at IS NOT NULL
                AND calculation_hash IS NOT NULL
                AND expected_position_count IS NOT NULL
                AND generated_position_count = expected_position_count
            )
        )
);

COMMENT ON TABLE cost_management.cst_site_daily_close IS
'Cabecera versionada del cierre diario valorizado de una sucursal.';
COMMENT ON COLUMN cost_management.cst_site_daily_close.business_date IS
'Fecha operativa a la que pertenece el cierre.';
COMMENT ON COLUMN cost_management.cst_site_daily_close.cutoff_at IS
'Instante efectivo hasta el cual se reproducen eventos del Kardex.';
COMMENT ON COLUMN cost_management.cst_site_daily_close.events_recorded_through IS
'Watermark tecnico de recepcion de eventos usado para detectar eventos tardios.';
COMMENT ON COLUMN cost_management.cst_site_daily_close.quantity_control_by_uom IS
'Totales de cantidad separados por UOM; no sumar unidades y kilogramos.';
COMMENT ON COLUMN cost_management.cst_site_daily_close.supersedes_close_id IS
'Version CLOSED anterior reemplazada por reapertura y replay.';

CREATE TABLE cost_management.cst_site_daily_balance (
    id uuid NOT NULL,
    daily_close_id uuid NOT NULL,
    company_id uuid NOT NULL,
    site_id uuid NOT NULL,
    business_date date NOT NULL,
    product_id uuid NOT NULL,
    base_uom_id varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'ARS',
    closing_quantity numeric(20,6) NOT NULL,
    closing_inventory_value numeric(20,4) NOT NULL,
    closing_local_wac numeric(20,8),
    last_stock_event_id uuid,
    last_cost_event_id uuid,
    ledger_position_version bigint NOT NULL,
    provisional boolean NOT NULL DEFAULT false,
    calculation_hash varchar(128) NOT NULL,
    generated_at timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_cst_site_daily_balance
        PRIMARY KEY (id),
    CONSTRAINT fk_cst_site_daily_balance_close
        FOREIGN KEY (daily_close_id, company_id, site_id, business_date)
        REFERENCES cost_management.cst_site_daily_close
            (id, company_id, site_id, business_date)
        ON DELETE RESTRICT,
    CONSTRAINT fk_cst_site_daily_balance_stock_event
        FOREIGN KEY (last_stock_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cst_site_daily_balance_cost_event
        FOREIGN KEY (last_cost_event_id)
        REFERENCES cost_management.cst_cost_event(id) ON DELETE RESTRICT,
    CONSTRAINT uq_cst_site_daily_balance_product
        UNIQUE (daily_close_id, product_id, base_uom_id, currency_code),
    CONSTRAINT ck_cst_site_daily_balance_currency
        CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_cst_site_daily_balance_position_version
        CHECK (ledger_position_version >= 0)
);

COMMENT ON TABLE cost_management.cst_site_daily_balance IS
'Cantidad, valor y CPP de un articulo en una version de cierre diario.';
COMMENT ON COLUMN cost_management.cst_site_daily_balance.closing_quantity IS
'Cantidad en la UOM canonica al instante de corte.';
COMMENT ON COLUMN cost_management.cst_site_daily_balance.closing_inventory_value IS
'Valor contable de cierre en la moneda funcional indicada.';
COMMENT ON COLUMN cost_management.cst_site_daily_balance.closing_local_wac IS
'Costo promedio ponderado local al cierre; puede ser nulo para posicion sin costo.';
COMMENT ON COLUMN cost_management.cst_site_daily_balance.last_stock_event_id IS
'Ultimo evento fisico incluido en la linea de cierre.';
COMMENT ON COLUMN cost_management.cst_site_daily_balance.last_cost_event_id IS
'Ultimo evento economico incluido en la linea de cierre.';

CREATE UNIQUE INDEX ux_cst_site_daily_close_current
    ON cost_management.cst_site_daily_close
        (company_id, site_id, business_date)
    WHERE status = 'CLOSED';

CREATE UNIQUE INDEX ux_cst_site_daily_close_processing
    ON cost_management.cst_site_daily_close
        (company_id, site_id, business_date)
    WHERE status IN ('CALCULATING', 'PROVISIONAL');

CREATE UNIQUE INDEX ux_cst_site_daily_close_supersedes
    ON cost_management.cst_site_daily_close (supersedes_close_id)
    WHERE supersedes_close_id IS NOT NULL;

CREATE INDEX ix_cst_site_daily_close_history
    ON cost_management.cst_site_daily_close
        (company_id, site_id, business_date DESC, close_version DESC);

CREATE INDEX ix_cst_site_daily_close_status
    ON cost_management.cst_site_daily_close
        (status, business_date, site_id);

CREATE INDEX ix_cst_site_daily_balance_lookup
    ON cost_management.cst_site_daily_balance
        (company_id, site_id, product_id, business_date DESC);

CREATE INDEX ix_cst_site_daily_balance_product_history
    ON cost_management.cst_site_daily_balance
        (company_id, product_id, business_date DESC, site_id);

DO $verify$
BEGIN
    IF to_regclass('cost_management.cst_site_daily_close') IS NULL
       OR to_regclass('cost_management.cst_site_daily_balance') IS NULL THEN
        RAISE EXCEPTION
            'CNX-COST-CR-001: verificacion final de objetos fallida';
    END IF;
END
$verify$;
