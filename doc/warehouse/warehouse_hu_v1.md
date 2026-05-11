# warehouse_hu_v1.sql

## Objetivo
Crear las tablas warehouse HU v1 y sus índices para soportar el pipeline Python de indexación.

## Objetos creados
- `analytics.wh_hu_group` (1 fila por `group_id`)
- `analytics.wh_hu_node` (1 fila por `node_id`)
- `analytics.wh_hu_embedding_input` (3 filas por grupo: `full`, `solution`, `hu_description`)
- `analytics.wh_etl_watermark` (control incremental)

## Decisiones aplicadas
- Horas en `NUMERIC(12,2)`
- Progreso en `NUMERIC(5,2)`
- Borrado lógico con `is_deleted` en group y node
- Tipos embedding restringidos por check constraint

## Índices
- Group: `project_id`, `partner_id`, `max_write_date`, `is_deleted`
- Node: `group_id`, `write_date`, `project_id`, `partner_id`, `is_deleted`
- Embedding input: `embedding_type`, `(project_id, partner_id)`

## Uso
Ejecutar:
```sql
\i database/sql/warehouse/warehouse_hu_v1.sql
```
