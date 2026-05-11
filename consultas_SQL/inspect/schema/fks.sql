-- inspect/schema/fks.sql
-- Foreign keys entrantes/salientes para una tabla.
-- Parámetros: :schema, :table, :direction ('outbound' | 'inbound' | 'both')

WITH fks AS (
    -- Salientes: la tabla apunta a otras
    SELECT
        'outbound'::text          AS direction,
        c.conname                 AS constraint_name,
        ns.nspname                AS schema,
        cl.relname                AS "table",
        att.attname               AS "column",
        fns.nspname               AS ref_schema,
        fcl.relname               AS ref_table,
        fatt.attname              AS ref_column,
        c.confdeltype             AS on_delete,
        c.confupdtype             AS on_update
    FROM pg_constraint c
    JOIN pg_class cl       ON cl.oid = c.conrelid
    JOIN pg_namespace ns   ON ns.oid = cl.relnamespace
    JOIN pg_class fcl      ON fcl.oid = c.confrelid
    JOIN pg_namespace fns  ON fns.oid = fcl.relnamespace
    JOIN unnest(c.conkey, c.confkey) WITH ORDINALITY AS k(conkey, confkey, ord) ON TRUE
    JOIN pg_attribute att  ON att.attrelid = c.conrelid  AND att.attnum  = k.conkey
    JOIN pg_attribute fatt ON fatt.attrelid = c.confrelid AND fatt.attnum = k.confkey
    WHERE c.contype = 'f' AND ns.nspname = :schema AND cl.relname = :table

    UNION ALL

    -- Entrantes: otras tablas apuntan aquí
    SELECT
        'inbound'::text,
        c.conname,
        ns.nspname, cl.relname, att.attname,
        fns.nspname, fcl.relname, fatt.attname,
        c.confdeltype, c.confupdtype
    FROM pg_constraint c
    JOIN pg_class cl       ON cl.oid = c.conrelid
    JOIN pg_namespace ns   ON ns.oid = cl.relnamespace
    JOIN pg_class fcl      ON fcl.oid = c.confrelid
    JOIN pg_namespace fns  ON fns.oid = fcl.relnamespace
    JOIN unnest(c.conkey, c.confkey) WITH ORDINALITY AS k(conkey, confkey, ord) ON TRUE
    JOIN pg_attribute att  ON att.attrelid = c.conrelid  AND att.attnum  = k.conkey
    JOIN pg_attribute fatt ON fatt.attrelid = c.confrelid AND fatt.attnum = k.confkey
    WHERE c.contype = 'f' AND fns.nspname = :schema AND fcl.relname = :table
)
SELECT *
FROM fks
WHERE (:direction = 'both' OR direction = :direction)
ORDER BY direction, constraint_name;
