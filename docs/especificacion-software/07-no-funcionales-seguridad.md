# Requerimientos no funcionales, seguridad y operación

## Seguridad

- Autenticación y autorización provistas por el framework CONNEXA.
- Aislamiento obligatorio por tenant y compañía; alcance por sucursal cuando aplique.
- Principio de mínimo privilegio y permisos por acción, no sólo por pantalla.
- Cuatro ojos: quien calcula/resuelve no aprueba su propia operación material.
- Originales, OCR, payloads y datos fiscales protegidos y enmascarados.
- Descargas y visualización de documentos quedan auditadas.
- Secretos y endpoints sólo en configuración segura por ambiente.

## Roles iniciales

| Rol | Capacidades |
|---|---|
| `COST_VIEWER` | consultar costos, Kardex y cierres autorizados |
| `COST_OPERATOR` | operar eventos, cierres y reintentos no sensibles |
| `COST_ANALYST` | analizar costos y preparar versiones |
| `COST_APPROVER` | aprobar/publicar costos y reaperturas |
| `AP_MATCH_OPERATOR` | resolver documentos, asignaciones y excepciones |
| `CREDIT_NOTE_APPROVER` | aprobar/rechazar solicitudes NC |
| `COST_ADMIN` | administrar políticas y configuración |
| `COST_AUDITOR` | acceso de sólo lectura a evidencia y auditoría |

## Auditoría

Registrar actor, rol, tenant, compañía, acción, agregado, versión, estado anterior
y posterior, motivo, instante, IP/canal y `correlationId`. No almacenar secretos ni
documentos completos en logs.

Acciones especialmente auditadas: publicación, override, reapertura, replay,
reversa, aprobación, rechazo, solicitud NC, reintento externo y exportación.

## Observabilidad

- Logs estructurados con `traceId`, `correlationId`, `operationId` y agregado.
- Métricas RED para APIs y USE para workers/recursos.
- Métricas funcionales de pendientes, errores, antigüedad y reconciliación.
- Health checks separados para aplicación, base, mensajería, storage y adaptadores.
- Alertas sin incluir documentos, CUIT completos ni payload sensible.

## Rendimiento y resiliencia

- Consulta simple de costo: objetivo p95 menor a 500 ms en condiciones nominales.
- Comandos sincrónicos: objetivo p95 menor a 2 s; trabajo pesado responde `202`.
- APIs paginadas; sin consultas o exportaciones ilimitadas.
- Timeout, circuit breaker y backoff en integraciones externas.
- Inbox/outbox con entrega al menos una vez y consumidor idempotente.
- Recuperación de workers sin duplicar efectos económicos.
- Cierre, replay y exportación reanudables desde checkpoint seguro.

Los volúmenes, SLA definitivos, retención, RPO y RTO son parámetros pendientes de
validación con Arquitectura y Operaciones.

## Compatibilidad

- Contratos versionados y cambios backward-compatible dentro de `v1`.
- Nuevos campos opcionales; no cambiar significado de campos publicados.
- OpenAPI como fuente del cliente Frontend y pruebas de contrato.
- Eventos con `schemaVersion` y compatibilidad validada por consumidor.

