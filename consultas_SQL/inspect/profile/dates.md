# inspect/profile/dates

## Objetivo
Distribución temporal de una columna fecha/timestamp: rango (`first`, `last`), NULLs y conteo por bucket (`day`, `week`, `month`, `quarter`, `year`).

## Alcance
- Una sola columna; se castea a `timestamp`. Para tipos `date` el cast es directo, para `timestamptz` se descarta la zona horaria.

## Objetos creados
Ninguno.

## Parámetros
| Nombre    | Tipo  | Default | Descripción |
|-----------|-------|---------|-------------|
| `:bucket` | text  | `month` | Uno de: `day`, `week`, `month`, `quarter`, `year`. Validado por la CLI antes de enviar. |
| `:limit`  | int   | `60`    | Máx. de buckets a devolver (más recientes primero). |
| `{{schema}}`, `{{table}}`, `{{column}}` | ident | — | Identificadores citados. |

## Columnas / Salida
- Fila `kind = 'summary'` con `n` (total), `first`, `last`, `n_null`.
- Resto de filas `kind = 'bucket'` con `bucket` (inicio del periodo) y `n`.

## Operación
```bash
puntdl inspect profile dates --table project_task --column create_date --bucket month
puntdl inspect profile dates --table project_task --column write_date --bucket week --limit 20
```

## Notas
- `date_trunc` respeta la zona horaria de la sesión Postgres; en este proyecto se asume UTC del dump.
- El parámetro `:bucket` no es un identificador (no va por `{{...}}`); es un texto pasado a `date_trunc` y la CLI restringe los valores a la lista permitida.
