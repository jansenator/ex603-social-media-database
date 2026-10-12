-- =================================================================
-- EX 603 Assignment 3 – q3_1.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit3/q3_1.sql
-- =================================================================
-- Task 3.1. What the reaction data contains, before any failure rate
-- is trusted. posts.like_count is a stored number on the post. It is
-- not the number of rows in likes. Post_01 stores 400 and has 11
-- reactions. Post_06 stores 0 and has 21. Post_14 stores 129, passes
-- the filter below, and has no reaction rows. The population for a
-- failure rate is likes (200 rows), not the stored like totals.


-- -----------------------------------------------------------------
-- 3.1a Active, highly liked posts — the producers whose records
--      anchor the audit. Nine posts qualify, so LIMIT 10 returns
--      every one of them. Requirement: SELECT, WHERE, ORDER BY, LIMIT.
-- screenshot: a3-3.1a-visible-posts
-- -----------------------------------------------------------------
SELECT post_id, post_title, like_count, is_visible
FROM posts
WHERE is_visible = TRUE
  AND like_count > 100
ORDER BY like_count DESC, post_id
LIMIT 10;


-- -----------------------------------------------------------------
-- 3.1b Every reaction status. Three values, not two. flagged is a
--      real status, and those rows have no removal reason. They are
--      not spam removals. Requirement: DISTINCT.
-- screenshot: a3-3.1b-statuses
-- -----------------------------------------------------------------
SELECT DISTINCT reaction_status
FROM likes
ORDER BY reaction_status;


-- -----------------------------------------------------------------
-- 3.1c Numeric range — reactions where someone stayed between 10 and
--      20 seconds. dwell_ms is stored in milliseconds.
--      Requirement: WHERE on a numeric range.
-- screenshot: a3-3.1c-range
-- -----------------------------------------------------------------
SELECT COUNT(*)                AS reactions,
       MIN(dwell_ms)           AS shortest_ms,
       MAX(dwell_ms)           AS longest_ms,
       ROUND(AVG(dwell_ms), 1) AS average_ms
FROM likes
WHERE dwell_ms BETWEEN 10000 AND 20000;


-- -----------------------------------------------------------------
-- 3.1c Explicit list — reactions marked removed or flagged. Active
--      reactions are left out of this count.
--      Requirement: WHERE ... IN (...).
-- screenshot: a3-3.1c-in
-- -----------------------------------------------------------------
SELECT reaction_status,
       COUNT(*) AS reactions
FROM likes
WHERE reaction_status IN ('removed', 'flagged')
GROUP BY reaction_status
ORDER BY reaction_status;


-- -----------------------------------------------------------------
-- 3.1d Text pattern — post titles from Post_01 through Post_09.
--      Requirement: LIKE.
-- screenshot: a3-3.1d-like
-- -----------------------------------------------------------------
SELECT post_id, post_title, is_visible, like_count
FROM posts
WHERE post_title LIKE 'Post_0%'
ORDER BY post_id;


-- -----------------------------------------------------------------
-- 3.1d Missing removal reasons. A missing reason is labeled
--      "No reason provided". The large group is the reactions that
--      were never removed. Requirement: COALESCE.
-- screenshot: a3-3.1d-reason-counts
-- -----------------------------------------------------------------
SELECT COALESCE(removal_reason, 'No reason provided') AS reason_label,
       COUNT(*) AS reactions
FROM likes
GROUP BY removal_reason
ORDER BY reactions DESC, reason_label;


-- -----------------------------------------------------------------
-- 3.1d The same missing reasons, row by row. Five rows stand in for
--      the 166. Requirement: IS NULL, COALESCE.
-- screenshot: a3-3.1d-reason-sample
-- -----------------------------------------------------------------
SELECT like_id,
       reaction_status,
       removal_reason,
       COALESCE(removal_reason, 'No reason provided') AS reason_label
FROM likes
WHERE removal_reason IS NULL
ORDER BY like_id
LIMIT 5;


-- -----------------------------------------------------------------
-- 3.1e Plain-language columns for one reaction at a time. Outcome is
--      the business reading of status plus reason. Time of day is
--      read from the hour of liked_at. Requirement: CASE.
-- screenshot: a3-3.1e-labeled-rows
-- -----------------------------------------------------------------
SELECT like_id,
       reaction_status,
       removal_reason,
       CASE
           WHEN reaction_status = 'removed'
                AND removal_reason = 'Spam detected' THEN 'Spam removal'
           WHEN reaction_status = 'removed' THEN 'Other removal'
           WHEN reaction_status = 'flagged' THEN 'Flagged for review'
           WHEN reaction_status = 'active' THEN 'Still active'
           ELSE 'Unexpected status'
       END AS outcome,
       CASE
           WHEN EXTRACT(HOUR FROM liked_at) < 6 THEN 'Night'
           WHEN EXTRACT(HOUR FROM liked_at) < 12 THEN 'Morning'
           WHEN EXTRACT(HOUR FROM liked_at) < 18 THEN 'Afternoon'
           ELSE 'Evening'
       END AS time_of_day
FROM likes
ORDER BY like_id
LIMIT 10;


-- -----------------------------------------------------------------
-- 3.1e How many reactions fall into each plain-language outcome.
--      These counts are the ones the finding memo quotes.
--      Requirement: CASE, GROUP BY.
-- screenshot: a3-3.1e-outcomes
-- -----------------------------------------------------------------
SELECT CASE
           WHEN reaction_status = 'removed'
                AND removal_reason = 'Spam detected' THEN 'Spam removal'
           WHEN reaction_status = 'removed' THEN 'Other removal'
           WHEN reaction_status = 'flagged' THEN 'Flagged for review'
           WHEN reaction_status = 'active' THEN 'Still active'
           ELSE 'Unexpected status'
       END AS outcome,
       COUNT(*) AS reactions
FROM likes
GROUP BY outcome
ORDER BY reactions DESC;
