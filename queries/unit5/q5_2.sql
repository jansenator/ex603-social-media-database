-- =================================================================
-- EX 603 Assignment 5 – q5_2.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit5/q5_2.sql
-- =================================================================
-- Task 5.2. Which posts have no reactions, and which joins drop them.
-- A producer is a post. An event is a row in likes.
-- Counts use post_id, so a post with many reactions is one producer.


-- -----------------------------------------------------------------
-- 5.2 Part A. Every post, including posts with no reactions.
--     COUNT(likes.like_id) is 0 when the post has no reaction row.
--     COUNT(*) would count the unmatched post as 1.
--     Requirement: LEFT JOIN.
-- screenshot: a5-5.2a-left
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       COUNT(likes.like_id) AS reactions
FROM posts
LEFT JOIN likes ON likes.post_id = posts.post_id
GROUP BY posts.post_id, posts.post_title
ORDER BY posts.post_id;


-- -----------------------------------------------------------------
-- 5.2 Part A. The same report through an inner join.
--     A post with no reaction row disappears.
--     Requirement: INNER JOIN.
-- screenshot: a5-5.2a-inner
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       COUNT(likes.like_id) AS reactions
FROM posts
INNER JOIN likes ON likes.post_id = posts.post_id
GROUP BY posts.post_id, posts.post_title
ORDER BY posts.post_id;


-- -----------------------------------------------------------------
-- 5.2 Part A. How many producers the inner join excludes.
--     Both counts are COUNT of distinct post_id, taken from the
--     two joins above. The third column is the difference.
--     Requirement: a count of the producers excluded by the inner join.
-- screenshot: a5-5.2a-excluded
-- -----------------------------------------------------------------
SELECT (SELECT COUNT(DISTINCT posts.post_id)
        FROM posts
        LEFT JOIN likes ON likes.post_id = posts.post_id)  AS producers_on_left_join,
       (SELECT COUNT(DISTINCT posts.post_id)
        FROM posts
        INNER JOIN likes ON likes.post_id = posts.post_id) AS producers_on_inner_join,
       (SELECT COUNT(DISTINCT posts.post_id)
        FROM posts
        LEFT JOIN likes ON likes.post_id = posts.post_id)
       -
       (SELECT COUNT(DISTINCT posts.post_id)
        FROM posts
        INNER JOIN likes ON likes.post_id = posts.post_id) AS producers_excluded_by_inner_join;


-- -----------------------------------------------------------------
-- 5.2 Part B. Right join that keeps every post.
--     likes is the left input and posts is the right input, so
--     RIGHT JOIN keeps the posts that have no reaction. The row
--     list should match the left join in Part A.
--     Requirement: RIGHT JOIN.
-- screenshot: a5-5.2b-right
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       COUNT(likes.like_id) AS reactions
FROM likes
RIGHT JOIN posts ON likes.post_id = posts.post_id
GROUP BY posts.post_id, posts.post_title
ORDER BY posts.post_id;


-- -----------------------------------------------------------------
-- 5.2 Part B. Confirm the left join and the right join name the
--     same posts. Each side of the UNION ALL is a set difference.
--     An empty result means no post id is on only one side.
--     Requirement: verify the two joins rather than assume they match.
-- screenshot: a5-5.2b-match
-- -----------------------------------------------------------------
WITH left_posts AS (
    SELECT posts.post_id
    FROM posts
    LEFT JOIN likes ON likes.post_id = posts.post_id
    GROUP BY posts.post_id
),
right_posts AS (
    SELECT posts.post_id
    FROM likes
    RIGHT JOIN posts ON likes.post_id = posts.post_id
    GROUP BY posts.post_id
)
(
    SELECT post_id
    FROM left_posts
    EXCEPT
    SELECT post_id
    FROM right_posts
)
UNION ALL
(
    SELECT post_id
    FROM right_posts
    EXCEPT
    SELECT post_id
    FROM left_posts
);


-- -----------------------------------------------------------------
-- 5.2 Part B. Full outer join of the same two tables.
--     posts_with_no_reaction counts preserved posts.
--     reactions_with_no_post counts preserved reactions.
--     A reaction whose post_id is missing from posts would appear
--     in the second count. The foreign key on likes.post_id
--     refuses that row, so the count is the check.
--     Requirement: FULL OUTER JOIN.
-- screenshot: a5-5.2b-full
-- -----------------------------------------------------------------
SELECT COUNT(*) FILTER (WHERE likes.like_id IS NULL)  AS posts_with_no_reaction,
       COUNT(*) FILTER (WHERE posts.post_id IS NULL)  AS reactions_with_no_post
FROM posts
FULL OUTER JOIN likes ON likes.post_id = posts.post_id;


-- -----------------------------------------------------------------
-- 5.2 Part C. Posts with no reaction row.
--     The extra columns are on the post, so the stored like_count
--     can be read next to the empty log.
--     Requirement: NOT EXISTS.
-- screenshot: a5-5.2c-not-exists
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       posts.author_country,
       posts.is_visible,
       posts.like_count
FROM posts
WHERE NOT EXISTS (
    SELECT 1
    FROM likes
    WHERE likes.post_id = posts.post_id
)
ORDER BY posts.post_id;


-- -----------------------------------------------------------------
-- 5.2 Part C. The same posts by set difference.
--     EXCEPT keeps columns that match on both sides, so this
--     returns post_id only. Compare these ids with Part C above.
--     Requirement: EXCEPT.
-- screenshot: a5-5.2c-except
-- -----------------------------------------------------------------
SELECT post_id
FROM posts
EXCEPT
SELECT post_id
FROM likes
ORDER BY post_id;
