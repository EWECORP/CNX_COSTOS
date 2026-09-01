---
id: CNX-COST-ADR-002
titulo: Frontera funcional e integración entre CONNEXA y SAP
estado: decision-arquitectonica
version: 1.0
fecha: 2026-09-01
documentos_relacionados:
  - CNX-COST-CR-001
  - CNX-COST-FS-002
  - CNX-COST-DOC-001
---

# Frontera funcional CONNEXA–SAP

## Decisión

CONNEXA implementará únicamente las capacidades operativas necesarias para
administrar stock, calcular y explicar costos, preservar la evidencia de origen y
producir interfaces completas, idempotentes y reconciliables con SAP.

SAP será, salvo decisión explícita del programa de integración, el sistema de
registro para contabilidad general, cuentas a pagar, impuestos oficiales, pagos,
valuación contable oficial y reportes legales o regulatorios.

La integración no convierte a CONNEXA en un ERP paralelo.

## Responsabilidad de CONNEXA

- movimiento físico y Kardex valorizado operativo;
- CPP local, consolidado y costo neto comercial;
- costo provisional de recepción y ajustes posteriores explicables;
- posición en tránsito y cierre diario operativo valorizado;
- recepción, preservación, hash, OCR y trazabilidad documental;
- relación operativa entre OC, recepción, factura y NC cuando sea necesaria para
  determinar el costo o resolver una diferencia logística/comercial;
- clasificación de componentes recuperables/capitalizables necesaria para formar
  el costo, utilizando reglas maestras acordadas con SAP;
- generación de mensajes hacia SAP y recepción de acuses técnicos y funcionales;
- idempotencia, reintentos, evidencia, estados y reconciliación de cada interfaz.

## Responsabilidad de SAP

- alta y contabilización oficial de facturas, NC y ND de proveedor;
- subledger de proveedores, vencimientos, pagos y compensaciones;
- asientos, períodos y libros contables oficiales;
- determinación, liquidación y presentación fiscal oficial;
- plan de cuentas, centros de costo, clases de documento y reglas de imputación;
- reportes legales, libros IVA, percepciones y organismos externos;
- numeración y referencia definitiva de los documentos contabilizados.

CONNEXA puede conservar los datos fiscales y contables que formen parte del
documento fuente o de la interfaz, pero no debe tratarlos como libro oficial.

## Capacidades de integración mínimas

Cada contrato CONNEXA–SAP deberá definir:

1. nombre y versión de interfaz;
2. dirección y evento disparador;
3. propietario funcional y sistema de registro por campo;
4. clave de negocio e idempotencia;
5. esquema de cabecera, líneas, impuestos, moneda y referencias;
6. mapeo de compañías, sucursales, depósitos, artículos, proveedores y UOM;
7. mapeo SAP de sociedad, centro, almacén y demás objetos requeridos;
8. semántica de fechas, zona horaria, moneda, precisión y redondeo;
9. validaciones, totales de control y tolerancias;
10. estados técnicos y funcionales separados;
11. acuse técnico, resultado funcional y referencia SAP;
12. reintento seguro, duplicado, orden tardío, reversa y corrección;
13. reconciliación por cantidad, importe, impuesto y cantidad de registros;
14. trazabilidad desde el hecho CONNEXA hasta el documento SAP;
15. seguridad, cifrado, retención, monitoreo y SLA.

## Interfaces candidatas

El catálogo definitivo depende del blueprint SAP. Como mínimo debe evaluarse:

- maestros necesarios para operar y mapear claves;
- recepciones y devoluciones de mercadería;
- transferencias y ajustes de inventario cuando SAP deba registrarlos;
- facturas, NC y ND con su referencia a OC y recepción;
- ventas consolidadas de BRIDGE cuando SAP las requiera;
- costo de mercadería vendida y ajustes de valuación, evitando doble registro;
- acuerdos, rappel y fletes sólo en el nivel de detalle requerido por SAP;
- acuses, rechazos, referencias SAP y archivos de reconciliación.

Esta lista es de análisis, no autoriza implementar todas las interfaces ni asigna
el sistema de registro antes del blueprint.

## Impacto sobre las tablas propuestas

- Las 17 tablas de `cost_management` soportan responsabilidades propias de
  CONNEXA, pero sus salidas contables son interfaces, no asientos oficiales.
- Las 4 tablas de `document_management` preservan evidencia operativa; no forman
  un archivo fiscal oficial salvo obligación acordada expresamente.
- Las 10 tablas de `accounts_payable` quedan **condicionadas** al fit-gap con SAP.
  Sólo deberán implementarse las partes requeridas para OCR, conciliación
  operativa, valorización y construcción de la interfaz.
- `ap_invoice_tax` es desglose del documento y dato de interfaz/costo; no es un
  subledger fiscal.
- `ap_external_exchange` y su detalle son una solución transitoria acotada a
  documentos de compra. Arquitectura debe decidir si se reemplazan por un
  componente de integración corporativo reutilizable.

## Condición de aprobación

La migración de `accounts_payable` no debe promoverse hasta disponer de:

- RACI CONNEXA–SAP–SGM aprobado;
- blueprint y contratos SAP versionados;
- decisión de dónde se realiza el triple match;
- definición del momento en que el costo provisional pasa a definitivo;
- catálogo de respuestas SAP y tratamiento de errores;
- prueba de que no se duplica contabilización, obligación fiscal ni cuenta a pagar.

