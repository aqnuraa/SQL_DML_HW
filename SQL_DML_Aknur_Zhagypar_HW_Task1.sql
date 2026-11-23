
-- SQL DML Homework - Task 1

-- ============================================================
-- SUBTASK 1: INSERT THREE FAVORITE FILMS
-- ============================================================

BEGIN;

INSERT INTO public.film (
    title,
    description,
    release_year,
    language_id,
    rental_duration,
    rental_rate,
    replacement_cost,
    last_update
)
SELECT
    v.title,
    v.description,
    v.release_year,
    l.language_id,
    v.rental_duration,
    v.rental_rate,
    25.00,
    CURRENT_DATE
FROM (
    VALUES
        (
            'The Matrix',
            'A hacker discovers the truth about reality.',
            1999,
            7,
            4.99::numeric
        ),
        (
            'Spirited Away',
            'A girl enters a mysterious spirit world.',
            2001,
            14,
            9.99::numeric
        ),
        (
            'The Dark Knight',
            'Batman faces the Joker in Gotham City.',
            2008,
            21,
            19.99::numeric
        )
) AS v(
    title,
    description,
    release_year,
    rental_duration,
    rental_rate
)
JOIN public.language l
    ON LOWER(TRIM(l.name)) = 'english'
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film f
    WHERE LOWER(f.title) = LOWER(v.title)
      AND f.release_year = v.release_year
)
RETURNING
    film_id,
    title,
    release_year,
    rental_duration,
    rental_rate;

-- Verify the three films before committing.

SELECT
    title,
    release_year,
    rental_duration,
    rental_rate
FROM public.film
WHERE (title, release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
);

-- If results are incorrect, execute ROLLBACK instead.
COMMIT;


-- ============================================================
-- SUBTASK 2: INSERT ACTORS AND FILM RELATIONSHIPS
-- ============================================================

BEGIN;

INSERT INTO public.actor (
    first_name,
    last_name,
    last_update
)
SELECT
    v.first_name,
    v.last_name,
    CURRENT_DATE
FROM (
    VALUES
        ('Keanu', 'Reeves'),
        ('Laurence', 'Fishburne'),
        ('Rumi', 'Hiiragi'),
        ('Miyu', 'Irino'),
        ('Christian', 'Bale'),
        ('Heath', 'Ledger')
) AS v(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = LOWER(v.first_name)
      AND LOWER(a.last_name) = LOWER(v.last_name)
)
RETURNING
    actor_id,
    first_name,
    last_name;


INSERT INTO public.film_actor (
    actor_id,
    film_id,
    last_update
)
SELECT
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM (
    VALUES
        ('Keanu', 'Reeves', 'The Matrix', 1999),
        ('Laurence', 'Fishburne', 'The Matrix', 1999),
        ('Rumi', 'Hiiragi', 'Spirited Away', 2001),
        ('Miyu', 'Irino', 'Spirited Away', 2001),
        ('Christian', 'Bale', 'The Dark Knight', 2008),
        ('Heath', 'Ledger', 'The Dark Knight', 2008)
) AS v(
    first_name,
    last_name,
    title,
    release_year
)
JOIN public.actor a
    ON LOWER(a.first_name) = LOWER(v.first_name)
   AND LOWER(a.last_name) = LOWER(v.last_name)
JOIN public.film f
    ON LOWER(f.title) = LOWER(v.title)
   AND f.release_year = v.release_year
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor fa
    WHERE fa.actor_id = a.actor_id
      AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

COMMIT;


-- ============================================================
-- SUBTASK 2B: ASSIGN GENRES TO THE THREE FILMS
-- ============================================================


BEGIN;

INSERT INTO public.film_category (
    film_id,
    category_id,
    last_update
)
SELECT
    f.film_id,
    c.category_id,
    CURRENT_DATE
FROM (
    VALUES
        ('The Matrix', 1999, 'Sci-Fi'),
        ('Spirited Away', 2001, 'Animation'),
        ('The Dark Knight', 2008, 'Action')
) AS v(title, release_year, category_name)
JOIN public.film f
    ON LOWER(f.title) = LOWER(v.title)
   AND f.release_year = v.release_year
JOIN public.category c
    ON LOWER(c.name) = LOWER(v.category_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_category fc
    WHERE fc.film_id = f.film_id
)
RETURNING film_id, category_id, last_update;


-- Verify that all three films have a category.

SELECT
    f.title,
    c.name AS genre
FROM public.film f
LEFT JOIN public.film_category fc
    ON fc.film_id = f.film_id
LEFT JOIN public.category c
    ON c.category_id = fc.category_id
WHERE (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
);

-- If any genre is NULL, correct it before committing.
COMMIT;


-- ============================================================
-- SUBTASK 3: ADD FILMS TO STORE INVENTORY
-- ============================================================

BEGIN;

INSERT INTO public.inventory (
    film_id,
    store_id,
    last_update
)
SELECT
    f.film_id,
    st.store_id,
    CURRENT_DATE
FROM public.film f
CROSS JOIN (
    SELECT store_id
    FROM public.store
    ORDER BY store_id
    LIMIT 1
) st
WHERE (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
)
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
      AND i.store_id = st.store_id
)
RETURNING inventory_id, film_id, store_id;

COMMIT;


-- ============================================================
-- SUBTASK 4: SELECT CUSTOMER, UPDATE DATA, DELETE OLD RECORDS
-- ============================================================

DROP TABLE IF EXISTS pg_temp.hw_customer;

CREATE TEMP TABLE hw_customer AS
SELECT
    c.customer_id
FROM public.customer c
WHERE LOWER(c.email) = LOWER('your.name@example.com')
   OR (
        (
            SELECT COUNT(*)
            FROM public.rental r
            WHERE r.customer_id = c.customer_id
        ) >= 43
        AND
        (
            SELECT COUNT(*)
            FROM public.payment p
            WHERE p.customer_id = c.customer_id
        ) >= 43
   )
ORDER BY
    (
        LOWER(c.email) = LOWER('your.name@example.com')
    ) DESC,
    c.customer_id
LIMIT 1;


-- Preview the customer BEFORE executing the destructive block.
-- Check the identity and the rental/payment counts.
-- On a first run, both counts must be at least 43.

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    (
        SELECT COUNT(*)
        FROM public.rental r
        WHERE r.customer_id = c.customer_id
    ) AS rental_count,
    (
        SELECT COUNT(*)
        FROM public.payment p
        WHERE p.customer_id = c.customer_id
    ) AS payment_count
FROM public.customer c
JOIN pg_temp.hw_customer h
    ON h.customer_id = c.customer_id;


-- STOP HERE if the selected customer is incorrect.
-- Do not run the following transaction until verified.

BEGIN;


-- Update the selected customer without changing address rows.
-- The address_id is retrieved from an existing address.
-- This avoids affecting other customers sharing that address.

UPDATE public.customer c
SET
    first_name = 'Aknur',
    last_name = 'Zhagypar',
    email = 'aknur.zhagypar@gmail.com',
    address_id = (
        SELECT address_id
        FROM public.address
        ORDER BY address_id
        LIMIT 1
    ),
    last_update = CURRENT_DATE
FROM pg_temp.hw_customer h
WHERE c.customer_id = h.customer_id
  AND (
      c.first_name,
      c.last_name,
      c.email,
      c.address_id
  ) IS DISTINCT FROM (
      'Aknur',
      'Zhagypar',
      'aknur.zhagypar@gmail.com',
      (
          SELECT address_id
          FROM public.address
          ORDER BY address_id
          LIMIT 1
      )
  )
RETURNING
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email;

-- Preview historical payments.

SELECT
    p.payment_id,
    p.rental_id,
    p.amount
FROM public.payment p
JOIN public.rental r
    ON r.rental_id = p.rental_id
JOIN pg_temp.hw_customer h
    ON h.customer_id = r.customer_id
WHERE NOT (
    r.rental_date = TIMESTAMP '2017-06-01 10:00:00'
    AND EXISTS (
        SELECT 1
        FROM public.inventory i
        JOIN public.film f
            ON f.film_id = i.film_id
        WHERE i.inventory_id = r.inventory_id
          AND (f.title, f.release_year) IN (
              ('The Matrix', 1999),
              ('Spirited Away', 2001),
              ('The Dark Knight', 2008)
          )
    )
);


-- Preview historical rentals.

SELECT
    r.rental_id,
    r.customer_id,
    r.rental_date
FROM public.rental r
JOIN pg_temp.hw_customer h
    ON h.customer_id = r.customer_id
WHERE NOT (
    r.rental_date = TIMESTAMP '2017-06-01 10:00:00'
    AND EXISTS (
        SELECT 1
        FROM public.inventory i
        JOIN public.film f
            ON f.film_id = i.film_id
        WHERE i.inventory_id = r.inventory_id
          AND (f.title, f.release_year) IN (
              ('The Matrix', 1999),
              ('Spirited Away', 2001),
              ('The Dark Knight', 2008)
          )
    )
);


-- Delete historical payments.
-- Payments for existing homework rentals are preserved.

DELETE FROM public.payment p
USING pg_temp.hw_customer h
WHERE p.customer_id = h.customer_id
  AND NOT EXISTS (
      SELECT 1
      FROM public.rental r
      JOIN public.inventory i
          ON i.inventory_id = r.inventory_id
      JOIN public.film f
          ON f.film_id = i.film_id
      WHERE r.rental_id = p.rental_id
        AND r.customer_id = h.customer_id
        AND r.rental_date =
            TIMESTAMP '2017-06-01 10:00:00'
        AND (f.title, f.release_year) IN (
            ('The Matrix', 1999),
            ('Spirited Away', 2001),
            ('The Dark Knight', 2008)
        )
  )
RETURNING p.payment_id, p.customer_id;


-- Delete historical rentals.
-- Existing homework rentals are excluded.

DELETE FROM public.rental r
USING pg_temp.hw_customer h
WHERE r.customer_id = h.customer_id
  AND NOT (
      r.rental_date = TIMESTAMP '2017-06-01 10:00:00'
      AND EXISTS (
          SELECT 1
          FROM public.inventory i
          JOIN public.film f
              ON f.film_id = i.film_id
          WHERE i.inventory_id = r.inventory_id
            AND (f.title, f.release_year) IN (
                ('The Matrix', 1999),
                ('Spirited Away', 2001),
                ('The Dark Knight', 2008)
            )
      )
  )
RETURNING r.rental_id, r.customer_id;

COMMIT;


-- ============================================================
-- SUBTASK 5: RENT THREE FILMS AND MAKE PAYMENTS
-- ============================================================


BEGIN;


INSERT INTO public.rental (
    rental_date,
    inventory_id,
    customer_id,
    return_date,
    staff_id,
    last_update
)
SELECT
    TIMESTAMP '2017-06-01 10:00:00',
    i.inventory_id,
    h.customer_id,
    TIMESTAMP '2017-06-01 10:00:00'
        + f.rental_duration * INTERVAL '1 day',
    s.staff_id,
    CURRENT_DATE
FROM public.film f
JOIN public.inventory i
    ON i.film_id = f.film_id
JOIN public.store st
    ON st.store_id = i.store_id
JOIN public.staff s
    ON s.store_id = st.store_id
CROSS JOIN pg_temp.hw_customer h
WHERE (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
)
AND st.store_id = (
    SELECT MIN(store_id)
    FROM public.store
)
AND i.inventory_id = (
    SELECT MIN(i2.inventory_id)
    FROM public.inventory i2
    WHERE i2.film_id = f.film_id
      AND i2.store_id = st.store_id
)
AND s.staff_id = (
    SELECT MIN(s2.staff_id)
    FROM public.staff s2
    WHERE s2.store_id = st.store_id
)
AND NOT EXISTS (
    SELECT 1
    FROM public.rental r
    WHERE r.customer_id = h.customer_id
      AND r.inventory_id = i.inventory_id
      AND r.rental_date =
          TIMESTAMP '2017-06-01 10:00:00'
)
RETURNING
    rental_id,
    inventory_id,
    customer_id,
    return_date;


-- Correct rentals inserted by an earlier version of this homework.
-- Only the selected customer's three films and exact homework
-- rental date are considered.

UPDATE public.rental r
SET
    return_date =
        r.rental_date + f.rental_duration * INTERVAL '1 day',
    last_update = CURRENT_DATE
FROM public.inventory i
JOIN public.film f
    ON f.film_id = i.film_id
JOIN pg_temp.hw_customer h
    ON TRUE
WHERE r.inventory_id = i.inventory_id
  AND r.customer_id = h.customer_id
  AND r.rental_date =
      TIMESTAMP '2017-06-01 10:00:00'
  AND (f.title, f.release_year) IN (
      ('The Matrix', 1999),
      ('Spirited Away', 2001),
      ('The Dark Knight', 2008)
  )
  AND r.return_date IS DISTINCT FROM (
      r.rental_date + f.rental_duration * INTERVAL '1 day'
  )
RETURNING r.rental_id, r.return_date;


-- Insert payments for the three rentals.
-- The rental_id is obtained from the rental table.
-- An existing payment for the rental prevents reinsertion.

INSERT INTO public.payment (
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
)
SELECT
    r.customer_id,
    r.staff_id,
    r.rental_id,
    f.rental_rate,
    TIMESTAMP '2017-06-01 11:00:00'
FROM public.rental r
JOIN public.inventory i
    ON i.inventory_id = r.inventory_id
JOIN public.film f
    ON f.film_id = i.film_id
JOIN pg_temp.hw_customer h
    ON h.customer_id = r.customer_id
WHERE (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
)
AND r.rental_date =
    TIMESTAMP '2017-06-01 10:00:00'
AND NOT EXISTS (
    SELECT 1
    FROM public.payment p
    WHERE p.rental_id = r.rental_id
)
RETURNING payment_id, rental_id, amount;

COMMIT;


-- ============================================================
-- FINAL VERIFICATION
-- ============================================================

-- Verify films, genres, rental rates, durations and actors.
-- Expected: three films with two actors each.

SELECT
    f.title,
    f.release_year,
    c.name AS genre,
    f.rental_duration,
    f.rental_rate,
    COUNT(DISTINCT fa.actor_id) AS actor_count
FROM public.film f
LEFT JOIN public.film_category fc
    ON fc.film_id = f.film_id
LEFT JOIN public.category c
    ON c.category_id = fc.category_id
LEFT JOIN public.film_actor fa
    ON fa.film_id = f.film_id
WHERE (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
)
GROUP BY f.film_id, c.name
ORDER BY f.release_year;


-- Verify the customer's rentals and payments.
-- Expected: three rental/payment pairs.
-- Return dates should match the film rental durations.

SELECT
    h.customer_id,
    f.title,
    r.rental_date,
    r.return_date,
    f.rental_duration,
    p.amount AS paid,
    f.rental_rate
FROM pg_temp.hw_customer h
JOIN public.rental r
    ON r.customer_id = h.customer_id
JOIN public.inventory i
    ON i.inventory_id = r.inventory_id
JOIN public.film f
    ON f.film_id = i.film_id
LEFT JOIN public.payment p
    ON p.rental_id = r.rental_id
WHERE r.rental_date =
    TIMESTAMP '2017-06-01 10:00:00'
AND (f.title, f.release_year) IN (
    ('The Matrix', 1999),
    ('Spirited Away', 2001),
    ('The Dark Knight', 2008)
)
ORDER BY f.title;
