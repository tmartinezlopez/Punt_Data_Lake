# consultas_SQL/inspect — Toolkit read-only de inspección

Conjunto de scripts SQL parametrizados que la CLI `puntdl-inspect` carga y ejecuta sin crear objetos en la BBDD. La sesión va fijada a `SET TRANSACTION READ ONLY` como defensa en profundidad.

## Estructura
- `schema/` — introspección de esquema (tablas, columnas, FKs, modelos Odoo).
- `quality/` — *(Fase 2)* calidad de datos: orphans, duplicados, nulos lógicos.
- `profile/` — *(Fase 2)* perfilado de columnas: distribuciones, longitudes, fechas.
- `hu/` — *(Fase 3)* métricas específicas HU v1.

## Convenciones
- Cada `.sql` lleva su `.md` con secciones *Objetivo*, *Alcance*, *Objetos creados*, *Parámetros*, *Columnas/Salida*, *Operación*, *Notas* (regla 1 del `CLAUDE.md`).
- Parámetros con sintaxis SQLAlchemy `:nombre`. Tipos soportados: `text`, `bool`, `int`.
- No se crean objetos: solo `SELECT`. Cualquier necesidad de materialización pasa por revisión y va a `consultas_SQL/` (no aquí).

## Catálogo (Fase 1)

| Categoría | Script | Comando CLI |
|-----------|--------|-------------|
| schema    | [tables.sql](schema/tables.sql) ([doc](schema/tables.md))            | `puntdl inspect schema tables` |
| schema    | [columns.sql](schema/columns.sql) ([doc](schema/columns.md))         | `puntdl inspect schema columns` |
| schema    | [fks.sql](schema/fks.sql) ([doc](schema/fks.md))                     | `puntdl inspect schema fks` |
| schema    | [odoo_models.sql](schema/odoo_models.sql) ([doc](schema/odoo_models.md)) | `puntdl inspect schema odoo-models` |
