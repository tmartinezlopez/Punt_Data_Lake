# consultas_SQL/inspect — Toolkit read-only de inspección

Conjunto de scripts SQL parametrizados que la CLI `puntdl-inspect` carga y ejecuta sin crear objetos en la BBDD. La sesión va fijada a `SET TRANSACTION READ ONLY` como defensa en profundidad.

## Estructura
- `schema/` — introspección de esquema (tablas, columnas, FKs, modelos Odoo).
- `quality/` — calidad de datos: orphans, duplicados, nulls exactos.
- `profile/` — perfilado de columnas: distribuciones, calidad textual, fechas.
- `hu/` — *(Fase 3)* métricas específicas HU v1.

## Convenciones
- Cada `.sql` lleva su `.md` con secciones *Objetivo*, *Alcance*, *Objetos creados*, *Parámetros*, *Columnas/Salida*, *Operación*, *Notas* (regla 1 del `CLAUDE.md`).
- **Valores** se pasan como bind params SQLAlchemy con sintaxis `:nombre`.
- **Identificadores** (esquema/tabla/columna) se sustituyen con `{{nombre}}`; el runner valida con regex `^[a-z_][a-z0-9_]{0,62}$` y los cita con `"..."` antes de inyectar. Nunca pasar valores de usuario como identificadores sin pasar por `quote_ident` / `join_identifiers`.
- No se crean objetos: solo `SELECT`. Cualquier necesidad de materialización pasa por revisión y va a `consultas_SQL/` (no aquí).

## Catálogo (Fases 1-2)

| Categoría | Script | Comando CLI |
|-----------|--------|-------------|
| schema    | [tables.sql](schema/tables.sql) ([doc](schema/tables.md))                | `puntdl inspect schema tables` |
| schema    | [columns.sql](schema/columns.sql) ([doc](schema/columns.md))             | `puntdl inspect schema columns` |
| schema    | [fks.sql](schema/fks.sql) ([doc](schema/fks.md))                         | `puntdl inspect schema fks` |
| schema    | [odoo_models.sql](schema/odoo_models.sql) ([doc](schema/odoo_models.md)) | `puntdl inspect schema odoo-models` |
| quality   | [orphans.sql](quality/orphans.sql) ([doc](quality/orphans.md))           | `puntdl inspect quality orphans` |
| quality   | [duplicates.sql](quality/duplicates.sql) ([doc](quality/duplicates.md))  | `puntdl inspect quality duplicates` |
| quality   | [nulls.sql](quality/nulls.sql) ([doc](quality/nulls.md))                 | `puntdl inspect quality nulls` |
| profile   | [column.sql](profile/column.sql) ([doc](profile/column.md))              | `puntdl inspect profile column` |
| profile   | [text.sql](profile/text.sql) ([doc](profile/text.md))                    | `puntdl inspect profile text` |
| profile   | [dates.sql](profile/dates.sql) ([doc](profile/dates.md))                 | `puntdl inspect profile dates` |
