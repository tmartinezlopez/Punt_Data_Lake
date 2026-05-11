# hu_estructura.sql (PRO)

## Objetivo
Construir y persistir la estructura jerárquica de HUs/subhistorias con un `anchor_task_id` funcional por árbol, optimizada para uso productivo en análisis y reporting.

## Diseño de rendimiento
La versión PRO separa en dos capas:
1. `analytics.v_hu_estructura_base` (ligera):
   - Construye jerarquía recursiva.
   - Calcula `child_count`.
   - Determina `anchor_task_id` con heurística ligera.
2. `analytics.mv_hu_estructura` (materializada):
   - Limpia texto de descripción.
   - Calcula banderas funcionales (`has_feature`, `has_scenario`, `has_gwt`).
   - Clasifica `is_container` e `is_functional`.

Esto evita recalcular regex pesadas y recursividad completa en cada consulta interactiva.

## Alcance temporal activo
- La vista está limitada a HUs con `create_date::date >= '2024-10-02'`.
- Motivo: reducir coste/volumen y centrarse en el periodo donde aparece el patrón Gherkin acordado.

## Objetos creados
- `analytics.v_hu_estructura_base`
- `analytics.mv_hu_estructura`
- Índices:
  - `public.project_task(parent_id)`
  - `analytics.mv_hu_estructura(root_id)`
  - `analytics.mv_hu_estructura(anchor_task_id)`
  - `analytics.mv_hu_estructura(task_id)`
  - `analytics.mv_hu_estructura(depth)`

## Reglas de anchor
Por cada `root_id`, el anchor es el primer nodo (menor profundidad) que:
- no es un nombre contenedor típico (`desarrollo`, `consultoría odoo`, `backlog`, etc.), y
- tiene señal funcional mínima (descripción limpia >= 80) o es hoja (`child_count = 0`).

Si no hay candidato, fallback al `root_id`.

## Salida principal (`analytics.mv_hu_estructura`)
- Jerarquía: `root_id`, `task_id`, `parent_id`, `depth`
- Agrupación funcional: `anchor_task_id`, `anchor_depth`
- Metadatos tarea: `name`, `state`, `active`, fechas, `child_count`
- Señales de contenido: `desc_len`, `has_feature`, `has_scenario`, `has_gwt`
- Clasificación: `is_container`, `is_functional`

## Operación
1. Ejecutar el script completo una vez.
2. Refrescar cuando cambie `project_task`:
```sql
REFRESH MATERIALIZED VIEW analytics.mv_hu_estructura;
```
3. Consultar:
```sql
SELECT *
FROM analytics.mv_hu_estructura
ORDER BY root_id, depth, task_id;
```

## Nota
Esta versión está pensada para producción. Si se requiere mayor precisión funcional, se ajustan únicamente las heurísticas de `is_container`/`is_functional`, sin cambiar la arquitectura.
