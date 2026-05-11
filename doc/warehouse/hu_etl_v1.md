# hu_etl_v1.py

## Objetivo
Poblar warehouse HU desde:
- `analytics.v_hu_raw`
- `analytics.mv_hu_estructura`

Modos soportados:
- `full`
- `incremental` (con `analytics.wh_etl_watermark`)

## Scripts
- `etl/hu_etl_v1.py` (orquestador Python)
- `database/sql/warehouse/warehouse_hu_v1_load.sql` (carga full)
- `database/sql/warehouse/warehouse_hu_v1_load_incremental.sql` (carga incremental)

## Variables de entorno
- `PGHOST` (default: `localhost`)
- `PGPORT` (default: `5432`)
- `PGUSER` (default: `postgres`)
- `PGPASSWORD` (opcional)
- `PGDATABASE` (default: `PUNT_SISTEMES_PRO`)
- `PSQL_PATH` (opcional, default PostgreSQL 17 en Windows)

## Qué hace
1. Ejecuta SQL transaccional de carga (`full` o `incremental`).
2. Carga:
   - `analytics.wh_hu_group`
   - `analytics.wh_hu_node`
   - `analytics.wh_hu_embedding_input` (`full`, `solution`, `hu_description`)
3. Gestiona watermark para incremental en `analytics.wh_etl_watermark`.
4. Devuelve métricas de ejecución en JSON.

## Reglas aplicadas
- `partner_id` de grupo:
  1. anchor si existe
  2. más frecuente en el grupo
  3. `NULL` si no hay
- Horas/progreso en formato numérico
- `is_deleted = false` en carga v1

## Ejecución
```bash
python etl/hu_etl_v1.py --mode full
python etl/hu_etl_v1.py --mode incremental
```

## Salida
JSON con:
- modo
- tiempo de ejecución
- filas en `wh_hu_group`
- filas en `wh_hu_node`
- filas en `wh_hu_embedding_input`
- watermark (antes/después en incremental)

## Próximo paso
- Optimizar tiempo incremental.
- Añadir validaciones de calidad por embedding.
