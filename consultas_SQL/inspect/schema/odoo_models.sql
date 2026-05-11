-- inspect/schema/odoo_models.sql
-- Cruza pg_catalog con ir_model + ir_module_module para mapear modelos Odoo a tablas físicas.
-- Parámetros: :like (patrón LIKE sobre ir_model.model), :limit
-- Notas:
--   - Tabla física = replace(ir_model.model, '.', '_') (convención Odoo).
--   - Modelos abstractos / TransientModel sin almacenamiento dejan `table` y `est_rows` NULL.
--   - El módulo se infiere por ir_model_data del registro de ir.model.

SELECT
    m.model                                      AS model,
    COALESCE(m.name->>'es_ES', m.name->>'en_US') AS label,
    mod.name                                     AS module,
    mod.state                                    AS module_state,
    c.relname                                    AS "table",
    c.reltuples::bigint                          AS est_rows,
    CASE WHEN c.oid IS NOT NULL
         THEN pg_size_pretty(pg_total_relation_size(c.oid))
    END                                          AS total_size
FROM ir_model m
LEFT JOIN ir_model_data d
       ON d.res_id = m.id
      AND d.model  = 'ir.model'
LEFT JOIN ir_module_module mod
       ON mod.name = d.module
LEFT JOIN pg_class c
       ON c.relname = replace(m.model, '.', '_')
      AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      AND c.relkind IN ('r', 'p')
WHERE m.model LIKE :like
ORDER BY est_rows DESC NULLS LAST, m.model
LIMIT :limit;
