---
id: CNX-COST-ARC-001
titulo: Propuesta de arquitectura para costos comerciales
estado: borrador
version: 0.1
fecha: 2026-08-31
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
| `local_inventory_wac` | compañía, artículo, sucursal, UOM, moneda | valuación y costo de salida local |
| `company_inventory_wac` | compañía, artículo, UOM, moneda | valuación consolidada del inventario existente |
| `company_commercial_net_cost` | compañía, artículo, moneda, vigencia | precios, margen y decisiones comerciales |

No deben exponerse bajo un único nombre ambiguo. El costo comercial puede incluir
condiciones estimadas o devengadas que no corresponden capitalizar en inventario;
por eso no siempre coincide con el promedio consolidado.

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

Las proyecciones pueden reconstruirse desde el ledger. La actualización debe ser
transaccional, secuencial por artículo-sitio y protegida con versión optimista.

### 4. Versiones de costo comercial

`cst_commercial_cost_version` publica un costo único por artículo y vigencia, con
su método, componentes, evidencia y hash de cálculo. Una versión puede estar en
`DRAFT`, `APPROVED`, `PUBLISHED` o `SUPERSEDED`.

Pricing y márgenes deben consumir solamente versiones `PUBLISHED`, mientras que
simulaciones pueden usar `DRAFT` de forma explícita.

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
posición previa. Una baja retira valor al costo promedio. Un alta necesita una
política de valorización explícita: costo promedio vigente, costo comercial
publicado o costo informado y aprobado.

### Devoluciones

- A proveedor: usar el costo de la recepción original cuando exista trazabilidad;
  de lo contrario aplicar la política de fallback y registrar la excepción.
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

1. Aprobar las decisiones funcionales de `03-decisiones-abiertas.md`.
2. Normalizar contratos de recepción, transferencia y movimiento.
3. Crear ledger, posiciones y reconciliación.
4. Generar eventos de apertura desde stock y costo inicial certificados.
5. Ejecutar en modo sombra y reconciliar cantidades/valores.
6. Activar recepciones y salidas.
7. Activar transferencias con costo transportado.
8. Incorporar notas de crédito y acuerdos comerciales.
9. Publicar costo comercial aprobado hacia Pricing y Analytics.

## Criterios mínimos de aceptación

- Reprocesar dos veces el mismo evento no cambia el resultado.
- Reversa más evento original deja cantidad y valor iniciales.
- Una transferencia interna sin cargos conserva el valor consolidado.
- La suma de posiciones locales coincide con la posición de compañía.
- Cada posición identifica su último evento aplicado.
- El ledger reproduce exactamente la posición actual.
- La cantidad espejo reconcilia con `stk_stock` dentro de tolerancia acordada.
- Los eventos tardíos siguen una regla de reapertura o ajuste documentada.
- Pricing conoce la versión y composición del costo consumido.
