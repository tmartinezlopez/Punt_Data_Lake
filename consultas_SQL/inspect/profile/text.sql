-- inspect/profile/text.sql
-- Perfilado de calidad de campo textual: longitudes, vacíos, presencia de
-- HTML y heurísticas estilo Gherkin (Feature/Scenario/GWT) heredadas de
-- consultas_SQL/hu_estructura.sql.
-- Aplica solo a una columna; útil para `project_task.description`, notas,
-- comentarios, etc.

WITH base AS (
    SELECT
        {{column}}::text AS raw,
        -- Texto plano: quitar etiquetas y entidades comunes.
        regexp_replace(
            regexp_replace(COALESCE({{column}}::text, ''), '<[^>]+>', ' ', 'g'),
            '&nbsp;|&#160;', ' ', 'gi'
        ) AS plain
    FROM {{schema}}.{{table}}
),
flagged AS (
    SELECT
        raw,
        plain,
        length(trim(plain))                                 AS plain_len,
        length(COALESCE(raw, ''))                           AS raw_len,
        (raw IS NULL)                                       AS is_null,
        (length(trim(COALESCE(raw, ''))) = 0)               AS is_empty,
        -- HTML-only: raw no vacío, pero al strippear no queda nada.
        (length(COALESCE(raw, '')) > 0 AND length(trim(plain)) = 0) AS is_html_only,
        (plain ~* 'feature\s*:')                            AS has_feature,
        (plain ~* 'scenario\s*:')                           AS has_scenario,
        (
            (plain ~* '\ygiven\y' AND plain ~* '\ywhen\y' AND plain ~* '\ythen\y')
            OR
            (plain ~* '\ydado\y' AND plain ~* '\ycuando\y' AND plain ~* '\yentonces\y')
        ) AS has_gwt
    FROM base
)
SELECT
    COUNT(*)                                                 AS n_total,
    SUM((is_null)::int)                                      AS n_null,
    SUM((is_empty AND NOT is_null)::int)                     AS n_empty,
    SUM(is_html_only::int)                                   AS n_html_only,
    SUM(has_feature::int)                                    AS n_has_feature,
    SUM(has_scenario::int)                                   AS n_has_scenario,
    SUM(has_gwt::int)                                        AS n_has_gwt,
    MIN(plain_len)                                           AS plain_len_min,
    round(AVG(plain_len)::numeric, 2)                        AS plain_len_avg,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY plain_len)  AS plain_len_p50,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY plain_len)  AS plain_len_p95,
    MAX(plain_len)                                           AS plain_len_max
FROM flagged;
