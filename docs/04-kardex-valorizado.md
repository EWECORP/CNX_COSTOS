---
id: CNX-COST-KDX-001
titulo: Kardex valorizado central
estado: aprobado-con-diseno-detallado-pendiente
version: 1.0
fecha: 2026-09-01
propietario: por-definir
documento_relacionado: CNX-COST-ARC-001
---

# Kardex valorizado central

## Respuesta corta

CONNEXA no tiene actualmente una entidad que funcione como Kardex valorizado
completo. Tiene documentos operativos, movimientos de cantidad, snapshots y
costos usados por otros cálculos, pero no un registro único que permita contestar:

> ¿Qué operación cambió este artículo-sucursal, en qué cantidad, por qué valor y
> cómo dejó el costo promedio?

El ledger propuesto en `cost_management` cubre esa brecha mediante
`cst_cost_event` y `cst_cost_event_line`.

## Situación durante la absorción de SGM

El historial operativo está repartido entre generaciones del modelo. PROD y TEST
conservan 337.436 movimientos en `public.fnd_stock_movement`; PROD sólo tenía 15
en `stock_management.stk_stock_movement`. DESA contenía 8.839.025 movimientos en
el modelo monolítico. TEST incorporó `inventory.inv_stock_movement` el 31 de agosto
de 2026, todavía sin datos al momento del relevamiento.

Esta coexistencia explica el bajo volumen del modelo nuevo. La nueva tabla mejora
la separación por contexto, pero sigue siendo un movimiento de cantidades y no un
Kardex valorizado.

## Diferencia entre movimiento y Kardex

Un movimiento de stock dice principalmente cuánto entró o salió. Un asiento de
Kardex debe congelar además su efecto económico:

| Dato | Movimiento actual | Kardex requerido |
|---|---:|---:|
| Artículo y sucursal | sí | sí |
| Cantidad y UOM | sí | sí, normalizada |
| Fecha efectiva completa | parcial | sí |
| Documento y línea origen | no confiable | sí |
| Costo unitario aplicado | no | sí |
| Variación de valor | no | sí |
| Cantidad antes/después | no | sí |
| Valor antes/después | no | sí |
| Costo promedio antes/después | no | sí |
| Moneda | no | sí |
| Reversa e idempotencia | no | sí |

## Estructura mínima del asiento

Cada línea del Kardex necesita:

- identificador inmutable e idempotente;
- compañía, artículo, sucursal y UOM canónica;
- tipo de movimiento;
- fecha efectiva, fecha de registración y secuencia;
- servicio, documento y línea origen;
- cantidad con signo;
- costo unitario aplicado;
- valor con signo;
- cantidad, valor y costo promedio antes/después;
- moneda y versión de la política de valuación;
- estado provisional/definitivo;
- referencia al asiento revertido cuando corresponda.

También debe admitir asientos con `quantity_delta = 0` y `value_delta != 0`. Son
necesarios para notas de crédito, rappel, revalorizaciones y otros ajustes que
cambian el valor sin mover unidades.

## Operaciones que deben producir asientos

- saldo inicial certificado;
- recepción de proveedor;
- venta o consumo;
- transferencia enviada, en tránsito y recibida;
- devolución a proveedor;
- devolución de cliente;
- ajuste positivo o negativo;
- diferencia de inventario;
- merma, rotura, vencimiento o decomiso;
- nota de crédito/débito atribuible a mercadería;
- devengamiento y liquidación de acuerdos comerciales;
- venta BRIDGE vinculada a su documento y línea comercial;
- consumo y producción mediante orden de transformación/receta;
- reversa y corrección.

## Transferencias: registración de doble efecto

Una transferencia interna debe generar al menos dos líneas y preferentemente una
posición intermedia:

```text
Sucursal origen  - cantidad / - valor al costo promedio de origen
En tránsito       + cantidad / + el mismo valor
En tránsito       - cantidad / - valor transportado
Sucursal destino  + cantidad / + valor transportado
```

La suma para la compañía es cero, salvo flete u otro cargo capitalizable. Esto
evita tratar una transferencia como una nueva compra y alterar artificialmente el
costo consolidado.

## Relación con las tablas existentes

Las entidades actuales deben ser fuentes, no el Kardex mismo:

| Fuente | Evento económico esperado |
|---|---|
| `pas_purchase_order_reception*` | recepción de proveedor y reversa |
| `pas_transfer_order*` | salida, tránsito y recepción interna |
| `pas_stock_adjustment*` | ajuste valorizado |
| ventas/movimientos externos | salida y costo de mercadería vendida |
| `inventory.inv_stock_movement*` | movimiento físico objetivo durante la migración |
| `commercial_agreements.*` | devengamiento, liquidación y true-up |
| `stk_stock` | reconciliación de cantidad actual |

`pas_stock_movement_replicator` podría ser parte del transporte de eventos, pero
no puede tomarse como ledger: no guarda valor ni costo promedio, sus filas están
`PENDING` y no se reflejan en `stk_stock_movement` en el ambiente relevado.

## Posición derivada

El Kardex es la fuente histórica. La tabla
`cst_site_cost_position` es una proyección rápida del último resultado:

```text
artículo + sucursal + UOM + moneda
cantidad actual
valor actual
costo promedio actual
último movimiento de stock
último ajuste de costo
versión
```

Si la proyección se pierde o queda inconsistente, debe poder reconstruirse
reproduciendo el ledger. Esa capacidad es la diferencia fundamental respecto de
agregar columnas de costo directamente a `stk_stock`.

## Cierre diario valorizado por sucursal

Se incorpora `cst_site_daily_balance` como la foto valorizada de cierre por
artículo. Su cabecera `cst_site_daily_close` demuestra que la sucursal y fecha se
procesaron de manera completa.

La cabecera conserva:

- compañía, sucursal, fecha de negocio y zona horaria;
- instante de corte y watermark del último evento incluido;
- versión del cierre y cierre anterior reemplazado;
- estado, cantidad esperada/procesada de posiciones;
- cantidad y valor totales de control;
- hash del resultado, inicio, cierre y reapertura.

Cada línea conserva:

```text
artículo + UOM + moneda
cantidad de cierre
valor de inventario de cierre
costo promedio local de cierre
último movimiento de stock
último ajuste de costo
versión de la posición del ledger
estado provisional
hash de cálculo
```

El cierre se calcula desde el ledger hasta el instante de corte. No se alimenta
copiando silenciosamente `stk_stock`, `fnd_stock_snapshot` ni
`pdd_branch_stock_position`; esas fuentes sólo participan en reconciliación o
apertura certificada.

Una reapertura ejecuta replay desde el punto necesario, genera una nueva cabecera
y nuevas líneas, y marca la versión previa como `SUPERSEDED`. De este modo pueden
reproducirse libros, márgenes y valuaciones tal como se conocían en cada cierre.

## Lo que falta además de las tablas

El Kardex requiere algo más que estructura física:

1. contrato normalizado para todos los productores de movimientos;
2. política versionada que determine qué afecta cantidad, inventario, costo
   comercial o resultados;
3. ordenamiento e idempotencia de eventos;
4. manejo de movimientos tardíos y períodos cerrados;
5. política de stock negativo;
6. conversión de UOM y moneda;
7. reversas en lugar de actualizaciones destructivas;
8. reconciliación continua con el stock operativo;
9. apertura certificada de cantidad, valor y costo;
10. monitoreo de eventos pendientes o rechazados.

Sin esas reglas, una tabla llamada `kardex` sería solamente otro historial
incompleto.

## Reglas aprobadas que condicionan el ledger

- La recepción cerrada registra síncronamente cantidad, costo provisional,
  posición y outbox.
- El costo se expresa funcionalmente en ARS, conservando moneda y cambio original.
- Pesables se valúan en kilogramos y los bultos por el factor del proveedor
  congelado en el evento.
- Ajustes positivos y sobrantes ingresan al costo promedio local.
- Stock negativo usa costo provisional y se regulariza mediante replay.
- Transferencias preservan costo por línea y una posición `IN_TRANSIT`.
- Bonificaciones aumentan cantidad y reducen costo unitario sin netear la merma.
- Impuestos recuperables no capitalizan; los no recuperables atribuibles sí.
- Períodos reabiertos generan nuevas versiones y deltas, nunca actualizaciones
  destructivas.

## Evidencia y auditoría

Cada asiento debe poder reconstruir su cálculo y demostrar documento/hash,
servicio y evento origen, actor, regla y versión, aprobaciones, valores
antes/después, correlación fiscal/contable y eventual reversa. La retención se
define por compañía y clase documental; la evidencia no puede depender de que SGM
continúe disponible.
