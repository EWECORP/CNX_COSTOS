---
id: CNX-COST-ADR-002
titulo: Frontera funcional e integración entre CONNEXA y el sistema contable
estado: decision-arquitectonica
version: 1.0
fecha: 2026-09-01
documentos_relacionados:
  - CNX-COST-CR-001
  - CNX-COST-FS-002
  - CNX-COST-DOC-001
---

# Frontera funcional CONNEXA–sistema contable

## Decisión

CONNEXA implementará las capacidades operativas necesarias para administrar stock,
calcular y explicar costos, preservar la evidencia de origen, conciliar las
recepciones con OC y documentos comerciales y producir interfaces completas,
idempotentes y reconciliables con el sistema contable de cada cliente.

El sistema contable del cliente será el sistema de registro para contabilidad
general, cuenta corriente y cuentas a pagar de proveedores, impuestos oficiales,
pagos, valuación contable oficial y reportes legales o regulatorios. Para DIARCO,
ese sistema es SAP; para otros clientes podrá ser SAP u otro producto.

La integración no convierte a CONNEXA en un ERP paralelo.

El desarrollo del bloque operativo `accounts_payable` de CONNEXA no queda
condicionado a un blueprint SAP. Debe ser consistente y agnóstico del sistema
contable, y exponer contratos canónicos que luego se adapten a cada cliente.

## Responsabilidad de CONNEXA

- movimiento físico y Kardex valorizado operativo;
- CPP local, consolidado y costo neto comercial;
- publicación corporativa del Costo Neto Comercial Unificado para Pricing y
  preservación del costo local de salida para rentabilidad por sucursal;
- costo provisional de recepción y ajustes posteriores explicables;
- posición en tránsito y cierre diario operativo valorizado;
- recepción, preservación, hash, OCR y trazabilidad documental;
- relación operativa entre OC, recepción, factura y NC cuando sea necesaria para
  determinar el costo o resolver una diferencia logística/comercial;
- emisión y seguimiento de solicitudes de nota de crédito originadas por
  diferencias entre factura, OC y recepción;
- clasificación de componentes recuperables/capitalizables necesaria para formar
  el costo, utilizando reglas maestras acordadas con el sistema contable;
- generación de mensajes hacia el sistema contable configurado y recepción de
  acuses técnicos y funcionales;
- idempotencia, reintentos, evidencia, estados y reconciliación de cada interfaz.

## Responsabilidad del sistema contable (SAP en DIARCO)

- alta y contabilización oficial de facturas, NC y ND de proveedor;
- subledger de proveedores, vencimientos, pagos y compensaciones;
- asientos, períodos y libros contables oficiales;
- determinación, liquidación y presentación fiscal oficial;
- plan de cuentas, centros de costo, clases de documento y reglas de imputación;
- reportes legales, libros IVA, percepciones y organismos externos;
- numeración y referencia definitiva de los documentos contabilizados.

CONNEXA puede conservar los datos fiscales y contables que formen parte del
documento fuente o de la interfaz, pero no debe tratarlos como libro oficial.
En DIARCO, SAP mantiene exactamente estas responsabilidades.

## Capacidades de integración mínimas

Cada contrato entre CONNEXA y el sistema contable deberá definir:

1. nombre y versión de interfaz;
2. dirección y evento disparador;
3. propietario funcional y sistema de registro por campo;
4. clave de negocio e idempotencia;
5. esquema de cabecera, líneas, impuestos, moneda y referencias;
6. mapeo de compañías, sucursales, depósitos, artículos, proveedores y UOM;
7. mapeo de sociedad, centro, almacén y demás objetos requeridos por el sistema contable;
8. semántica de fechas, zona horaria, moneda, precisión y redondeo;
9. validaciones, totales de control y tolerancias;
10. estados técnicos y funcionales separados;
11. acuse técnico, resultado funcional y referencia externa;
12. reintento seguro, duplicado, orden tardío, reversa y corrección;
13. reconciliación por cantidad, importe, impuesto y cantidad de registros;
14. trazabilidad desde el hecho CONNEXA hasta el documento del sistema contable;
15. seguridad, cifrado, retención, monitoreo y SLA.

## Interfaces candidatas

El catálogo definitivo depende de la integración contable de cada cliente. Como mínimo debe evaluarse:

- maestros necesarios para operar y mapear claves;
- recepciones y devoluciones de mercadería;
- transferencias y ajustes de inventario cuando el sistema contable deba registrarlos;
- facturas, NC, ND y solicitudes de NC con su referencia a OC y recepción;
- ventas consolidadas de BRIDGE cuando el sistema contable las requiera;
- costo de mercadería vendida y ajustes de valuación, evitando doble registro;
- acuerdos, rappel y fletes sólo en el nivel de detalle requerido por el sistema contable;
- acuses, rechazos, referencias externas y archivos de reconciliación.

Esta lista es de análisis y no autoriza implementar todas las interfaces. El
sistema de registro se define por responsabilidad funcional y por cliente.

## Impacto sobre las tablas propuestas

- Las 17 tablas de `cost_management` soportan responsabilidades propias de
  CONNEXA, pero sus salidas contables son interfaces, no asientos oficiales.
- Las 4 tablas de `document_management` preservan evidencia operativa; no forman
  un archivo fiscal oficial salvo obligación acordada expresamente.
- Las tablas de `accounts_payable` constituyen una capacidad operativa propia de
  CONNEXA para cerrar el flujo recepción–documento–conciliación–valorización. No
  constituyen un subledger contable ni dependen de un ERP específico.
- `ap_credit_note_request` registra la solicitud generada por una diferencia de
  conciliación. No representa una NC emitida ni un movimiento de cuenta corriente;
  esos efectos pertenecen al sistema contable.
- `ap_invoice_tax` es desglose del documento y dato de interfaz/costo; no es un
  subledger fiscal.
- `ap_external_exchange` y su detalle implementan el registro agnóstico del
  intercambio. Los adaptadores específicos —SAP para DIARCO u otros para otros
  clientes— traducen el contrato canónico.

## Condición de aprobación e integración

La implementación del bloque `accounts_payable` puede continuar sin esperar la
definición del sistema contable. Antes de activar una interfaz productiva con un
cliente se deberá disponer de:

- RACI CONNEXA–sistema contable aprobado;
- contratos de integración versionados para el sistema del cliente;
- confirmación de que el triple match operativo se realiza en CONNEXA;
- definición del momento en que el costo provisional pasa a definitivo;
- catálogo de respuestas externas y tratamiento de errores;
- prueba de que no se duplica contabilización, obligación fiscal ni cuenta a pagar.

