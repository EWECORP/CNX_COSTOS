# Frontend: pantallas y navegación

## Navegación propuesta

```text
Costos
├── Resumen operativo
├── Consulta de costos
├── Kardex valorizado
├── Cierres diarios
├── Documentos y conciliación
├── Solicitudes de nota de crédito
├── Publicación de costo comercial
├── Integraciones
├── Políticas y parámetros
└── Auditoría
```

El frontend debe utilizar shell, sesión, compañía/sucursal activa, componentes,
permisos, accesibilidad y manejo de errores del framework CONNEXA.

## F01 — Resumen operativo

- Tarjetas: eventos pendientes/rechazados, sucursales sin cerrar, posiciones
  provisionales, matches con excepción, solicitudes NC pendientes e interfaces fallidas.
- Tendencias de volumen y errores; alertas priorizadas.
- Todos los indicadores navegan a una bandeja filtrada.
- Refresco visible y fecha/hora de última actualización.

## F02 — Consulta de costos

- Búsqueda por SKU, EAN, descripción o ID.
- Muestra Costo Neto Comercial Unificado, CPP compañía y CPP por sucursal.
- Indica vigencia, moneda, UOM, estado provisional, versión y última actualización.
- Comparación de sucursales y explicación de componentes.
- Historial de versiones y enlace al Kardex.

## F03 — Kardex valorizado

- Filtros: período, compañía, sucursal, artículo, evento, estado y documento.
- Columnas: fecha efectiva, cantidad/valor anterior, variación, posterior, costo
  aplicado, provisional, origen y correlación.
- Detalle lateral: componentes, política, documento, reversa/replay y auditoría.
- Sólo lectura; exportación respeta filtros y permisos.

## F04 — Cierres diarios

- Matriz fecha–sucursal con estado y alertas.
- Detalle con watermark, controles, totales, hash y balances.
- Acciones: iniciar, reintentar, descargar y solicitar reapertura.
- Reapertura exige motivo, confirmación y permiso especial.
- Comparador entre versiones del mismo cierre.

## F05 — Documentos y conciliación

- Bandeja con estado documental, OCR, proveedor, importe y match.
- Visor de original junto a campos extraídos y confianza.
- Comparación línea a línea factura–OC–recepción.
- Resolución de asignaciones y excepciones, sin editar OC ni recepción.
- Acciones de aprobar/rechazar sujetas a cuatro ojos.
- Vista previa del ajuste de costo antes de aprobar.

## F06 — Solicitudes de nota de crédito

- Bandeja por proveedor, factura, motivo, importe, antigüedad y estado.
- Detalle de diferencias y evidencia de origen.
- Acciones: crear borrador, enviar a aprobación, aprobar, rechazar, cancelar,
  reintentar envío y relacionar la NC recibida.
- Timeline con usuario, fecha, acuse y referencia externa.
- No mostrar una solicitud como descuento confirmado hasta la respuesta externa.

## F07 — Costo comercial unificado

- Versiones por artículo y vigencia.
- Comparación propuesta versus publicada y variación absoluta/porcentual.
- Desglose de precio, descuentos, impuestos, flete, rappel y acuerdos.
- Acciones: calcular, revisar, aprobar, publicar y sustituir.
- Publicación exige segundo usuario y advertencia de consumidores afectados.

## F08 — Integraciones

- Bandeja inbox/outbox/external exchange.
- Estado técnico separado del resultado funcional.
- Payload visible sólo con permiso y datos sensibles enmascarados.
- Intentos, próxima ejecución, error, acuse y correlación.
- Reintento individual o por lote con confirmación.

## F09 — Políticas y parámetros

- Versionado de políticas, componentes, tolerancias, impuestos, UOM y redondeos.
- Simulación previa y vigencia futura.
- Nunca editar una versión ya utilizada; crear sucesora.
- Auditoría y cuatro ojos para cambios materiales.

## Estados UX comunes

- Carga con skeleton; vacío con explicación y acción posible.
- Error con `correlationId` copiable.
- Procesos largos con estado consultable; no bloquear la pantalla.
- Fechas en zona del usuario, conservando acceso al instante UTC.
- Importes con moneda y UOM siempre visibles.
- Badges coherentes para provisional, aprobado, publicado, rechazado y fallido.

