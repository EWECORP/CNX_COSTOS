---
id: CNX-COST-PLAN-001
titulo: Plan de implementación del sistema central de costos
estado: propuesto
version: 1.0
fecha: 2026-09-01
propietario: por-definir
documentos_relacionados:
  - CNX-COST-REL-001
  - CNX-COST-ARC-001
  - CNX-COST-DEC-001
  - CNX-COST-KDX-001
  - CNX-COST-DOC-001
  - CNX-COST-ADR-002
---

# Plan de implementación

## Objetivo

Implementar el Kardex valorizado y las tres posiciones de costo sin interrumpir la
absorción gradual de SGM y BRIDGE. La transición usa contratos idempotentes,
ejecución en sombra y reconciliación antes de convertir a CONNEXA en autoridad
operativa. SAP conserva las funciones ERP oficiales definidas en
`11-frontera-integracion-sap.md`.

## Fase 0A — Blueprint y frontera SAP

Entregables:

- RACI por proceso y dato entre CONNEXA, SAP, SGM y BRIDGE;
- sistema de registro por objeto y por campo;
- catálogo y versión de interfaces SAP;
- mapeo de claves y objetos organizativos;
- estados técnicos/funcionales, acuses, rechazos y referencias SAP;
- estrategia de idempotencia, reversa, reintento y reconciliación;
- fit-gap del bloque propuesto `accounts_payable`.

Criterio de salida: Arquitectura confirma qué funciones son propias de CONNEXA y
qué tablas de conciliación son realmente necesarias. Sin esta salida no se aplica
la cuarta migración candidata.

## Fase 0 — Gobierno y parametrización

Entregables:

- responsables de Producto, Compras, Operaciones, Contabilidad, Impuestos y Pricing;
- matriz de componentes y tratamiento contable/comercial/fiscal;
- UOM, factores, redondeos, tipos de cambio y tolerancias;
- catálogo normalizado de movimientos;
- política de períodos, replay, retención y materialidad;
- veinte casos dorados con resultado esperado.

Criterio de salida: matriz aprobada y casos dorados firmados por las áreas.

## Fase 1 — Contratos y calidad de datos

Entregables:

- evento canónico de movimiento con documento y línea origen;
- evento de recepción cerrada con OC, recepción, producto, sitio, UOM/factor,
  precio y componentes congelados;
- contrato de venta BRIDGE con cabecera, líneas, precios, impuestos y promociones;
- contrato de transferencia con costo por línea y posición en tránsito;
- eliminación de `custom1..4` como contrato implícito;
- claves idempotentes, secuencia, outbox e inbox;
- conciliación de maestros de compañía, artículo, sitio, proveedor y UOM.

Criterio de salida: contratos versionados y pruebas de duplicado, orden tardío y
reversa aprobadas en TEST.

## Fase 2 — Ledger y posiciones

Entregables:

- solicitud formal de cambio y scripts Flyway revisados por Arquitectura;
- implementación y promoción ejecutadas exclusivamente por CORE;
- esquema `cost_management` y migraciones Flyway verificadas;
- esquemas documentales y de conciliación desplegados inicialmente vacíos y sin
  habilitar productores;
- ledger inmutable, componentes, asignaciones y evidencias;
- posición local, consolidada, comercial y en tránsito;
- cierre diario versionado por sucursal y balance valorizado por artículo;
- motor de CPP, stock negativo, transferencias y replay;
- auditoría, segregación, monitoreo y reconciliación;
- API de consulta por artículo/sucursal y trazabilidad completa.

Criterio de salida: CORE confirma la aplicación escalonada autorizada; los casos
dorados se reproducen exactamente y ejecutar dos veces el mismo evento no cambia
el resultado. Un cierre diario se reconstruye desde el ledger, reconcilia con la
posición operativa y una reapertura conserva ambas versiones.

## Fase 3 — Apertura y modo sombra

Entregables:

- fecha de corte y saldos certificados de cantidad, valor y costo;
- carga de apertura usando `t055_articulos_condcompra_costos`, listas y fuentes
  contables como evidencia, no como historial;
- replay de una ventana histórica acordada;
- comparación diaria contra Stock, SGM y Contabilidad;
- tablero de diferencias con causa y resolución.

Criterio de salida: cantidades reconciliadas y diferencias de valor dentro de la
tolerancia aprobada durante un período continuo definido por el comité.

## Fase 4 — Recepciones y documentos

Entregables:

- costo provisional síncrono al cierre de recepción;
- repositorio documental, OCR versionado y documento comercial canónico;
- conciliación OC–recepción–factura/NC, excepciones y aprobaciones;
- ajustes a costo final y clasificación impositiva necesaria para la interfaz;
- integración temporal con SGM mediante un conector trazable.

Criterio de salida: ninguna recepción cerrada queda sin movimiento y valorización;
cada ajuste se explica desde el documento original hasta el ledger.

## Fase 5 — Ventas, transferencias y transformaciones

Entregables:

- ingestión completa de BRIDGE por artículo, sucursal, precio, cantidad e impuesto;
- costo de mercadería vendida vinculado con la línea de venta;
- transferencias con origen, tránsito, destino y flete;
- órdenes de transformación para recetas, rendimiento, merma y subproductos;
- tratamiento de devoluciones y ajustes físicos.

Criterio de salida: conservación de cantidad y valor en transferencias internas y
trazabilidad venta–salida–costo–margen.

## Fase 6 — Acuerdos, costo comercial e interfaces SAP

Entregables:

- devengamiento, liquidación y `TRUE_UP` de rappel;
- distribución por recepción, SKU, categoría, proveedor o compras elegibles;
- workflow y publicación versionada del costo comercial;
- interfaces completas hacia SAP con componentes de costo, impuestos fuente y
  referencias operativas necesarias;
- recepción de acuses técnicos, resultados funcionales y número SAP;
- reconciliación de totales y documentos entre CONNEXA y SAP;
- contratos de consumo para Pricing, Analytics y Finanzas.

Criterio de salida: inventario y costos CONNEXA reconcilian con los documentos y
registros oficiales SAP sin doble contabilización ni doble obligación fiscal.

## Orden inmediato de trabajo

1. Nombrar responsables y convocar el taller de casos dorados.
2. Certificar el contrato real de cierre de recepción y el flujo nuevo de BRIDGE.
3. Definir el corte de apertura y fuentes autorizadas de costo inicial.
4. Aprobar RACI, blueprint y contratos SAP antes de autorizar tablas de conciliación.
5. Someter solicitud, migraciones, controles y políticas a revisión contable, impositiva,
   seguridad y arquitectura.
6. Entregar a CORE el paquete aprobado para implementación escalonada.
7. Prototipar recepción provisional, transferencia y venta en TEST después de la
   confirmación de CORE.
8. Ejecutar replay y reconciliación en sombra.
9. Planificar activación gradual por sucursal o familia de artículos, con rollback
   operacional basado en consumidores, nunca borrando el ledger.

## Riesgos a controlar

- coexistencia de `public.fnd_*`, `stock_management.stk_*` e `inventory.inv_*`;
- movimientos sin documento o semántica en campos genéricos;
- recepción sin vínculo directo a línea de OC y producto;
- datos monetarios heredados en `double precision`;
- listas, factores y reglas modificables sin versión histórica;
- stock negativo y eventos fuera de orden;
- documentos OCR duplicados o de baja confianza;
- diferencias entre TEST, PROD y DESA en migraciones y restricciones;
- dependencia transitoria de SGM para conciliación.
- duplicación accidental de funciones, documentos o estados oficiales de SAP;
- interfaz sin acuse funcional o sin reconciliación extremo a extremo.

## Gobierno de salida a producción

La habilitación requiere aprobación conjunta de Producto, Operaciones,
Contabilidad, Impuestos, Seguridad y Arquitectura. Debe existir monitoreo,
reconciliación, replay probado, plan de contingencia y evidencia de que ningún
consumidor fiscal o contable depende de una proyección no certificada.

La aplicación de cambios físicos, incluyendo pruebas de migración sobre ambientes
compartidos, corresponde exclusivamente a CORE y sigue el procedimiento de
`07-gobierno-cambios-base-datos.md`.
