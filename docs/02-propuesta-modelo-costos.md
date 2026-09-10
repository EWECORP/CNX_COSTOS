---
id: CNX-COST-ARC-001
titulo: Propuesta de arquitectura para costos comerciales
estado: aprobado-con-diseno-detallado-pendiente
version: 1.0
fecha: 2026-09-01
propietario: por-definir
documento_relacionado: CNX-COST-REL-001
---

# Propuesta de arquitectura para costos comerciales

## Decisión arquitectónica principal

Crear un bounded context `cost_management` que mantenga un ledger económico
inmutable y proyecciones de lectura. Stock Management continúa siendo autoridad de
cantidades operativas; Cost Management mantiene una cantidad espejo para valuar y
reconciliar, no para reemplazar la operación de stock.

El modelo publica tres métricas distintas:

| Métrica | Granularidad | Uso |
|---|---|---|
| `local_inventory_wac` | compañía, artículo, sucursal, UOM, moneda | valuación, costo de venta, rentabilidad y performance de la sucursal |
| `company_inventory_wac` | compañía, artículo, UOM, moneda | valuación consolidada del inventario existente |
| `company_commercial_net_cost` | compañía, artículo, moneda, vigencia | costo neto comercial unificado para precios, margen objetivo y decisiones comerciales |

Esta arquitectura y las decisiones funcionales 1 a 23 fueron aprobadas
conceptualmente el 1 de septiembre de 2026. No deben exponerse bajo un único
nombre ambiguo. El costo comercial puede incluir
condiciones estimadas o devengadas que no corresponden capitalizar en inventario;
por eso no siempre coincide con el promedio consolidado.

El **Costo Neto Comercial Unificado** es único a nivel compañía/cadena por artículo,
UOM, moneda y vigencia. Pricing, promociones y fijación de márgenes deben consumir
la versión `PUBLISHED` de este costo para mantener una base homogénea entre
sucursales. Las excepciones comerciales locales, si se habilitan, se aplican como
reglas de precio y no crean otra autoridad de costo.

La rentabilidad y performance de cada sucursal se calculan con el costo local
efectivamente aplicado a sus salidas. Para análisis históricos se utiliza
`cst_cost_event_line.unit_cost` y el evento de venta correspondiente; nunca el CPP
actual, porque puede haber cambiado después de la operación.

## Componentes del modelo

### 1. Ledger de eventos

`cst_cost_event` registra el hecho económico: tipo, fuente, documento, momento
efectivo, momento de registración, estado, moneda, clave idempotente y eventual
reversa.

`cst_cost_event_line` registra cada artículo-sitio con:

- cantidad en UOM canónica;
- costo unitario y variación de valor;
- posición y costo antes/después;
- documento y línea origen;
- sucursal contraparte cuando corresponda;
- versión de política aplicada.

Los eventos publicados no se editan. Un error se corrige con un evento inverso y
un evento nuevo. Esto permite reproducir cualquier posición y explicar cada
cambio.

### 2. Componentes y asignaciones

`cst_cost_component` descompone el valor en precio base, descuento en factura,
bonificación, flete, impuesto no recuperable, rappel, nota de crédito u otro
concepto. Cada componente declara tres tratamientos independientes:

- capitaliza inventario;
- integra costo comercial;
- va directo a resultados.

`cst_adjustment_allocation` distribuye notas de crédito, acuerdos y ajustes
retroactivos a recepciones, artículos y sucursales. Debe conservar la base y el
método de prorrateo utilizados.

### 3. Posiciones actuales

`cst_site_cost_position` es la proyección artículo-sucursal: cantidad, valor,
promedio ponderado, último evento de stock, último evento de costo y versión.

`cst_company_cost_position` consolida cantidades y valores de todos los sitios de
una compañía. También referencia la versión vigente del costo neto comercial.

`cst_site_daily_close` identifica y controla el cierre de una sucursal para una
fecha de negocio: zona horaria, instante de corte, versión, estado, último evento
incluido, cantidades de control y hash. `cst_site_daily_balance` conserva para esa
versión la cantidad, valor y CPP final de cada artículo/UOM/moneda.

El cierre diario es una proyección histórica del ledger, no otra autoridad de
stock. Una reapertura crea una nueva versión de `cst_site_daily_close` y nuevas
líneas; la versión anterior pasa a `SUPERSEDED` y nunca se actualizan sus importes.

Las proyecciones pueden reconstruirse desde el ledger. La actualización debe ser
transaccional, secuencial por artículo-sitio y protegida con versión optimista.

### 3.1. Cierre diario por sucursal

El proceso sólo puede marcar un cierre como `CLOSED` cuando:

- alcanzó el watermark de eventos definido para la sucursal y fecha;
- no existen eventos anteriores pendientes o rechazados sin resolución;
- cantidad final reconcilia con la posición operativa certificada;
- valor y CPP se reconstruyen desde el ledger;
- la cantidad de posiciones esperadas coincide con las generadas;
- se guardaron totales y hash de control.

Estados propuestos: `CALCULATING`, `PROVISIONAL`, `CLOSED`, `SUPERSEDED` y
`FAILED`. La reapertura se representa mediante una versión nueva que referencia a
la anterior, no mediante edición de sus saldos. Sólo una versión puede ser el cierre vigente por
compañía, sucursal y fecha de negocio.

### 4. Versiones de costo comercial

`cst_commercial_cost_version` publica un costo único por artículo y vigencia, con
su método, componentes, evidencia y hash de cálculo. Una versión puede estar en
`DRAFT`, `CALCULATED`, `UNDER_REVIEW`, `APPROVED`, `PUBLISHED` o `SUPERSEDED`.

Pricing y márgenes deben consumir solamente versiones `PUBLISHED`, mientras que
simulaciones pueden usar `DRAFT` de forma explícita.

La publicación es corporativa: no se generan versiones comerciales distintas por
sucursal. Cada mensaje de outbox debe identificar la versión, vigencia, UOM,
moneda, método y hash de cálculo del Costo Neto Comercial Unificado.

### 5. Reconciliación y publicación

`cst_reconciliation` compara periódicamente cantidad espejo contra `stk_stock`, y
valor consolidado contra la suma de posiciones locales. Las diferencias generan
alerta y nunca se corrigen silenciosamente.

Un outbox transaccional publica cambios de costo a Pricing, Analytics y otros
consumidores sin acoplarlos a las tablas internas.

## Reglas de cálculo

### Entrada por compra

Para una posición positiva o nula:

```text
valor_nuevo    = valor_anterior + cantidad_recibida * costo_unitario_capitalizable
cantidad_nueva = cantidad_anterior + cantidad_recibida
costo_pp_nuevo = valor_nuevo / cantidad_nueva
```

El costo unitario capitalizable se congela al cerrar la recepción:

```text
precio base
- descuentos de factura
- bonificaciones atribuibles
- rappel y acuerdos de compra estimados elegibles
+ flete capitalizable
+ impuestos no recuperables
+ otros cargos capitalizables
```

La OC es una expectativa. El impacto se produce con una recepción en estado final
aceptado, usando la cantidad efectivamente recibida.

Cuando la factura todavía no está conciliada, la recepción se valoriza de forma
`PROVISIONAL` con el precio y condiciones conocidos de la OC. La conciliación de
factura no vuelve a ingresar unidades: genera un ajuste de valor por la diferencia
entre el costo provisional y el costo capitalizable definitivo. Una nota de
crédito conciliada genera otro ajuste de valor negativo y conserva la referencia a
la factura, recepción y artículos afectados.

### Salida

```text
valor_salida   = cantidad_salida * costo_pp_anterior
valor_nuevo    = valor_anterior - valor_salida
cantidad_nueva = cantidad_anterior - cantidad_salida
```

Mientras quede stock positivo, el costo promedio no cambia. Se registra el costo
de salida para trazabilidad y margen realizado.

### Transferencia interna

Una transferencia dentro de la misma compañía no es una nueva compra:

1. la salida retira cantidad y valor al costo de origen;
2. una posición virtual `IN_TRANSIT` conserva ese valor;
3. la recepción ingresa al destino con el costo transportado;
4. solo fletes u otros cargos capitalizables agregan valor;
5. el valor y costo consolidado de compañía no cambian salvo por esos cargos.

El CD se modela como otro sitio. Una operación entre compañías distintas se trata
como venta y compra intercompany, no como transferencia interna.

### Ajustes físicos

Un conteo que informa cantidad absoluta se convierte en un delta contra la
posición previa. Una baja retira valor al costo promedio. Un alta o sobrante
ingresa al costo promedio local vigente y conserva motivo y aprobación.

### Devoluciones

- A proveedor: usar el costo de la recepción original cuando exista trazabilidad;
  sin documento original usar el precio de lista vigente y registrar por separado
  valor comercial, valor contable y diferencia.
- De cliente: revertir el costo de salida original cuando sea posible; fallback al
  costo promedio actual.

### Notas de crédito y acuerdos

Una nota o acuerdo debe clasificarse antes de impactar:

| Caso | Inventario | Costo comercial | Resultado |
|---|---|---|---|
| Descuento atribuible a mercadería aún en stock | sí | sí | parte vendida solamente |
| Rappel estimado sobre compras | según política de devengamiento | sí | parte no capitalizable/vendida |
| Ajuste prospectivo de lista | no | sí | no |
| Servicio de exhibición o publicidad | no | configurable como ingreso comercial separado | sí |
| Penalidad o acuerdo financiero | no | normalmente no | sí |

Para rappel mensual se recomienda devengar una tasa esperada sobre recepciones y
realizar un `TRUE_UP` al liquidar. La diferencia se reparte entre inventario
remanente y costo de mercadería vendida según una política aprobada. La estimación
y la liquidación real deben conservarse como componentes distintos.

Cuando un acuerdo de compras no identifique SKU, se asigna en orden a recepción o
SKU, categoría/marca, proveedor y compras netas elegibles. Sin base objetiva, el
importe se registra en resultados. Los acuerdos por publicidad, exhibición,
financiación o servicios no reducen inventario.

### Bonificaciones y merma

Las unidades gratis del mismo artículo se suman a la cantidad recibida y el valor
total pagado se distribuye sobre todas las unidades. Si la bonificación corresponde
a otro SKU, el valor se distribuye usando precios relativos. No se registra el SKU
bonificado en cero si eso distorsiona margen, transferencia o devolución.

La merma física se registra en bruto cuando ocurre. Una bonificación que la
compensa puede reducir costo y alimentar un indicador adicional de merma neta,
pero no debe ocultar la pérdida operativa.

### Impuestos

La recuperabilidad se resuelve mediante una matriz versionada por compañía,
impuesto, jurisdicción, artículo/categoría, proveedor, operación y vigencia:

- IVA y percepciones recuperables: dato fuente de la interfaz contable, fuera del costo;
- impuestos no recuperables directamente atribuibles: integran costo;
- recuperabilidad parcial: división explícita entre crédito y costo;
- retenciones: crédito/cancelación tributaria, no costo;
- clasificación incierta: provisional y ajustable al conciliar.

### Transformaciones y recetas

Una receta se registra mediante una orden de transformación. Los ingredientes
salen al costo local; el producto elaborado ingresa con ingredientes más costos de
conversión atribuibles. Rendimiento, merma, coproductos y subproductos quedan
separados. No se modela como transferencia.

### Stock negativo

El stock negativo observado impide aplicar el promedio simple sin distorsión. Se
propone:

1. conservar el último costo válido como costo provisional de las salidas que
   llevan la posición a negativo;
2. al recibir, cancelar primero la cantidad negativa;
3. reconocer por separado la diferencia entre costo provisional y costo real;
4. promediar únicamente el remanente que deja stock positivo;
5. marcar la posición y los eventos como `PROVISIONAL` hasta regularización.

## Matriz inicial de eventos

| Evento | Cantidad local | Valor local | Costo PP local | Consolidado compañía |
|---|---:|---:|---:|---:|
| Recepción proveedor cerrada | + | + al costo recibido | recalcula | recalcula |
| Venta/salida | - | - al PP | no cambia | PP no cambia |
| Transferencia enviada | - origen / + tránsito | mueve valor | destino pendiente | no cambia |
| Transferencia recibida | - tránsito / + destino | mueve valor | recalcula destino | no cambia |
| Ajuste negativo | - | - al PP | no cambia | PP no cambia |
| Ajuste positivo | + | + según política | recalcula | recalcula |
| NC capitalizable | 0 | - | recalcula | recalcula |
| Rappel devengado | 0 | según política | según política | actualiza costo comercial |
| Cambio de lista | 0 | 0 | no cambia | solo costo comercial |

## Contratos necesarios con módulos actuales

### Procurement and Sourcing

El evento de recepción debería incluir como mínimo:

- `event_id` idempotente;
- `purchase_order_id`, `purchase_order_line_id`, `reception_id` y
  `reception_line_id`;
- `product_id`, `site_id`, cantidad, UOM y factor a UOM canónica;
- precio unitario congelado, descuentos, cargos, impuestos y moneda;
- fecha efectiva y fecha de contabilización;
- estado final o reversa.

Durante una transición puede resolverse la línea de OC por `(purchase_order_id,
sku)`, dado que hoy es unívoco, pero el contrato definitivo debe transportar IDs.

### Stock Management

Cada movimiento debe incluir documento y línea origen, fecha efectiva completa,
secuencia, cantidad en UOM canónica y tipo normalizado. Los campos `custom1..4` no
son un contrato suficiente sin semántica documentada.

`stk_stock` sigue siendo la cantidad operativa a reconciliar. No debe usarse como
única fuente para inferir historia.

### Transferencias

La salida debe publicar el costo transportado por línea, calculado por Cost
Management a partir de la posición de origen. La cabecera puede mantener el total,
pero no debe prorratearse entre artículos sin una base aprobada.

### Commercial Agreements

El módulo debe publicar eventos de devengamiento, liquidación y reversa con alcance
resuelto a artículos/sitios, base de cálculo, tasa, período y documento generado.
La clasificación contable/comercial pertenece a una política versionada, no a
lógica fija dentro del consumidor.

### BRIDGE y documentos de venta

BRIDGE debe publicar cabecera, línea, artículo, sucursal, caja, precio, cantidad,
promoción, impuestos, moneda y clave fiscal/idempotente. La línea comercial genera
el movimiento de salida; Cost Management asigna el costo de mercadería vendida.
La interfaz del sistema contable consume el documento canónico; no reconstruye IVA ni ventas desde
movimientos agregados de stock. El sistema contable conserva los registros fiscal y contable
oficiales.

## Consistencia al cierre

El cierre físico de una recepción confirma como una única unidad lógica:

1. recepción cerrada;
2. movimiento de cantidad;
3. valorización provisional;
4. actualización de posición local;
5. posición en tránsito cuando corresponda;
6. registro de outbox.

Si no puede persistirse movimiento y valorización, la recepción queda en una
excepción controlada y no en estado final silencioso. Factura, OCR, conciliación,
interfaz contable y publicación hacia consumidores pueden ejecutarse asincrónicamente
con SLA, reintentos, monitoreo e idempotencia.

## Aprobación, publicación y auditoría

Compras valida condiciones y acuerdos; Operaciones cantidades, UOM y flete;
Impuestos recuperabilidad; Contabilidad capitalización y resultados; Comercial
aprueba la versión publicada para Pricing. Cambios manuales requieren cuatro ojos,
motivo, vigencia, tolerancia y evidencia.

El ledger es append-only. Conserva documento y hash, evento origen, fecha efectiva
y de registración, valores antes/después, regla y versión, actor, aprobación,
reversa y correlación con la referencia externa. La retención y acceso se parametrizan
por compañía y clase documental.

## Compatibilidad con la arquitectura de CONNEXA

- Usa un esquema y prefijo propios: `cost_management.cst_*`.
- Conserva UUID de producto y sitio; evita depender de códigos mutables.
- Respeta bounded contexts: referencias externas por ID y contratos de evento, no
  escrituras cruzadas en tablas de otros módulos.
- Replica solo los datos maestros mínimos si el servicio necesita autonomía.
- Usa outbox/inbox e idempotencia, compatibles con procesamiento asíncrono.
- Mantiene políticas parametrizables por compañía y vigencia.
- Usa `numeric` para cantidades e importes monetarios, no `double precision`.

## Precisión propuesta

| Dato | Tipo sugerido |
|---|---|
| Cantidad canónica | `numeric(20,6)` |
| Costo unitario | `numeric(20,8)` |
| Importe/valor | `numeric(20,4)` |
| Tasa/porcentaje | `numeric(12,8)` |
| Tiempo efectivo | `timestamptz` |

El redondeo ocurre al publicar o contabilizar, no en cada paso intermedio. La
política debe indicar moneda base, escala y método de redondeo.

## Secuencia de implementación sugerida

1. Parametrizar las decisiones aprobadas de `03-decisiones-abiertas.md`.
2. Certificar contratos de recepción, BRIDGE, transferencia y movimiento.
3. Documentar la solicitud de cambio y preparar la migración Flyway para revisión
   de Arquitectura y ejecución exclusiva de CORE.
4. Crear ledger, posiciones, auditoría y reconciliación.
5. Generar apertura desde stock y costo inicial certificados.
6. Ejecutar en modo sombra y reconciliar cantidades/valores.
7. Activar recepciones provisionales y ajustes documentales.
8. Activar ventas, transferencias y transformaciones.
9. Incorporar notas de crédito, impuestos y acuerdos comerciales.
10. Publicar costo comercial y subledgers hacia Pricing, Analytics y Finanzas.

El detalle de fases y criterios de salida se encuentra en
`06-plan-de-implementacion.md`. El gobierno obligatorio de cambios está definido
en `07-gobierno-cambios-base-datos.md`.

## Criterios mínimos de aceptación

- Reprocesar dos veces el mismo evento no cambia el resultado.
- Reversa más evento original deja cantidad y valor iniciales.
- Una transferencia interna sin cargos conserva el valor consolidado.
- La suma de posiciones locales coincide con la posición de compañía.
- Cada sucursal/fecha posee como máximo una versión diaria vigente.
- El detalle diario coincide con la posición reconstruida al instante de corte.
- Reabrir y repetir un cierre conserva la versión anterior y publica otra con sus
  diferencias explicables.
- Cada posición identifica su último evento aplicado.
- El ledger reproduce exactamente la posición actual.
- La cantidad espejo reconcilia con `stk_stock` dentro de tolerancia acordada.
- Los eventos tardíos siguen una regla de reapertura o ajuste documentada.
- Pricing conoce la versión y composición del costo consumido.
- El cierre de recepción nunca queda final sin movimiento y costo provisional.
- Una bonificación reduce costo sin compensar la merma física registrada.
- Un impuesto recuperable nunca capitaliza y uno no recuperable aplica la matriz
  vigente.
- El replay de un período cerrado produce deltas auditables y es determinístico.
