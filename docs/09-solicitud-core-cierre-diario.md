---
id: CNX-COST-CR-001
titulo: Solicitud a CORE — modelo integral de costos y conciliación
estado: preparada-para-revision
version: 2.0
fecha: 2026-09-01
ambiente_solicitado: Desarrollo (PGD_HOST)
solicitante: por-definir
responsable_core: por-definir
responsable_arquitectura: por-definir
documentos_relacionados:
  - CNX-COST-FS-001
  - CNX-COST-FS-002
  - CNX-COST-DB-GOV-001
  - CNX-COST-ADR-002
---

# Solicitud de cambio CNX-COST-CR-001

## Resumen

Se solicita a CORE y Arquitectura revisar el modelo físico integral diseñado hasta
el momento. La revisión comprende cuatro migraciones candidatas, pero la
autorización debe ser escalonada: núcleo de costos, cierre y documentos pueden
evaluarse para **Desarrollo (`PGD_HOST`)**; `accounts_payable` queda condicionada
al fit-gap y blueprint de integración con SAP. `PGT_HOST` es Testing y queda fuera
de esta primera implementación; cualquier promoción requiere evidencia y autorización.

## Alcance físico

La solicitud inventaría tres esquemas y 31 tablas nuevas. Inventariar no implica
autorizar todas para implementación:

| Esquema | Tablas | Alcance |
|---|---:|---|
| `cost_management` | 17 | ledger, posiciones, costo comercial, tránsito, auditoría, integración y cierre diario |
| `document_management` | 4 | documento, binario y OCR versionado |
| `accounts_payable` | 10 | propuesta condicionada: documento de compra, match operativo e intercambio externo |

El inventario y la responsabilidad de cada tabla se encuentran en
`10-especificacion-funcional-modelo-integral.md`.

### Inventario completo incluido en la solicitud

#### `cost_management` — 17 tablas

1. `cst_cost_policy`
2. `cst_cost_event`
3. `cst_cost_event_line`
4. `cst_cost_component`
5. `cst_commercial_cost_version`
6. `cst_site_cost_position`
7. `cst_company_cost_position`
8. `cst_adjustment_allocation`
9. `cst_tax_treatment_policy`
10. `cst_in_transit_position`
11. `cst_cost_approval`
12. `cst_audit_entry`
13. `cst_reconciliation`
14. `cst_inbox_event`
15. `cst_outbox_event`
16. `cst_site_daily_close`
17. `cst_site_daily_balance`

#### `document_management` — 4 tablas

1. `doc_document`
2. `doc_binary`
3. `doc_extraction_run`
4. `doc_extracted_field`

#### `accounts_payable` — 10 tablas

1. `ap_invoice`
2. `ap_invoice_line`
3. `ap_invoice_tax`
4. `ap_document_relation`
5. `ap_match`
6. `ap_match_allocation`
7. `ap_match_exception`
8. `ap_match_approval`
9. `ap_external_exchange`
10. `ap_external_exchange_line`

La responsabilidad funcional, relaciones y reglas de cada entidad están
detalladas en `10-especificacion-funcional-modelo-integral.md`.

## Scripts candidatos y orden

1. `V20260901180000__create_cost_management_core.sql`
2. `V20260901190000__create_cost_management_daily_close.sql`
3. `V20260901200000__create_document_management.sql`
4. `V20260901210000__create_accounts_payable_matching.sql`

Todas las versiones son provisionales. CORE debe confirmar o renombrar los
archivos antes de incorporarlos a su repositorio Flyway oficial. Los cuatro
archivos forman el inventario completo, pero se aprueban por etapas. El cuarto
script no debe aplicarse hasta aprobar `CNX-COST-ADR-002` y confirmar que no
duplica funciones de SAP.

## Frontera con SAP

CONNEXA conserva las funciones operativas necesarias para stock, Kardex, costos,
documentos fuente e interfaces. SAP es el sistema de registro contable, fiscal y
de cuentas a pagar, salvo decisión explícita y documentada del programa SAP.

Por lo tanto, quedan fuera de CONNEXA:

- subledger oficial de proveedores y pagos;
- contabilización y libros oficiales;
- liquidaciones y presentaciones fiscales;
- plan de cuentas y reglas de imputación SAP;
- reportes legales y regulatorios.

El detalle fiscal almacenado en CONNEXA sólo soporta la formación del costo, la
validación documental y el contrato de interfaz. Los estados locales no deben
interpretarse como contabilización en SAP. Véase
`11-frontera-integracion-sap.md`.

## Alcance funcional

- Kardex inmutable e idempotente;
- CPP local, consolidado y costo neto comercial;
- posición en tránsito y costo transportado;
- componentes, impuestos, rappel, NC/ND y asignaciones;
- stock negativo, ajustes, reversas y replay;
- cierre diario valorizado por sucursal;
- documentos originales, hashes y OCR versionado;
- factura canónica, desglose fiscal y conciliación de tres vías;
- excepciones, cuatro ojos e intercambio detallado con SGM;
- inbox, outbox, auditoría y reconciliación.

## Validación previa de Desarrollo

Consulta de sólo lectura realizada el 1 de septiembre de 2026 contra `PGD_HOST`:

| Control | Resultado |
|---|---|
| Base | `connexa_platform` |
| PostgreSQL | 14.24 |
| Sesión de inspección | read-only |
| Esquemas `cost_management`, `document_management`, `accounts_payable` | no existen |
| Colisiones `cst_*`, `doc_*`, `ap_*` | ninguna |
| Historial Flyway observado | sólo `supply_planning.flyway_schema_history` |

CORE debe decidir si cada bounded context utiliza su propia historia Flyway o una
historia compartida. Ningún script crea o altera `flyway_schema_history`.

## Fuera de alcance

- backfill, saldos iniciales o datos de prueba;
- activación de productores/consumidores;
- cambios sobre tablas existentes;
- subledgers fiscal, contable y de proveedores, pagos y reporting regulatorio;
- contabilización, determinación fiscal o presentación ante organismos externos;
- grants, roles y ownership definitivos;
- eliminación de objetos legacy.

Los subledgers permanecen fuera porque todavía requieren modelo físico aprobado
por Contabilidad, Impuestos y Arquitectura.

## Dependencias

- aprobación funcional de `CNX-COST-FS-002`;
- confirmación de nombres y fronteras de esquemas;
- owner, roles, grants, cifrado y retención;
- versión y configuración Flyway de CORE;
- revisión de performance, locks y particionamiento futuro;
- contratos de eventos de Stock, Procurement, BRIDGE y Acuerdos;
- política de storage para archivos y resultados OCR.

## Impacto esperado

- DDL aditivo sobre objetos nuevos;
- tablas vacías, sin DML ni backfill;
- sin modificación de aplicaciones u objetos existentes;
- sin extensiones PostgreSQL adicionales;
- UUID generados por las aplicaciones;
- locks restringidos a objetos nuevos;
- sin impacto funcional hasta habilitar productores.

## Riesgos

- owner o permisos incorrectos;
- versión Flyway ya reservada;
- intentar liberar las cuatro capacidades simultáneamente;
- crecimiento del ledger/auditoría sin particionamiento futuro;
- exposición de datos fiscales/documentales sin control de acceso;
- habilitar escritores antes de idempotencia y monitoreo;
- interpretar tablas vacías como funcionalidad completa.

## Precondiciones de CORE

1. Confirmar destino Desarrollo (`PGD_HOST`).
2. Confirmar ausencia de esquemas/tablas y revisar drift.
3. Asignar versiones Flyway definitivas.
4. Definir historia Flyway, owner y grants por esquema.
5. Confirmar ejecución transaccional de cada archivo.
6. Revisar constraints, índices y referencias entre migraciones.
7. Aprobar el orden y decidir si se aplica cada etapa.
8. Aprobar RACI, blueprint y contratos SAP antes de autorizar `accounts_payable`.
9. Verificar que ningún estado o tabla replique una función oficial de SAP.

## Validaciones posteriores

```sql
SELECT nspname
FROM pg_namespace
WHERE nspname IN (
    'cost_management', 'document_management', 'accounts_payable'
)
ORDER BY nspname;

SELECT table_schema, count(*) AS table_count
FROM information_schema.tables
WHERE table_schema IN (
    'cost_management', 'document_management', 'accounts_payable'
)
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY table_schema;

SELECT conrelid::regclass AS relation_name,
       conname,
       pg_get_constraintdef(oid, true) AS definition
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname IN (
    'cost_management', 'document_management', 'accounts_payable'
)
ORDER BY conrelid::regclass::text, conname;
```

Resultado esperado para las etapas no condicionadas: `cost_management=17` y
`document_management=4`. `accounts_payable=10` sólo si el fit-gap SAP confirma y
Arquitectura autoriza el cuarto script completo; si se reduce o reemplaza, CORE
debe actualizar solicitud, migración y resultado esperado antes de aplicarlo.
CORE debe adjuntar versiones, checksums y resultado Flyway.

## Pruebas por etapa

### Núcleo de costos

- idempotencia de inbox y evento origen;
- recepción con componentes y posición local/compañía;
- transferencia, reversa, stock negativo y reconciliación;
- costo comercial y aprobación.

### Cierre diario

- cierre de dos sucursales;
- unicidad de versión vigente;
- replay con versión anterior `SUPERSEDED`;
- consultas por artículo, sucursal y fecha.

### Documentos

- documento con original y hash;
- dos corridas OCR y corrección humana;
- detección de clave natural duplicada.

### Conciliación

- factura con líneas e impuestos;
- asignación muchos-a-muchos contra OC/recepción;
- excepción y aprobación operativa;
- construcción de interfaz, envío y respuesta por línea de SGM/SAP.

Los datos sintéticos no se incluyen en Flyway. CORE debe autorizar su carga y
tratamiento en Desarrollo.

## Contingencia

Cada migración debe ejecutarse transaccionalmente. Ante falla se espera rollback
de esa versión. Si una etapa ya fue aplicada, se deshabilitan escritores y se
prepara una migración correctiva hacia adelante.

No se incluye `DROP`. Cualquier eliminación requiere otra solicitud, verificación
de tablas vacías y ausencia de dependencias, y aprobación expresa de CORE.

## Promoción

```text
Desarrollo (PGD_HOST)
  → evidencia y aprobación
  → Testing (PGT_HOST)
  → evidencia y aprobación
  → Producción (PGP_HOST)
```

La secuencia, ventanas y agrupamiento de migraciones son decisión de CORE.

## Aprobaciones requeridas

| Área | Responsable | Estado |
|---|---|---|
| Producto/Costos | por-definir | pendiente |
| Operaciones | por-definir | pendiente |
| Compras | por-definir | pendiente |
| Contabilidad | por-definir | pendiente |
| Impuestos | por-definir | pendiente |
| Seguridad | por-definir | pendiente |
| Arquitectura | por-definir | pendiente |
| CORE | por-definir | pendiente |
