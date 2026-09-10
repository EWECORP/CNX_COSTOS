---
id: CNX-COST-DOC-001
titulo: Documentos de recepción y conciliación de compras
estado: aprobado-con-parametros-pendientes
version: 1.0
fecha: 2026-09-01
propietario: por-definir
documentos_relacionados:
  - CNX-COST-ARC-001
  - CNX-COST-KDX-001
  - CNX-COST-ADR-002
---

# Documentos de recepción y conciliación de compras

## Objetivo

Incorporar facturas, remitos, notas de crédito, notas de débito y otros documentos
asociados a la entrega, conciliarlos contra órdenes de compra y recepciones, y
producir una valorización aprobada y trazable para el Kardex y una interfaz
completa con SAP, sin duplicar los subledgers oficiales del ERP.

## Hallazgos en producción

La medición inicial estaba rotulada como DESA, pero la conexión utilizada
correspondía a `PGP_HOST`. Las cifras siguientes son, por lo tanto, de producción.

CONNEXA ya posee un circuito significativo de captura documental en
`mail_processor`:

| Entidad | Filas observadas |
|---|---:|
| Correos | 12.361 |
| Adjuntos | 12.144 |
| Documentos extraídos | 11.559 al actualizar el perfil |
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
- no existe una entidad canónica de factura/NC dentro de producción; las entidades
  `acp_purchase_invoice*` visibles son enlaces a otro ambiente/esquema.

### Calidad observada de la extracción

El perfil detallado original sobre 11.523 documentos mostró:

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
aprobación. Produce asignaciones explícitas contra OC y recepción y, cuando la
factura presenta una diferencia reclamable, emite una solicitud de nota de crédito.

### Procurement

Autoridad sobre OC, recepción física, cantidades aceptadas, rechazos, lotes y
fechas de recepción.

### Cost Management

Consume exclusivamente resultados de conciliación aprobados. Registra costo
provisional, ajustes a costo definitivo y NC/ND en el Kardex.

### Tax y Accounting

El sistema contable del cliente recibe mediante interfaces los componentes fiscales
y contables aprobados. No
debe reconstruirlos consultando directamente el OCR. CONNEXA conserva esos datos
como evidencia de costo e interfaz, no como subledger oficial.

### Sistema contable (SAP en DIARCO)

Es el sistema de registro de cuentas a pagar, cuenta corriente de proveedores,
contabilización, impuestos, pagos y reportes legales. Una aprobación local habilita
el ajuste de costo y la interfaz; no equivale a contabilización externa. En DIARCO
este sistema es SAP; en otros clientes puede ser otro sistema contable.

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

`ap_credit_note_request` registra la solicitud emitida por CONNEXA cuando la
factura conciliada difiere de la OC o de la recepción y corresponde reclamar un
descuento. Conserva importe, moneda, motivo, evidencia, conciliación y excepción
de origen, estados, envío y referencia externa. No es una NC emitida ni modifica
por sí misma la cuenta corriente del proveedor.

### Integración transitoria con SGM y sistema contable objetivo

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
canónico no depende de su estructura particular. La salida hacia el sistema
contable debe incluir acuse técnico, resultado funcional, referencia externa y reconciliación; CONNEXA no
reproduce el posting contable internamente.

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
PENDING -> AUTO_MATCHED -> APPROVED -> READY_FOR_EXPORT
                                      -> EXPORTED -> EXTERNAL_ACCEPTED
        -> PARTIAL_MATCH
        -> EXCEPTION -> MANUAL_MATCH -> APPROVED
        -> REJECTED
```

La aprobación operativa y la aceptación del sistema contable deben ser estados distintos.
Aprobar confirma la conciliación y autoriza el costo/interfaz; sólo la respuesta de
el sistema contable confirma el registro oficial.

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

El cierre físico y este asiento provisional forman una única unidad lógica. Si no
se puede persistir movimiento, valorización, posición y outbox, la recepción debe
quedar en excepción y no cerrada silenciosamente.

### 2. Factura conciliada

Al aprobar la conciliación:

```text
INVOICE_COST_ADJUSTMENT
cantidad_delta = 0
valor_delta    = costo capitalizable facturado - valor provisional asignado
estado_costo   = FINAL o PARTIALLY_FINAL
```

El IVA recuperable y las percepciones computables no capitalizan. Los impuestos
no recuperables directamente atribuibles, impuestos internos y fletes
capitalizables sí integran costo según una matriz fiscal/contable versionada. Una
recuperabilidad parcial divide explícitamente crédito fiscal y costo.

### 3. Nota de crédito o débito

Una NC/ND conciliada genera un ajuste de valor referenciado a factura, recepción y
artículos. Si parte de la mercadería ya fue vendida, la política debe distribuir el
efecto entre inventario remanente y costo de mercadería vendida/resultados.

Cuando la factura recibida difiere de la OC o de la recepción fuera de tolerancia,
CONNEXA genera una `CREDIT_NOTE_REQUEST`. La solicitud se envía al circuito
correspondiente y luego al sistema contable para que el cliente gestione el
descuento en la cuenta corriente del proveedor. La posterior NC real se ingresa
como documento independiente y se relaciona con la solicitud, factura y match de
origen.

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
      ┌───────────┴────────────┐
      ▼                        ▼
   Kardex          Solicitud NC / interfaz contable
      │                        │
 costo definitivo      acuse y referencia externa
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
8. Separación entre corrección, conciliación, solicitud de NC, aprobación e interfaz contable.
9. Trazabilidad completa de envíos y respuestas de SGM/sistema contable.
10. Reconciliación de cantidad e importe entre documentos CONNEXA y registros externos.

## Decisiones aplicables

- El costo provisional nace al cierre físico con precio y condiciones de la OC.
- Pesables se concilian y valúan en kilogramos; bultos usan el factor de compra del
  proveedor congelado en la OC y recepción.
- Factura, NC y ND producen ajustes de valor sin duplicar cantidad.
- Acuerdos atribuibles a compras reducen costo; servicios comerciales o financieros
  van a resultados.
- Bonificaciones forman parte de la cantidad recibida y reducen el costo unitario.
- Períodos cerrados se corrigen mediante reapertura, replay y asientos delta.
- La evidencia y sus versiones se conservan conforme a estándares de auditoría.

## Parámetros y definiciones de integración pendientes

- autoridad y fecha objetivo para que CONNEXA reemplace a SGM en conciliación;
- tolerancias por compañía, proveedor, categoría y tipo de documento;
- métodos de prorrateo por tipo de cargo o descuento;
- matriz impositiva de recuperabilidad y vigencia;
- aprobadores y umbrales de materialidad;
- política para facturas sin OC, servicios sin recepción y NC sin referencia;
- retención, acceso, cifrado y clasificación de originales;
- contrato detallado de intercambio y respuesta por línea mientras continúe SGM.
- RACI, objetos de negocio y contratos del adaptador contable de cada cliente.
