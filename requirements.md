# requirements.txt — Documentación

## Objetivo
Lockfile con las versiones **exactas** de dependencias Python resueltas en el `.venv` del proyecto, para que cualquier máquina pueda reproducir el entorno sin sorpresas de resolución. La fuente de verdad de los **rangos** sigue siendo `pyproject.toml`; `requirements.txt` es la foto fija de un instante.

## Alcance
- Cubre el toolkit `puntdl-inspect` (CLI Python que consume los `.sql` de `consultas_SQL/inspect/`).
- No incluye herramientas de desarrollo (linters, pytest, etc.) — se añadirán a un `requirements-dev.txt` separado cuando aparezcan.

## Cómo se genera
Desde el `.venv` activado y con el paquete instalado:

```bash
python -m venv .venv               # solo la primera vez (regla 5 CLAUDE.md)
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
pip freeze --exclude-editable > requirements.txt
```

`--exclude-editable` evita que `puntdl-inspect` aparezca en el lockfile (es el propio proyecto, no una dependencia externa).

## Cómo se instala en otra máquina

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -e . --no-deps         # registra el entrypoint `puntdl` sin tocar versiones
```

## Cuándo actualizarlo
- Al añadir/quitar una dependencia en `pyproject.toml`.
- Al subir un mínimo de versión que cambie la resolución (`>=` mayor en pyproject).
- Al adoptar un parche de seguridad publicado para alguna dependencia.

En cada actualización: regenerar con `pip freeze --exclude-editable`, verificar el diff y hacer commit del par `pyproject.toml` + `requirements.txt`.

## Inventario actual

### Top-level (declaradas en `pyproject.toml`)
| Paquete            | Versión   | Rol |
|--------------------|-----------|-----|
| typer              | 0.25.1    | Framework de la CLI (`puntdl ...`). |
| SQLAlchemy         | 2.0.49    | Engine + ejecución de SQL parametrizado. |
| psycopg            | 3.3.4     | Driver Postgres v3 (capa Python). |
| psycopg-binary     | 3.3.4     | Wheel binaria de psycopg (evita compilación local). |
| pandas             | 3.0.2     | Materialización de resultados y `to_markdown`/`to_csv`. |
| rich               | 15.0.0    | Tablas y color en terminal. |
| python-dotenv      | 1.2.2     | Carga de `.env` (credenciales Postgres). |
| tabulate           | 0.10.0    | Backend de `DataFrame.to_markdown`. |

### Transitivas (resueltas por pip)
`annotated-doc`, `click`, `greenlet`, `markdown-it-py`, `mdurl`, `numpy`, `Pygments`, `python-dateutil`, `shellingham`, `six`, `typing_extensions`.

No fijamos rangos manualmente para transitivas: las hereda pip a partir de los top-level.

## Notas
- Si en CI hace falta acelerar instalación, se puede sustituir `pip` por `uv pip install -r requirements.txt`; el formato del lockfile sigue siendo válido.
- `psycopg-binary` no debe usarse en producción de larga vida (recomendación oficial), pero es perfecto para esta CLI local de inspección y para CI.
