# Entrega incremental y criterios de aceptación

## Cortes de entrega

| Corte | Backoffice | Frontend | Salida verificable |
|---|---|---|---|
| 1. Base | eventos, ledger y posiciones | consulta de costos y Kardex | recepción/salida idempotente y explicable |
| 2. Cierre | motor y versiones de cierre | tablero y cierre diario | cierre reconstruible por sucursal |
| 3. Documentos | documento, OCR y storage | bandeja y visor | original y extracción trazables |
| 4. Match/AP | conciliación y excepciones | triple match | ajuste aprobado sin duplicar cantidad |
| 5. Solicitud NC | workflow y adaptador | bandeja y timeline NC | reclamo trazable hasta respuesta externa |
| 6. Comercial | cálculo/aprobación/publicación | comparación y publicación | Pricing consume versión publicada |
| 7. Operación | replay, reconciliación y monitoreo | integraciones, auditoría y reportes | modo sombra estable y observable |

## Definition of Done por historia

- Regla funcional y permisos identificados.
- API documentada en OpenAPI con ejemplos y errores.
- Migración Flyway revisada y aplicada sólo por CORE.
- Pruebas unitarias, integración, contrato y autorización.
- Idempotencia, concurrencia y reversa cubiertas cuando correspondan.
- Logs, métricas y auditoría disponibles.
- Estados vacío/carga/error implementados en Frontend.
- Criterios funcionales demostrados con datos sintéticos fuera de Flyway.
- Evidencia de QA y aprobación del responsable funcional.

## Escenarios de aceptación transversales

1. Repetir un comando con la misma clave y contenido no duplica efectos.
2. Repetir la clave con contenido diferente produce conflicto auditable.
3. Una recepción cerrada actualiza ledger, posición y outbox atómicamente.
4. Una venta conserva el costo local aplicado aunque el CPP cambie después.
5. Una transferencia conserva costo y valor consolidado entre origen y destino.
6. Una factura aprobada ajusta valor sin duplicar cantidades.
7. Una diferencia reclamable crea una única solicitud NC trazable.
8. La NC real queda relacionada pero diferenciada de la solicitud.
9. Sólo una versión comercial publicada está vigente por clave y momento.
10. Pricing obtiene el Costo Neto Comercial Unificado publicado.
11. La rentabilidad de sucursal usa el costo histórico de sus salidas.
12. Reabrir un cierre conserva y permite comparar ambas versiones.
13. Un usuario no puede aprobar su propia operación cuando aplica cuatro ojos.
14. Una falla externa se reintenta sin duplicar el mensaje funcional.
15. Todo error mostrado permite copiar el `correlationId`.

## Dependencias para comenzar

- Repositorio y módulo Java asignados por el equipo Backoffice.
- Convenciones concretas del framework CONNEXA y plantilla de servicio.
- OpenAPI y mecanismo de generación de clientes acordados.
- Identidad de tenant, compañía, sucursal, producto, proveedor y UOM confirmada.
- Contratos de recepción, movimientos, ventas y documentos versionados.
- Matriz inicial de políticas, tolerancias, roles y casos dorados.
- Ambientes, mensajería, storage documental y observabilidad disponibles.

## Pendientes que no bloquean el esqueleto

- SLA, RPO/RTO y retención definitivos.
- Adaptadores contables adicionales; SAP es el primero para DIARCO.
- Parámetros finales de impuestos, acuerdos, recetas y materialidad.
- Diseño visual definitivo, siempre que respete navegación, acciones y permisos.

