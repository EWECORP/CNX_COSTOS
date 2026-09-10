# Matriz de trazabilidad

Esta matriz es el índice verificable de la especificación. Cada historia técnica o
funcional debe referenciar al menos un ID y adjuntar su evidencia de aceptación.

| ID | Requerimiento | Backoffice/API | UI/Reporte | Evidencia mínima |
|---|---|---|---|---|
| RF-01 | Registrar eventos idempotentes | Cost Event Service / `POST /cost-events` | Kardex | prueba duplicado/conflicto |
| RF-02 | Calcular CPP local | Valuation y Position Services | Consulta de costos | caso dorado de recepción/salida |
| RF-03 | Consolidar costo compañía | Position Service | Consulta de costos | suma reconciliada de sucursales |
| RF-04 | Transportar costo | Valuation Service | Kardex | transferencia origen–tránsito–destino |
| RF-05 | Conservar costo histórico de venta | Cost Event Service | Rentabilidad por sucursal | CPP posterior no altera margen histórico |
| RF-06 | Cerrar día por sucursal | Daily Close Service | Cierres diarios | reconstrucción y hash coincidentes |
| RF-07 | Reabrir sin destruir historia | Daily Close Service | Comparador de cierres | dos versiones trazables |
| RF-08 | Preservar documento y OCR | Document/Extraction Services | Visor documental | hash, versión y corrección auditada |
| RF-09 | Conciliar OC–recepción–factura | Matching Service | Triple match | diferencias y tolerancia por línea |
| RF-10 | Aprobar con cuatro ojos | Approval rules | Match/costo/NC | segundo actor obligatorio |
| RF-11 | Ajustar costo definitivo | Valuation Service | Match y Kardex | valor cambia sin duplicar cantidad |
| RF-12 | Emitir solicitud de NC | Credit Note Request Service | Bandeja NC | solicitud única ligada a excepción |
| RF-13 | Relacionar NC recibida | Document/Matching Services | Detalle NC | documento distinto y relación completa |
| RF-14 | Calcular costo comercial | Commercial Cost Service | Costo comercial | componentes y hash reproducibles |
| RF-15 | Publicar costo unificado | Commercial Cost Service / evento | Publicación | una versión vigente consumible |
| RF-16 | Entregar mensajes confiables | Integration Service | Integraciones | reintento sin duplicación funcional |
| RF-17 | Reconciliar posiciones | Reconciliation Service | Tablero/reportes | diferencia explicada y estado |
| RF-18 | Revertir y reproducir | Event/Replay Services | Kardex/auditoría | reversa y replay equivalentes |
| RF-19 | Respetar aislamiento y permisos | Seguridad CONNEXA | Todas | pruebas tenant/compañía/rol |
| RF-20 | Observar extremo a extremo | Todos los servicios | Tablero/integraciones | correlación en API, evento y log |

## Regla de mantenimiento

- Un cambio funcional actualiza esta matriz, OpenAPI, eventos y aceptación.
- Un endpoint nuevo sin RF asociado no está listo para revisión.
- Una pantalla no puede asumir reglas no implementadas por el servicio.
- La evidencia se referencia desde la historia, pipeline o acta de aceptación; no
  se incrusta información sensible en este repositorio.

