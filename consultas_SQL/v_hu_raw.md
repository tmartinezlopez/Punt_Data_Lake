# v_hu_raw.sql

## Objetivo
Exponer una vista **cruda** de Historias de Usuario orientada a backend, sin enriquecimiento semántico y sin campos descriptivos tipo `name`.

## Alcance
- Fuente principal: `public.project_task`
- Asignaciones: `project_task_user_rel` (agregado en array de IDs)
- Sin joins de nombres ni traducciones
- Sin limpieza de texto (se mantiene `description_raw`)
- Filtro temporal activo: `create_date::date >= '2024-10-02'`

## Vista creada
- `analytics.v_hu_raw`

## Columnas
- Jerarquía y contexto: `hu_id`, `hu_parent_id`, `project_id`
- Responsables: `owner_user_id`, `assignee_user_ids`
- Contenido crudo: `description_raw`
- Esfuerzo y avance: `allocated_hours`, `effective_hours`, `remaining_hours`, `total_hours_spent`, `progress`
- Estado operativo: `state`, `stage_id`, `priority`, `active`
- Fechas: `date_assign`, `date_deadline`, `date_end`, `create_date`, `write_date`
- Trazabilidad comercial/ticket: `company_id`, `partner_id`, `helpdesk_ticket_id`, `sale_order_id`, `sale_line_id`

## Notas
- Diseñada para extracción, analítica y pipelines backend.
- Si más adelante se necesitan nombres, se recomienda resolverlos en una capa de presentación separada.
