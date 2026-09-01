---
id: CNX-COST-DOC-001
titulo: Documentos de recepción y conciliación de compras
estado: borrador
version: 0.1
fecha: 2026-08-31
propietario: por-definir
documentos_relacionados:
  - CNX-COST-ARC-001
  - CNX-COST-KDX-001
---

# Documentos de recepción y conciliación de compras

## Objetivo

Incorporar facturas, remitos, notas de crédito, notas de débito y otros documentos
asociados a la entrega, conciliarlos contra órdenes de compra y recepciones, y
producir una valorización aprobada y trazable para el Kardex, el subledger fiscal y
el subledger contable.

## Hallazgos en DESA

CONNEXA ya posee un circuito significativo de captura documental en
`mail_processor`:

| Entidad | Filas observadas |
|---|---:|
| Correos | 12.361 |
| Adjuntos | 12.144 |
| Documentos extraídos | 11.523 |
| Líneas de producto extraídas | 62.910 |
| Detalles de IIBB | 25.935 |
| Otros impuestos | 2.413 |

El OCR extrae CUIT, tipo y número de comprobante, punto de venta, fechas, CAE,
moneda, importes netos y totales, IVA, IIBB, descuentos, impuestos internos,
productos, cantidades, EAN y precios. También conserva archivos PDF/EDI y logs de
procesamiento.

Sin embargo, el circuito no está integrado relacionalmente con Procurement:

- `pas_purchase_order_reception_document` existe, pero tiene cero filas;
- solo contempla actualmente los tipos `Factura` y `Remito`;
- el OCR guarda referencias de compra y recepción como texto, no como IDs;
- no existe vínculo entre línea OCR, línea de OC y línea de recepción;
- no hay estado persistido de conciliación con SGM ni respuesta por línea;
- no existe una entidad canónica de factura/NC dentro de DESA; las entidades
  `acp_purchase_invoice*` visibles son enlaces a otro ambiente/esquema.

### Calidad observada de la extracción

Sobre 11.523 documentos:

- 11.218 tienen CUIT de proveedor;
- 11.060 tienen tipo de comprobante;
- 10.761 tienen punto de venta;
- 11.277 tienen número;
- 11.071 tienen fecha;
- 11.120 tienen CAE;
- 10.320 tienen referencia de compra;
- 11.286 tienen referencia de recepción;
- se detectaron 77 claves naturales duplicadas, con 94 documentos adicionales.

Sobre 62.910 líneas:

- 61.262 tienen código de artículo;
- 62.910 tienen EAN;
- 60.700 tienen cantidad;
- 57.213 tienen precio unitario;
- 58.168 tienen subtotal;
- ninguna tiene tasa de IVA extraída en el campo de línea;
- 19.445 tienen precio unitario neto de descuentos;
- solo una tiene precio neto con impuestos internos calculado.

La captura actual es una buena base, pero no alcanza por sí sola para contabilizar
o valorizar automáticamente todas las recepciones. Debe conservar confianza por
campo y pasar por validación/conciliación antes de publicar efectos económicos.

## Separación de responsabilidades

### Document Management / OCR

Responsable de recibir, preservar y extraer documentos. No determina por sí solo
el costo ni modifica recepciones.

### Accounts Payable / Invoice Matching

Responsable del documento canónico, validaciones, deduplicación, conciliación y
aprobación. Produce asignaciones explícitas contra OC y recepción.

### Procurement

Autoridad sobre OC, recepción física, cantidades aceptadas, rechazos, lotes y
fechas de recepción.

### Cost Management

Consume exclusivamente resultados de conciliación aprobados. Registra costo
provisional, ajustes a costo definitivo y NC/ND en el Kardex.

### Tax y Accounting

Reciben los componentes fiscales y contables aprobados. No deben reconstruirlos
consultando directamente el OCR.

## Modelo conceptual propuesto

### Documento y archivo

`doc_document`:

- tipo canónico: factura, remito, NC, ND u otro;
- compañía receptora y proveedor;
- CUIT, tipo, punto de venta y número;
- fechas de emisión, vencimiento, CAE y período de servicio;
- moneda y tipo de cambio;
- totales declarados;
- estado y versión;
- hash documental e identificador idempotente.

`doc_binary` conserva original, MIME, tamaño, hash, origen, fecha de recepción y
ubicación segura. El original es inmutable; una sustitución crea otra versión.

`doc_extraction_run` conserva motor/modelo OCR, versión, momento, resultado y
confianza. `doc_extracted_field` conserva valor original, valor normalizado,
coordenadas/página, confianza y eventual corrección humana.

### Documento comercial canónico

`ap_invoice` y `ap_invoice_line` representan factura, NC o ND después de validar la
extracción. Separar:

- importes netos;
- IVA por alícuota;
- impuestos internos;
- percepciones por impuesto, régimen y jurisdicción;
- descuentos y bonificaciones;
- fletes y otros cargos;
- importes no gravados/exentos;
- total del comprobante.

`ap_document_relation` vincula NC/ND con factura original, factura con remito y
documentos sustituidos o anulados.

### Conciliación

`ap_match` registra una ejecución de conciliación y su versión.

`ap_match_allocation` debe permitir relaciones muchos-a-muchos entre:

- línea de factura/NC;
- línea de OC;
- línea de recepción;
- artículo canónico;
- cantidad e importe asignados.

Esto es necesario porque una factura puede cubrir varias OC o recepciones, una
recepción puede ser facturada parcialmente y una NC puede afectar varias líneas de
una factura anterior.

`ap_match_exception` registra diferencias estructuradas y su resolución.
`ap_match_approval` conserva usuario, rol, fecha, decisión y motivo.

### Integración con SGM

`ap_external_exchange` debe conservar:

- sistema destino/origen;
- ID de paquete y correlación;
- documento y versión enviados;
- hash del payload;
- fecha, intentos y estado;
- respuesta de SGM;
- resultado de conciliación por línea;
- errores y evidencia de reproceso.

Mientras SGM sea quien concilia, CONNEXA debe persistir el paquete enviado y
recibir el resultado detallado. Un estado genérico `SENT` no alcanza para valorizar
ni auditar. En el modelo objetivo, SGM queda detrás de un conector y el contrato
canónico no depende de su estructura particular.

## Conciliación de tres vías

Para mercadería, la regla general es:

```text
Orden de Compra  = qué se autorizó comprar y a qué condiciones
Recepción        = qué cantidad se entregó y aceptó físicamente
Factura / NC     = qué cantidad e importe pretende cobrar o descontar el proveedor
```

La conciliación debe comparar por línea:

- proveedor y compañía;
- artículo por SKU proveedor, EAN y SKU interno;
- UOM y factor de conversión;
- cantidad ordenada, recibida, rechazada y facturada;
- precio de OC y precio facturado;
- descuentos de cabecera y línea;
- impuestos y percepciones;
- moneda y tipo de cambio;
- remito, lote y recepción asociados;
- tolerancias configuradas.

Debe soportar:

- recepciones parciales y múltiples;
- facturas parciales o consolidadas;
- múltiples facturas por recepción;
- mercadería bonificada;
- diferencias de peso o productos fraccionables;
- sustituciones de artículo;
- faltantes, sobrantes y rechazos;
- factura previa o posterior a la recepción;
- servicios o cargos sin movimiento físico;
- NC/ND posteriores;
- duplicados y reenvíos del mismo documento.

## Estados sugeridos

### Documento

```text
RECEIVED -> EXTRACTED -> VALIDATED -> IDENTIFIED
         -> MANUAL_REVIEW
         -> DUPLICATE / REJECTED
```

### Conciliación

```text
PENDING -> AUTO_MATCHED -> APPROVED -> POSTED
        -> PARTIAL_MATCH
        -> EXCEPTION -> MANUAL_MATCH -> APPROVED
        -> REJECTED
```

La aprobación y el posting deben ser estados distintos. Aprobar una factura
confirma la conciliación; publicar genera efectos en Cost, Tax y Accounting.

## Reglas de tolerancia

Las tolerancias deben parametrizarse por compañía, proveedor, categoría y vigencia:

- diferencia absoluta y porcentual de cantidad;
- diferencia de precio unitario;
- diferencia de total;
- diferencia de impuestos por redondeo;
- días entre recepción y factura;
- sobreentrega permitida;
- necesidad de aprobación según importe o excepción.

Cada auto-match debe guardar la regla y versión utilizadas. Una tolerancia no debe
alterar los datos originales: solo determina si la diferencia requiere excepción.

## Efecto sobre el Kardex

Se propone una valorización en dos etapas:

### 1. Recepción física

Al cerrar la recepción:

```text
RECEIPT_PROVISIONAL
cantidad_delta = cantidad aceptada
valor_delta    = cantidad aceptada * costo estimado de OC
estado_costo   = PROVISIONAL
```

Esto permite disponer de stock valorizado aun si la factura llega después.

### 2. Factura conciliada

Al aprobar la conciliación:

```text
INVOICE_COST_ADJUSTMENT
cantidad_delta = 0
valor_delta    = costo capitalizable facturado - valor provisional asignado
estado_costo   = FINAL o PARTIALLY_FINAL
```

El IVA recuperable y las percepciones no deben capitalizarse automáticamente. Su
tratamiento depende de política fiscal/contable versionada. Impuestos internos,
fletes y otros cargos requieren clasificación explícita.

### 3. Nota de crédito o débito

Una NC/ND conciliada genera un ajuste de valor referenciado a factura, recepción y
artículos. Si parte de la mercadería ya fue vendida, la política debe distribuir el
efecto entre inventario remanente y costo de mercadería vendida/resultados.

## Flujo objetivo

```text
Email / portal / EDI / carga en recepción
                  │
            Documento inmutable
                  │
           OCR + normalización
                  │
     Identificación y deduplicación
                  │
      Conciliación OC–recepción–factura
                  │
        Excepciones y aprobación
                  │
      ┌───────────┼────────────┐
      ▼           ▼            ▼
   Kardex      Fiscal      Contabilidad
      │
   costo definitivo
```

## Controles mínimos

1. Unicidad por compañía, CUIT proveedor, tipo, punto de venta y número.
2. Hash del archivo para detectar reenvíos idénticos.
3. CAE y datos fiscales validados según integración disponible.
4. Totales de control: neto + impuestos + percepciones + cargos - descuentos.
5. Ningún dato OCR de baja confianza se publica sin regla o revisión.
6. Ninguna línea se valoriza sin asignación a artículo y recepción, salvo cargos
   generales con método de distribución aprobado.
7. Reversas y rectificaciones; nunca borrado del documento contabilizado.
8. Separación de funciones entre corrección, conciliación, aprobación y posting.
9. Trazabilidad completa de envíos y respuestas de SGM.
10. Reconciliación de cantidad e importe entre documentos y subledgers.

## Decisiones a cerrar

- Si CONNEXA o SGM será autoridad de conciliación en el modelo objetivo.
- Momento exacto de valorización provisional y final.
- Tolerancias por tipo de operación.
- UOM y factores para bultos, unidades y peso.
- Método de prorrateo de descuentos/cargos de cabecera.
- Tratamiento de IVA, IIBB, impuestos internos, percepciones y fletes.
- Aprobaciones requeridas para diferencias y documentos manuales.
- Política para facturas sin OC y servicios sin recepción.
- Política para NC sin referencia inequívoca a factura/línea.
- Retención, acceso y cifrado de originales documentales.
