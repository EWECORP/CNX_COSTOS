# Paquete Flyway — CNX Cost Management

Estado: candidato para revisión de CORE  
Ambiente inicial autorizado: Desarrollo (`PGD_HOST`)  
Ejecución: exclusiva del equipo CORE

## Contenido y orden

| Orden | Migración | Resultado |
|---:|---|---|
| 1 | `sql/V20260901180000__create_cost_management_core.sql` | ledger, políticas, posiciones, costo comercial, integración y auditoría |
| 2 | `sql/V20260901190000__create_cost_management_daily_close.sql` | cierre diario y balances por sucursal |
| 3 | `sql/V20260901200000__create_document_management.sql` | documentos, binarios y OCR versionado |
| 4 | `sql/V20260901210000__create_accounts_payable_matching.sql` | factura canónica, match, solicitud NC e intercambio externo |

El directorio completo constituye **un único paquete de entrega Flyway**, pero las
migraciones permanecen separadas. No deben concatenarse: el orden conserva las
dependencias, mejora la evidencia de despliegue y permite a CORE aprobar cada
bounded context explícitamente.

## Inventario esperado

| Esquema | Tablas |
|---|---:|
| `cost_management` | 17 |
| `document_management` | 4 |
| `accounts_payable` | 11 |
| **Total** | **32** |

## Uso en el pipeline de CORE

1. Verificar `checksums.sha256` y comparar el paquete con la solicitud aprobada.
2. Confirmar base destino, usuario, historia Flyway, owners, roles y grants.
3. Ejecutar `flyway info` y `flyway validate`.
4. Aplicar primero en Desarrollo mediante el pipeline institucional.
5. Ejecutar las validaciones posteriores de `../../09-solicitud-core-cierre-diario.md`.
6. Adjuntar salida de Flyway, conteos, constraints, índices y checksums.
7. Promover a otro ambiente sólo con evidencia y autorización.

Ejemplo orientativo sin credenciales:

```text
flyway -locations=filesystem:./sql info
flyway -locations=filesystem:./sql validate
flyway -locations=filesystem:./sql migrate
```

CORE debe incorporar la ubicación a su configuración real; no se distribuyen
URLs, usuarios ni contraseñas en este paquete.

## Precondiciones

- PostgreSQL y base autorizados por CORE.
- Ausencia de los tres esquemas o resolución documentada de cualquier drift.
- Versiones Flyway confirmadas o renombradas antes de su primera aplicación.
- Estrategia de `flyway_schema_history` definida por CORE.
- Revisión de locks, performance, ownership, permisos y backup.
- Ningún productor/consumidor se activa con estas migraciones.

## Reglas de modificación

- Antes de aplicar: un cambio exige reemplazar el archivo, actualizar checksum y
  repetir la revisión.
- Después de aplicar: una corrección se entrega en una migración nueva; nunca se
  modifica una versión registrada por Flyway.
- No ejecutar `clean`, `DROP` ni reparación automática como parte de esta entrega.
- Los datos iniciales, backfill y datos de prueba no pertenecen a estas migraciones.

## Sobre una migración SQL única

No se entrega un `create_all.sql` versionado porque perdería el límite entre
componentes y haría más riesgosa una corrección. Si CORE necesita atomicidad de
despliegue puede usar las capacidades transaccionales/grupales de su pipeline,
manteniendo las cuatro versiones y verificando previamente que su configuración y
la versión de Flyway lo soporten.

