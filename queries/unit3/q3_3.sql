-- =================================================================
-- EX 603 Assignment 3 – q3_3.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit3/q3_3.sql
-- =================================================================
-- Task 3.3. One question, three ways.
-- Which users took part in a reaction that was removed as spam?
-- A spam removal is reaction_status = 'removed' and
-- removal_reason = 'Spam detected'.
--
-- The three forms return the same rows on this data. They would not
-- if the test were rewritten with NOT IN on removal_reason. That
-- column is missing on 166 reactions. NOT IN becomes unknown for
-- every row when the list can contain a missing value, so the query
-- returns nobody. NOT EXISTS, and a left join that keeps non-matches,
-- still return the reactions that were not spam removals.
-- likes.user_id is never missing, and this spam-removal set is not
-- empty, so the three forms below stay aligned.


-- -----------------------------------------------------------------
-- 3.3 Form 1. Users whose id is in the spam-removal reactions.
--     Requirement: subquery with IN.
-- screenshot: a3-3.3-in
-- -----------------------------------------------------------------
SELECT user_id, user_name
FROM users
WHERE user_id IN (
    SELECT user_id
    FROM likes
    WHERE reaction_status = 'removed'
      AND removal_reason = 'Spam detected'
)
ORDER BY user_id;


-- -----------------------------------------------------------------
-- 3.3 Form 2. Name the spam-removal set, then join it to users.
--     Requirement: WITH.
-- screenshot: a3-3.3-with
-- -----------------------------------------------------------------
WITH spam_removals AS (
    SELECT DISTINCT user_id
    FROM likes
    WHERE reaction_status = 'removed'
      AND removal_reason = 'Spam detected'
)
SELECT users.user_id, users.user_name
FROM users
INNER JOIN spam_removals ON spam_removals.user_id = users.user_id
ORDER BY users.user_id;


-- -----------------------------------------------------------------
-- 3.3 Form 3. Keep a user when a matching spam removal exists.
--     Requirement: a third form, EXISTS. Not IN, and not WITH.
-- screenshot: a3-3.3-exists
-- -----------------------------------------------------------------
SELECT user_id, user_name
FROM users
WHERE EXISTS (
    SELECT 1
    FROM likes
    WHERE likes.user_id = users.user_id
      AND likes.reaction_status = 'removed'
      AND likes.removal_reason = 'Spam detected'
)
ORDER BY user_id;


-- -----------------------------------------------------------------
-- 3.3 Same rows, not the same count. Each number is how many rows
--     are in one result and not the other. Zero in both directions
--     means the row sets match. A matching count alone would not
--     show that.
-- screenshot: a3-3.3-same-rows
-- -----------------------------------------------------------------
WITH form1 AS (
    SELECT user_id, user_name
    FROM users
    WHERE user_id IN (
        SELECT user_id
        FROM likes
        WHERE reaction_status = 'removed'
          AND removal_reason = 'Spam detected'
    )
),
form2 AS (
    SELECT users.user_id, users.user_name
    FROM users
    INNER JOIN (
        SELECT DISTINCT user_id
        FROM likes
        WHERE reaction_status = 'removed'
          AND removal_reason = 'Spam detected'
    ) AS spam_removals ON spam_removals.user_id = users.user_id
),
form3 AS (
    SELECT user_id, user_name
    FROM users
    WHERE EXISTS (
        SELECT 1
        FROM likes
        WHERE likes.user_id = users.user_id
          AND likes.reaction_status = 'removed'
          AND likes.removal_reason = 'Spam detected'
    )
)
SELECT
    (SELECT COUNT(*) FROM (TABLE form1 EXCEPT TABLE form2) AS d) AS form1_minus_form2,
    (SELECT COUNT(*) FROM (TABLE form2 EXCEPT TABLE form1) AS d) AS form2_minus_form1,
    (SELECT COUNT(*) FROM (TABLE form1 EXCEPT TABLE form3) AS d) AS form1_minus_form3,
    (SELECT COUNT(*) FROM (TABLE form3 EXCEPT TABLE form1) AS d) AS form3_minus_form1;
