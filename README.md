# Punt Data Lake

Data lake local sobre PostgreSQL para analisis de datos extraidos de Odoo, con capa SQL en `analytics` y utilidades Python para inspeccion/ETL.

## 1) Requisitos

- Docker Desktop (o Postgres local)
- Python 3.11+
- PowerShell (Windows)

## 2) Arranque rapido

1. Configura variables:
```powershell
Copy-Item .env.example .env
```

2. Levanta Postgres:
```powershell
docker compose up -d
```

3. Restaura dump (ejemplo):
```powershell
docker exec -i puntdl_postgres pg_restore -U postgres -d PUNT_SISTEMES_PRO /dumps/<archivo.dump>
```

4. Aplica vistas SQL:
```powershell
docker exec -i puntdl_postgres psql -U postgres -d PUNT_SISTEMES_PRO < database/sql/views/v_hu_raw.sql
docker exec -i puntdl_postgres psql -U postgres -d PUNT_SISTEMES_PRO < database/sql/views/hu_estructura.sql
```

5. Crea tablas warehouse:
```powershell
docker exec -i puntdl_postgres psql -U postgres -d PUNT_SISTEMES_PRO < database/sql/warehouse/warehouse_hu_v1.sql
```

6. Carga warehouse (full):
```powershell
python etl/hu_etl_v1.py --mode full
```

## 3) Entorno Python (estandar)

Usar siempre `.venv`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pip install -e . --no-deps
```

## 4) Comandos utiles

- Inspeccion schema:
```powershell
puntdl inspect schema tables --schema public --limit 20
```

- Calidad:
```powershell
puntdl inspect quality nulls --schema public --table project_task
```

- Perfilado texto:
```powershell
puntdl inspect profile text --schema public --table project_task --column description
```

## 5) Limpieza de estado Git local

Si aparecen miles de cambios en `.venv/` o `vendor/`:

```powershell
git rm -r --cached .venv vendor
git add .gitignore
git status
```

Esto limpia el indice Git sin borrar tus archivos locales.

