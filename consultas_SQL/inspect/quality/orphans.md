# inspect/quality/orphans

## Objetivo
Detectar **FKs colgantes**: filas de una tabla cuyo `column` apunta a un valor que no existe en la tabla referenciada. Útil para auditar consistencia tras migraciones o dumps incompletos.

## Alcance
- Una FK simple (una sola columna). FKs compuestas no soportadas en v1.
- Si la CLI no recibe `--ref-table`/`--ref-column`, los resuelve automáticamente vía `pg_constraint`.

## Objetos creados
Ninguno (SELECT puro).

## Parámetros
| Nombre        | Tipo  | Default | Descripción |
|---------------|-------|---------|-------------|
| `:sample`     | int   | `10`    | Máx. filas de muestra a devolver. |
| `{{schema}}`  | ident | —       | Esquema de la tabla origen. |
| `{{table}}`   | ident | —       | Tabla origen. |
| `{{column}}`  | ident | —       | Columna FK con potenciales huérfanos. |
| `{{ref_schema}}` / `{{ref_table}}` / `{{ref_column}}` | ident | resuelto vía FK | Lado referenciado. |

## Columnas / Salida
- `bad_value` — valor presente en `column` que no existe en `ref_column`.
- `n_orphans_total` — total global de huérfanos (vía `COUNT(*) OVER ()`); mismo valor en todas las filas.
- `row_data` — `to_jsonb` de la fila huérfana completa.

Si el resultado está vacío, **no hay huérfanos**.

## Operación
```bash
puntdl inspect quality orphans --table project_task --column parent_id
puntdl inspect quality orphans --table project_task --column partner_id --sample 20
```

## Notas
- Una FK declarada `ON DELETE SET NULL` o `RESTRICT` evita huérfanos por construcción; aun así esta herramienta los detecta si por alguna razón existen (carga manual, dump parcial).
- `ctid` no se devuelve aquí; si hace falta para localizar físicamente, mirar `row_data`.
