---
id: CNX-COST-FS-001
titulo: Especificación funcional del cierre diario valorizado por sucursal
estado: propuesto-para-revision
version: 1.0
fecha: 2026-09-01
propietario_funcional: por-definir
propietario_tecnico: por-definir
documentos_relacionados:
  - CNX-COST-ARC-001
  - CNX-COST-KDX-001
  - CNX-COST-PLAN-001
  - CNX-COST-DB-GOV-001
---

# Especificación funcional del cierre diario valorizado

## Objetivo

Conservar una posición oficial, versionada y reproducible de cantidad, valor y
costo promedio ponderado de cada artículo al cierre de cada sucursal y fecha de
negocio.

El cierre es una proyección del Kardex valorizado. No reemplaza el ledger ni el
stock operativo y no se alimenta mediante una copia sin control de snapshots
legacy o de planificación.

## Alcance del primer corte

Incluye:

- cabecera de cierre por compañía, sucursal y fecha de negocio;
- detalle por artículo, UOM canónica y moneda funcional;
- cantidad, valor y CPP al instante de corte;
- watermark y últimos eventos incluidos;
- control de completitud, reconciliación, hash y auditoría;
- reapertura mediante una versión nueva;
- consultas históricas y selección del cierre vigente.

No incluye en este primer script:

- motor que calcula o publica el cierre;
- carga de saldos o backfill histórico;
- creación del ledger completo `cst_cost_event*`;
- integración automática con SGM, BRIDGE o PDD;
- construcción de interfaces SAP contables/fiscales o interfaces de Pricing;
- permisos y roles definitivos, que debe definir CORE con Seguridad.

## Definiciones

- **Fecha de negocio:** día operativo al que pertenece el cierre, independiente de
  la fecha técnica en que se calcula.
- **Instante de corte:** timestamp con zona horaria hasta el cual se consideran los
  eventos efectivos.
- **Watermark:** instante hasta el cual se confirmó la recepción técnica de eventos,
  usado para detectar eventos tardíos.
- **Versión de cierre:** número creciente dentro de compañía, sucursal y fecha.
- **Cierre vigente:** única versión en estado `CLOSED` para esa clave.
- **Replay:** reconstrucción del ledger desde un punto anterior para incorporar una
  corrección o evento tardío.

## Actores

| Actor | Responsabilidad |
|---|---|
| Stock/Inventory | Proveer posición operativa y movimientos físicos certificados |
| Cost Management | Reproducir ledger, calcular valores, CPP y cierre |
| Operaciones | Resolver movimientos pendientes y validar diferencias físicas |
| Contabilidad | Validar valor, períodos y reaperturas materiales |
| Auditoría | Consultar versiones, evidencia y trazabilidad |
| CORE | Implementar cambios físicos y operar Flyway |

## Modelo funcional

### Cabecera `cst_site_daily_close`

Representa la ejecución completa del cierre. Conserva:

- compañía, sucursal y fecha de negocio;
- zona horaria e instante de corte;
- versión y estado;
- último movimiento y último ajuste de costo incluidos;
- watermark de eventos recibidos;
- cantidad de posiciones esperadas y generadas;
- totales de cantidad separados por UOM;
- valor total de inventario en moneda funcional;
- hash del cálculo;
- versión anterior reemplazada;
- fechas de inicio, cierre y reapertura;
- error estructurado cuando falla.

### Detalle `cst_site_daily_balance`

Conserva para cada artículo:

- UOM canónica y moneda funcional;
- cantidad de cierre;
- valor de inventario;
- CPP local;
- último movimiento y ajuste de costo;
- versión de la posición del ledger;
- indicador provisional y hash de línea.

## Estados

```text
CALCULATING → PROVISIONAL → CLOSED
      │             │
      └─────────────┴────→ FAILED

CLOSED anterior → SUPERSEDED
                         ▲
nueva versión: CALCULATING → PROVISIONAL → CLOSED
```

- `CALCULATING`: cálculo en curso; no puede consumirse como cierre.
- `PROVISIONAL`: resultado completo pendiente de controles o aprobación.
- `CLOSED`: cierre oficial y vigente.
- `SUPERSEDED`: versión histórica reemplazada por replay.
- `FAILED`: ejecución fallida con evidencia del error.

## Reglas funcionales

### RF-01 — Unicidad vigente

Sólo puede existir una versión `CLOSED` por compañía, sucursal y fecha de negocio.
Puede coexistir con una versión nueva en cálculo durante una reapertura.

### RF-02 — Completitud

No se publica `CLOSED` si:

- existen eventos anteriores al watermark pendientes o rechazados;
- faltan artículos esperados;
- la cantidad generada de posiciones no coincide con la esperada;
- falta hash o instante de cierre;
- la reconciliación de cantidad no supera la tolerancia aprobada.

### RF-03 — Fuente

Cantidad, valor y CPP se reconstruyen desde el ledger hasta `cutoff_at`.
`stk_stock`, `fnd_stock_snapshot`, `stk_stock_snapshot` y PDD sirven para
reconciliación o apertura certificada, no como reemplazo silencioso del ledger.

### RF-04 — Granularidad

La clave de detalle es cierre, artículo, UOM canónica y moneda. Los pesables se
expresan en kilogramos; los restantes artículos usan su unidad canónica.

### RF-05 — Moneda

El primer alcance publica ARS. La columna de moneda se conserva para que la clave y
el contrato no deban cambiar si aparecen otras monedas funcionales.

### RF-06 — Stock cero y negativo

Las posiciones en cero se conservan cuando formen parte del universo certificado.
El stock negativo se permite con costo provisional y debe quedar identificado en
el ledger; el cierre refleja exactamente ese estado.

### RF-07 — Inmutabilidad

Un cierre `CLOSED` no se edita. Una corrección genera una versión posterior y la
anterior queda `SUPERSEDED` al publicar la nueva.

### RF-08 — Reapertura

La reapertura requiere motivo, actor y autorización según materialidad. El replay
recalcula desde el punto afectado y permite explicar las diferencias entre ambas
versiones.

### RF-09 — Idempotencia

Repetir el mismo cálculo con iguales entradas produce el mismo hash y no publica
una segunda versión equivalente.

### RF-10 — Cierre sincronizado

El cierre diario sólo avanza cuando los movimientos de recepción ya confirmaron
cantidad, costo provisional, posición y outbox. El cierre no reemplaza esa
sincronización transaccional.

## Flujo normal

1. Determinar compañía, sucursal, fecha, zona horaria y corte.
2. Crear cabecera `CALCULATING` con versión siguiente.
3. Confirmar watermark y ausencia de eventos bloqueantes.
4. Reproducir el ledger hasta el corte.
5. Generar una línea por artículo/UOM/moneda.
6. Calcular controles por UOM, valor total y hashes.
7. Reconciliar contra la posición operativa certificada.
8. Pasar a `PROVISIONAL` y ejecutar controles/aprobaciones.
9. En una publicación atómica, marcar cierre anterior `SUPERSEDED` y nueva versión
   `CLOSED`.
10. Publicar evento de cierre mediante outbox en una etapa posterior del proyecto.

## Consultas funcionales requeridas

- cierre vigente de una sucursal y fecha;
- cierre de un artículo en todas las sucursales;
- evolución diaria de cantidad, valor y CPP;
- comparación entre dos versiones de una fecha reabierta;
- cierres provisionales, fallidos o faltantes;
- trazabilidad desde una línea hasta los últimos eventos del Kardex;
- reconciliación de totales con compañía y contabilidad.

## Controles y auditoría

- actor y motivo de reapertura se conservarán en el módulo de auditoría;
- hashes usan entradas ordenadas de manera determinística;
- los detalles fallidos no se publican como oficiales;
- las referencias a eventos son lógicas en el primer script y se convertirán en FK
  cuando el ledger físico sea aprobado;
- ninguna interfaz SAP contable/fiscal utiliza `PROVISIONAL` por defecto;
- retención y acceso siguen la política aprobada para el ledger.

## Criterios de aceptación

1. Crear cierres independientes para dos sucursales en la misma fecha.
2. Impedir dos versiones simultáneas en estado `CLOSED` para la misma clave.
3. Impedir dos líneas del mismo artículo/UOM/moneda dentro de un cierre.
4. Impedir cerrar sin `closed_at`, hash o igualdad entre posiciones esperadas y
   generadas.
5. Permitir cantidades negativas y cero con precisión de seis decimales.
6. Preservar importes y CPP sin `double precision`.
7. Crear una nueva versión que referencia a la anterior.
8. Mantener consultable la versión `SUPERSEDED`.
9. Resolver eficientemente artículo/sucursal/fecha mediante los índices definidos.
10. Aplicar la migración sobre una base vacía de estos objetos y verificar que una
    segunda aplicación sea rechazada/controlada por Flyway.

## Parámetros pendientes antes de construir el proceso

- hora de corte y zona horaria por sucursal;
- tolerancia de reconciliación de cantidad y valor;
- universo esperado de artículos, incluyendo posiciones cero;
- tiempo de espera por eventos tardíos;
- aprobadores y materialidad para reapertura;
- SLA de cierre y publicación;
- período histórico inicial a cargar;
- política de retención física y particionamiento.
