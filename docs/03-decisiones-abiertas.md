---
id: CNX-COST-DEC-001
titulo: Decisiones funcionales del modelo de costos
estado: aprobado-con-parametros-pendientes
version: 1.0
fecha: 2026-09-01
propietario: por-definir
documento_relacionado: CNX-COST-ARC-001
---

# Decisiones funcionales del modelo de costos

Las siguientes decisiones fueron confirmadas por Dirección el 1 de septiembre de
2026. Son la base funcional para el diseño detallado; no sustituyen la aprobación
contable, impositiva ni técnica de cada parametrización.

## Decisiones aprobadas

1. El costo neto comercial contempla precio, descuentos, bonificaciones,
   impuestos internos y no recuperables, flete, rappel estimado/real, NC/ND y
   acuerdos. Cada componente declara si afecta inventario, costo comercial o
   resultados.
2. Se publican tres métricas separadas: costo promedio local, valuación consolidada
   de compañía y costo neto comercial para pricing.
3. El costo nace al cierre físico de la recepción, con estimación basada en la OC;
   factura, NC y conciliación producen ajustes posteriores sin reingresar unidades.
4. Rappel y acuerdos de compra atribuibles a mercadería reducen costo. Se devengan
   cuando son medibles y suficientemente probables, con `TRUE_UP` al liquidarse.
   Servicios, publicidad, exhibición y financiación van a resultados.
5. El stock negativo utiliza costo provisional. La regularización genera replay y
   diferencias explícitas, sin reescribir eventos históricos.
6. Las transferencias llevan costo transportado, posición `IN_TRANSIT` y flete
   capitalizable. No alteran el consolidado salvo cargos externos.
7. La UOM de valuación es la unidad del artículo; para pesables es kilogramo. Los
   bultos se convierten mediante el factor de compra del proveedor congelado en la
   OC y en el evento.
8. La moneda funcional es ARS. El modelo conservará moneda e importe original,
   tipo de cambio, fecha y fuente para soportar operaciones futuras.
9. Dentro de la compañía se usan transferencias sin resultado. Entre compañías se
   registran compra/venta intercompany. Recetas y rotisería se modelan como
   transformación: consumo de ingredientes al costo local más costos de conversión.
10. Una devolución sin documento original se valoriza al precio de lista vigente,
    conservando por separado valor comercial, valor contable y excepción aplicada.
11. Ajustes positivos y sobrantes ingresan al costo promedio local. Los negativos
    salen al costo local vigente.
12. Los períodos cerrados admiten reapertura y replay mediante nuevas versiones y
    asientos delta; nunca mediante edición destructiva.
13. El costo comercial usa una combinación parametrizable de última compra,
    promedio de recepciones, lista vigente, proveedor, disponibilidad, acuerdos,
    rappel, flete e impuestos.
14. La OC elegida determina el costo de la recepción. Las listas de todos los
    proveedores se conservan para abastecimiento y costo proyectado, pero no se
    mezclan con el costo contable de la compra recibida.
15. Los acuerdos sin SKU se distribuyen por esta jerarquía: recepción/SKU,
    categoría o marca, proveedor y finalmente compras netas elegibles. Sin una base
    objetiva, el concepto va a resultados.
16. La mercadería bonificada integra la cantidad total recibida y reduce el costo
    unitario. Si el SKU bonificado es distinto, la contraprestación se distribuye
    por precios relativos. La bonificación no oculta la merma física.
17. Impuestos recuperables y percepciones computables no integran costo y se
    transportan como datos fuente hacia SAP, que mantiene el registro fiscal
    oficial. Los no recuperables y directamente atribuibles sí integran costo; la
    recuperabilidad parcial se divide explícitamente.
18. El costo comercial sigue `DRAFT -> CALCULATED -> UNDER_REVIEW -> APPROVED ->
    PUBLISHED -> SUPERSEDED`, con cuatro ojos, tolerancias, vigencia, motivo de
    override y segregación de funciones.
19. El ledger es inmutable, idempotente, reproducible y trazable a documento,
    regla, usuario, aprobación y asiento. La retención se parametriza por compañía
    y clase documental conforme a los estándares de auditoría aplicables.
20. Movimiento, valorización provisional, posición local y outbox se confirman de
    forma síncrona al cierre físico. Los consumidores posteriores pueden procesar
    asincrónicamente con SLA, reintentos e idempotencia.
21. CONNEXA no implementa contabilidad, subledger de proveedores, liquidación
    fiscal, pagos ni reporting legal propios. Conserva la evidencia y el detalle
    necesarios para costo e interfaces completas con SAP, sistema de registro
    oficial para esas funciones salvo decisión explícita del blueprint.

## Gobierno de cambios de base de datos

Se establece como restricción de implementación:

- únicamente el grupo CORE realiza cambios en las bases CONNEXA;
- cada cambio comienza con una solicitud documentada;
- el equipo del proyecto genera un script Flyway, pero no lo ejecuta;
- Arquitectura revisa modelo, impacto, compatibilidad, performance y recuperación;
- CORE implementa y promueve el cambio de manera escalonada;
- cada ambiente requiere evidencia y autorización antes de avanzar al siguiente;
- una corrección posterior se realiza con una nueva migración, nunca modificando
  una migración ya aplicada.

## Parámetros pendientes, no decisiones conceptuales

- matriz de recuperabilidad por impuesto, compañía, jurisdicción, operación y
  vigencia;
- tolerancias de cantidad, precio, impuesto y total por proveedor/categoría;
- umbrales de materialidad y circuito nominal de aprobadores;
- tasas esperadas, probabilidad y método de prorrateo por tipo de acuerdo;
- fuente y convención de tipo de cambio;
- plazos de retención y clasificación de información;
- SLA cuantitativo para publicación, replay, conciliación y recuperación;
- reglas de costos de conversión, rendimiento, merma y subproductos por receta.

## Datos y contratos a corregir o certificar

- Agregar `product_id` y `purchase_order_line_id` a la recepción o al evento que
  publica.
- Congelar precio, moneda, UOM/factor y componentes en el evento de recepción.
- Transportar costo por línea en transferencias.
- Documentar o reemplazar `custom1..4` en movimientos.
- Resolver las 13.132 filas `PENDING` del replicador y certificar su semántica.
- Reconciliar productos no coincidentes entre réplicas.
- Certificar la frescura de `stk_stock` y poblar fecha efectiva.
- Depurar catálogo de tipos de movimiento y códigos duplicados.
- Definir si las 1.012 posiciones negativas son válidas o errores de integración.

## Próximo taller de parametrización

Realizar un taller de 90 minutos con un caso completo y documentos reales
anonimizados:

1. OC con precio, descuento y bonificación;
2. recepción parcial en una sucursal;
3. transferencia de parte de la mercadería a otra sucursal;
4. venta parcial;
5. nota de crédito mensual y rappel;
6. cálculo esperado de las tres métricas antes y después de cada paso.

El resultado debe ser una matriz versionada de reglas y casos esperados, utilizable
como especificación y como fixture de pruebas.
