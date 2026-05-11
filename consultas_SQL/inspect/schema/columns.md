# inspect/schema/columns

## Objetivo
Describir las columnas de una tabla con su tipo, nulabilidad, default y estadísticas de uso (fracción de nulos y distintos estimados), para decidir rápidamente qué campos son útiles dentro de un modelo Odoo.

## Alcance
- Una tabla concreta del esquema indicado.
- Excluye columnas droppeadas (`attisdropped`) y columnas de sistema (`attnum <= 0`).

## Objetos creados
Ninguno.

## Parámetros
| Nombre        | Tipo  | Default   | Descripción |
|---------------|-------|-----------|-------------|
| `:schema`     | text  | `public`  | Esquema. |
| `:table`      | text  | —         | Tabla a inspeccionar. |
| `:only_used`  | bool  | `false`   | Si `true`, filtra columnas con `null_frac < 1` (al menos un valor no NULL según `pg_stats`). |

## Columnas / Salida
- `ord`, `column`, `type`.
- `nullable` — `NOT attnotnull`.
- `default` — expresión por defecto si la hay.
- `null_frac`, `n_distinct` — estimaciones del último `ANALYZE` (vía `pg_stats`).
- `comment` — `COMMENT ON COLUMN` si existe.

## Operación
```bash
puntdl inspect schema columns --table project_task --only-used
```

## Notas
- `null_frac` y `n_distinct` son **estimaciones**; si se necesita exactitud para auditoría, usar el comando `inspect quality nulls` (Fase 2) que ejecuta agregados reales.
- `pg_stats` solo expone filas para columnas analizadas y a las que el usuario actual tiene acceso.
