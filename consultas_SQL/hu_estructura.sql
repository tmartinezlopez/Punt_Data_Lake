-- hu_estructura.sql (PRO)

CREATE INDEX IF NOT EXISTS idx_project_task_parent_id ON public.project_task(parent_id);

DROP VIEW IF EXISTS analytics.v_hu_estructura_base CASCADE;
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_hu_estructura;

CREATE OR REPLACE VIEW analytics.v_hu_estructura_base AS
WITH RECURSIVE base AS (
    SELECT
        t.id,
        t.parent_id,
        t.name,
        t.state,
        t.active,
        t.create_date,
        t.write_date,
        t.description
    FROM public.project_task t
    WHERE t.create_date >= TIMESTAMP '2024-10-02 00:00:00'
),
roots AS (
    SELECT
        b.id AS root_id,
        (b.parent_id IS NOT NULL AND p.id IS NULL) AS is_synthetic_root
    FROM base b
    LEFT JOIN base p ON p.id = b.parent_id
    WHERE b.parent_id IS NULL OR p.id IS NULL
),
tree AS (
    SELECT
        r.root_id,
        r.root_id AS id,
        0 AS depth,
        ARRAY[r.root_id]::int[] AS path
    FROM roots r
    UNION ALL
    SELECT
        tr.root_id,
        c.id,
        tr.depth + 1,
        tr.path || c.id
    FROM tree tr
    JOIN base c ON c.parent_id = tr.id
    WHERE c.id <> ALL(tr.path)
),
children_count AS (
    SELECT b.parent_id AS id, COUNT(*)::int AS child_count
    FROM base b
    WHERE b.parent_id IS NOT NULL
    GROUP BY b.parent_id
),
nodes AS (
    SELECT
        tr.root_id,
        tr.id AS task_id,
        tr.depth,
        b.parent_id,
        b.name,
        b.state,
        b.active,
        b.create_date,
        b.write_date,
        b.description,
        COALESCE(cc.child_count, 0) AS child_count
    FROM tree tr
    JOIN base b ON b.id = tr.id
    LEFT JOIN children_count cc ON cc.id = tr.id
),
anchor_per_root AS (
    SELECT DISTINCT ON (n.root_id)
        n.root_id,
        n.task_id AS anchor_task_id,
        n.depth AS anchor_depth
    FROM nodes n
    WHERE
        lower(trim(coalesce(n.name, ''))) NOT IN ('desarrollo', 'consultoria odoo', 'consultoría odoo', 'tareas', 'tarea', 'backlog', 'general')
        AND (
            length(trim(regexp_replace(COALESCE(n.description, ''), '<[^>]+>', ' ', 'g'))) >= 80
            OR n.child_count = 0
        )
    ORDER BY n.root_id, n.depth ASC, n.task_id ASC
),
anchor_final AS (
    SELECT
        r.root_id,
        r.is_synthetic_root,
        COALESCE(a.anchor_task_id, r.root_id) AS anchor_task_id,
        COALESCE(a.anchor_depth, 0) AS anchor_depth
    FROM roots r
    LEFT JOIN anchor_per_root a ON a.root_id = r.root_id
)
SELECT
    n.root_id,
    af.is_synthetic_root,
    af.anchor_task_id,
    af.anchor_depth,
    n.task_id,
    n.parent_id,
    n.depth,
    n.name,
    n.state,
    n.active,
    n.create_date,
    n.write_date,
    n.child_count,
    n.description
FROM nodes n
JOIN anchor_final af ON af.root_id = n.root_id;

CREATE MATERIALIZED VIEW analytics.mv_hu_estructura AS
WITH enriched AS (
    SELECT
        b.root_id,
        b.is_synthetic_root,
        b.anchor_task_id,
        b.anchor_depth,
        b.task_id,
        b.parent_id,
        b.depth,
        b.name,
        b.state,
        b.active,
        b.create_date,
        b.write_date,
        b.child_count,
        regexp_replace(
            regexp_replace(COALESCE(b.description, ''), '<[^>]+>', ' ', 'g'),
            '&nbsp;|&#160;',
            ' ',
            'gi'
        ) AS desc_txt
    FROM analytics.v_hu_estructura_base b
),
flags AS (
    SELECT
        e.*,
        length(trim(COALESCE(e.desc_txt, ''))) AS desc_len,
        (e.desc_txt ~* 'feature\\s*:') AS has_feature,
        (e.desc_txt ~* 'scenario\\s*:') AS has_scenario,
        (
            (e.desc_txt ~* '\\bgiven\\b' AND e.desc_txt ~* '\\bwhen\\b' AND e.desc_txt ~* '\\bthen\\b')
            OR
            (e.desc_txt ~* '\\bdado\\b' AND e.desc_txt ~* '\\bcuando\\b' AND e.desc_txt ~* '\\bentonces\\b')
        ) AS has_gwt
    FROM enriched e
)
SELECT
    e.root_id,
    e.is_synthetic_root,
    e.anchor_task_id,
    e.anchor_depth,
    e.task_id,
    e.parent_id,
    e.depth,
    e.name,
    e.state,
    e.active,
    e.create_date,
    e.write_date,
    e.child_count,
    e.desc_len,
    e.has_feature,
    e.has_scenario,
    e.has_gwt,
    (
        lower(trim(coalesce(e.name, ''))) IN ('desarrollo', 'consultoria odoo', 'consultoría odoo', 'tareas', 'tarea', 'backlog', 'general')
        OR
        (e.desc_len < 80 AND e.child_count >= 5)
    ) AS is_container,
    (
        NOT (
            lower(trim(coalesce(e.name, ''))) IN ('desarrollo', 'consultoria odoo', 'consultoría odoo', 'tareas', 'tarea', 'backlog', 'general')
            OR (e.desc_len < 80 AND e.child_count >= 5)
        )
        AND (
            e.has_feature
            OR e.has_scenario
            OR e.has_gwt
            OR e.desc_len >= 180
            OR (
                lower(trim(coalesce(e.name, ''))) NOT IN ('desarrollo', 'consultoria odoo', 'consultoría odoo', 'tareas', 'tarea', 'backlog', 'general')
                AND e.desc_len >= 80
            )
        )
    ) AS is_functional
FROM flags e;

CREATE INDEX IF NOT EXISTS idx_mv_hu_estructura_root_id ON analytics.mv_hu_estructura(root_id);
CREATE INDEX IF NOT EXISTS idx_mv_hu_estructura_anchor_task_id ON analytics.mv_hu_estructura(anchor_task_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_hu_estructura_task_id_uq ON analytics.mv_hu_estructura(task_id);
CREATE INDEX IF NOT EXISTS idx_mv_hu_estructura_depth ON analytics.mv_hu_estructura(depth);
ANALYZE analytics.mv_hu_estructura;
