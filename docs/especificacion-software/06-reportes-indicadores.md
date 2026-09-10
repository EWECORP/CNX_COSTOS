# Reportes e indicadores

## Reportes operativos

| Reporte | Grano | Métricas principales |
|---|---|---|
| Posición valorizada | artículo–sucursal–fecha | cantidad, valor, CPP, provisional |
| Cierre diario | sucursal–fecha–versión | cantidad, valor, diferencias y estado |
| Movimientos sin valorizar | evento–línea | antigüedad, origen y causa |
| Reconciliación de stock | artículo–sucursal | cantidad operativa vs espejo |
| Conciliación documental | factura–línea | OC, recepción, diferencia y tolerancia |
| Solicitudes de NC | proveedor–solicitud | importe, antigüedad, estado y referencia |
| Integraciones | mensaje–intento | latencia, estado técnico/funcional y error |

## Reportes comerciales y analíticos

| Reporte | Regla |
|---|---|
| Costo Neto Comercial Unificado | sólo versión `PUBLISHED` vigente |
| Evolución del costo comercial | comparar versiones y componentes |
| Rentabilidad por sucursal | venta neta menos costo local congelado en la salida |
| Performance de tienda | margen real, costo de venta, ajustes y merma por período |
| Dispersión de CPP | variación del CPP local entre sucursales |
| Impacto de acuerdos | estimado, devengado, liquidado y `TRUE_UP` |

## Definiciones mínimas

```text
costo_venta_local = suma del valor de salida congelado en eventos de venta
margen_real       = venta_neta - costo_venta_local
margen_porcentaje = margen_real / venta_neta, cuando venta_neta != 0
diferencia_match  = importe_facturado - importe_aceptado_segun_OC_y_recepcion
antiguedad_NC     = fecha_actual - requested_at para solicitudes no cerradas
```

Los importes de venta provienen del contrato BRIDGE/Pricing; Cost Management no
se convierte en autoridad de ventas. Todo reporte debe declarar fecha de datos,
moneda, UOM, filtros, versión de costo y tratamiento de anulaciones.

## Exportaciones

- CSV/XLSX para grillas operativas; generación asincrónica para grandes volúmenes.
- PDF sólo para evidencia aprobada o cierre formal.
- Exportación registra usuario, filtros, instante y cantidad de filas.
- Enmascarar payloads, documentos y datos sensibles según rol.
- Límite sincrónico configurable; superar el límite crea una operación descargable.

## Indicadores del tablero

- Porcentaje de sucursales cerradas en término.
- Eventos pendientes/rechazados y máxima antigüedad.
- Artículos con costo provisional.
- Diferencia de valorización contra posición operativa.
- Matches automáticos, manuales y con excepción.
- Importe y antigüedad de solicitudes NC abiertas.
- Costo comercial pendiente de publicación.
- Tasa de error y latencia de interfaces.

