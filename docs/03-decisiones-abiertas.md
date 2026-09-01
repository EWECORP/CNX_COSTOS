---
id: CNX-COST-DEC-001
titulo: Decisiones abiertas para el modelo de costos
estado: borrador
version: 0.1
fecha: 2026-08-31
propietario: por-definir
documento_relacionado: CNX-COST-ARC-001
---

# Decisiones abiertas para el modelo de costos

Estas decisiones requieren validación de Comercial, Finanzas/Contabilidad,
Compras, Operaciones y Producto antes de implementar.

## Bloqueantes

1. **Definición de costo neto comercial.** Confirmar componentes incluidos:
   descuentos de factura, bonificaciones, impuestos internos, flete, rappel
   estimado/real, notas de crédito, servicios y acuerdos financieros.
2. **Uso de las tres métricas.** Aprobar que valuación local, valuación consolidada
   y costo comercial para pricing sean métricas separadas.
3. **Momento de reconocimiento.** Definir si el costo nace al cierre físico de
   recepción, con factura, con triple control o mediante una estimación y ajuste
   posterior.
4. **Rappel y acuerdos retroactivos.** Definir devengamiento, tasa esperada, true-up
   y distribución entre inventario remanente y resultados.
5. **Stock negativo.** Aprobar costo provisional y tratamiento de diferencias al
   regularizar.
6. **Transferencias.** Confirmar costo transportado, inclusión de fletes y uso de
   una posición en tránsito.
7. **UOM canónica.** Definir unidad de valuación por artículo y reglas para bulto,
   unidad, peso y productos fraccionables.
8. **Moneda.** Definir moneda funcional por compañía, tipo de cambio, fuente y fecha
   aplicable.

## Importantes para el diseño detallado

9. Alcance de compañía y tratamiento intercompany, e Interdepartamental, Ejemplo RECETAS quue usa rotiseria para producir comida en el local.
10. Política para devoluciones sin documento original.
11. Política de valorización de ajustes positivos y sobrantes.
12. Períodos cerrados: reapertura, replay o ajuste en período corriente.
13. Horizonte del costo comercial: última compra, promedio de recepciones, lista
    vigente o combinación parametrizable.
14. Proveedor elegido cuando hay múltiples fuentes de abastecimiento.
15. Distribución de acuerdos sin alcance a SKU: venta, compra, stock, categoría u
    otra base.
16. Tratamiento de mercadería bonificada y cantidad gratis.
17. Recuperabilidad de IVA e impuestos por compañía/artículo.
18. Flujo de aprobación y publicación de nuevas versiones hacia Pricing.
19. Retención del ledger y requerimientos de auditoría.
20. SLA de actualización y consistencia: síncrono al cierre o consistencia eventual.

## Datos y contratos a corregir o certificar

- Agregar `product_id` y `purchase_order_line_id` a la recepción o al evento que
  publica.
- Congelar precio, moneda, UOM/factor y componentes en el evento de recepción.
- Transportar costo por línea en transferencias.
- Documentar o reemplazar `custom1..4` en movimientos.
- Resolver las 13.132 filas `PENDING` del replicador y certificar su semántica.
- Reconciliar productos no coincidentes entre réplicas.
- Certificar la frescura de `stk_stock` y poblar fecha efectiva.
- Depurar catálogo de tipos de movimiento y códigos duplicados.
- Definir si las 1.012 posiciones negativas son válidas o errores de integración.

## Próximo taller recomendado

Realizar un taller de 90 minutos con un caso completo y documentos reales
anonimizados:

1. OC con precio, descuento y bonificación;
2. recepción parcial en una sucursal;
3. transferencia de parte de la mercadería a otra sucursal;
4. venta parcial;
5. nota de crédito mensual y rappel;
6. cálculo esperado de las tres métricas antes y después de cada paso.

El resultado del taller debe ser una matriz de reglas aprobada, no solamente una
fórmula general.
