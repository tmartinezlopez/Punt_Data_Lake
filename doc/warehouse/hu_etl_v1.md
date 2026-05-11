# hu_etl_v1.py

## Objetivo
Poblar `analytics.wh_hu_group` y `analytics.wh_hu_node` desde:
- `analytics.v_hu_raw`
- `analytics.mv_hu_estructura`

Modo actual: **full load**.

## Scripts
- `etl/hu_etl_v1.py` (orquestador Python)
- `database/sql/warehouse/warehouse_hu_v1_load.sql` (lógica SQL de carga)

## Variables de entorno
- `PGHOST` (default: `localhost`)
- `PGPORT` (default: `5432`)
- `PGUSER` (default: `postgres`)
- `PGPASSWORD` (opcional si la instancia no lo requiere)
- `PGDATABASE` (default: `PUNT_SISTEMES_PRO`)
- `PSQL_PATH` (opcional, default PostgreSQL 17 en Windows)

## Qué hace
1. Ejecuta SQL transaccional de carga full.
2. Trunca `wh_hu_node` y `wh_hu_group`.
3. Inserta grupos agregados y nodos desde las vistas fuente.
4. Devuelve métricas de ejecución en JSON.

## Reglas importantes aplicadas
- `partner_id` de grupo:
  1. anchor si existe
  2. más frecuente en el grupo
  3. `NULL` si no hay
- Horas/progreso en formato numérico
- `is_deleted = false` en carga full inicial

## Ejecución
```bash
python etl/hu_etl_v1.py
```

Salida:
- JSON con contadores (`source_rows`, `group_rows`, `node_rows`) y timestamps.

## Próximo paso
- Añadir incremental con `wh_etl_watermark`.
- Añadir generación de `wh_hu_embedding_input`.
