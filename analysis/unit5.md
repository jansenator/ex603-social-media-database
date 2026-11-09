# Task 5.1

The three-table join is a reaction review. Each row is one reaction: the account (`user_id`, `user_name`), the post (`post_id`, `post_title`), and the time (`liked_at`). The result has 200 rows, one per reaction. A trust lead can filter that list to Post_02 and Post_03 and see who reacted and when. Assignment 4 had the post ids and the rates, and this is the list behind those rates.

The tags on a post are not columns of `posts`. `post_hashtags` stores one row for each post and tag, and `hashtags` stores the name. Post_02 carries fitness, tech, and travel. Post_03 carries food and tech. Tech is the tag the two posts share. Without the junction, a post would have room for a single tag, or the names would be packed into one text column. A second tag would have nowhere normal to go, and finding every post on tech would mean parsing that text.

Five posts carry tech. Post_02 has 3 spam removals out of 16 reactions. Post_03 has 2 out of 13. Post_05 has 0 out of 18. Post_10 has 0 out of 19. Post_11 has 1 out of 16. The tag the two reviewed posts share is also on posts Assignment 4 left off the review list.

The self join pairs Post_02 and Post_03 with the other posts from the same author country. Post_02 is visible, the stored like count is 400, and the country is Vietnam. The peers are Post_06, stored count 0, and Post_11, stored count 207. The left join in Task 5.2 counts 21 reactions on Post_06 and 16 on Post_11. Assignment 4 counted 1 spam removal on Post_06. Post_03 is hidden, the stored like count is 400, and the country is Brazil. The peers are Post_05 (stored count 400, visible, 18 reactions, 0 spam removals), Post_12 (stored count 51, 17 reactions), and Post_13 (stored count 153, 11 reactions). Post_05 matches Post_03 on country and on the stored count, and Post_05 has no spam removals. Post_02 is visible and Post_03 is hidden, so a hidden post does not describe both posts under review. The stored like count is a column on `posts`. It is a different number from the reaction log. Post_14 stores 129 and has no reactions.

# Task 5.2

The inner join excludes post 14 and post 15. The left join returns 15 posts. The inner join returns 13. The excluded count is 2.

A post with no events has no row in `likes`. Post_14 and Post_15 are both visible. The stored like counts are 129 and 84. The reaction log is empty for both. That emptiness is what the queries show. The log does not say whether the counter was copied from another system, whether the reactions were never written, or whether they were removed from this table. Choosing among those explanations needs the load that filled `like_count`.

An inner join of posts to reactions builds a report of 13 posts. Post_14 and Post_15 are visible, and they are absent from that report. A reader who treats the report as the whole catalog misses two posts.

The posts that have never had a reaction belong on an inventory of what is published. They do not belong in the spam-rate comparison. That rate uses reactions as the denominator, and these posts have none.

The action is the one in the memo. Review the reactions on Post_02 and Post_03 before a payout that uses them. Reconcile the stored like count on Post_14 and Post_15 with the reaction log, and keep those two posts out of that spam review.

The right join puts `likes` on the left and `posts` on the right, so every post is kept. It returns the same 15 post ids as the left join. The set difference between those two id lists is empty. The full outer join counts 2 posts with no reaction and 0 reactions with no post. A full outer join can show a gap on either side. This dataset has a gap only on the post side. The foreign key on `likes.post_id` refuses a reaction whose post is missing, which is why the reaction side of that count is 0.

`NOT EXISTS` and `EXCEPT` both return post 14 and post 15. `NOT EXISTS` filters `posts`, so it can also return the title, the country, the visibility, and the stored count. `EXCEPT` subtracts one set of columns from another, so both sides list `post_id` only, and duplicate ids are dropped. The identifiers are the same.

# Task 5.3

The cross join of `hashtags` and `posts` is a coverage grid. The hashtag table has 5 rows, the post table has 15, the product is 75, and the cross join returns 75. Set that grid against `post_hashtags` and the missing pairs are the tags a post does not carry. A cross join of the reaction log and the posts would be 200 times 15, which is 3,000 rows, with every reaction attached to every post. That shape is what a forgotten join condition produces.

`EXPLAIN ANALYZE` runs the three-table join from Task 5.1, including the `ORDER BY`. The plan is a sort, a hash join, and a nested loop.

The sort is on `liked_at` and `like_id`. It is quicksort, about 35 kB, over the 200 rows the joins produced. It carries the `ORDER BY`. It is separate from the join choice.

The hash join reads `likes` with a sequential scan of 200 rows and probes a hash built from `users`. The hash is one batch and about 10 kB. The plan estimates 100 rows in `users`. The scan returns 30. The primary key on `users` could drive a nested loop. The planner hashed the accounts instead, because probing a 10 kB hash beats an index lookup on every reaction. There is no index on `likes.user_id`, so a search for one account cannot seek that account's reactions and the unfiltered join reads the whole log.

The nested loop looks up `posts` for each of those 200 rows. The lookup is an index scan on `posts_pkey`. Each reaction stores one `post_id`, and that column is the primary key. Memoize sits on the lookup: 13 misses and 187 hits. Thirteen posts appear in the reaction log, and the other lookups reuse those thirteen keys.

The plan names the step that reads a whole table. On this dataset the query finishes in a fraction of a millisecond, and a scan of 200 reactions is cheap. That scan is the step that grows when the log grows. An index on `likes.user_id`, together with a filter for one account, lets the planner start at that account and seek the index. If `users` grew until the hash needed more than one batch, a merge join of two inputs ordered by account id can cost less than a hash that spills to disk.

# Reflection

The plan hashed the 30 accounts and looked up each post by primary key. Size, indexes, and how often a key repeats are what chose those methods.

The reaction log has 200 rows and is scanned from start to finish. The accounts are smaller, so those 30 rows are built into a hash of about 10 kB, in one batch. The account primary key could drive a nested loop. The hash wins because probing that batch beats an index lookup on every reaction. The plan estimates 100 accounts against an actual 30, because the account table has not been analyzed. On a large account table that miss can spill the hash to disk or skip a cheaper index.

Each reaction names one post, and that id is the primary key, so the nested loop seeks it. Memoize shows 13 misses and 187 hits: 13 posts appear in the log, and the rest are repeats. Without that index, hashing the posts would be the likely plan.

An index on the reaction's account id, plus a filter for one account, lets the planner seek that account's reactions instead of hashing every account and scanning the log. Millions of reactions with no such filter keep the hash join and make the scan the slow step. If the accounts no longer fit in one hash batch, a merge join of two inputs ordered by account id can cost less. Analyzing the tables replaces the estimate of 100 before the planner chooses.
