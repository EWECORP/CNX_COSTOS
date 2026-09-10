# Especificación de software — Cost Management

Estado: baseline funcional para diseño técnico  
Destino: Backoffice Java y Frontend CONNEXA  
Alcance: costos, Kardex valorizado, cierre diario, documentos, conciliación y solicitudes de NC

## Propósito

Este paquete traduce las decisiones funcionales de `CNX_COSTOS` a requerimientos
implementables. Es autocontenido para el desarrollo, pero no reemplaza las
decisiones y evidencias detalladas de `../`.

El módulo es la autoridad de valorización operativa de CONNEXA. Otros módulos
registran hechos mediante APIs o eventos y consumen costos publicados; no escriben
directamente en sus tablas ni recalculan costos.

## Lectura recomendada

| Documento | Audiencia | Contenido |
|---|---|---|
| `01-alcance-arquitectura.md` | Todos | alcance, fronteras y arquitectura lógica |
| `02-dominio-reglas.md` | Backoffice, QA, Producto | entidades, estados e invariantes |
| `03-servicios-backoffice-java.md` | Backoffice Java | componentes, transacciones y procesos |
| `04-apis-eventos.md` | Backoffice, integraciones, Frontend | contratos HTTP, eventos y errores |
| `05-frontend-pantallas.md` | Frontend, UX, QA | pantallas, acciones, filtros y permisos |
| `06-reportes-indicadores.md` | Frontend, Analytics, Producto | reportes, métricas y exportaciones |
| `07-no-funcionales-seguridad.md` | Arquitectura, Backoffice, DevOps | seguridad, auditoría y operación |
| `08-entrega-aceptacion.md` | Líderes y QA | alcance incremental y criterios de aceptación |
| `09-matriz-trazabilidad.md` | Todos | requerimiento, componente, interfaz y evidencia |
| `flyway-package/` | CORE y Backoffice | paquete físico con cuatro migraciones ordenadas y checksums |

## Convenciones obligatorias

- Fechas de negocio: `date`; instantes: UTC ISO-8601 y persistencia `timestamptz`.
- Importes y costos: decimal exacto; nunca `double`/`float`.
- IDs: UUID generados por la aplicación.
- Toda escritura lleva compañía/tenant, sistema origen, `correlationId` e
  `Idempotency-Key`.
- Eventos publicados, documentos y cierres confirmados son inmutables.
- Correcciones mediante reversa, nueva versión o replay; nunca edición destructiva.
- APIs y UI usan nombres funcionales; los nombres físicos de tablas no se exponen
  como contrato público.

## Fuentes de decisión

- `../02-propuesta-modelo-costos.md`
- `../03-decisiones-abiertas.md`
- `../04-kardex-valorizado.md`
- `../05-documentos-recepcion-y-conciliacion.md`
- `../08-especificacion-funcional-cierre-diario.md`
- `../10-especificacion-funcional-modelo-integral.md`
- `../11-frontera-integracion-sap.md`
