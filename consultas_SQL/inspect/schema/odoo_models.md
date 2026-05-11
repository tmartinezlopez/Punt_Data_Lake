# inspect/schema/odoo_models

## Objetivo
Cruzar `ir_model` + `ir_module_module` con `pg_catalog` para obtener, por modelo Odoo, su etiqueta humana, módulo de origen, estado del módulo y la tabla física asociada (si la hay) con su tamaño estimado.

## Alcance
- Modelos definidos en `ir_model` (no se asume nada sobre módulos personalizados vs estándar).
- Tabla física inferida por convención Odoo: `replace(ir_model.model, '.', '_')` en esquema `public`.
- Modelos abstractos / `TransientModel` sin almacenamiento aparecen con `table`, `est_rows`, `total_size` en NULL.

## Objetos creados
Ninguno.

## Parámetros
| Nombre   | Tipo  | Default | Descripción |
|----------|-------|---------|-------------|
| `:like`  | text  | `%`     | Patrón `LIKE` sobre `ir_model.model` (ej. `project.%`). |
| `:limit` | int   | `50`    | Filas a devolver. |

## Columnas / Salida
- `model` — `ir.model.model` (ej. `project.task`).
- `label` — etiqueta humana de `ir.model.name`. En Odoo 17 el campo es JSONB con traducciones por idioma; aquí se devuelve `es_ES` si existe, con fallback a `en_US`.
- `module` / `module_state` — módulo que registró el modelo y su estado (`installed`, `to upgrade`, etc.).
- `table` — nombre físico en `public`.
- `est_rows` — filas estimadas (`reltuples`).
- `total_size` — tamaño total legible (datos + índices + TOAST).

## Operación
```bash
puntdl inspect schema odoo-models --like project.%
```

## Notas
- Algunos modelos heredan de otros y comparten tabla; aquí se muestra cada `ir_model` por separado.
- `ir_model_data` puede tener varias filas para el mismo `res_id` (módulo definidor + extensiones); el `LEFT JOIN` provoca duplicados — para v1 no se deduplica, lo cual es útil para ver qué módulos extienden el modelo. Si molesta, agrupar/filtrar en sucesivas iteraciones.
