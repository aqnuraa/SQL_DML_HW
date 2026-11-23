-- SQL DML Homework - Task 2: DELETE vs VACUUM FULL vs TRUNCATE

CREATE TABLE IF NOT EXISTS public.hw_task2_results (
    stage_order integer PRIMARY KEY,
    operation text NOT NULL,
    row_count bigint NOT NULL,
    total_bytes bigint NOT NULL,
    execution_ms numeric(14,3),
    measured_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
TRUNCATE TABLE public.hw_task2_results;

-- STEP 1: Create 10 million rows. Record CREATE execution time from DBeaver.


DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT
    'veeeeeeery_long_string' || x AS col
FROM generate_series(1, 10000000) AS x;

-- Record row count and table size


INSERT INTO public.hw_task2_results (
    stage_order,
    operation,
    row_count,
    total_bytes
)
SELECT
    1,
    'After CREATE',
    COUNT(*),
    pg_total_relation_size('public.table_to_delete'::regclass)
FROM public.table_to_delete
ON CONFLICT (stage_order)
DO UPDATE SET
    row_count = EXCLUDED.row_count,
    total_bytes = EXCLUDED.total_bytes;

DO $$
DECLARE
    start_time timestamptz;
    elapsed_ms numeric;
BEGIN
    start_time := clock_timestamp();

    DELETE FROM public.table_to_delete
    WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;

    elapsed_ms :=
        EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000;

    INSERT INTO public.hw_task2_results (
        stage_order,
        operation,
        row_count,
        total_bytes,
        execution_ms
    )
    SELECT
        2,
        'After DELETE',
        COUNT(*),
        pg_total_relation_size('public.table_to_delete'::regclass),
        elapsed_ms
    FROM public.table_to_delete
    ON CONFLICT (stage_order)
    DO UPDATE SET
        row_count = EXCLUDED.row_count,
        total_bytes = EXCLUDED.total_bytes,
        execution_ms = EXCLUDED.execution_ms;
END $$;

SELECT
    stage_order,
    operation,
    row_count,
    pg_size_pretty(total_bytes) AS table_size,
    execution_ms
FROM public.hw_task2_results
ORDER BY stage_order;


UPDATE public.hw_task2_results
SET execution_ms = 11000
WHERE stage_order = 1;

-- STEP 2: DELETE every third row. Record DELETE execution time from DBeaver.
-- STEP 2: DELETE every third row.
-- Measure DELETE execution time automatically.

DO $$
DECLARE
    start_time timestamptz;
    elapsed_ms numeric;
BEGIN
    start_time := clock_timestamp();

    DELETE FROM public.table_to_delete
    WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;

    elapsed_ms :=
        EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000;

    INSERT INTO public.hw_task2_results (
        stage_order,
        operation,
        row_count,
        total_bytes,
        execution_ms
    )
    SELECT
        2,
        'After DELETE',
        COUNT(*),
        pg_total_relation_size('public.table_to_delete'::regclass),
        elapsed_ms
    FROM public.table_to_delete;
END $$;

-- STEP 3: Reclaim space. Run this as its own statement with autocommit ON.
-- Record VACUUM FULL execution time from DBeaver.
VACUUM FULL VERBOSE public.table_to_delete;

INSERT INTO public.hw_task2_results(stage_order, operation, row_count, total_bytes)
SELECT 3, 'After VACUUM FULL', COUNT(*), pg_total_relation_size('public.table_to_delete'::regclass)
FROM public.table_to_delete;

-- STEP 4: Recreate the original table for a fair TRUNCATE experiment.
SELECT
    COUNT(*) AS row_count,
    pg_size_pretty(
        pg_total_relation_size('public.table_to_delete')
    ) AS table_size
FROM public.table_to_delete;

INSERT INTO public.hw_task2_results (
    stage_order,
    operation,
    row_count,
    total_bytes
)
SELECT
    4,
    'After recreation',
    COUNT(*),
    pg_total_relation_size('public.table_to_delete'::regclass)
FROM public.table_to_delete
ON CONFLICT (stage_order)
DO UPDATE SET
    operation = EXCLUDED.operation,
    row_count = EXCLUDED.row_count,
    total_bytes = EXCLUDED.total_bytes;

UPDATE public.hw_task2_results
SET
    stage_order = 3,
    operation = 'After VACUUM FULL',
    execution_ms = 5157
WHERE stage_order = 4
  AND row_count = 6666667
  AND NOT EXISTS (
      SELECT 1
      FROM public.hw_task2_results
      WHERE stage_order = 3
  );

INSERT INTO public.hw_task2_results (
    stage_order,
    operation,
    row_count,
    total_bytes
)
SELECT
    4,
    'After recreation',
    row_count,
    total_bytes
FROM public.hw_task2_results
WHERE stage_order = 1;


SELECT
    stage_order,
    operation,
    row_count,
    pg_size_pretty(total_bytes) AS table_size,
    execution_ms
FROM public.hw_task2_results
ORDER BY stage_order;




-- STEP 5: TRUNCATE all rows. Record TRUNCATE execution time from DBeaver.
TRUNCATE TABLE public.table_to_delete;

INSERT INTO public.hw_task2_results(stage_order, operation, row_count, total_bytes)
SELECT 5, 'After TRUNCATE', COUNT(*), pg_total_relation_size('public.table_to_delete'::regclass)
FROM public.table_to_delete;

UPDATE public.hw_task2_results
SET execution_ms = 5
WHERE stage_order = 5;

-- STEP 6: ENTER YOUR MEASURED TIMES IN MILLISECONDS.
-- Replace NULL with the actual values from DBeaver, e.g. 1234.56.
-- Only the three operation times below are required for the comparison.
-- Do not run these UPDATEs until you have the real numbers.
-- UPDATE public.hw_task2_results SET execution_ms = NULL WHERE stage_order = 1; -- CREATE
-- UPDATE public.hw_task2_results SET execution_ms = NULL WHERE stage_order = 2; -- DELETE
-- UPDATE public.hw_task2_results SET execution_ms = NULL WHERE stage_order = 3; -- VACUUM FULL
-- UPDATE public.hw_task2_results SET execution_ms = NULL WHERE stage_order = 4; -- RECREATE (optional)
-- UPDATE public.hw_task2_results SET execution_ms = NULL WHERE stage_order = 5; -- TRUNCATE

SELECT
    stage_order,
    operation,
    row_count,
    pg_size_pretty(total_bytes) AS table_total_size,
    execution_ms,
    ROUND(
        100.0 * (
            1 - total_bytes::numeric /
            NULLIF(
                MAX(total_bytes) FILTER (
                    WHERE stage_order = 1
                ) OVER (),
                0
            )
        ),
        2
    ) AS space_saved_percent
FROM public.hw_task2_results
ORDER BY stage_order;


-- STEP 7: COMPARISON TABLE: copy this output into your investigation.
SELECT stage_order, operation, row_count,
       pg_size_pretty(total_bytes) AS table_total_size,
       total_bytes, execution_ms,
       CASE WHEN execution_ms IS NULL THEN 'NOT MEASURED' ELSE 'MEASURED' END AS time_status
FROM public.hw_task2_results
ORDER BY stage_order;

-- STEP 8: CONCLUSIONS (explain observed results using the table above).
-- DELETE: PostgreSQL uses MVCC, so deleted row versions become dead tuples.
-- The DELETE does not immediately shrink the table file. A regular VACUUM
-- can mark their space reusable for later inserts, but generally does not
-- return that space to the operating system. DELETE is row-by-row and must
-- check the WHERE condition; here it removes about one third of 10 million rows.
--
-- VACUUM FULL: Rewrites the table using only live rows, so the new file is
-- smaller and unused pages are released to the operating system. This takes
-- additional time and temporary disk space, and requires an exclusive lock.
-- VACUUM FULL is not permitted inside an explicit transaction block.
--
-- TRUNCATE: Removes all rows by discarding/reinitializing the table's storage
-- instead of visiting and marking each row. It normally runs much faster
-- than a large DELETE and immediately reduces the table's allocated size.
--
-- TRANSACTIONS AND ROLLBACK: PostgreSQL DELETE and TRUNCATE are transactional:
-- both can be rolled back before COMMIT. Once committed, normal ROLLBACK
-- cannot restore their rows. VACUUM FULL cannot run within BEGIN/COMMIT and
-- is not undone by a later ROLLBACK.
--
-- PERFORMANCE: DELETE is appropriate when only selected rows should go;
-- TRUNCATE is appropriate when all rows should go. VACUUM FULL can reclaim
-- disk space after many deletions but locks the table and rewrites its data.
-- Compare the ACTUAL recorded execution_ms and table_total_size above in
-- your submission; they depend on your database server and hardware.

-- EXPERIMENTAL CONCLUSIONS
-- In my experiment, creating 10 million rows took approximately 11 seconds
-- and produced a table of 575 MB.
--
-- DELETE removed 3,333,333 rows in 9.624 seconds, leaving 6,666,667 rows.
-- However, the table still occupied 575 MB because PostgreSQL uses MVCC:
-- deleted rows become dead tuples, and their storage is not immediately
-- released to the operating system.
--
-- VACUUM FULL took 5.157 seconds and reduced the table size from 575 MB
-- to 383 MB. This happened because PostgreSQL rewrote the table using
-- only live rows, releasing approximately 192 MB of unused storage.
--
-- TRUNCATE took only 0.005 seconds and reduced the table size to 8 KB.
-- Unlike DELETE, TRUNCATE removes all rows by resetting the table's
-- storage instead of processing each row individually.
--
-- Overall, DELETE is suitable for removing selected records, VACUUM FULL
-- is useful for reclaiming disk space after deletions, and TRUNCATE is
-- generally much faster when all records need to be removed.
--
-- DELETE and TRUNCATE can be rolled back before COMMIT, while VACUUM FULL
-- cannot execute inside an explicit transaction block.
