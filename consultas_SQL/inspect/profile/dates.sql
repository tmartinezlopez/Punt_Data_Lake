-- inspect/profile/dates.sql
-- Perfilado de una columna fecha/timestamp: rango, distribución por bucket y
-- recuento de NULLs.
-- Parámetros: :bucket ('day' | 'week' | 'month' | 'quarter' | 'year'),
--             :limit (int) — cantidad máxima de buckets a devolver.

WITH base AS (
    SELECT {{column}}::timestamp AS d FROM {{schema}}.{{table}}
),
summary AS (
    SELECT
        'summary'::text                    AS kind,
        NULL::timestamp                    AS bucket,
        COUNT(*)                           AS n,
        MIN(d)                             AS first,
        MAX(d)                             AS last,
        COUNT(*) FILTER (WHERE d IS NULL)  AS n_null
    FROM base
),
buckets AS (
    SELECT
        'bucket'::text                            AS kind,
        date_trunc(:bucket, d)                    AS bucket,
        COUNT(*)                                  AS n,
        NULL::timestamp                           AS first,
        NULL::timestamp                           AS last,
        NULL::bigint                              AS n_null
    FROM base
    WHERE d IS NOT NULL
    GROUP BY date_trunc(:bucket, d)
)
SELECT kind, bucket, n, first, last, n_null
FROM (
    SELECT 0 AS sort_key, summary.* FROM summary
    UNION ALL
    SELECT 1, b.*
    FROM (
        SELECT * FROM buckets
        ORDER BY bucket DESC
        LIMIT :limit
    ) b
) u
ORDER BY sort_key, bucket DESC NULLS LAST;
