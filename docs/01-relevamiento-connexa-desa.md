---
id: CNX-COST-REL-001
titulo: Relevamiento de costos y stock en CONNEXA DESA
estado: borrador
version: 0.1
fecha: 2026-08-31
propietario: por-definir
ambiente: Connexa DESA
---

# Relevamiento de costos y stock en CONNEXA DESA

## Alcance y fuentes

El relevamiento fue realizado el 31 de agosto de 2026 mediante consultas de solo
lectura sobre `connexa_platform_ms`. Se inspeccionaron catálogo, restricciones,
estadísticas y agregados; no se modificó la base.

Fuentes utilizadas:

- catálogo PostgreSQL de DESA;
- datos agregados de los esquemas `inventory`, `stock_management`,
  `procurement_and_sourcing` y `commercial_agreements`;
- código de sincronización de productos de `C:\ETL\CNX_DIARCO_SYNC_V2`;
- historial Flyway disponible en la propia base.

El endpoint solicitado para `Connexa_DESA` no expone PostgreSQL directamente a
esta red. El endpoint de base configurado en los procesos ETL sí conecta con
`connexa_platform_ms`. No se registran direcciones ni credenciales en este
documento.

## Resumen ejecutivo

CONNEXA ya dispone de entidades para productos, sitios, stock actual, movimientos,
órdenes de compra, recepciones, transferencias y acuerdos comerciales. Sin
embargo, hoy no existe un ledger central de costo ni una posición de valor/costo
por artículo-sucursal.

Los campos `base_price` actuales son precios maestros replicados, no un costo
promedio ponderado calculado a partir de movimientos. El stock actual conserva
cantidad, pero no valor, costo promedio ni referencia al último movimiento que lo
explica. Por eso el modelo vigente no alcanza para trazabilidad histórica,
valuación reproducible ni costo neto comercial consolidado.

## Modelo existente

### Maestros

| Entidad | Tabla actual | Hallazgo |
|---|---|---|
| Producto | `inventory.inv_product` | 18.232 filas; contiene `base_price` |
| Producto-proveedor | `inventory.inv_product_supplier` | 22.746 filas; contiene otro `base_price` |
| Producto replicado en stock | `stock_management.stk_stock_product` | 18.263 filas |
| Sitio replicado en stock | `stock_management.stk_stock_site` | 185 filas |
| Producto-sitio de abastecimiento | `procurement_and_sourcing.pas_product_site` | existe, pero está vacío |

Los identificadores UUID se preservan mayormente entre bounded contexts: 18.229
de 18.232 productos de Procurement coinciden por ID con Inventory; los 185 sitios
de Stock coinciden con sitios de Procurement. Existen diferencias que deberán
reconciliarse antes del arranque del nuevo servicio.

En la integración vigente, `inventory.inv_product.base_price` se actualiza desde
`src.m_3_articulos.precio_compra`. Es, por lo tanto, un dato fuente de precio de
compra y no el resultado de un promedio ponderado por recepción.

### Posición de stock

`stock_management.stk_stock` tiene una clave única por `(product_id, site_id)` y
almacena cantidad y unidad de medida. No almacena:

- valor de inventario;
- costo promedio;
- moneda;
- último movimiento aplicado;
- documento origen;
- versión de cálculo.

Perfil observado:

| Métrica | Valor |
|---|---:|
| Posiciones | 117.334 |
| Productos con posición | 14.657 |
| Sitios con posición | 11 |
| Posiciones en cero | 73.046 |
| Posiciones negativas | 1.012 |
| Posiciones con fecha/hora de fuente | 0 |

`created_at` está entre enero y febrero de 2026, pero no permite demostrar la
frescura de la cantidad porque puede no actualizarse con cada cambio.

### Movimientos de stock

El catálogo `stk_stock_movement_type` es amplio y contempla recepciones,
transferencias, ventas, devoluciones, inventarios, mermas y ajustes. Hay problemas
de calidad en el catálogo: códigos externos duplicados, errores tipográficos y
semánticas de `overrides_existing_stock` que deben validarse.

La tabla final `stock_management.stk_stock_movement` contiene solo 15 filas. Ningún
par artículo-sitio de esas filas coincide con las 117.334 posiciones actuales.
Consecuentemente, hoy no puede responderse cuál fue el último movimiento que
explica cada stock.

Procurement contiene además 13.132 filas en
`pas_stock_movement_replicator`, todas con estado `PENDING`, y ninguna comparte ID
con las 15 filas del servicio de Stock. Esas filas cubren 5.181 pares
artículo-sitio, pero solo 3.383 posiciones actuales. Esto es evidencia de una
brecha de publicación o de una semántica no documentada; no se afirma que sea una
falla de runtime sin revisar el servicio productor y consumidor.

### Estructuras que parecen un Kardex, pero no lo son

La búsqueda adicional de tablas, vistas, rutinas y triggers confirmó que no existe
un Kardex valorizado central:

- `stk_stock_count_snapshot` tiene columnas `cost` y `wac`, pero sus 14.657 filas
  corresponden a un único conteo físico y ambos campos están nulos en todas ellas;
- `view_base_stock_sucursal` expone stock, precio de costo y último ingreso como una
  foto proveniente del sistema origen, no como una secuencia de movimientos;
- las vistas `stockfull` y `stockfull_actives` solo combinan producto, sucursal y
  cantidad;
- Supply Planning conserva costos de referencia, costo neto o última recepción en
  entidades de cálculo y workflow, pero no registra cada entrada y salida
  valorizada;
- no hay funciones de costo/Kardex ni triggers que actualicen cantidad, valor y
  promedio ante movimientos de Stock o Procurement.

Estas estructuras pueden aportar saldo inicial o referencias para reconciliación,
pero no sustituyen un ledger auditable.

### Compras y recepciones

| Entidad | Filas | Período observado |
|---|---:|---|
| Órdenes de compra | 39.426 | 2024-02-08 a 2026-08-28 |
| Líneas de OC | 403.653 | — |
| Recepciones | 1.792 | desde 2026-03-16 |
| Líneas de recepción | 12.734 | 2026-07-06 a 2026-08-25 |

Todas las líneas de OC tienen `unit_price`; 403.621 tienen valor positivo. Ninguna
usa actualmente `discount_rate`. El vínculo `trade_agreement_id` de la cabecera de
OC tampoco está poblado.

La línea de recepción guarda SKU, cantidad y UOM, pero no `product_id`,
`purchase_order_line_id`, precio, descuentos, impuestos ni costo efectivo. Hoy se
puede reconstruir la línea de OC por `(purchase_order_id, sku)`: las 12.734 líneas
observadas resolvieron de manera unívoca y no hay SKU repetidos dentro de una OC.
Esto es útil para un adaptador inicial, pero es una dependencia implícita y frágil
para un contrato definitivo.

Los estados disponibles permiten registrar costo al cerrar una recepción y no al
crear la OC. La recepción cancelada no debe producir efecto; una corrección de una
recepción ya contabilizada debe generar reversa, no editar historia.

### Transferencias

Existen 6.399 transferencias y 143.343 líneas entre enero y agosto de 2026. La
cabecera tiene `total_transfer_valuation` poblado en todas las órdenes y positivo
en 6.355, pero la línea no conserva costo unitario ni valor transferido. Por ello
no puede determinarse el valor artículo por artículo a partir de la transferencia
sola.

La recepción de transferencia tiene 1.519 líneas. El modelo permite distinguir
origen y destino, pero falta transportar el costo originado en la sucursal o CD de
salida.

### Acuerdos comerciales

El esquema `commercial_agreements` ya modela:

- acuerdos y plantillas;
- cuotas con monto fijo;
- porcentaje sobre recepciones;
- rappel sobre recepciones y escalas;
- alcance por artículo/clase y por tienda;
- contraprestaciones;
- tipo de documento a generar, incluida solicitud de nota de crédito.

Las tablas transaccionales analizadas están vacías en DESA. La capacidad de
modelado existe, pero todavía no hay datos con los cuales validar liquidación,
devengamiento o distribución al costo.

## Brechas para el objetivo de costos

1. No existe un hecho económico inmutable que una documento, artículo, sitio,
   cantidad, precio, componentes de costo y momento efectivo.
2. `stk_stock` es una posición de cantidad, no una posición valorizada.
3. No existe costo promedio por artículo-sucursal ni consolidado compañía.
4. No existe referencia confiable al último movimiento aplicado a cada posición.
5. Las recepciones no congelan el costo unitario aplicado.
6. Las transferencias no preservan costo por línea.
7. Los ajustes comerciales no están clasificados entre inventario, costo
   comercial y resultado.
8. Se usan `double precision` para importes; un ledger monetario debería usar
   decimales exactos.
9. Hay stock negativo y debe definirse una política explícita para que no deforme
   el promedio.
10. No hay reconciliación demostrable entre ledger de movimientos y posición de
    stock.

## Conclusión

La extensión debe construirse como un bounded context de costos que consuma los
eventos ya originados por Procurement, Stock y Acuerdos Comerciales. No conviene
agregar solamente una columna de costo a `stk_stock`: eso resolvería la lectura
actual, pero no la trazabilidad, reversiones, retroactividad, auditoría ni el costo
comercial consolidado.
