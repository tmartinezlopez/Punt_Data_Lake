# inspect/profile/column

## Objetivo
Resumen genérico de una columna: total, NULLs, cardinalidad y top-N valores con porcentaje. Útil para entender rápido qué guarda un campo (estados, prioridades, claves bajas de cardinalidad).

## Alcance
- Una sola columna; se castea a `text` para listarla en `top` aunque sea numérica.
- Top-N excluye NULLs (cuentan aparte en el resumen).

## Objetos creados
Ninguno.

## Parámetros
| Nombre        | Tipo  | Default | Descripción |
|---------------|-------|---------|-------------|
| `:top_n`      | int   | `10`    | Tamaño del top de valores. |
| `{{schema}}`, `{{table}}`, `{{column}}` | ident | — | Identificadores citados. |

## Columnas / Salida
Una fila `kind = 'summary'` (la primera) seguida de hasta `top_n` filas `kind = 'top'`:

- `summary`: `n` = total, `n_null`, `n_distinct`.
- `top`: `value`, `n`, `pct` (porcentaje sobre total incl. NULLs).

## Operación
```bash
puntdl inspect profile column --table project_task --column state
puntdl inspect profile column --table project_task --column stage_id --top-n 20
```

## Notas
- `n_distinct` se calcula con `COUNT(DISTINCT)` real — costoso en columnas muy variadas; tener en cuenta en tablas grandes.
- Para campos textuales largos (descripciones) usar `profile text` en su lugar; el cast a text del top sería poco útil.
