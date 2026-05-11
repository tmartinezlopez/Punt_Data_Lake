-- inspect/schema/tables.sql
-- Lista tablas de un esquema con conteo estimado y tamaño opcional.
-- Parámetros: :schema, :like, :with_size (bool), :non_empty (bool), :limit (int)

SELECT
    n.nspname                                   AS schema,
    c.relname                                   AS table,
    c.reltuples::bigint                         AS est_rows,
    CASE WHEN :with_size THEN pg_size_pretty(pg_total_relation_size(c.oid)) END AS total_size,
    CASE WHEN :with_size THEN pg_total_relation_size(c.oid) END                 AS total_size_bytes,
    obj_description(c.oid)                      AS comment
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname = :schema
  AND c.relname LIKE :like
  AND ((NOT :non_empty) OR c.reltuples > 0)
ORDER BY c.reltuples DESC, c.relname
LIMIT :limit;
