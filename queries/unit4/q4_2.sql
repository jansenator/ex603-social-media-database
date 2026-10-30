-- =================================================================
-- EX 603 Assignment 4 – q4_2.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit4/q4_2.sql
-- =================================================================
-- Task 4.2. The breakdown behind the failure rate.
-- A producer is a post. A failure is a spam removal:
-- reaction_status = 'removed' and removal_reason = 'Spam detected'.
-- The rate uses every reaction as the base, including reactions
-- with no removal reason. Region is likes.client_country.
-- The volume line from Task 4.1 is 10 reactions.


-- -----------------------------------------------------------------
-- 4.2 Part A. For each post, in one pass and with no WHERE on the
--     query: how many reactions does this post have, and how many
--     of them were removed as spam?
--     Both totals are columns of the same row. The rate is those
--     two totals divided. Posts 14 and 15 have no reactions, so
--     the rate is null there.
--     Requirement: CASE inside an aggregate. No WHERE.
-- screenshot: a4-4.2a-conditional
-- -----------------------------------------------------------------
SELECT posts.post_id,
       COUNT(likes.like_id) AS reactions,
       SUM(CASE
               WHEN likes.reaction_status = 'removed'
                    AND likes.removal_reason = 'Spam detected'
               THEN 1
               ELSE 0
           END) AS spam_removals,
       ROUND(
           100.0 * SUM(CASE
                           WHEN likes.reaction_status = 'removed'
                                AND likes.removal_reason = 'Spam detected'
                           THEN 1
                           ELSE 0
                       END)
           / NULLIF(COUNT(likes.like_id), 0),
           2
       ) AS failure_rate_pct
FROM posts
LEFT JOIN likes ON likes.post_id = posts.post_id
GROUP BY posts.post_id
ORDER BY spam_removals DESC, failure_rate_pct DESC NULLS LAST, posts.post_id;


-- -----------------------------------------------------------------
-- 4.2 Part B. Subtotals for each viewer country, and one platform
--     grand total. No post rows and no reaction rows.
--     The five country rows are the subtotals. The grand total is
--     the single row labeled "Platform total". GROUPING returns 1
--     on that row because ROLLUP has collapsed client_country.
--     On a country row GROUPING returns 0.
--     Requirement: GROUP BY ROLLUP.
-- screenshot: a4-4.2b-rollup
-- -----------------------------------------------------------------
SELECT CASE
           WHEN GROUPING(client_country) = 1 THEN 'Platform total'
           ELSE client_country
       END AS region,
       COUNT(*) AS reactions,
       SUM(CASE
               WHEN reaction_status = 'removed'
                    AND removal_reason = 'Spam detected'
               THEN 1
               ELSE 0
           END) AS spam_removals,
       ROUND(
           100.0 * SUM(CASE
                           WHEN reaction_status = 'removed'
                                AND removal_reason = 'Spam detected'
                           THEN 1
                           ELSE 0
                       END)
           / COUNT(*),
           2
       ) AS failure_rate_pct
FROM likes
GROUP BY ROLLUP(client_country)
ORDER BY GROUPING(client_country), client_country;


-- -----------------------------------------------------------------
-- 4.2 Part C. Baseline for posts with enough volume.
--     The WITH block is one row per post: reactions and spam
--     removals. The outer query keeps posts with at least 10
--     reactions and reduces them to one baseline.
--     The pooled rate is spam removals divided by reactions, so a
--     post with 21 reactions counts more than a post with 11.
--     The average of rates gives every qualifying post the same
--     weight. The baseline used in the finding is the pooled rate.
--     Requirement: WITH, then a second aggregation.
-- screenshot: a4-4.2c-baseline
-- -----------------------------------------------------------------
WITH per_post AS (
    SELECT posts.post_id,
           COUNT(likes.like_id) AS reactions,
           SUM(CASE
                   WHEN likes.reaction_status = 'removed'
                        AND likes.removal_reason = 'Spam detected'
                   THEN 1
                   ELSE 0
               END) AS spam_removals
    FROM posts
    LEFT JOIN likes ON likes.post_id = posts.post_id
    GROUP BY posts.post_id
)
SELECT COUNT(*) AS high_volume_posts,
       SUM(reactions) AS reactions,
       SUM(spam_removals) AS spam_removals,
       ROUND(100.0 * SUM(spam_removals) / SUM(reactions), 2)
           AS pooled_failure_rate_pct,
       ROUND(AVG(100.0 * spam_removals / reactions), 2)
           AS average_of_rates_pct
FROM per_post
WHERE reactions >= 10;
