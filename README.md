# Costos comerciales de CONNEXA

Este repositorio contiene el relevamiento y la propuesta, todavía en estado de
borrador, para incorporar trazabilidad de costos y una posición central de costo
neto comercial en CONNEXA.

## Documentos

- [`docs/01-relevamiento-connexa-desa.md`](docs/01-relevamiento-connexa-desa.md): evidencia del modelo y los datos actuales.
- [`docs/02-propuesta-modelo-costos.md`](docs/02-propuesta-modelo-costos.md): arquitectura funcional y técnica propuesta.
- [`docs/03-decisiones-abiertas.md`](docs/03-decisiones-abiertas.md): decisiones funcionales necesarias antes de implementar.
- [`docs/04-kardex-valorizado.md`](docs/04-kardex-valorizado.md): brecha actual y estructura mínima del ledger valorizado.
- [`docs/05-documentos-recepcion-y-conciliacion.md`](docs/05-documentos-recepcion-y-conciliacion.md): recepción documental, OCR y conciliación OC-recepción-factura/NC.
- [`sql/001_cost_management_draft.sql`](sql/001_cost_management_draft.sql): DDL conceptual no ejecutado.

## Reproducibilidad

Los scripts `inspect_*.py` consultan únicamente metadatos y agregados de DESA.
Fuerzan sesiones PostgreSQL de solo lectura, no contienen credenciales y toman la
configuración ya existente del entorno ETL local.

## Estado

Todo el contenido es `borrador`. No constituye una definición funcional aprobada
ni autoriza cambios en ambientes de CONNEXA.
