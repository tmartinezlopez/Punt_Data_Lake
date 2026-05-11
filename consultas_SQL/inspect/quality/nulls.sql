-- inspect/quality/nulls.sql
-- Recuento EXACTO de NULLs por columna en una tabla. El placeholder
-- "col_aggregates" se genera dinámicamente en Python: una lista de
-- expresiones `count(*) FILTER (WHERE "col" IS NULL) AS "col"` por cada
-- columna almacenada. Se devuelve una fila por columna mediante UNPIVOT vía
-- jsonb_each (de modo que la SQL final es siempre del mismo tamaño).
-- Parámetros: :threshold (float).

WITH counts AS (
    SELECT COUNT(*) AS n_total,
           {{col_aggregates}}
    FROM {{schema}}.{{table}}
)
SELECT
    j.key                                     AS column,
    (j.value)::bigint                         AS n_null,
    counts.n_total                            AS n_total,
    (j.value::bigint)::float
        / NULLIF(counts.n_total, 0)::float    AS null_frac
FROM counts,
     LATERAL jsonb_each(
        to_jsonb(counts) - 'n_total'
     ) j
WHERE (j.value::bigint)::float
        / NULLIF(counts.n_total, 0)::float >= :threshold
ORDER BY null_frac DESC, j.key;
