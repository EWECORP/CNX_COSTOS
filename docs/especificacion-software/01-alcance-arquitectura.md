# Alcance y arquitectura lógica

## Resultado esperado

Cost Management recibe hechos operativos, los registra de forma idempotente,
calcula su efecto económico y publica proyecciones confiables para Stock, Pricing,
Compras, Analytics e integraciones contables.

```text
Stock / Compras / BRIDGE / Acuerdos / Documentos
                        |
                 APIs y eventos
                        v
   +------------------------------------------------+
   | Cost Management                                |
   | ledger -> valorización -> posiciones -> cierre |
   | documentos -> match -> ajuste / solicitud NC   |
   +------------------------------------------------+
          | consultas          | outbox
          v                    v
 Pricing / Backoffice / Analytics / ERP del cliente
```

## Capacidades incluidas

1. Ledger económico inmutable por artículo y sucursal.
2. CPP local, CPP consolidado y posiciones en tránsito.
3. Costo Neto Comercial Unificado por compañía/cadena.
4. Recepciones provisionales y ajustes a costo definitivo.
5. Ventas, transferencias, devoluciones, ajustes, transformaciones y replay.
6. Cierre diario valorizado, versionado y reconstruible.
7. Preservación documental, hash, OCR y corrección humana.
8. Conciliación OC–recepción–factura, tolerancias y aprobaciones.
9. Solicitudes de nota de crédito por diferencias reclamables.
10. Inbox, outbox, interfaces agnósticas y reconciliación externa.

## Autoridad por información

| Información | Autoridad |
|---|---|
| Cantidad operativa y recepción física | Stock/Procurement |
| Ledger valorizado y costo aplicado | Cost Management |
| CPP vigente por sucursal | Cost Management |
| Costo Neto Comercial Unificado | Cost Management |
| Documento original y OCR | Document Management |
| Match operativo y solicitud de NC | Accounts Payable operativo de CONNEXA |
| Contabilidad, impuestos oficiales, pagos y cuenta corriente | Sistema contable del cliente |
| Precio de venta | Pricing |

Para DIARCO, el sistema contable es SAP. El núcleo no debe contener lógica SAP;
esa lógica pertenece a un adaptador de integración.

## Principios de diseño

- Arquitectura modular dentro del framework CONNEXA, con límites explícitos entre
  costo, documentos, conciliación e integración.
- Escritura sólo mediante servicios de aplicación; sin acceso directo de otros
  módulos a las tablas.
- Consultas optimizadas mediante proyecciones; el ledger es la evidencia y fuente
  de reconstrucción.
- Comandos sincrónicos cortos; procesos pesados mediante worker/evento.
- Un mismo contrato canónico para todos los clientes; adaptadores externos por ERP.
- Autorización por tenant, compañía, sucursal, acción y rol.

## Fuera de alcance

- Operación física de stock, OC o recepción.
- Motor de precios, promociones o surtido.
- Contabilidad general y asientos oficiales.
- Subledger y cuenta corriente de proveedores.
- Liquidación fiscal, pagos y reportes regulatorios.
- Edición directa de eventos, cierres o documentos publicados.

