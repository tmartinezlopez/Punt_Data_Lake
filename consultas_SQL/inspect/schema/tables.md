# inspect/schema/tables

## Objetivo
Listar tablas de un esquema con conteo de filas estimado y, opcionalmente, tamaño en disco. Pensado para mapear las ~1100 tablas del dump de Odoo y localizar las relevantes por patrón de nombre.

## Alcance
- Solo tablas (`relkind IN ('r','p')`); excluye vistas, índices, secuencias y materializadas.
- Conteo `est_rows` proviene de `pg_class.reltuples` — es una **estimación** actualizada por el último `ANALYZE`, no exacta.

## Objetos creados
Ninguno (consulta SELECT pura, read-only).

## Parámetros
| Nombre        | Tipo  | Default      | Descripción |
|---------------|-------|--------------|-------------|
| `:schema`     | text  | `public`     | Esquema a inspeccionar. |
| `:like`       | text  | `%`          | Patrón `LIKE` sobre nombre de tabla. |
| `:with_size`  | bool  | `false`      | Si `true`, calcula `pg_total_relation_size`. |
| `:non_empty`  | bool  | `false`      | Si `true`, filtra `reltuples > 0`. |
| `:limit`      | int   | `50`         | Límite de filas a devolver. |

## Columnas / Salida
- `schema`, `table` — identificador completo.
- `est_rows` — estimación de filas.
- `total_size` / `total_size_bytes` — tamaño legible y bytes (solo si `:with_size`).
- `comment` — `COMMENT ON TABLE` si existe.

## Operación
Desde la CLI:
```bash
puntdl inspect schema tables --like project_% --with-size --non-empty
```
Equivalente psql:
```sql
\set schema 'public'
\set like 'project_%'
\set with_size true
\set non_empty true
\set limit 50
\i consultas_SQL/inspect/schema/tables.sql
```

## Notas
- Para conteos exactos haría falta `SELECT COUNT(*)` por tabla — coste prohibitivo en 1100 tablas. Refrescar `ANALYZE` si se sospecha drift.
- `obj_description` retorna `NULL` para la mayoría de tablas de Odoo (no usa comentarios SQL).
