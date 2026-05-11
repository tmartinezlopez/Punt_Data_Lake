-- warehouse_hu_v1_load_incremental.sql
-- Carga incremental v1 por grupos afectados.
-- Requiere variable psql: :watermark_ts

BEGIN;

DROP TABLE IF EXISTS tmp_affected_groups;
CREATE TEMP TABLE tmp_affected_groups AS
SELECT DISTINCT s.anchor_task_id AS group_id
FROM analytics.v_hu_raw r
JOIN analytics.mv_hu_estructura s
  ON s.task_id = r.hu_id
WHERE r.write_date > CAST(:'watermark_ts' AS timestamp);

DELETE FROM analytics.wh_hu_embedding_input e
USING tmp_affected_groups g
WHERE e.group_id = g.group_id;

DELETE FROM analytics.wh_hu_node n
USING tmp_affected_groups g
WHERE n.group_id = g.group_id;

DELETE FROM analytics.wh_hu_group gg
USING tmp_affected_groups g
WHERE gg.group_id = g.group_id;

INSERT INTO analytics.wh_hu_group (
    group_id, project_id, partner_id, root_id, node_count, max_depth,
    min_create_date, max_write_date, sum_allocated_hours, sum_effective_hours,
    sum_remaining_hours, sum_total_hours_spent, avg_progress, done_nodes,
    in_progress_nodes, canceled_nodes, helpdesk_ticket_ids, sale_order_ids,
    sale_line_ids, owner_user_ids, assignee_user_ids, is_deleted, created_at, updated_at
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
    JOIN tmp_affected_groups ag
      ON ag.group_id = s.anchor_task_id
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
    node_id, group_id, parent_id, project_id, partner_id, depth, state, active, priority,
    owner_user_id, assignee_user_ids, allocated_hours, effective_hours, remaining_hours,
    total_hours_spent, progress, helpdesk_ticket_id, sale_order_id, sale_line_id, create_date,
    write_date, description_raw, description_clean, is_container, is_functional, has_feature,
    has_scenario, has_gwt, is_deleted, created_at, updated_at
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
    COALESCE(r.allocated_hours, 0)::numeric(12,2),
    COALESCE(r.effective_hours, 0)::numeric(12,2),
    COALESCE(r.remaining_hours, 0)::numeric(12,2),
    COALESCE(r.total_hours_spent, 0)::numeric(12,2),
    LEAST(GREATEST(COALESCE(r.progress, 0), -999.99), 999.99)::numeric(5,2),
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
    FALSE,
    NOW(),
    NOW()
FROM analytics.v_hu_raw r
JOIN analytics.mv_hu_estructura s
  ON s.task_id = r.hu_id
JOIN tmp_affected_groups ag
  ON ag.group_id = s.anchor_task_id;

INSERT INTO analytics.wh_hu_embedding_input (
    group_id, embedding_type, embedding_text, project_id, partner_id, embedded_at, meta, created_at, updated_at
)
WITH g AS (
    SELECT *
    FROM analytics.wh_hu_group
    WHERE is_deleted = FALSE
      AND group_id IN (SELECT group_id FROM tmp_affected_groups)
),
n AS (
    SELECT *
    FROM analytics.wh_hu_node
    WHERE is_deleted = FALSE
      AND group_id IN (SELECT group_id FROM tmp_affected_groups)
),
anchor_data AS (
    SELECT
        g.group_id, g.project_id, g.partner_id, g.root_id, g.node_count, g.max_depth,
        g.min_create_date, g.max_write_date, g.done_nodes, g.in_progress_nodes, g.canceled_nodes,
        g.sum_allocated_hours, g.sum_effective_hours, g.sum_remaining_hours, g.sum_total_hours_spent, g.avg_progress,
        a.node_id AS anchor_hu_id,
        COALESCE(a.description_clean, '') AS anchor_description
    FROM g
    LEFT JOIN n a
      ON a.group_id = g.group_id
     AND a.node_id = g.group_id
),
full_text AS (
    SELECT
        ad.group_id, ad.project_id, ad.partner_id, NOW() AS embedded_at,
        jsonb_build_object(
            'group_id', ad.group_id, 'project_id', ad.project_id, 'partner_id', ad.partner_id,
            'root_id', ad.root_id, 'node_count', ad.node_count, 'max_depth', ad.max_depth,
            'min_create_date', ad.min_create_date, 'max_write_date', ad.max_write_date, 'embedded_at', NOW()
        ) AS meta,
        LEFT(
            concat(
                '[META] group_id=', ad.group_id, ' project_id=', COALESCE(ad.project_id::text, 'N/A'),
                ' partner_id=', COALESCE(ad.partner_id::text, 'N/A'), ' root_id=', COALESCE(ad.root_id::text, 'N/A'),
                ' node_count=', ad.node_count, ' max_depth=', ad.max_depth,
                ' min_create_date=', COALESCE(ad.min_create_date::text, 'N/A'),
                ' max_write_date=', COALESCE(ad.max_write_date::text, 'N/A'),
                E'\n[WORKLOAD] allocated=', COALESCE(ad.sum_allocated_hours::text, '0'),
                ' effective=', COALESCE(ad.sum_effective_hours::text, '0'),
                ' remaining=', COALESCE(ad.sum_remaining_hours::text, '0'),
                ' spent=', COALESCE(ad.sum_total_hours_spent::text, '0'),
                ' avg_progress=', COALESCE(ad.avg_progress::text, '0'),
                E'\n[NODES]\n',
                COALESCE((
                    SELECT string_agg(
                        concat(
                            'hu_id=', n1.node_id, ' depth=', COALESCE(n1.depth::text, '0'),
                            ' state=', COALESCE(n1.state, 'N/A'), ' active=', COALESCE(n1.active::text, 'N/A'),
                            ' progress=', COALESCE(n1.progress::text, '0'), E'\n',
                            COALESCE(n1.description_clean, ''), E'\n---\n'
                        ),
                        '' ORDER BY n1.depth, n1.create_date, n1.node_id
                    )
                    FROM n n1
                    WHERE n1.group_id = ad.group_id
                ), '')
            ),
            12000
        ) AS embedding_text
    FROM anchor_data ad
),
solution_text AS (
    SELECT
        ad.group_id, ad.project_id, ad.partner_id, NOW() AS embedded_at,
        jsonb_build_object(
            'group_id', ad.group_id, 'project_id', ad.project_id, 'partner_id', ad.partner_id,
            'done_nodes', ad.done_nodes, 'in_progress_nodes', ad.in_progress_nodes, 'canceled_nodes', ad.canceled_nodes,
            'max_write_date', ad.max_write_date, 'embedded_at', NOW()
        ) AS meta,
        LEFT(
            concat(
                '[META] group_id=', ad.group_id, ' project_id=', COALESCE(ad.project_id::text, 'N/A'),
                ' partner_id=', COALESCE(ad.partner_id::text, 'N/A'),
                ' done_nodes=', ad.done_nodes, ' in_progress_nodes=', ad.in_progress_nodes,
                ' canceled_nodes=', ad.canceled_nodes, ' max_write_date=', COALESCE(ad.max_write_date::text, 'N/A'),
                E'\n[RESOLUTION]\n',
                COALESCE((
                    SELECT string_agg(
                        concat(
                            'hu_id=', n1.node_id, ' state=', COALESCE(n1.state, 'N/A'),
                            ' effective_hours=', COALESCE(n1.effective_hours::text, '0'),
                            ' write_date=', COALESCE(n1.write_date::text, 'N/A'), E'\n',
                            COALESCE(n1.description_clean, ''), E'\n---\n'
                        ),
                        '' ORDER BY (CASE WHEN n1.state = '1_done' THEN 0 ELSE 1 END), n1.write_date DESC, n1.node_id DESC
                    )
                    FROM n n1
                    WHERE n1.group_id = ad.group_id
                ), '')
            ),
            9000
        ) AS embedding_text
    FROM anchor_data ad
),
desc_text AS (
    SELECT
        ad.group_id, ad.project_id, ad.partner_id, NOW() AS embedded_at,
        jsonb_build_object(
            'group_id', ad.group_id, 'anchor_task_id', ad.group_id,
            'project_id', ad.project_id, 'partner_id', ad.partner_id,
            'anchor_hu_id', ad.anchor_hu_id,
            'description_source', CASE WHEN length(COALESCE(ad.anchor_description, '')) >= 220 THEN 'anchor_only' ELSE 'anchor_plus_children' END,
            'max_write_date', ad.max_write_date, 'embedded_at', NOW()
        ) AS meta,
        LEFT(
            concat(
                '[META] group_id=', ad.group_id, ' anchor_task_id=', ad.group_id,
                ' project_id=', COALESCE(ad.project_id::text, 'N/A'),
                ' partner_id=', COALESCE(ad.partner_id::text, 'N/A'),
                ' anchor_hu_id=', COALESCE(ad.anchor_hu_id::text, 'N/A'),
                ' description_source=', CASE WHEN length(COALESCE(ad.anchor_description, '')) >= 220 THEN 'anchor_only' ELSE 'anchor_plus_children' END,
                E'\n[ANCHOR_DESCRIPTION]\n', COALESCE(ad.anchor_description, ''),
                CASE
                    WHEN length(COALESCE(ad.anchor_description, '')) >= 220 THEN ''
                    ELSE concat(
                        E'\n[CHILD_DESCRIPTIONS]\n',
                        COALESCE((
                            SELECT string_agg(
                                concat(
                                    'hu_id=', n1.node_id, ' depth=', COALESCE(n1.depth::text, '0'), E'\n',
                                    COALESCE(n1.description_clean, ''), E'\n---\n'
                                ),
                                '' ORDER BY n1.depth, n1.create_date, n1.node_id
                            )
                            FROM n n1
                            WHERE n1.group_id = ad.group_id
                              AND n1.node_id <> ad.anchor_hu_id
                              AND COALESCE(n1.description_clean, '') <> ''
                        ), '')
                    )
                END
            ),
            7000
        ) AS embedding_text
    FROM anchor_data ad
)
SELECT group_id, 'full', embedding_text, project_id, partner_id, embedded_at, meta, NOW(), NOW() FROM full_text
UNION ALL
SELECT group_id, 'solution', embedding_text, project_id, partner_id, embedded_at, meta, NOW(), NOW() FROM solution_text
UNION ALL
SELECT group_id, 'hu_description', embedding_text, project_id, partner_id, embedded_at, meta, NOW(), NOW() FROM desc_text;

COMMIT;
