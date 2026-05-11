# inspect/schema/fks

## Objetivo
Listar las claves foráneas que **salen** de una tabla (referencias a otras) y las que **entran** (otras tablas que la referencian). Permite mapear el subgrafo relacional alrededor de un modelo Odoo.

## Alcance
- FKs declaradas en `pg_constraint` (`contype = 'f'`).
- Soporta FKs compuestas: cada par columna/refcolumna sale como fila independiente.

## Objetos creados
Ninguno.

## Parámetros
| Nombre        | Tipo  | Default   | Descripción |
|---------------|-------|-----------|-------------|
| `:schema`     | text  | `public`  | Esquema de la tabla foco. |
| `:table`      | text  | —         | Tabla foco. |
| `:direction`  | text  | `both`    | `outbound`, `inbound` o `both`. |

## Columnas / Salida
- `direction` — `outbound` (la tabla referencia) / `inbound` (es referenciada).
- `constraint_name`.
- `schema`, `table`, `column` — lado origen.
- `ref_schema`, `ref_table`, `ref_column` — lado destino.
- `on_delete`, `on_update` — códigos de `pg_constraint.confdeltype/confupdtype` (`a` no action, `r` restrict, `c` cascade, `n` set null, `d` set default).

## Operación
```bash
puntdl inspect schema fks --table project_task --direction inbound
```

## Notas
- En Odoo muchos campos `*_id` no son FKs reales (p.ej. `res_id` polimórfico). Esta vista solo enseña FKs declaradas físicamente.
- Para inspección rápida del grafo completo de un modelo, suele ser más útil `inbound` (qué tablas dependen) que `outbound`.
