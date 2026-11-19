
-- SQL DML Homework - Task 2
-- STEP 1: CREATE TABLE

DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

SELECT COUNT(*) FROM public.table_to_delete;


-- STEP 2: INITIAL TABLE SIZE

SELECT
    table_schema,
    table_name,
    pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS indexes,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *,
        total_bytes - index_bytes - COALESCE(toast_bytes, 0)
        AS table_bytes
    FROM (
        SELECT
            n.nspname AS table_schema,
            c.relname AS table_name,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(c.reltoastrelid) AS toast_bytes
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r'
    ) a
) a
WHERE table_schema = 'public'
AND table_name = 'table_to_delete';


-- STEP 3: DELETE ONE THIRD OF ROWS

DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;

SELECT COUNT(*) AS remaining_rows
FROM public.table_to_delete;


-- Check size after DELETE.

SELECT
    pg_size_pretty(pg_total_relation_size('public.table_to_delete'))
    AS total_size;


-- STEP 4: VACUUM FULL

VACUUM FULL VERBOSE public.table_to_delete;

SELECT
    pg_size_pretty(pg_total_relation_size('public.table_to_delete'))
    AS size_after_vacuum;


-- STEP 5: RECREATE TABLE

DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

SELECT COUNT(*) AS recreated_rows
FROM public.table_to_delete;


-- STEP 6: TRUNCATE

TRUNCATE TABLE public.table_to_delete;

SELECT COUNT(*) AS remaining_rows
FROM public.table_to_delete;

SELECT
    pg_size_pretty(pg_total_relation_size('public.table_to_delete'))
    AS size_after_truncate;


-- CONCLUSIONS

-- DELETE:
-- Removes individual rows and leaves dead tuples.
-- Space is generally reusable after VACUUM but is not
-- immediately returned to the operating system.
-- DELETE can be rolled back before COMMIT.

-- VACUUM FULL:
-- Rewrites the table and physically releases unused space.
-- Requires an ACCESS EXCLUSIVE lock.
-- Cannot run inside a transaction block.

-- TRUNCATE:
-- Removes all rows without scanning individual records.
-- Usually faster than deleting all rows individually.
-- Releases the table's old storage pages.
-- Can be rolled back before COMMIT in PostgreSQL.

-- Actual execution times and storage sizes depend on
-- the server configuration and hardware.
-- Record measured values in your assignment report.
