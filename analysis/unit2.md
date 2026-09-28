# Unit 2 – Translating the ERD into DDL

The script is [`schema/schema.sql`](../schema/schema.sql). This note explains the order it creates tables in, the foreign-key delete rules, and the `CHECK` constraints. The diagram in [`schema/erd.md`](../schema/erd.md) matches the script.

## What changed from Unit 1

Unit 1 named types in the ERD directly (`bigint`, `text`, `timestamptz`, `numeric(10, 2)`). Assignment 2 maps those domains to a specific PostgreSQL type, so the diagram was updated rather than left beside a different script.

- Surrogate keys are `INTEGER GENERATED ALWAYS AS IDENTITY`. The foreign keys that point at them are `INTEGER` as well.
- Short text uses a stated length. `display_name` is `VARCHAR(50)`, the length of an X/Twitter display name. `catalog_name` is `VARCHAR(40)`, enough for a topic label such as `Live Music`. `event_type` is `VARCHAR(32)`, enough for an action token such as `video_progress`.
- `occurred_at` is `TIMESTAMP`. It is `NOT NULL` and has no default, so a row has to say when the action happened. That keeps historical loads from silently receiving `now()`.
- `engagement_score` is `NUMERIC(3, 2)`. The assignment maps a score to that type. The type itself stops at 9.99. The check below still rejects negatives. No 5-star ceiling was added, because Unit 1 defined zero as “no engagement” and did not define a maximum score.
- `catalog.parent_catalog_id` is new. Unit 1’s catalog was a flat list. A topic now may sit under one parent topic, which is the recursive foreign key in this model. It is the only nullable column. A referral column was not added to `actor`; that relationship is not part of this platform.

Nothing in the schema is a stored generated value. `follower_count` and `engagement_score` are facts recorded on the row. Later units can sum the score. They do not need a column that copies that sum.

`catalog_name` is also `UNIQUE`. The match is exact, so `Sports` and `sports` are different labels. `display_name` is not unique. It is a label, not a login.

## Creation order

A table is created only after every table it references. `catalog` references only itself, and PostgreSQL allows that inside one `CREATE TABLE`.

| Order | Table | Why it is here |
| --- | --- | --- |
| 1 | `actor` | It references nothing. |
| 2 | `catalog` | Its only foreign key points at `catalog`. |
| 3 | `producer` | It references nothing. |
| 4 | `producer_catalog` | It references `producer` and `catalog`. |
| 5 | `event` | It references `actor` and `producer`. |

The reset block drops in the reverse of this list: `event`, `producer_catalog`, `producer`, `catalog`, `actor`. Each drop uses `CASCADE`.

## Foreign keys

One row per foreign key.

| Foreign key | ON DELETE choice | Reason (one sentence) |
| --- | --- | --- |
| `fk_event_actor` | `RESTRICT` | An event is a fact with its own key, so deleting an actor must not erase the actions later units will count. |
| `fk_event_producer` | `RESTRICT` | The same fact-table duty: a producer is retired with `is_active = false`, which keeps the history `SUM(engagement_score)` needs. |
| `fk_producer_catalog_producer` | `CASCADE` | A tag row has no identity apart from the producer it belongs to, and that producer’s tags are meaningless once the producer row is actually gone. |
| `fk_producer_catalog_catalog` | `RESTRICT` | A topic is shared by many producers, so deleting the topic must not silently untag all of them. |
| `fk_catalog_parent` | `RESTRICT` | Deleting a parent topic must not silently promote every child topic to a top-level topic. |

`ON UPDATE` is left at the PostgreSQL default. The identity keys are not renumbered.

`ON DELETE SET NULL` cannot be used on the first four foreign keys. The event keys are `NOT NULL`, and the junction keys are part of the primary key. Setting either to null would fail at delete time, and it would also turn “exactly one parent” into an optional parent.

### `fk_event_actor`

An actor is someone who likes, views, or otherwise acts. The event row is the record of that action. It points at the actor, and it has its own `event_id`.

Deleting an actor while events still point at them is refused. The events stay, and so do the totals later units will compute from them. Removing the person from the product, if that is required, is an update: change `display_name` to something anonymous and leave `actor_id` in place so the events still join. Actors have no `is_active` flag. That flag lives on `producer`.

`ON DELETE CASCADE` would treat those actions as disposable children of the account. The relationship is non-identifying, and the event table is the table later units aggregate. `ON DELETE SET NULL` would fail because `actor_id` is `NOT NULL`, and a sentinel “unknown actor” row is not part of the model.

### `fk_event_producer`

A producer is the account the action is about. Deleting that account while events still point at it is refused. The retire path is `is_active = false`. The producer row and its `producer_id` stay, so engagement history still joins.

A producer with no events can still be hard-deleted. The junction rule below then removes that producer’s tags.

`ON DELETE CASCADE` would delete every event about that producer. `is_active` would not matter, because the history it is meant to preserve would already be gone. `ON DELETE SET NULL` fails for the same reason as on the actor key: `producer_id` is `NOT NULL`.

### `fk_producer_catalog_producer`

`producer_catalog` is the membership. The row is the pair `(producer_id, catalog_id)` and has no key of its own. The ERD marks the relationship identifying.

A producer delete only reaches this rule when `fk_event_producer` has already allowed it, which means that producer has no events. The tags left behind would describe an account that no longer exists. `CASCADE` removes that producer’s memberships and no one else’s.

`ON DELETE RESTRICT` would force a separate untag step for an account that already has no history. Those tags do not need to outlive the producer. `ON DELETE SET NULL` is impossible because `producer_id` is part of the primary key.

### `fk_producer_catalog_catalog`

Catalog rows are the shared topic list. One topic classifies many producers. Both junction foreign keys already prevent orphans. Identifying the relationship does not require `CASCADE`.

`RESTRICT` turns retirement of a topic into two steps: untag or re-tag the producers, then delete the catalog row. `ON DELETE CASCADE` would make `DELETE FROM catalog WHERE catalog_name = 'Sports'` drop every Sports membership, leave the producers in place, and cause later “filter by catalog” queries to undercount. That mass untag would be implicit in the topic delete.

### `fk_catalog_parent`

Topics form a tree, or a forest of trees. `Sports` may be the parent of `Basketball`. A top-level topic has a null parent.

Deleting `Sports` while `Basketball` still names it as parent is refused. Someone re-parents `Basketball`, or removes it, and then deletes `Sports`. The same friction protects the topic list from the junction side: a tagged topic cannot disappear in one statement either.

`ON DELETE SET NULL` would succeed for the self-reference, because the parent column is nullable. Deleting `Entertainment` would then detach `News`, `Sports`, and every other child and make each of them a top-level topic. The taxonomy would flatten without anyone choosing a new parent. `ON DELETE CASCADE` would delete the descendant topics as well. A parent delete would take the subtree with it.

The check on this column stops a topic from being its own parent. It does not stop a longer cycle, such as `Sports` → `Basketball` → `Sports`. A `CHECK` only sees the row being written. Cycles of more than one hop would have to be refused in a later trigger or in the application. None is defined here.

## CHECK constraints

### `chk_actor_display_name`

`CHECK (length(btrim(display_name)) > 0)` makes `''` and `'   '` unstorable on `actor`. `NOT NULL` does not do that. A client can send an empty display name from a blank form, and `btrim` also rejects a name that is only spaces. `btrim` strips spaces, not tabs or newlines.

### `chk_producer_display_name`

The same empty-name state, on `producer`. A producer with a blank name would still pass `NOT NULL` and would show up as an empty account in any list filtered only on `is_active`.

### `chk_producer_follower_count`

`CHECK (follower_count >= 0)` makes a negative follower count unstorable. Zero remains valid for a new account. A bad import or an unchecked decrement in the application could otherwise write `-1`, and any later filter on follower count would treat that account as smaller than every real one.

### `chk_catalog_name`

The same empty-name state, on `catalog_name`. An empty topic would still be unique if only one such row existed, and it would split “producers with no real topic” away from producers that are simply untagged.

### `chk_catalog_not_self_parent`

`CHECK (parent_catalog_id IS DISTINCT FROM catalog_id)` makes a topic that is its own parent unstorable. A null parent is allowed, because `IS DISTINCT FROM` treats null as different from the topic’s own id. The bad row can arrive as an update that copies `catalog_id` into `parent_catalog_id`, or as an insert that supplies both values. The longer cycle described above is a separate hole.

### `chk_event_event_type`

The same empty-name state, on `event_type`. The column is open `VARCHAR(32)`, with no `IN (...)` list, so new action names can be added without a schema change. Empty is still not a name. A client that omits the type and sends `''` would otherwise store an action that no report could group.

### `chk_event_engagement_score`

`CHECK (engagement_score >= 0)` makes a negative score unstorable. Zero stays valid and means no engagement. `NUMERIC(3, 2)` already rejects anything above 9.99, so the check’s job is the sign. A negative score would pull `SUM` and `AVG` down. It can arrive from a scoring formula that subtracts too much, or from a file that uses `-1` as a missing value.
