# inspect/quality/duplicates

## Objetivo
Detectar duplicados por una o varias columnas: combinaciones de valores que aparecen >= `min_count` veces en la tabla. Sirve tanto para auditar claves naturales (p.ej. `vat` en `res_partner`) como para encontrar registros repetidos.

## Alcance
- Una tabla, N columnas pasadas por la CLI con `--by col1 --by col2 ...`.
- Cualquier subconjunto de columnas almacenadas (no calculadas).
- NULLs cuentan como un grupo (`GROUP BY` considera NULL = NULL en agrupación).

## Objetos creados
Ninguno.

## Parámetros
| Nombre        | Tipo  | Default | Descripción |
|---------------|-------|---------|-------------|
| `:min_count`  | int   | `2`     | Mínimo de ocurrencias para reportar el grupo. |
| `:limit`      | int   | `50`    | Filas a devolver. |
| `{{schema}}`, `{{table}}`, `{{by_cols}}` | ident | — | Identificadores citados; `by_cols` es la lista separada por comas. |

## Columnas / Salida
- Cada columna de `--by` aparece como columna propia.
- `n` — número de ocurrencias del grupo.
- `ctids_sample` — array con hasta 5 `ctid` (`tuple id` de Postgres) de filas representativas. Útil para localizarlas con `SELECT * FROM tbl WHERE ctid = '(0,1)'::tid`.

## Operación
```bash
puntdl inspect quality duplicates --table res_partner --by vat
puntdl inspect quality duplicates --table res_partner --by name --by email --min-count 3
```

## Notas
- Los `ctid` son **volátiles**: cambian tras `VACUUM FULL` o reescritura de la tabla. Útiles a corto plazo para inspección, no como identificadores duraderos.
- Para encontrar duplicados ignorando mayúsculas/acentos, esta v1 no aplica normalización; será una iteración posterior (`--normalize` o vista dedicada).
