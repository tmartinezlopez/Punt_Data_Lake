# Punt Data Lake

Data lake local sobre Postgres 16 (Docker) para análisis de datos extraídos de Odoo. Incluye vistas SQL en el esquema `analytics` sobre las tablas crudas de Odoo en `public`, y (previsto) una capa Python de análisis/extracción sobre esas vistas.

> Este archivo sigue la convención [AGENTS.md](https://agents.md/) y aplica a cualquier agente de codificación (Codex, Cursor, etc.). Su contenido se mantiene sincronizado con `CLAUDE.md` (mismo proyecto, distintas herramientas).

## Stack técnico

- **Almacenamiento**: PostgreSQL 16 en Docker (`docker-compose.yml`).
- **Modelado**: SQL puro — vistas y materializadas en el esquema `analytics`.
- **Análisis / pipelines (previsto)**: Python con `pandas` para manipulación y `SQLAlchemy` (+ `psycopg[binary]`) para conexión a Postgres. Aún no hay código Python en el repo; cuando se añada irá en una carpeta dedicada (ej. `src/` o `notebooks/`) con su `pyproject.toml`/`requirements.txt`.

## Estructura

- `docker-compose.yml` — Postgres 16 con dumps montados en `/dumps:ro`.
- `.env.example` — variables (`POSTGRES_USER/PASSWORD/DB/PORT`). Copiar a `.env`.
- `bbdd/dumps/` — dumps de Odoo (ignorados por git).
- `consultas_SQL/` — scripts y documentación de vistas analíticas:
  - `hu_estructura.sql` / `.md` — vista base + materializada `analytics.mv_hu_estructura` (jerarquía de HUs con `anchor_task_id`).
  - `v_hu_raw.sql` / `.md` — vista cruda `analytics.v_hu_raw` orientada a backend, sin enriquecimiento.

## Operación

```bash
cp .env.example .env
docker compose up -d
# restaurar dump:
docker exec -i puntdl_postgres pg_restore -U punt -d puntdl /dumps/<archivo>
# aplicar vistas:
docker exec -i puntdl_postgres psql -U punt -d puntdl < consultas_SQL/hu_estructura.sql
```

Refrescar materializada tras cambios en `project_task`:
```sql
REFRESH MATERIALIZED VIEW analytics.mv_hu_estructura;
```

## Convenciones

- Esquema crudo de Odoo: `public`. Esquema analítico: `analytics`.
- Filtro temporal estándar en vistas HU: `create_date::date >= '2024-10-02'`.
- Cambios en heurísticas funcionales (`is_container`, `is_functional`, anchor) se ajustan dentro del SQL sin alterar arquitectura.

## Reglas de trabajo para el agente

1. **Documentar toda vista SQL nueva.** Cada `.sql` en `consultas_SQL/` debe ir acompañado de un `.md` con el mismo nombre y secciones: *Objetivo*, *Alcance*, *Objetos creados*, *Columnas/Salida*, *Operación* y *Notas*. Usar `hu_estructura.md` y `v_hu_raw.md` como plantilla.
2. **Revisar SQL antes de aplicarlo.** No ejecutar `CREATE`, `DROP`, `ALTER`, `REFRESH MATERIALIZED VIEW`, ni cargas/restauraciones contra la BBDD sin mostrar antes el SQL y pedir confirmación explícita. Las consultas `SELECT` de inspección sí pueden ejecutarse directamente.
3. **No tocar dumps ni `.env`.** No modificar, mover ni borrar archivos en `bbdd/dumps/`. No editar `.env` (es local de cada máquina); los cambios de variables van siempre en `.env.example`.
4. **Python (cuando se introduzca).** Mantener `pandas` + `SQLAlchemy` como base. Conexión a Postgres leyendo de `.env` (no hardcodear credenciales). Consultas pesadas se resuelven en SQL/vista; Python sólo transforma o presenta.
5. **Siempre venv antes de instalar dependencias.** Cualquier `pip install` debe ejecutarse dentro de un entorno virtual del proyecto (`python -m venv .venv && source .venv/bin/activate`). Prohibido instalar contra el intérprete del sistema o con `sudo pip`. El `.venv/` va ignorado por git. Esta regla aplica también a `pip install -e .`, `pip-tools`, `uv pip`, etc.
6. **Mantener `requirements.txt` sincronizado.** Tras cualquier cambio en `pyproject.toml` o actualización de versiones, regenerar con `pip freeze --exclude-editable > requirements.txt` y revisar el diff junto al `pyproject.toml` en el mismo commit. La documentación operativa del lockfile vive en `requirements.md`.
