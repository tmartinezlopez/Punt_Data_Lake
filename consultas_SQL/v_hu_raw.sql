-- v_hu_raw.sql
-- Vista cruda de Historias de Usuario (backend-first, sin campos name)

CREATE SCHEMA IF NOT EXISTS analytics;

DROP VIEW IF EXISTS analytics.v_hu_raw;

CREATE VIEW analytics.v_hu_raw AS
WITH assignees AS (
    SELECT
        r.task_id,
        array_agg(r.user_id ORDER BY r.user_id) AS assignee_user_ids
    FROM project_task_user_rel r
    GROUP BY r.task_id
)
SELECT
    t.id AS hu_id,
    t.parent_id AS hu_parent_id,
    t.project_id,
    t.pnt_main_owner_id AS owner_user_id,
    a.assignee_user_ids,
    t.description AS description_raw,
    t.allocated_hours,
    t.effective_hours,
    t.remaining_hours,
    t.total_hours_spent,
    t.progress,
    t.state,
    t.stage_id,
    t.priority,
    t.active,
    t.date_assign,
    t.date_deadline,
    t.date_end,
    t.create_date,
    t.write_date,
    t.company_id,
    t.partner_id,
    t.helpdesk_ticket_id,
    t.sale_order_id,
    t.sale_line_id
FROM project_task t
LEFT JOIN assignees a ON a.task_id = t.id
WHERE t.create_date::date >= DATE '2024-10-02';
