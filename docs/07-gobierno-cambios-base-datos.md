---
id: CNX-COST-DB-GOV-001
titulo: Gobierno de cambios de base de datos
estado: aprobado
version: 1.0
fecha: 2026-09-01
propietario: CORE
documentos_relacionados:
  - CNX-COST-ARC-001
  - CNX-COST-PLAN-001
---

# Gobierno de cambios de base de datos

## Regla principal

Los cambios físicos en las bases de CONNEXA son responsabilidad exclusiva del
grupo CORE. El equipo de Costos puede analizar, documentar y preparar artefactos,
pero no ejecutar DDL, migraciones, cargas, correcciones ni pruebas destructivas en
ambientes compartidos.

## Flujo obligatorio

```text
Necesidad funcional
  → solicitud documentada
  → diseño y análisis de impacto
  → script Flyway propuesto
  → revisión de Arquitectura
  → aprobación de CORE
  → implementación escalonada por CORE
  → verificación y evidencia por ambiente
  → autorización para promover
```

## Contenido mínimo de la solicitud

1. Identificador, título, solicitante y responsables funcional/técnico.
2. Problema, objetivo y decisión funcional relacionada.
3. Ambiente, servicio, esquema y objetos alcanzados.
4. Modelo actual y modelo propuesto.
5. Compatibilidad con aplicaciones y consumidores existentes.
6. Volumen estimado, bloqueos esperados y duración.
7. Impacto sobre datos históricos, auditoría y períodos cerrados.
8. Estrategia de backfill o apertura, si corresponde.
9. Validaciones previas y posteriores.
10. Observabilidad, reconciliación y criterios de éxito.
11. Estrategia de contingencia y recuperación.
12. Riesgos, dependencias y ventana requerida.
13. Aprobaciones de Producto, Contabilidad, Impuestos, Seguridad y Arquitectura
    cuando correspondan.

## Paquete técnico a entregar

- migración Flyway con nombre y versión acordados con CORE;
- consultas de precondición exclusivamente de lectura;
- DDL compatible hacia adelante;
- índices y constraints con análisis de bloqueo;
- backfill separado y reanudable cuando exista volumen significativo;
- consultas de validación posterior;
- plan de monitoreo y reconciliación;
- evidencia de pruebas en un entorno autorizado;
- instrucciones de contingencia.

El archivo `sql/001_cost_management_draft.sql` es sólo un modelo conceptual. No
debe renombrarse ni ejecutarse como migración sin completar este proceso.

La especificación particular del cierre se encuentra en
`08-especificacion-funcional-cierre-diario.md`; el inventario integral, en
`10-especificacion-funcional-modelo-integral.md`; y la solicitud completa, en
`09-solicitud-core-cierre-diario.md`. La solicitud entrega cuatro scripts
candidatos ordenados para costos, cierre, documentos y conciliación.

## Reglas para scripts Flyway

- Una migración aplicada es inmutable. Toda corrección usa una versión nueva.
- No depender de datos o estados no verificados: declarar precondiciones.
- Evitar DDL y backfill masivo en la misma migración cuando aumente el riesgo.
- Usar `numeric` para importes y costos y `timestamptz` para instantes efectivos.
- Crear primero estructuras compatibles; activar productores y consumidores en
  pasos posteriores.
- Diseñar expansión y contracción: agregar, poblar, validar, activar y recién luego
  retirar estructuras antiguas.
- No eliminar ni renombrar objetos usados hasta certificar todos los consumidores.
- Definir idempotencia de cargas aunque la versión Flyway se ejecute una sola vez.
- Medir locks, espacio, tiempo y efecto sobre réplicas antes de producción.

## Promoción escalonada

El orden concreto de ambientes lo determina CORE. Como regla de control, cada
etapa debe completar:

1. aplicación por CORE;
2. verificación de versión Flyway y objetos;
3. pruebas funcionales y técnicas;
4. reconciliación de datos;
5. observación durante la ventana acordada;
6. registro de evidencia e incidentes;
7. autorización explícita antes de promover.

No se presume que una aplicación correcta en TEST autorice automáticamente el
siguiente ambiente.

## Contingencia

Las migraciones se diseñan preferentemente hacia adelante. Cuando no sea seguro
revertir DDL o datos, la contingencia consiste en desactivar productores o
consumidores mediante configuración, preservar la estructura y aplicar una nueva
migración correctiva.

Nunca se debe usar rollback destructivo sobre el ledger valorizado. Los eventos
económicos se corrigen mediante reversas y nuevos eventos; la estructura física se
corrige mediante nuevas migraciones aprobadas.

## Evidencia de cierre

CORE registra por ambiente la versión aplicada, fecha, responsable, resultado,
duración, validaciones y observaciones. El solicitante adjunta la conformidad
funcional y las reconciliaciones. La solicitud sólo se cierra cuando la evidencia
queda accesible para Arquitectura y Auditoría.
