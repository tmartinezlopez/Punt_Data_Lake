-- inspect/quality/duplicates.sql
-- Detecta combinaciones de {{by_cols}} con >= :min_count ocurrencias en
-- {{schema}}.{{table}}. El placeholder {{by_cols}} se construye en Python con
-- `join_identifiers` y se proyecta tal cual; cada columna sale como columna
-- propia en la salida.
-- Parámetros: :min_count (int, default 2), :limit (int).

SELECT
    {{by_cols}},
    COUNT(*)                          AS n,
    (array_agg(ctid::text))[1:5]      AS ctids_sample
FROM {{schema}}.{{table}}
GROUP BY {{by_cols}}
HAVING COUNT(*) >= :min_count
ORDER BY n DESC
LIMIT :limit;
