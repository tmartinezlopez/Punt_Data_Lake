# inspect/profile/text

## Objetivo
Caracterizar la **calidad** de un campo textual: longitudes, vacíos, HTML inerte y heurísticas Gherkin (Feature/Scenario/GWT) heredadas de `hu_estructura.sql`. Pensado para `project_task.description` y similares.

## Alcance
- Una sola columna textual (cast a `text` antes de procesar).
- Stripping de HTML básico: etiquetas y entidades `&nbsp;`/`&#160;`. No es un parser HTML completo.

## Objetos creados
Ninguno.

## Parámetros
| Nombre  | Tipo  | Default | Descripción |
|---------|-------|---------|-------------|
| `{{schema}}`, `{{table}}`, `{{column}}` | ident | — | Identificadores citados. |

## Columnas / Salida
Una sola fila resumen:
- `n_total`, `n_null`, `n_empty`, `n_html_only`.
- `n_has_feature`, `n_has_scenario`, `n_has_gwt` — contadores de heurísticas.
- `plain_len_min/avg/p50/p95/max` — distribución de longitud tras strip HTML.

## Operación
```bash
puntdl inspect profile text --table project_task --column description
```

## Notas
- Las heurísticas Feature/Scenario/GWT replican las usadas para el flag `is_functional` en `mv_hu_estructura`. Esta herramienta da una vista *agregada* del corpus; para investigar fila a fila usar consultas ad-hoc contra la materializada.
- `n_html_only` mide registros con marcado pero sin contenido textual real (ruido típico tras pegar desde Word/Outlook).
