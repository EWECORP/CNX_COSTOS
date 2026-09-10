# Servicios de Backoffice Java

## Estructura lógica

El equipo debe implementar estos componentes usando las convenciones del framework
CONNEXA para configuración, seguridad, persistencia, errores y observabilidad.

| Componente | Responsabilidad |
|---|---|
| Cost Event Service | validar y registrar eventos idempotentes |
| Valuation Service | aplicar CPP, componentes y valor económico |
| Position Service | mantener posiciones local, compañía y tránsito |
| Commercial Cost Service | calcular, aprobar y publicar costo unificado |
| Daily Close Service | calcular, validar, cerrar y reabrir cierres |
| Document Service | preservar metadatos, binario, hash y versiones |
| Extraction Service | registrar OCR y correcciones humanas |
| Matching Service | ejecutar y resolver conciliación de tres vías |
| Credit Note Request Service | emitir, aprobar y seguir solicitudes de NC |
| Reconciliation Service | comparar cantidades, valores y sistemas externos |
| Integration Service | inbox, outbox, entrega, acuses y reintentos |
| Audit Service | registrar acciones, reglas, versiones y evidencia |

## Operaciones transaccionales críticas

1. **Cerrar recepción:** validar entrada, crear evento/líneas/componentes, actualizar
   posición local y compañía y grabar outbox en una transacción.
2. **Registrar salida:** congelar CPP local como `unitCost`, actualizar posición y
   publicar costo de venta para rentabilidad.
3. **Transferir:** salida origen, posición en tránsito y entrada destino mediante
   correlación común, sin perder el costo transportado.
4. **Aprobar match:** cerrar excepciones requeridas, crear ajuste de valor y outbox.
5. **Solicitar NC:** crear una sola solicitud por origen/motivo, aprobarla y generar
   mensaje canónico al adaptador contable.
6. **Publicar costo comercial:** validar cuatro ojos, cerrar vigencia anterior,
   publicar nueva versión y outbox atómicamente.
7. **Cerrar día:** fijar watermark, validar completitud, persistir balances y hash.

## Procesos asincrónicos

- Consumo de inbox y aplicación de eventos.
- Reintentos de outbox con backoff y dead-letter operativo.
- Cálculo masivo de costo comercial.
- Cierre diario y reconstrucción.
- Replay por período/artículo/sucursal.
- OCR y normalización documental.
- Auto-match y reconciliaciones periódicas.
- Envío/consulta de interfaces externas.

Cada job debe soportar reanudación, exclusión mutua, métricas, correlación y
cancelación segura. Prefect puede orquestar lotes, pero las reglas de negocio
permanecen en servicios Java reutilizables.

## Persistencia

- Repositorios separados por agregado; no exponer entidades ORM en la API.
- DTOs y contratos versionados independientes del esquema físico.
- Transacciones locales cortas y outbox transaccional.
- Paginación por cursor para Kardex, auditoría y bandejas voluminosas.
- Consultas de lectura específicas; evitar cargar grafos ORM completos.
- Sin `DELETE` funcional sobre ledger, documentos, aprobaciones o cierres.

## Adaptadores

Definir puertos para maestros, Stock, Procurement, BRIDGE, almacenamiento
documental, OCR, mensajería y sistema contable. La implementación SAP de DIARCO
debe ser un adaptador; ningún servicio de dominio debe importar tipos SAP.

