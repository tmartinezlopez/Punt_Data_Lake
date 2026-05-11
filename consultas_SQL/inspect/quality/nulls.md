# inspect/quality/nulls

## Objetivo
Reportar la fracción **exacta** de NULLs por columna en una tabla, no la estimación de `pg_stats`. Útil para decidir qué campos están realmente poblados y cuáles son ruido (típico tras heredar campos de muchos módulos Odoo).

## Alcance
- Una sola tabla.
- Solo columnas almacenadas físicamente (excluye columnas droppeadas y de sistema).
- Lectura completa de la tabla: 1 pase secuencial. En tablas grandes (decenas de millones) prefiere `inspect schema columns --only-used`, que usa `pg_stats`.

## Objetos creados
Ninguno.

## Parámetros
| Nombre              | Tipo   | Default | Descripción |
|---------------------|--------|---------|-------------|
| `:threshold`        | float  | `0.0`   | Filtra columnas con `null_frac >= threshold` (entre 0 y 1). |
| `{{schema}}`, `{{table}}` | ident | — | Identificadores citados. |
| `{{col_aggregates}}` | expr   | — | Generado por la CLI a partir de `pg_attribute`: lista de `count(*) FILTER (WHERE "col" IS NULL) AS "col"` separada por comas. |

## Columnas / Salida
- `column` — nombre de la columna.
- `n_null` — recuento exacto de NULLs.
- `n_total` — total de filas (igual para todas).
- `null_frac` — `n_null / n_total` (0..1).

## Operación
```bash
puntdl inspect quality nulls --table project_task --threshold 0.9
```

## Notas
- El truco para devolver una fila por columna sin construir `UNION` manual: en Python se construye un agregado por columna en `{{col_aggregates}}`; el SQL final hace `to_jsonb(counts) - 'n_total'` y `jsonb_each` para "des-pivotar" a (column, value).
- Para tablas con cientos de columnas (frecuente en Odoo extendido), el plan es un único seq scan con N agregados — eficiente y barato.
