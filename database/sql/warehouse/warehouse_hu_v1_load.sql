-- warehouse_hu_v1_load.sql
-- Carga FULL v1 desde vistas HU hacia warehouse.

BEGIN;

TRUNCATE TABLE analytics.wh_hu_embedding_input, analytics.wh_hu_node, analytics.wh_hu_group;

INSERT INTO analytics.wh_hu_group (
    group_id,
    project_id,
    partner_id,
    root_id,
    node_count,
    max_depth,
    min_create_date,
    max_write_date,
    sum_allocated_hours,
    sum_effective_hours,
    sum_remaining_hours,
    sum_total_hours_spent,
    avg_progress,
    done_nodes,
    in_progress_nodes,
    canceled_nodes,
    helpdesk_ticket_ids,
    sale_order_ids,
    sale_line_ids,
    owner_user_ids,
    assignee_user_ids,
    is_deleted,
    created_at,
    updated_at
)
WITH base AS (
    SELECT
        r.hu_id,
        r.hu_parent_id,
        r.project_id,
        r.owner_user_id,
        r.assignee_user_ids,
        r.allocated_hours,
        r.effective_hours,
        r.remaining_hours,
        r.total_hours_spent,
        r.progress,
        r.state,
        r.create_date,
        r.write_date,
        r.partner_id,
        r.helpdesk_ticket_id,
        r.sale_order_id,
        r.sale_line_id,
        s.anchor_task_id AS group_id,
        s.root_id,
        s.depth
    FROM analytics.v_hu_raw r
    JOIN analytics.mv_hu_estructura s
      ON s.task_id = r.hu_id
),
partner_rollup AS (
    SELECT
        b.group_id,
        COALESCE(
            MAX(CASE WHEN b.hu_id = b.group_id THEN b.partner_id END),
            (
                SELECT b2.partner_id
                FROM base b2
                WHERE b2.group_id = b.group_id
                  AND b2.partner_id IS NOT NULL
                GROUP BY b2.partner_id
                ORDER BY COUNT(*) DESC, b2.partner_id
                LIMIT 1
            )
        ) AS partner_id
    FROM base b
    GROUP BY b.group_id
)
SELECT
    b.group_id,
    MIN(b.project_id) FILTER (WHERE b.project_id IS NOT NULL) AS project_id,
    pr.partner_id,
    MIN(b.root_id) FILTER (WHERE b.root_id IS NOT NULL) AS root_id,
    COUNT(*)::int AS node_count,
    MAX(COALESCE(b.depth, 0))::int AS max_depth,
    MIN(b.create_date) AS min_create_date,
    MAX(b.write_date) AS max_write_date,
    COALESCE(SUM(b.allocated_hours), 0)::numeric(12,2) AS sum_allocated_hours,
    COALESCE(SUM(b.effective_hours), 0)::numeric(12,2) AS sum_effective_hours,
    COALESCE(SUM(b.remaining_hours), 0)::numeric(12,2) AS sum_remaining_hours,
    COALESCE(SUM(b.total_hours_spent), 0)::numeric(12,2) AS sum_total_hours_spent,
    LEAST(GREATEST(COALESCE(AVG(b.progress), 0), -999.99), 999.99)::numeric(5,2) AS avg_progress,
    COUNT(*) FILTER (WHERE b.state = '1_done')::int AS done_nodes,
    COUNT(*) FILTER (WHERE b.state = '01_in_progress')::int AS in_progress_nodes,
    COUNT(*) FILTER (WHERE b.state = '1_canceled')::int AS canceled_nodes,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT b.helpdesk_ticket_id), NULL)::bigint[] AS helpdesk_ticket_ids,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT b.sale_order_id), NULL)::bigint[] AS sale_order_ids,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT b.sale_line_id), NULL)::bigint[] AS sale_line_ids,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT b.owner_user_id), NULL)::bigint[] AS owner_user_ids,
    ARRAY(
        SELECT DISTINCT x
        FROM base b2
        CROSS JOIN LATERAL unnest(COALESCE(b2.assignee_user_ids, ARRAY[]::bigint[])) AS x
        WHERE b2.group_id = b.group_id
          AND x IS NOT NULL
        ORDER BY x
    )::bigint[] AS assignee_user_ids,
    FALSE AS is_deleted,
    NOW() AS created_at,
    NOW() AS updated_at
FROM base b
JOIN partner_rollup pr ON pr.group_id = b.group_id
GROUP BY b.group_id, pr.partner_id;

INSERT INTO analytics.wh_hu_node (
    node_id,
    group_id,
    parent_id,
    project_id,
    partner_id,
    depth,
    state,
    active,
    priority,
    owner_user_id,
    assignee_user_ids,
    allocated_hours,
    effective_hours,
    remaining_hours,
    total_hours_spent,
    progress,
    helpdesk_ticket_id,
    sale_order_id,
    sale_line_id,
    create_date,
    write_date,
    description_raw,
    description_clean,
    is_container,
    is_functional,
    has_feature,
    has_scenario,
    has_gwt,
    is_deleted,
    created_at,
    updated_at
)
SELECT
    r.hu_id AS node_id,
    s.anchor_task_id AS group_id,
    r.hu_parent_id AS parent_id,
    r.project_id,
    r.partner_id,
    s.depth,
    r.state,
    r.active,
    r.priority,
    r.owner_user_id,
    r.assignee_user_ids,
    COALESCE(r.allocated_hours, 0)::numeric(12,2) AS allocated_hours,
    COALESCE(r.effective_hours, 0)::numeric(12,2) AS effective_hours,
    COALESCE(r.remaining_hours, 0)::numeric(12,2) AS remaining_hours,
    COALESCE(r.total_hours_spent, 0)::numeric(12,2) AS total_hours_spent,
    LEAST(GREATEST(COALESCE(r.progress, 0), -999.99), 999.99)::numeric(5,2) AS progress,
    r.helpdesk_ticket_id,
    r.sale_order_id,
    r.sale_line_id,
    r.create_date,
    r.write_date,
    r.description_raw,
    btrim(regexp_replace(COALESCE(r.description_raw, ''), '<[^>]+>', ' ', 'g')) AS description_clean,
    s.is_container,
    s.is_functional,
    s.has_feature,
    s.has_scenario,
    s.has_gwt,
    FALSE AS is_deleted,
    NOW() AS created_at,
    NOW() AS updated_at
FROM analytics.v_hu_raw r
JOIN analytics.mv_hu_estructura s
  ON s.task_id = r.hu_id;

COMMIT;
