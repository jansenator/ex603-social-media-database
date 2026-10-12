-- =================================================================
-- EX 603 Assignment 3 – q3_2.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit3/q3_2.sql
-- =================================================================
-- Task 3.2. Two problems in the dashboard query.
-- Part A uses likes.removal_reason, which is already missing on 166
-- of 200 reactions. No rows were inserted.
-- Part B contains one statement that is supposed to fail. psql prints
-- that error and continues. Leave the failing statement in the file.


-- -----------------------------------------------------------------
-- 3.2a Broken filter — "reason is not spam", written as an inequality.
--      A comparison with a missing reason is unknown, and WHERE keeps
--      only true rows, so those reactions disappear. The statement
--      still succeeds. It returns 22.
-- screenshot: included in a3-3.2a-null-counts
-- -----------------------------------------------------------------
SELECT COUNT(*) AS broken_inequality_count
FROM likes
WHERE removal_reason <> 'Spam detected';


-- -----------------------------------------------------------------
-- 3.2a Rows the broken filter silently dropped: reasons that are
--      missing. This count is 166. 22 + 166 = 188, which is not the
--      table total of 200.
-- screenshot: included in a3-3.2a-null-counts
-- -----------------------------------------------------------------
SELECT COUNT(*) AS silently_omitted_count
FROM likes
WHERE removal_reason IS NULL;


-- -----------------------------------------------------------------
-- 3.2a The two counts, the spam rows, and the table total together.
--      inequality_matches (22) + omitted_null_reasons (166) = 188,
--      not table_total (200). The other 12 are real spam removals.
--      The inequality correctly rejects those. The 166 missing
--      reasons are the rows that vanished with no error.
--      22 + 166 + 12 = 200.
-- screenshot: a3-3.2a-null-counts
-- -----------------------------------------------------------------
SELECT 'inequality_matches' AS measure, COUNT(*) AS rows
FROM likes
WHERE removal_reason <> 'Spam detected'
UNION ALL
SELECT 'omitted_null_reasons', COUNT(*)
FROM likes
WHERE removal_reason IS NULL
UNION ALL
SELECT 'spam_removals', COUNT(*)
FROM likes
WHERE removal_reason = 'Spam detected'
UNION ALL
SELECT 'table_total', COUNT(*)
FROM likes;


-- -----------------------------------------------------------------
-- 3.2a Repair. Every reaction that was not removed as spam.
--      A missing reason counts as not spam, so those rows come back.
--      Requirement: an explicit IS NULL test beside the inequality.
--      Returns 188.
-- screenshot: a3-3.2a-repaired
-- -----------------------------------------------------------------
SELECT COUNT(*) AS reactions_that_are_not_spam_removals
FROM likes
WHERE removal_reason <> 'Spam detected'
   OR removal_reason IS NULL;


-- -----------------------------------------------------------------
-- 3.2b Alias used before it exists. The label is defined in SELECT
--      and referenced in WHERE. WHERE runs first, so the label is
--      not a column yet.
--      Run this statement by itself for the error screenshot.
--      Verbatim PostgreSQL error:
--        ERROR:  column "reason_label" does not exist
--        LINE 4: WHERE reason_label = 'No reason provided';
--                      ^
-- screenshot: a3-3.2b-alias-error
-- -----------------------------------------------------------------
SELECT like_id,
       COALESCE(removal_reason, 'No reason provided') AS reason_label
FROM likes
WHERE reason_label = 'No reason provided';


-- -----------------------------------------------------------------
-- 3.2b Rewrite 1. Repeat the expression in WHERE. Same question:
--      how many reactions have no removal reason?
-- screenshot: a3-3.2b-rewrites
-- -----------------------------------------------------------------
SELECT COALESCE(removal_reason, 'No reason provided') AS reason_label,
       COUNT(*) AS reactions
FROM likes
WHERE COALESCE(removal_reason, 'No reason provided') = 'No reason provided'
GROUP BY reason_label;


-- -----------------------------------------------------------------
-- 3.2b Rewrite 2. Compute the label inside WITH, then filter on it.
--      Outside the WITH, reason_label is a real column.
-- screenshot: a3-3.2b-rewrites
-- -----------------------------------------------------------------
WITH labeled AS (
    SELECT COALESCE(removal_reason, 'No reason provided') AS reason_label
    FROM likes
)
SELECT reason_label,
       COUNT(*) AS reactions
FROM labeled
WHERE reason_label = 'No reason provided'
GROUP BY reason_label;
