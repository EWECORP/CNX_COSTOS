# Dominio, estados y reglas

## Agregados funcionales

| Agregado | Entidades principales | Responsabilidad |
|---|---|---|
| Política de costo | `cst_cost_policy`, `cst_tax_treatment_policy` | reglas versionadas y vigentes |
| Evento de costo | `cst_cost_event`, líneas y componentes | hecho económico inmutable |
| Posición | posición local, compañía y tránsito | lectura vigente reconstruible |
| Costo comercial | versión y aprobación | costo corporativo publicable |
| Cierre diario | cabecera y balances | foto valorizada versionada |
| Documento | documento, binario, extracción y campos | evidencia y OCR |
| Conciliación | factura, líneas, impuestos, match y asignaciones | triple match operativo |
| Solicitud de NC | `ap_credit_note_request` | reclamo y seguimiento externo |
| Integración | inbox, outbox y external exchange | entrega idempotente y trazable |

## Inventario físico baseline

| Esquema | Tablas |
|---|---|
| `cost_management` | `cst_cost_policy`, `cst_cost_event`, `cst_cost_event_line`, `cst_cost_component`, `cst_commercial_cost_version`, `cst_site_cost_position`, `cst_company_cost_position`, `cst_adjustment_allocation`, `cst_tax_treatment_policy`, `cst_in_transit_position`, `cst_cost_approval`, `cst_audit_entry`, `cst_reconciliation`, `cst_inbox_event`, `cst_outbox_event`, `cst_site_daily_close`, `cst_site_daily_balance` |
| `document_management` | `doc_document`, `doc_binary`, `doc_extraction_run`, `doc_extracted_field` |
| `accounts_payable` | `ap_invoice`, `ap_invoice_line`, `ap_invoice_tax`, `ap_document_relation`, `ap_match`, `ap_match_allocation`, `ap_match_exception`, `ap_match_approval`, `ap_credit_note_request`, `ap_external_exchange`, `ap_external_exchange_line` |

Son 32 tablas candidatas. Las referencias a maestros externos son IDs lógicos; las
FK físicas se limitan a entidades que pertenecen al paquete. El detalle de columnas,
constraints e índices está en las cuatro migraciones `../../sql/V202609*.sql`.

## Semántica de costos

| Métrica | Granularidad | Uso autorizado |
|---|---|---|
| CPP local | compañía–artículo–sucursal–UOM–moneda | inventario, salida y rentabilidad local |
| CPP compañía | compañía–artículo–UOM–moneda | consolidación del inventario |
| Costo Neto Comercial Unificado | compañía–artículo–UOM–moneda–vigencia | Pricing y margen objetivo |

La rentabilidad histórica usa el costo congelado en el evento de venta, no el CPP
vigente al consultar. Pricing consume únicamente costos comerciales `PUBLISHED`.

## Reglas invariantes

- Una clave `(company, sourceService, sourceEventId)` produce como máximo un evento.
- Cantidad posterior = cantidad anterior + variación.
- Valor posterior = valor anterior + variación.
- Una recepción cerrada registra movimiento, valorización, posición y outbox como
  una unidad lógica.
- Factura/NC/ND ajusta valor; no vuelve a ingresar o retirar unidades ya registradas.
- Transferencia interna conserva cantidad y valor consolidado, salvo cargos externos.
- Un cierre vigente es único por compañía, sucursal y fecha de negocio.
- Una reapertura crea nueva versión y deja la anterior como `SUPERSEDED`.
- Una publicación comercial vigente no se modifica: se sustituye con otra versión.
- Documento binario y hash son inmutables.
- Una solicitud de NC no es una NC emitida ni afecta por sí misma la cuenta corriente.

## Estados principales

```text
Evento:       PENDING -> POSTED -> REVERSED
                         \-> REJECTED

Costo:        DRAFT -> CALCULATED -> UNDER_REVIEW -> APPROVED
                                                   -> PUBLISHED -> SUPERSEDED

Cierre:       CALCULATING -> PROVISIONAL -> CLOSED -> SUPERSEDED
                        \-> FAILED

Match:        PENDING -> AUTO_MATCHED -> APPROVED -> READY_FOR_EXPORT
                  \-> PARTIAL_MATCH / EXCEPTION -> MANUAL_MATCH -> APPROVED

Solicitud NC: DRAFT -> PENDING_APPROVAL -> APPROVED -> SENT -> ACKNOWLEDGED
                                                    -> CREDIT_NOTE_RECEIVED -> CLOSED
                  \-> REJECTED / CANCELLED
```

## Diferencias de conciliación

Se comparan proveedor, artículo, UOM, cantidad, precio, descuentos, impuestos,
moneda, OC y recepción. Cada resultado conserva política y versión de tolerancia.

- Dentro de tolerancia: auto-match elegible para aprobación.
- Fuera de tolerancia aceptable: excepción y aprobación manual.
- Diferencia reclamable a favor del cliente: solicitud de NC.
- Documento o referencia inválida: rechazo sin valorización definitiva.
- NC recibida: documento nuevo relacionado con solicitud, factura y match originales.

## Consistencia y concurrencia

- Procesamiento secuencial por compañía–artículo–sucursal.
- Bloqueo o versión optimista sobre la posición.
- Reintento seguro sólo con la misma clave idempotente y payload equivalente.
- Misma clave con payload diferente devuelve conflicto y genera alerta.
- Eventos fuera de orden quedan pendientes de resolución o replay controlado.
