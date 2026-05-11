-- inspect/profile/column.sql
-- Perfilado genérico de una columna: cardinalidad, NULLs y top-N de valores.
-- Devuelve `:top_n + 1` filas: la primera con el resumen (kind = 'summary')
-- y el resto con el top-N de valores (kind = 'top').
-- Parámetros: :top_n (int).

WITH base AS (
    SELECT {{column}} AS v FROM {{schema}}.{{table}}
),
summary AS (
    SELECT
        'summary'::text          AS kind,
        NULL::text               AS value,
        COUNT(*)                 AS n,
        NULL::numeric            AS pct,
        COUNT(*) FILTER (WHERE v IS NULL)        AS n_null,
        COUNT(DISTINCT v)                        AS n_distinct
    FROM base
),
tot AS (SELECT COUNT(*)::numeric AS n FROM base),
top AS (
    SELECT
        'top'::text                              AS kind,
        v::text                                  AS value,
        COUNT(*)                                 AS n,
        round(COUNT(*)::numeric / NULLIF((SELECT n FROM tot), 0) * 100, 2) AS pct,
        NULL::bigint                             AS n_null,
        NULL::bigint                             AS n_distinct
    FROM base
    WHERE v IS NOT NULL
    GROUP BY v
    ORDER BY COUNT(*) DESC
    LIMIT :top_n
)
SELECT kind, value, n, pct, n_null, n_distinct
FROM (
    SELECT 0 AS sort_key, summary.* FROM summary
    UNION ALL
    SELECT 1, top.*         FROM top
) u
ORDER BY sort_key, n DESC NULLS LAST;
