-- LEVEL 1

-- Question 1: Number of users with sessions
SELECT COUNT(DISTINCT user_id) AS num_users_with_sessions
FROM sessions;


-- Question 2: Number of chargers used by user with id 1
-- cuenta los valores unicos del usuario id 1
SELECT COUNT(DISTINCT charger_id) AS num_chargers
FROM sessions
WHERE user_id = 1;



-- LEVEL 2

-- Question 3: Number of sessions per charger type (AC/DC):
SELECT type, COUNT(*) AS num_sessions
FROM sessions
JOIN chargers ON sessions.charger_id = chargers.id
GROUP BY type;

-- Question 4: Chargers being used by more than one user
SELECT charger_id, COUNT(DISTINCT user_id) AS num_users
FROM sessions
GROUP BY charger_id
HAVING num_users > 1;


-- Question 5: Average session time per charger 
-- calculamos el intervalo en dias
SELECT charger_id, 
       AVG((strftime('%s', end_time) - strftime('%s', start_time)) / (60.0 * 60.0 * 24.0)) AS avg_session_time_days
FROM sessions
GROUP BY charger_id;



-- LEVEL 3

-- Question 6: Full username of users that have used more than one charger in one day (NOTE: for date only consider start_time)

SELECT u.name, u.surname
FROM users u
JOIN sessions s ON u.id = s.user_id
WHERE strftime('%Y-%m-%d', s.start_time)
GROUP BY u.id, strftime('%Y-%m-%d', s.start_time)
HAVING COUNT(DISTINCT s.charger_id) > 1;

-- Question 7: Top 3 chargers with longer sessions
SELECT charger_id, 
       AVG((strftime('%s', end_time) - strftime('%s', start_time)) / (60.0 * 60.0 * 24.0)) AS avg_session_duration_days
FROM sessions
GROUP BY charger_id
ORDER BY avg_session_duration_days DESC
LIMIT 3;


-- Question 8: Average number of users per charger (per charger in general, not per charger_id specifically)
-- si no es por charger_id, podemos hacer por tipo. unimos las tablas de cargador y sesiones, para poder calcular el promedio por tipo de cargador
SELECT 
    c.type AS charger_type,
    AVG(users_per_charger) AS avg_users_per_charger_type
FROM (
    SELECT 
        charger_id,
        COUNT(DISTINCT user_id) AS users_per_charger
    FROM sessions
    GROUP BY charger_id
) AS charger_user_counts
JOIN chargers c ON charger_user_counts.charger_id = c.id
GROUP BY c.type;




-- Question 9: Top 3 users with more chargers being used
SELECT user_id, COUNT(DISTINCT charger_id) AS num_chargers_used
FROM sessions
GROUP BY user_id
ORDER BY num_chargers_used DESC
LIMIT 3;


-- LEVEL 4

-- Question 10: Number of users that have used only AC chargers, DC chargers or both
-- El case when es para buscar que sea exclusivo uno o el otro, o ambos, y los sumamos para clasificar los usuarios.
SELECT 
    SUM(CASE WHEN ac_count > 0 AND dc_count = 0 THEN 1 ELSE 0 END) AS users_only_ac,
    SUM(CASE WHEN ac_count = 0 AND dc_count > 0 THEN 1 ELSE 0 END) AS users_only_dc,
    SUM(CASE WHEN ac_count > 0 AND dc_count > 0 THEN 1 ELSE 0 END) AS users_both_ac_dc
FROM (
    SELECT 
        user_id,
        COUNT(DISTINCT CASE WHEN type = 'AC' THEN charger_id END) AS ac_count,
        COUNT(DISTINCT CASE WHEN type = 'DC' THEN charger_id END) AS dc_count
    FROM sessions
    JOIN chargers ON sessions.charger_id = chargers.id
    GROUP BY user_id
) AS charger_counts;

-- Question 11: Monthly average number of users per charger
SELECT 
    strftime('%Y-%m', s.start_time) AS month,
    c.type,
    AVG(num_users_per_charger) AS avg_users_per_charger
FROM (
    SELECT 
        charger_id,
        COUNT(DISTINCT user_id) AS num_users_per_charger
    FROM sessions
    GROUP BY charger_id
) AS user_counts
JOIN chargers c ON user_counts.charger_id = c.id
JOIN sessions s ON user_counts.charger_id = s.charger_id
GROUP BY month, c.type;


-- Question 12: Top 3 users per charger (for each charger, number of sessions)
WITH ranked_users AS (
    SELECT 
        user_id,
        charger_id,
        ROW_NUMBER() OVER(PARTITION BY charger_id ORDER BY COUNT(*) DESC) AS top3
    FROM sessions
    GROUP BY user_id, charger_id
)
SELECT 
    user_id,
    charger_id,
    top3
FROM ranked_users
WHERE top3 <= 3;




-- LEVEL 5

-- Question 13: Top 3 users with longest sessions per month (consider the month of start_time)
SELECT 
    u.id AS user_id,
    u.name,
    u.surname,
    s.total_session_hours
FROM (
    SELECT 
        user_id,
        SUM(strftime('%s', end_time) - strftime('%s', start_time)) / (60.0*60.0) AS total_session_hours
    FROM sessions
    GROUP BY user_id
    ORDER BY total_session_hours DESC
    LIMIT 3
) AS s
JOIN users u ON s.user_id = u.id;

    
-- Question 14. Average time between sessions for each charger for each month (consider the month of start_time)
-- Primero tengo que encontrar el tiempo entre sesiones, por eso el with session_gaps, la funcion LEAD se usa para ver el resultado siguiente, en sentido secuencial, por eso nos sirve para ver la siguiente sesion (en Ventas lo usamos para ver ventas mensuales por ejemplo)
-- con el over partition los datos se dividen en particiones segun el charger_id y el año y mes de start_time, y el order por start_time ayuda a que el lead funcione porque irá en order correcto de tiempo en cada sesion consecutiva
-- el resto ya es consulta normal

WITH session_gaps AS (
    SELECT 
        charger_id,
        strftime('%Y-%m', start_time) AS month,
        LEAD(start_time) OVER(PARTITION BY charger_id, strftime('%Y-%m', start_time) ORDER BY start_time) AS next_session_start,
        start_time,
        (strftime('%s', LEAD(start_time) OVER(PARTITION BY charger_id, strftime('%Y-%m', start_time) ORDER BY start_time)) - strftime('%s', start_time)) / (60.0*60.0) AS session_gap_hours
    FROM sessions
)
SELECT 
    charger_id,
    month,
    AVG(session_gap_hours) AS avg_session_gap_hours
FROM session_gaps
GROUP BY charger_id, month;

