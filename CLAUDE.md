# Punt Data Lake

Data lake local sobre Postgres 16 (Docker) para análisis de datos extraídos de Odoo. Incluye vistas SQL en el esquema `analytics` sobre las tablas crudas de Odoo en `public`, y (previsto) una capa Python de análisis/extracción sobre esas vistas.

## Stack técnico

- **Almacenamiento**: PostgreSQL 16 en Docker (`docker-compose.yml`).
- **Modelado**: SQL puro — vistas y materializadas en el esquema `analytics`.
- **Análisis / pipelines (previsto)**: Python con `pandas` para manipulación y `SQLAlchemy` (+ `psycopg[binary]`) para conexión a Postgres. Aún no hay código Python en el repo; cuando se añada irá en una carpeta dedicada (ej. `src/` o `notebooks/`) con su `pyproject.toml`/`requirements.txt`.

## Estructura

- `docker-compose.yml` — Postgres 16 con dumps montados en `/dumps:ro`.
- `.env.example` — variables (`POSTGRES_USER/PASSWORD/DB/PORT`). Copiar a `.env`.
- `bbdd/dumps/` — dumps de Odoo (ignorados por git).
- `consultas_SQL/` — scripts SQL de vistas analíticas:
  - `hu_estructura.sql` — vista base + materializada `analytics.mv_hu_estructura` (jerarquía de HUs con `anchor_task_id`).
  - `v_hu_raw.sql` — vista cruda `analytics.v_hu_raw` orientada a backend, sin enriquecimiento.
- `doc/` — documentación de las vistas y decisiones de modelado:
  - `hu_estructura.md`, `v_hu_raw.md` — documentación por vista (hermana del `.sql`).
  - `HU_v1_decisiones.md` — decisiones de diseño del modelo HU v1.
  - `README_SQL_HU.md` — índice / guía de la capa SQL HU.

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

1. **Documentar toda vista SQL nueva.** Cada `.sql` en `consultas_SQL/` debe ir acompañado de un `.md` con el mismo nombre en `doc/`, con secciones: *Objetivo*, *Alcance*, *Objetos creados*, *Columnas/Salida*, *Operación* y *Notas*. Usar `doc/hu_estructura.md` y `doc/v_hu_raw.md` como plantilla.
2. **Revisar SQL antes de aplicarlo.** No ejecutar `CREATE`, `DROP`, `ALTER`, `REFRESH MATERIALIZED VIEW`, ni cargas/restauraciones contra la BBDD sin mostrar antes el SQL y pedir confirmación explícita. Las consultas `SELECT` de inspección sí pueden ejecutarse directamente.
3. **No tocar dumps ni `.env`.** No modificar, mover ni borrar archivos en `bbdd/dumps/`. No editar `.env` (es local de cada máquina); los cambios de variables van siempre en `.env.example`.
4. **Python (cuando se introduzca).** Mantener `pandas` + `SQLAlchemy` como base. Conexión a Postgres leyendo de `.env` (no hardcodear credenciales). Consultas pesadas se resuelven en SQL/vista; Python sólo transforma o presenta.

