-- =================================================================
-- EX 603 Assignment 5 – q5_1.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- Database: ex603_data
-- Run: psql -d ex603_data -f queries/unit5/q5_1.sql
-- =================================================================
-- Task 5.1. Put a name on the posts from Assignment 4.
-- A producer is a post. An actor is a user. An event is a reaction
-- in likes. The catalog is hashtags. The junction is post_hashtags.
-- Assignment 4 sent posts 2 and 3 for a closer look: 3 spam
-- removals out of 16 reactions, and 2 out of 13.


-- -----------------------------------------------------------------
-- 5.1.1 Who reacted, to which post, and when.
--       Three tables: likes, users, and posts.
--       Requirement: join three tables. One row per reaction.
-- screenshot: a5-5.1-three-tables
-- -----------------------------------------------------------------
SELECT users.user_id,
       users.user_name,
       posts.post_id,
       posts.post_title,
       likes.liked_at
FROM likes
INNER JOIN users ON users.user_id = likes.user_id
INNER JOIN posts ON posts.post_id = likes.post_id
ORDER BY likes.liked_at, likes.like_id;


-- -----------------------------------------------------------------
-- 5.1.2 Which tags do the two posts from Assignment 4 carry?
--       posts to hashtags goes through post_hashtags. A post can
--       carry more than one tag, so the tags live on the junction
--       and not on the post.
--       Requirement: producer to catalog through the junction table.
-- screenshot: a5-5.1-investigated-tags
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       hashtags.hashtag_name
FROM posts
INNER JOIN post_hashtags ON post_hashtags.post_id = posts.post_id
INNER JOIN hashtags ON hashtags.hashtag_id = post_hashtags.hashtag_id
WHERE posts.post_id IN (2, 3)
ORDER BY posts.post_id, hashtags.hashtag_name;


-- -----------------------------------------------------------------
-- 5.1.3 Which posts carry the tag those two posts share?
--       The shared tag is tech. Post 2 also has travel and fitness.
--       Post 3 also has food. This list is every post on tech.
--       The reaction count and the spam-removal count sit beside
--       the tag so the shared tag can be read against the rates
--       from Assignment 4. A spam removal is reaction_status
--       'removed' and removal_reason 'Spam detected'.
--       Requirement: producers for the catalog tag.
-- screenshot: a5-5.1-tech
-- -----------------------------------------------------------------
SELECT posts.post_id,
       posts.post_title,
       hashtags.hashtag_name,
       COUNT(likes.like_id) AS reactions,
       COUNT(*) FILTER (
           WHERE likes.reaction_status = 'removed'
             AND likes.removal_reason = 'Spam detected'
       ) AS spam_removals
FROM posts
INNER JOIN post_hashtags ON post_hashtags.post_id = posts.post_id
INNER JOIN hashtags ON hashtags.hashtag_id = post_hashtags.hashtag_id
LEFT JOIN likes ON likes.post_id = posts.post_id
WHERE hashtags.hashtag_name = 'tech'
GROUP BY posts.post_id, posts.post_title, hashtags.hashtag_name
ORDER BY posts.post_id;


-- -----------------------------------------------------------------
-- 5.1.4 Do posts 2 and 3 look like the other posts from the same
--       country?
--       The self join pairs each of those posts with the other
--       posts that name the same author_country. The stored
--       like_count and is_visible are the characteristics on the
--       post row. Spam removals are not on this table. Those rates
--       are the Assignment 4 counts.
--       Requirement: self join on the producer table.
-- screenshot: a5-5.1-self-join
-- -----------------------------------------------------------------
SELECT focus.post_id           AS focus_post,
       focus.post_title        AS focus_title,
       focus.author_country,
       focus.is_visible        AS focus_visible,
       focus.like_count        AS focus_like_count,
       peer.post_id            AS peer_post,
       peer.post_title         AS peer_title,
       peer.is_visible         AS peer_visible,
       peer.like_count         AS peer_like_count
FROM posts AS focus
INNER JOIN posts AS peer
    ON peer.author_country = focus.author_country
   AND peer.post_id <> focus.post_id
WHERE focus.post_id IN (2, 3)
ORDER BY focus.post_id, peer.post_id;
