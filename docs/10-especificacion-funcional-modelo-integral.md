---
id: CNX-COST-FS-002
titulo: Especificación funcional integral — costos, documentos y conciliación
estado: propuesto-para-revision
version: 1.0
fecha: 2026-09-01
ambiente_inicial: Desarrollo (PGD_HOST)
documentos_relacionados:
  - CNX-COST-ARC-001
  - CNX-COST-KDX-001
  - CNX-COST-DOC-001
  - CNX-COST-FS-001
  - CNX-COST-DB-GOV-001
  - CNX-COST-ADR-002
---

# Especificación funcional integral

## Objetivo

Presentar a CORE y Arquitectura el conjunto completo de entidades físicas
diseñadas hasta el momento para el sistema central de costos, el cierre diario,
la preservación documental y la conciliación operativa de compras. El inventario
no asigna a CONNEXA funciones contables, fiscales o de cuentas a pagar propias de
SAP.

## Bounded contexts y tablas

### Cost Management

| Tabla | Responsabilidad |
|---|---|
| `cst_cost_policy` | Política versionada de valuación por compañía y evento |
| `cst_cost_event` | Cabecera inmutable e idempotente del hecho económico |
| `cst_cost_event_line` | Cantidad, valor y CPP antes/después por artículo-sucursal |
| `cst_cost_component` | Precio, descuentos, flete, impuestos, rappel y otros componentes |
| `cst_site_cost_position` | Posición actual y CPP local |
| `cst_company_cost_position` | Posición y CPP consolidado de compañía |
| `cst_commercial_cost_version` | Versiones aprobables/publicables del costo comercial |
| `cst_adjustment_allocation` | Distribución de NC, acuerdos y true-up |
| `cst_tax_treatment_policy` | Recuperabilidad y capitalización impositiva versionada |
| `cst_in_transit_position` | Cantidad y valor transportados entre sitios |
| `cst_cost_approval` | Aprobación del costo comercial |
| `cst_audit_entry` | Evidencia de acciones, reglas y estados antes/después |
| `cst_reconciliation` | Diferencias entre posición operativa y Kardex |
| `cst_inbox_event` | Recepción idempotente de eventos externos |
| `cst_outbox_event` | Publicación transaccional a consumidores |
| `cst_site_daily_close` | Cabecera versionada del cierre diario de sucursal |
| `cst_site_daily_balance` | Cantidad, valor y CPP por artículo al cierre |

### Document Management

| Tabla | Responsabilidad |
|---|---|
| `doc_document` | Identidad, tipo, importes, estado y versión del documento |
| `doc_binary` | Original inmutable, hash, MIME y ubicación segura |
| `doc_extraction_run` | Ejecución versionada de OCR/extracción |
| `doc_extracted_field` | Valor original/normalizado, confianza y corrección humana |

### Accounts Payable / Matching

Este bloque es una capacidad operativa propia de CONNEXA, independiente del
sistema contable del cliente. Cierra el flujo recepción–documento–conciliación–
valorización y prepara interfaces completas; no constituye el subledger oficial
de proveedores.

| Tabla | Responsabilidad |
|---|---|
| `ap_invoice` | Representación operativa de factura, NC o ND validada para costo/interfaz |
| `ap_invoice_line` | Artículos, cantidades, UOM, precios y netos |
| `ap_invoice_tax` | Desglose fuente para validación, costo e interfaz; no libro fiscal |
| `ap_document_relation` | NC/ND, reemplazos y referencias entre documentos |
| `ap_match` | Versión y estado de conciliación |
| `ap_match_allocation` | Relación muchos-a-muchos factura–OC–recepción |
| `ap_match_exception` | Diferencias y resolución estructurada |
| `ap_match_approval` | Segregación y aprobación del match |
| `ap_credit_note_request` | Solicitud de NC originada por diferencias de conciliación y seguimiento externo |
| `ap_external_exchange` | Paquete, payload, respuesta y reintentos con SGM o sistema contable |
| `ap_external_exchange_line` | Resultado externo detallado por asignación/línea |

`ap_invoice_tax` y `ap_external_exchange_line` se formalizan como tablas de apoyo
porque el diseño aprobado exige desglose fiscal y respuesta de SGM por línea.

## Relaciones principales

```text
doc_document → doc_binary → doc_extraction_run → doc_extracted_field
      │
      └→ ap_invoice → ap_invoice_line → ap_invoice_tax
                         │
                         └→ ap_match → ap_match_allocation
                                        ├→ ap_match_exception
                                        ├→ ap_match_approval
                                        ├→ ap_credit_note_request
                                        └→ ap_external_exchange/line

Recepción / venta / transferencia / match aprobado
      → cst_inbox_event
      → cst_cost_event → cst_cost_event_line → cst_cost_component
      → posiciones local, compañía y tránsito
      → cierre diario
      → cst_outbox_event
```

## Reglas transversales

- UUID provistos por la aplicación; las migraciones no requieren extensiones.
- Importes y costos usan `numeric`; ningún monto usa `double precision`.
- Instantes usan `timestamptz`; fechas de negocio usan `date`.
- Eventos y documentos publicados no se borran ni reescriben.
- Reversas y replay generan nuevas filas/versiones.
- Referencias a maestros de otros bounded contexts son IDs lógicos para evitar
  escrituras cruzadas y dependencias de despliegue.
- Los datos contables o fiscales se conservan como evidencia y contenido de
  interfaz; SAP mantiene los libros oficiales.
- Una aprobación local autoriza el costo o la interfaz, pero no equivale a un
  documento contabilizado por SAP.
- FK físicas sólo unen tablas dentro del paquete propio.
- Inbox, claves naturales y hashes soportan idempotencia/deduplicación.
- Cada migración es aditiva y no contiene backfill.
- El Costo Neto Comercial Unificado se publica por compañía/cadena, artículo,
  UOM, moneda y vigencia, y es la base común de Pricing y margen objetivo.
- La rentabilidad y performance por sucursal utilizan el costo local congelado en
  el evento de salida, no el CPP vigente al momento de consultar.

## Flujos cubiertos

1. Recepción cerrada con costo provisional y CPP.
2. Conciliación OC–recepción–factura y ajuste a costo definitivo.
3. NC/ND y distribución entre inventario y costo vendido.
4. Transferencia con posición en tránsito y costo transportado.
5. Venta BRIDGE con salida y costo de mercadería vendida.
6. Bonificaciones, impuestos, rappel y acuerdos.
7. Stock negativo, ajustes, devoluciones y replay.
8. Cierre diario valorizado y reconstruible.
9. OCR, corrección humana, intercambio con SGM y auditoría.
10. Solicitud de NC ante diferencias de factura contra OC/recepción.
11. Publicación versionada del costo comercial.

## Fuera de esta solicitud física

- tablas del subledger fiscal definitivo;
- tablas del subledger contable y plan de cuentas;
- subledger de proveedores, vencimientos y pagos;
- tablas de presentaciones regulatorias;
- modelos de Pricing, Analytics o Data Warehouse;
- tablas operativas existentes de ventas BRIDGE, Stock, Procurement o PDD.

Estos bloques están definidos funcionalmente, pero todavía no tienen modelo físico
aprobado por Contabilidad, Impuestos y Arquitectura. Incluir tablas inventadas en
esta migración aumentaría el riesgo y violaría el proceso de gobierno acordado.

Las 11 tablas de `accounts_payable` forman el bloque operativo necesario para
cerrar la recepción, conciliación y valorización. La activación de cada adaptador
contable sí requiere el contrato particular del cliente conforme a
`CNX-COST-ADR-002`.

## Criterios de aceptación del esquema

- Se revisan 32 tablas: 17 de Cost Management, 4 documentales y 11 de
  conciliación operativa. La aprobación puede comprender un subconjunto.
- Las migraciones autorizadas se aplican en orden dentro de Flyway; la cuarta
  puede aprobarse como capacidad propia de CONNEXA y sus adaptadores se habilitan
  por cliente.
- No se cargan datos funcionales.
- No se modifican objetos existentes.
- Constraints impiden duplicados, estados inválidos y relaciones huérfanas internas.
- Índices soportan procesos pendientes, trazabilidad e historia.
- Una migración fallida revierte su transacción.
- Flyway registra una sola aplicación por versión.
- El despliegue inicial ocurre sólo en Desarrollo (`PGD_HOST`).

## Decisiones que CORE/Arquitectura deben revisar

- nombres definitivos de esquemas y versiones Flyway;
- repositorio y ubicación oficial de migraciones;
- owner, roles y grants;
- una historia Flyway por bounded context o historia compartida;
- particionamiento futuro de eventos, auditoría, documentos y cierres;
- política de almacenamiento para binarios y resultados OCR;
- datos sensibles, cifrado, masking y retención;
- estrategia de expansión/contracción y promoción a Testing (`PGT_HOST`).
- RACI, objetos del sistema contable, ownership por campo y contratos de interfaz;
- estrategia de adaptadores contables por cliente, comenzando por SAP para DIARCO.
