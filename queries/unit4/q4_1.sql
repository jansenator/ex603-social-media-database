-- =================================================================
-- EX 603 Assignment 4 – q4_1.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit4/q4_1.sql
-- =================================================================
-- Task 4.1. Platform performance, then the same numbers by producer.
-- A producer is a post. The metric is dwell_ms, milliseconds a
-- viewer stayed on the reaction. A failure is a spam removal:
-- reaction_status = 'removed' and removal_reason = 'Spam detected'.
-- The dataset has no region column. The reaction's region is
-- likes.client_country, the country of the client that reacted.
-- There are 15 posts and 200 reactions. Posts 14 and 15 have no
-- reaction rows.


-- -----------------------------------------------------------------
-- 4.1.1 Whole reaction log: how many reactions, the total, average,
--       minimum, and maximum dwell, and how many distinct actors
--       (users) appear.
--       Requirement: COUNT, SUM, AVG, MIN, MAX, COUNT DISTINCT.
--       The minimum is 0. The check on dwell_ms allows zero, and 34
--       of the 200 reactions are exactly 0. A dwell of zero is a
--       legal value and a doubtful one: the timer may never have
--       started. It is not a negative, which the check would reject.
-- screenshot: a4-4.1-platform
-- -----------------------------------------------------------------
SELECT COUNT(*)                     AS reactions,
       SUM(dwell_ms)                AS total_dwell_ms,
       ROUND(AVG(dwell_ms), 2)      AS average_dwell_ms,
       MIN(dwell_ms)                AS minimum_dwell_ms,
       MAX(dwell_ms)                AS maximum_dwell_ms,
       COUNT(DISTINCT user_id)      AS distinct_actors
FROM likes;


-- -----------------------------------------------------------------
-- 4.1.2 Event count and average dwell for every post, including the
--       two posts that have no reactions. Those two sort last.
--       Average dwell is null when a post has no reactions.
--       Requirement: GROUP BY, aggregate, ORDER BY.
-- screenshot: a4-4.1-by-producer
-- -----------------------------------------------------------------
SELECT posts.post_id,
       COUNT(likes.like_id)            AS reactions,
       ROUND(AVG(likes.dwell_ms), 2)   AS average_dwell_ms
FROM posts
LEFT JOIN likes ON likes.post_id = posts.post_id
GROUP BY posts.post_id
ORDER BY reactions DESC, posts.post_id;


-- -----------------------------------------------------------------
-- 4.1.3 Posts with enough reactions for a rate to mean anything.
--       Threshold: 10 reactions.
--       The counts jump from 6 to 11. Below 10 there is one post
--       with 6 reactions and two posts with none. One spam removal
--       among 6 reactions moves the rate by about 17 points, so
--       that rate is not a basis for an investigation. Ten sits in
--       the gap and drops those three posts.
--       Requirement: HAVING.
-- screenshot: a4-4.1-having
-- -----------------------------------------------------------------
SELECT posts.post_id,
       COUNT(likes.like_id)            AS reactions,
       ROUND(AVG(likes.dwell_ms), 2)   AS average_dwell_ms
FROM posts
LEFT JOIN likes ON likes.post_id = posts.post_id
GROUP BY posts.post_id
HAVING COUNT(likes.like_id) >= 10
ORDER BY reactions DESC, posts.post_id;


-- -----------------------------------------------------------------
-- 4.1.4 One row per post and viewer country, so a regional leader
--       can read their own country without losing the post.
--       Region is likes.client_country. There is no region column.
--       author_country is one value per post, so pairing it with
--       post_id would not be a second dimension.
--       Requirement: GROUP BY two columns.
-- screenshot: a4-4.1-two-dimensions
-- -----------------------------------------------------------------
SELECT likes.post_id,
       likes.client_country                         AS region,
       COUNT(*)                                     AS reactions,
       ROUND(AVG(likes.dwell_ms), 2)                AS average_dwell_ms,
       SUM(CASE
               WHEN likes.reaction_status = 'removed'
                    AND likes.removal_reason = 'Spam detected'
               THEN 1
               ELSE 0
           END)                                     AS spam_removals
FROM likes
GROUP BY likes.post_id, likes.client_country
ORDER BY likes.client_country, reactions DESC, likes.post_id;
