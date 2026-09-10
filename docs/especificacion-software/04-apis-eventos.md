# APIs y eventos

## Reglas generales HTTP

- Base sugerida: `/api/v1/cost-management`.
- JSON UTF-8; nombres `camelCase`; importes como número decimal, nunca binario.
- `Authorization`, `X-Tenant-Id`, `X-Company-Id` y `X-Correlation-Id` obligatorios.
- `Idempotency-Key` obligatorio en POST de comandos.
- Respuestas paginadas por `cursor` y `limit`.
- Fechas de negocio `YYYY-MM-DD`; instantes UTC ISO-8601.
- Escritura aceptada para proceso asincrónico: `202 Accepted` con `operationId`.

## Comandos

| Método y ruta | Acción | Resultado |
|---|---|---|
| `POST /cost-events` | registrar hecho económico | evento aceptado o duplicado idempotente |
| `POST /cost-events/{id}/reverse` | generar reversa | nuevo evento correlacionado |
| `POST /replays` | solicitar reconstrucción | operación asincrónica |
| `POST /daily-closes` | iniciar cierre | operación y cierre en cálculo |
| `POST /daily-closes/{id}/reopen` | crear nueva versión | cierre sucesor |
| `POST /matches` | iniciar match | resultado o proceso asincrónico |
| `POST /matches/{id}/decisions` | aprobar/rechazar | nueva decisión auditada |
| `POST /credit-note-requests` | emitir solicitud NC | solicitud idempotente |
| `POST /credit-note-requests/{id}/decisions` | aprobar/rechazar | transición válida |
| `POST /commercial-costs/calculations` | calcular versión | versión `CALCULATED` |
| `POST /commercial-costs/{id}/decisions` | aprobar/rechazar | decisión cuatro ojos |
| `POST /commercial-costs/{id}/publish` | publicar | versión vigente y evento |
| `POST /integrations/{id}/retry` | reintentar entrega | intento auditado |

## Consultas

| Método y ruta | Uso |
|---|---|
| `GET /costs/products/{productId}` | tres métricas y vigencias del artículo |
| `GET /costs/products/{productId}/sites/{siteId}` | costo y posición local |
| `GET /commercial-costs/{productId}/history` | versiones comerciales |
| `GET /kardex` | movimientos valorizados con filtros |
| `GET /kardex/{eventId}` | detalle, componentes y trazabilidad |
| `GET /daily-closes` | estado por sucursal/fecha |
| `GET /daily-closes/{id}/balances` | artículos del cierre |
| `GET /documents` | bandeja documental |
| `GET /documents/{id}` | metadatos, OCR y relaciones |
| `GET /matches` | bandeja de conciliación |
| `GET /matches/{id}` | comparación por línea y excepciones |
| `GET /credit-note-requests` | bandeja de solicitudes NC |
| `GET /integrations` | mensajes, intentos y estados |
| `GET /operations/{id}` | progreso de procesos asincrónicos |

## Ejemplo mínimo de evento

```json
{
  "sourceService": "procurement",
  "sourceEventId": "reception-123-closed-v1",
  "eventType": "RECEIPT_PROVISIONAL",
  "effectiveAt": "2026-09-09T18:30:00Z",
  "currencyCode": "ARS",
  "lines": [{
    "sourceLineId": "reception-line-10",
    "productId": "uuid",
    "siteId": "uuid",
    "baseUomId": "UN",
    "quantityDelta": 10,
    "unitCost": 125.40,
    "components": []
  }]
}
```

## Respuesta de error

```json
{
  "code": "COST_IDEMPOTENCY_CONFLICT",
  "message": "La clave ya fue utilizada con otro contenido",
  "correlationId": "uuid",
  "details": [{"field": "sourceEventId", "reason": "payloadMismatch"}]
}
```

Códigos mínimos: validación `400`, autenticación `401`, autorización `403`, no
encontrado `404`, conflicto/idempotencia `409`, regla funcional `422`, concurrencia
`423/409`, límite `429` y error interno `500`.

## Eventos publicados

| Evento | Consumidores típicos |
|---|---|
| `CostEventPosted` | Stock, Analytics |
| `SiteCostPositionChanged` | Analytics, rentabilidad |
| `CommercialCostPublished` | Pricing, promociones |
| `DailyCloseCompleted` | Operaciones, Analytics |
| `MatchApproved` | Costos, integración contable |
| `CreditNoteRequested` | workflow, adaptador contable |
| `CreditNoteAcknowledged` | Compras, AP operativo |
| `IntegrationFailed` | monitoreo y soporte |

Envelope obligatorio: `eventId`, `eventType`, `schemaVersion`, `occurredAt`,
`tenantId`, `companyId`, `source`, `correlationId`, `aggregateId`, `payload`.

