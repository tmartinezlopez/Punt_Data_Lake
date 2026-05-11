-- inspect/quality/orphans.sql
-- Muestrea filas de {{schema}}.{{table}} cuyo valor de {{column}} no existe en
-- {{ref_schema}}.{{ref_table}}.{{ref_column}}.
-- Cada fila incluye `n_orphans_total` (mismo valor en todas las filas, vía
-- window function): conteo global de huérfanos. Si el resultado está vacío
-- no hay huérfanos.
-- Parámetros: :sample (int) — máximo de filas de muestra a devolver.

SELECT
    t.{{column}}                       AS bad_value,
    COUNT(*) OVER ()                   AS n_orphans_total,
    to_jsonb(t.*)                      AS row_data
FROM {{schema}}.{{table}} t
LEFT JOIN {{ref_schema}}.{{ref_table}} r
       ON r.{{ref_column}} = t.{{column}}
WHERE t.{{column}} IS NOT NULL
  AND r.{{ref_column}} IS NULL
ORDER BY t.{{column}}
LIMIT :sample;
