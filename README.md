# Costos comerciales de CONNEXA

Este repositorio contiene el relevamiento validado en producción, testing y
desarrollo, las decisiones funcionales aprobadas y la arquitectura propuesta para
incorporar trazabilidad de costos y una posición central de costo neto comercial
en CONNEXA.

## Documentos

- [`docs/01-relevamiento-connexa-desa.md`](docs/01-relevamiento-connexa-desa.md): evidencia comparada de PROD, TEST y DESA. El nombre se conserva por compatibilidad histórica.
- [`docs/02-propuesta-modelo-costos.md`](docs/02-propuesta-modelo-costos.md): arquitectura funcional y técnica propuesta.
- [`docs/03-decisiones-abiertas.md`](docs/03-decisiones-abiertas.md): registro de decisiones funcionales aprobadas y parámetros aún por instrumentar.
- [`docs/04-kardex-valorizado.md`](docs/04-kardex-valorizado.md): brecha actual y estructura mínima del ledger valorizado.
- [`docs/05-documentos-recepcion-y-conciliacion.md`](docs/05-documentos-recepcion-y-conciliacion.md): recepción documental, OCR y conciliación OC-recepción-factura/NC.
- [`docs/06-plan-de-implementacion.md`](docs/06-plan-de-implementacion.md): próximos pasos, entregables, responsables y criterios de salida.
- [`docs/07-gobierno-cambios-base-datos.md`](docs/07-gobierno-cambios-base-datos.md): solicitud, revisión y promoción controlada de cambios Flyway por CORE.
- [`docs/08-especificacion-funcional-cierre-diario.md`](docs/08-especificacion-funcional-cierre-diario.md): comportamiento funcional y criterios de aceptación del cierre diario valorizado.
- [`docs/09-solicitud-core-cierre-diario.md`](docs/09-solicitud-core-cierre-diario.md): solicitud de cambio preparada para CORE y Arquitectura.
- [`docs/10-especificacion-funcional-modelo-integral.md`](docs/10-especificacion-funcional-modelo-integral.md): inventario funcional de las 31 tablas propuestas.
- [`docs/11-frontera-integracion-sap.md`](docs/11-frontera-integracion-sap.md): responsabilidades de CONNEXA y SAP, contratos mínimos y condición para Accounts Payable.
- [`sql/V20260901180000__create_cost_management_core.sql`](sql/V20260901180000__create_cost_management_core.sql): núcleo Flyway candidato de Cost Management.
- [`sql/V20260901190000__create_cost_management_daily_close.sql`](sql/V20260901190000__create_cost_management_daily_close.sql): cierre diario Flyway candidato.
- [`sql/V20260901200000__create_document_management.sql`](sql/V20260901200000__create_document_management.sql): documentos y OCR Flyway candidato.
- [`sql/V20260901210000__create_accounts_payable_matching.sql`](sql/V20260901210000__create_accounts_payable_matching.sql): factura y conciliación Flyway candidato.
- [`sql/001_cost_management_draft.sql`](sql/001_cost_management_draft.sql): DDL conceptual no ejecutado.

## Reproducibilidad

Los scripts `inspect_*.py` existentes perfilan PROD mediante `PGP_*` y consultan
únicamente metadatos y agregados. La validación comparada adicional utilizó
`PGP_*`, `PGT_*` y `PGD_*`, siempre con sesiones PostgreSQL forzadas a solo
lectura. Las credenciales permanecen en `.env` y no se documentan ni versionan.

## Estado

Las decisiones funcionales 1 a 21 están aprobadas a nivel conceptual. El DDL
continúa siendo un borrador no ejecutable hasta cerrar los parámetros operativos,
el blueprint SAP, los contratos de integración, las pruebas de replay y la
aprobación técnica/contable. La migración de `accounts_payable` está condicionada
al fit-gap con SAP para evitar duplicar funciones del ERP.

Ningún archivo de este repositorio autoriza por sí mismo cambios en ambientes de
CONNEXA.

Los cambios de base son ejecutados exclusivamente por el grupo CORE. Este proyecto
documenta la solicitud y prepara el script Flyway; Arquitectura lo revisa y CORE
decide e implementa su promoción escalonada.
