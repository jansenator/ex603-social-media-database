-- =================================================================
-- EX 603 Assignment 5 – q5_3.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit5/q5_3.sql
-- =================================================================
-- Task 5.3. What a cross join multiplies, and how PostgreSQL runs
-- the three-table join from Task 5.1.
-- hashtags has 5 rows. posts has 15. The product is 75.
-- The three-table statement is the one in q5_1.sql, including the
-- ORDER BY. EXPLAIN ANALYZE runs that SELECT. It does not write.


-- -----------------------------------------------------------------
-- 5.3 Part A. Source counts, the product, and the cross join count.
--     The last column is COUNT(*) of hashtags CROSS JOIN posts.
--     It should equal hashtag_rows * post_rows.
--     Requirement: CROSS JOIN, both source counts, and the result count.
-- screenshot: a5-5.3-cross-join
-- -----------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM hashtags) AS hashtag_rows,
       (SELECT COUNT(*) FROM posts)    AS post_rows,
       (SELECT COUNT(*) FROM hashtags)
       * (SELECT COUNT(*) FROM posts)  AS product,
       (SELECT COUNT(*)
        FROM hashtags
        CROSS JOIN posts)              AS cross_join_rows;


-- -----------------------------------------------------------------
-- 5.3 Part A. The pairs behind that count.
--     Every hashtag next to every post, with no match condition.
--     The capture for this part is the count above. This statement
--     is the product those four numbers come from.
--     Requirement: the CROSS JOIN itself.
-- -----------------------------------------------------------------
SELECT hashtags.hashtag_name,
       posts.post_id,
       posts.post_title
FROM hashtags
CROSS JOIN posts
ORDER BY hashtags.hashtag_name, posts.post_id;


-- -----------------------------------------------------------------
-- 5.3 Part B. How the three-table join from q5_1.sql is run.
--     Same SELECT as Task 5.1, including the sort.
--     ANALYZE executes the SELECT and reports actual rows.
--     Requirement: EXPLAIN of the three-table join.
-- screenshot: a5-5.3-explain
-- -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT users.user_id,
       users.user_name,
       posts.post_id,
       posts.post_title,
       likes.liked_at
FROM likes
INNER JOIN users ON users.user_id = likes.user_id
INNER JOIN posts ON posts.post_id = likes.post_id
ORDER BY likes.liked_at, likes.like_id;
