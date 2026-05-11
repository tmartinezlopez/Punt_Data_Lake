-- inspect/schema/columns.sql
-- Columnas de una tabla con tipo, nullable, default y estadísticas (pg_stats).
-- Parámetros: :schema, :table, :only_used (bool)
-- Notas: :only_used filtra a columnas cuya `null_frac` (estimada por ANALYZE)
--        sea < 1, lo que indica que existe al menos un valor no NULL.

SELECT
    a.attnum                                          AS ord,
    a.attname                                         AS column,
    format_type(a.atttypid, a.atttypmod)              AS type,
    NOT a.attnotnull                                  AS nullable,
    pg_get_expr(d.adbin, d.adrelid)                   AS "default",
    s.null_frac                                       AS null_frac,
    s.n_distinct                                      AS n_distinct,
    col_description(a.attrelid, a.attnum)             AS comment
FROM pg_attribute a
JOIN pg_class c       ON c.oid = a.attrelid
JOIN pg_namespace n   ON n.oid = c.relnamespace
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
LEFT JOIN pg_stats s   ON s.schemaname = n.nspname
                      AND s.tablename = c.relname
                      AND s.attname = a.attname
WHERE n.nspname = :schema
  AND c.relname = :table
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND ((NOT :only_used) OR COALESCE(s.null_frac, 1) < 1)
ORDER BY a.attnum;
