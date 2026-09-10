# Índice de CNX_COSTOS

## 1. Objetivo del repositorio

Este proyecto documenta la propuesta de costos comerciales para CONNEXA, con foco en:

- trazabilidad de costos
- costo neto comercial
- relevamiento comparado entre ambientes
- kardex valorizado
- documentos de recepción y conciliación
- cierre diario y gobierno de cambios en base de datos

El repositorio funciona como referencia funcional y técnica para la solicitud y preparación de cambios de base, sin reemplazar la aprobación formal de CORE/Arquitectura.

## 2. Estructura del proyecto

```text
CNX_COSTOS/
├── README.md                  # Descripción general y estado del proyecto
├── INDEX.md                   # Índice navegable del repositorio
├── .env                       # Variables locales sensibles (no versionadas)
├── docs/
│   ├── 01-relevamiento-connexa-desa.md
│   ├── 02-propuesta-modelo-costos.md
│   ├── 03-decisiones-abiertas.md
│   ├── 04-kardex-valorizado.md
│   ├── 05-documentos-recepcion-y-conciliacion.md
│   ├── 06-plan-de-implementacion.md
│   ├── 07-gobierno-cambios-base-datos.md
│   ├── 08-especificacion-funcional-cierre-diario.md
│   ├── 09-solicitud-core-cierre-diario.md
│   ├── 10-especificacion-funcional-modelo-integral.md
│   ├── 11-frontera-integracion-sap.md
│   └── Modelo_COSTOS_CNX.zip
├── sql/
│   ├── 001_cost_management_draft.sql
│   ├── V20260901180000__create_cost_management_core.sql
│   ├── V20260901190000__create_cost_management_daily_close.sql
│   ├── V20260901200000__create_document_management.sql
│   └── V20260901210000__create_accounts_payable_matching.sql
├── inspect_connexa.py
├── inspect_core_model.py
├── inspect_data_profile.py
├── inspect_receipt_documents.py
└── inspect_valued_ledger.py
```

## 3. Índice temático

### 3.1 Relevamiento y contexto

- [README.md](README.md): estado general, alcance y restricciones de uso.
- [docs/01-relevamiento-connexa-desa.md](docs/01-relevamiento-connexa-desa.md): evidencia comparada de production, test y desarrollo.
- [docs/02-propuesta-modelo-costos.md](docs/02-propuesta-modelo-costos.md): propuesta de arquitectura funcional y técnica.
- [docs/03-decisiones-abiertas.md](docs/03-decisiones-abiertas.md): decisiones aprobadas y pendientes.

### 3.2 Modelado y kardex

- [docs/04-kardex-valorizado.md](docs/04-kardex-valorizado.md): brecha actual y estructura mínima del ledger valorizado.
- [docs/10-especificacion-funcional-modelo-integral.md](docs/10-especificacion-funcional-modelo-integral.md): inventario funcional de 31 tablas propuestas.

### 3.3 Documentos y conciliación

- [docs/05-documentos-recepcion-y-conciliacion.md](docs/05-documentos-recepcion-y-conciliacion.md): recepción documental, OCR y conciliación de OC, recepción y factura/NC.
- [docs/11-frontera-integracion-sap.md](docs/11-frontera-integracion-sap.md): límites entre CONNEXA y SAP, contratos mínimos y condición para cuentas por pagar.

### 3.4 Operación y cierre diario

- [docs/08-especificacion-funcional-cierre-diario.md](docs/08-especificacion-funcional-cierre-diario.md): comportamiento funcional y criterios de aceptación del cierre diario valorizado.
- [docs/09-solicitud-core-cierre-diario.md](docs/09-solicitud-core-cierre-diario.md): cambio preparado para CORE y Arquitectura.
- [docs/06-plan-de-implementacion.md](docs/06-plan-de-implementacion.md): roadmap, entregables, responsables y criterios de salida.

### 3.5 Gobierno de base de datos

- [docs/07-gobierno-cambios-base-datos.md](docs/07-gobierno-cambios-base-datos.md): flujo de solicitud, revisión y promoción controlada de cambios Flyway.
- [sql/V20260901180000__create_cost_management_core.sql](sql/V20260901180000__create_cost_management_core.sql): núcleo Flyway candidato.
- [sql/V20260901190000__create_cost_management_daily_close.sql](sql/V20260901190000__create_cost_management_daily_close.sql): cierre diario Flyway candidato.
- [sql/V20260901200000__create_document_management.sql](sql/V20260901200000__create_document_management.sql): documentos y OCR Flyway candidato.
- [sql/V20260901210000__create_accounts_payable_matching.sql](sql/V20260901210000__create_accounts_payable_matching.sql): factura y conciliación Flyway candidato.
- [sql/001_cost_management_draft.sql](sql/001_cost_management_draft.sql): DDL conceptual no ejecutado.

## 4. Scripts de inspección

Estos scripts consultan metadatos y agregados, mayormente orientados a validación y perfilamiento de datos. Los nombres sugieren su foco:

- [inspect_connexa.py](inspect_connexa.py): inspección general del modelo CONNEXA.
- [inspect_core_model.py](inspect_core_model.py): inspección del modelo central o núcleo.
- [inspect_data_profile.py](inspect_data_profile.py): perfilado de datos y estadísticas.
- [inspect_receipt_documents.py](inspect_receipt_documents.py): revisión de documentos de recepción.
- [inspect_valued_ledger.py](inspect_valued_ledger.py): análisis del ledger valorizado.

## 5. Cómo navegar el proyecto

1. Empezar por [README.md](README.md) para entender alcance y estado.
2. Revisar [docs/02-propuesta-modelo-costos.md](docs/02-propuesta-modelo-costos.md) y [docs/10-especificacion-funcional-modelo-integral.md](docs/10-especificacion-funcional-modelo-integral.md) para modelo funcional.
3. Consultar [docs/08-especificacion-funcional-cierre-diario.md](docs/08-especificacion-funcional-cierre-diario.md) y [docs/09-solicitud-core-cierre-diario.md](docs/09-solicitud-core-cierre-diario.md) para operación.
4. Resolver detalles de la base en [docs/07-gobierno-cambios-base-datos.md](docs/07-gobierno-cambios-base-datos.md) y en la carpeta [sql/](sql/).
5. Usar los scripts [inspect_*.py](inspect_connexa.py) para validación de metadatos y perfilado.

## 6. Estado del proyecto

- Decisiones funcionales 1 a 21 aprobadas a nivel conceptual.
- El DDL sigue siendo borrador no ejecutable hasta cerrar parámetros operativos, contrato SAP y pruebas de replay.
- La migración de cuentas por pagar depende del fit-gap con SAP.
- Los cambios en ambientes de CONNEXA deben ejecutarse solo por CORE/Arquitectura y no por este repositorio en sí.

## 7. Recomendación de uso

Este repositorio debe utilizarse como:

- biblioteca de requisitos funcionales
- base de documentación técnica y operativa
- conjunto de propuestas de modelo y migración
- fuente de evidencia para validación y revisión

No es un repositorio de despliegue ni una base de ejecución de cambios en producción.
