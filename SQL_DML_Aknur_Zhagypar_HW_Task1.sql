
-- SQL DML Homework - Task 1

-- SUBTASK 1: INSERT FAVORITE FILMS

BEGIN;

INSERT INTO public.film (
    title, description, release_year, language_id,
    rental_duration, rental_rate, replacement_cost, last_update
)
SELECT
    v.title,
    v.description,
    v.release_year,
    l.language_id,
    v.duration,
    v.rate,
    25.00,
    CURRENT_DATE
FROM (
    VALUES
        ('The Matrix', 'A hacker discovers the truth about reality.', 1999, 7, 4.99::numeric),
        ('Spirited Away', 'A girl enters a mysterious spirit world.', 2001, 14, 9.99::numeric),
        ('The Dark Knight', 'Batman faces the Joker in Gotham City.', 2008, 21, 19.99::numeric)
) AS v(title, description, release_year, duration, rate)
CROSS JOIN (
    SELECT language_id
    FROM public.language
    WHERE LOWER(name) = 'english'
    LIMIT 1
) l
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film f
    WHERE LOWER(f.title) = LOWER(v.title)
      AND f.release_year = v.release_year
)
RETURNING film_id, title, release_year, rental_rate;

COMMIT;


-- SUBTASK 2: INSERT ACTORS AND FILM RELATIONSHIPS


BEGIN;

INSERT INTO public.actor (first_name, last_name, last_update)
SELECT v.first_name, v.last_name, CURRENT_DATE
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
RETURNING actor_id, first_name, last_name;


INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM (
    VALUES
        ('Keanu', 'Reeves', 'The Matrix', 1999),
        ('Laurence', 'Fishburne', 'The Matrix', 1999),
        ('Rumi', 'Hiiragi', 'Spirited Away', 2001),
        ('Miyu', 'Irino', 'Spirited Away', 2001),
        ('Christian', 'Bale', 'The Dark Knight', 2008),
        ('Heath', 'Ledger', 'The Dark Knight', 2008)
) v(first_name, last_name, title, release_year)
JOIN public.actor a
    ON LOWER(a.first_name) = LOWER(v.first_name)
   AND LOWER(a.last_name) = LOWER(v.last_name)
JOIN public.film f
    ON f.title = v.title
   AND f.release_year = v.release_year
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor fa
    WHERE fa.actor_id = a.actor_id
      AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

COMMIT;


-- SUBTASK 3: ADD FILMS TO INVENTORY

BEGIN;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM public.film f
CROSS JOIN (
    SELECT store_id
    FROM public.store
    ORDER BY store_id
    LIMIT 1
) s
WHERE f.title IN ('The Matrix', 'Spirited Away', 'The Dark Knight')
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
      AND i.store_id = s.store_id
)
RETURNING inventory_id, film_id, store_id;

COMMIT;

-- SUBTASK 4: UPDATE CUSTOMER AND DELETE OLD RECORDS


-- Select a customer with at least 43 rentals and payments.
-- Reuse the marked customer when rerunning the script.

DROP TABLE IF EXISTS pg_temp.hw_customer;

CREATE TEMP TABLE hw_customer AS
SELECT c.customer_id
FROM public.customer c
WHERE LOWER(c.email) = LOWER('your.name@example.com')
   OR (
       (SELECT COUNT(*) FROM public.rental r
        WHERE r.customer_id = c.customer_id) >= 43
       AND
       (SELECT COUNT(*) FROM public.payment p
        WHERE p.customer_id = c.customer_id) >= 43
   )
ORDER BY
    (LOWER(c.email) = LOWER('your.name@example.com')) DESC,
    c.customer_id
LIMIT 1;

SELECT c.*
FROM public.customer c
JOIN hw_customer h USING (customer_id);

BEGIN;

UPDATE public.customer c
SET first_name = 'YOUR_FIRST_NAME',
    last_name = 'YOUR_LAST_NAME',
    email = 'your.name@example.com',
    address_id = (
        SELECT address_id
        FROM public.address
        ORDER BY address_id
        LIMIT 1
    ),
    last_update = CURRENT_DATE
FROM hw_customer h
WHERE c.customer_id = h.customer_id
RETURNING c.customer_id, c.first_name, c.last_name, c.email;


-- Preview records before deletion.
SELECT * FROM public.payment
WHERE customer_id IN (SELECT customer_id FROM hw_customer);

SELECT * FROM public.rental
WHERE customer_id IN (SELECT customer_id FROM hw_customer);


DELETE FROM public.payment p
USING hw_customer h
WHERE p.customer_id = h.customer_id
RETURNING p.payment_id, p.customer_id;

DELETE FROM public.rental r
USING hw_customer h
WHERE r.customer_id = h.customer_id
RETURNING r.rental_id, r.customer_id;

COMMIT;


-- SUBTASK 5: RENT FILMS AND INSERT PAYMENTS

BEGIN;

INSERT INTO public.rental (
    rental_date, inventory_id, customer_id,
    return_date, staff_id, last_update
)
SELECT
    TIMESTAMP '2017-06-01 10:00:00',
    i.inventory_id,
    h.customer_id,
    TIMESTAMP '2017-06-15 10:00:00',
    s.staff_id,
    CURRENT_DATE
FROM public.film f
JOIN public.inventory i USING (film_id)
JOIN public.store st USING (store_id)
JOIN public.staff s USING (store_id)
CROSS JOIN hw_customer h
WHERE f.title IN ('The Matrix', 'Spirited Away', 'The Dark Knight')
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
      AND r.rental_date = TIMESTAMP '2017-06-01 10:00:00'
)
RETURNING rental_id, inventory_id, customer_id;


INSERT INTO public.payment (
    customer_id, staff_id, rental_id, amount, payment_date
)
SELECT
    r.customer_id,
    r.staff_id,
    r.rental_id,
    f.rental_rate,
    TIMESTAMP '2017-06-01 11:00:00'
FROM public.rental r
JOIN public.inventory i USING (inventory_id)
JOIN public.film f USING (film_id)
JOIN hw_customer h USING (customer_id)
WHERE f.title IN ('The Matrix', 'Spirited Away', 'The Dark Knight')
AND r.rental_date = TIMESTAMP '2017-06-01 10:00:00'
AND NOT EXISTS (
    SELECT 1
    FROM public.payment p
    WHERE p.rental_id = r.rental_id
)
RETURNING payment_id, rental_id, amount;

COMMIT;


-- FINAL VERIFICATION


SELECT
    f.title,
    f.release_year,
    f.rental_rate,
    f.rental_duration,
    COUNT(fa.actor_id) AS actors
FROM public.film f
LEFT JOIN public.film_actor fa USING (film_id)
WHERE f.title IN ('The Matrix', 'Spirited Away', 'The Dark Knight')
GROUP BY f.film_id
ORDER BY f.release_year;

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT r.rental_id) AS rentals,
    COUNT(DISTINCT p.payment_id) AS payments
FROM public.customer c
JOIN hw_customer h USING (customer_id)
LEFT JOIN public.rental r USING (customer_id)
LEFT JOIN public.payment p USING (customer_id)
GROUP BY c.customer_id;
