# Constraints

Rules that protect the five-role social media database. Relation schemas are in [`schema-definition.md`](schema-definition.md). The DDL is [`schema.sql`](schema.sql). The same choices are explained for the assignment write-up in [`../analysis/unit2.md`](../analysis/unit2.md).

These rules keep rows identifiable, keep values in range, and keep every foreign key pointing at a real parent. Surrogate integer keys are treated as immutable, so `ON UPDATE` is left at the PostgreSQL default (`NO ACTION`).

## Entity integrity

Every column is `NOT NULL` except `catalog.parent_catalog_id`. A top-level topic has no parent, so that self-reference is optional (`|o` on the ERD). The other four foreign keys are mandatory: `||` means “exactly one parent,” and the junction columns are part of a composite primary key.

| Table | Constraint | Protects |
| --- | --- | --- |
| `actor` | `PRIMARY KEY (actor_id)` | One identity per actor. |
| `producer` | `PRIMARY KEY (producer_id)` | One identity per producer. |
| `event` | `PRIMARY KEY (event_id)` | One identity per recorded action. The grain is the surrogate key, not a natural `(actor, producer, timestamp)` tuple, so two actions in the same tick are allowed. |
| `catalog` | `PRIMARY KEY (catalog_id)` | One identity per topic. |
| `catalog` | `UNIQUE (catalog_name)` | Topic labels are a controlled vocabulary. Two rows named `Sports` would split filters and joins. Uniqueness is exact-match on `varchar` (`Sports` and `sports` are different labels). |
| `producer_catalog` | `PRIMARY KEY (producer_id, catalog_id)` | One membership per producer–topic pair; both columns are therefore `NOT NULL`. |

`display_name` is a label, not a login. It is `NOT NULL` but not `UNIQUE` on `actor` or `producer`.

Keys are `INTEGER GENERATED ALWAYS AS IDENTITY`. Foreign-key columns are `INTEGER` so the types match exactly.

## Domain integrity

`NOT NULL` still allows `''`. The checks below reject empty and space-only strings (`btrim` strips spaces, not tabs or newlines), and they keep the numeric columns that later units will filter or aggregate from going negative.

| Table | Constraint | Protects |
| --- | --- | --- |
| `actor` | `CHECK (length(btrim(display_name)) > 0)` | An actor always has a real display name. |
| `producer` | `CHECK (length(btrim(display_name)) > 0)` | A producer always has a real display name. |
| `producer` | `CHECK (follower_count >= 0)` | Follower counts cannot go negative. Zero is valid for a new account. |
| `catalog` | `CHECK (length(btrim(catalog_name)) > 0)` | A topic always has a real name. |
| `catalog` | `CHECK (parent_catalog_id IS DISTINCT FROM catalog_id)` | A topic cannot be its own parent. Null still passes, so a top-level topic is valid. A cycle of more than one hop (`Sports` → `Basketball` → `Sports`) is not visible to a row-level check. |
| `event` | `CHECK (length(btrim(event_type)) > 0)` | Every action has a non-empty type label. |
| `event` | `CHECK (engagement_score >= 0)` | Aggregations (`SUM` / `AVG`) must not ingest negative scores. Zero is a valid “no engagement” fact. |

`is_active` is `boolean NOT NULL`. That already limits it to true or false; no extra `CHECK` is required. `event_type` stays open `varchar(32)`: the platform is generic social media, and a closed `IN (...)` list would freeze the action vocabulary before later units exist. `numeric(3, 2)` caps `engagement_score` at 9.99. Lengths are `varchar(50)` for display names, `varchar(40)` for topic names, and `varchar(32)` for action tokens.

No `CHECK (occurred_at <= now())`. That rule breaks historical loads, demos, and ordinary clock skew. `occurred_at` is `timestamp NOT NULL` with no default, so an insert has to supply the time.

No column is `GENERATED ALWAYS AS (...) STORED`. `follower_count` and `engagement_score` are stored facts.

## Referential integrity

There are five foreign keys. `ON DELETE SET NULL` would fail at delete time on four of them: the event foreign keys are `NOT NULL` (`||` on the ERD) and the junction foreign keys are part of the primary key. It would also change event cardinality from “exactly one parent” to optional. `catalog.parent_catalog_id` is nullable, so `SET NULL` would succeed there; it is still rejected, for the reason in the last row.

`RESTRICT` is written explicitly instead of relying on PostgreSQL’s default `NO ACTION`. For a non-deferrable constraint the failed `DELETE` looks the same; `RESTRICT` also cannot be deferred. The name is the policy.

| Child | Parent | ON DELETE | Justification |
| --- | --- | --- | --- |
| `event.actor_id` | `actor.actor_id` | **RESTRICT** | Each event has exactly one actor, but the event is a fact with its own key, not a component of the actor. Deleting an actor must not erase likes, views, or other actions that later units will count and sum. `RESTRICT` refuses the delete while any events still point at that actor. Account removal, if needed, is an update (anonymize `display_name`) that keeps the primary key so events still join. |
| `event.producer_id` | `producer.producer_id` | **RESTRICT** | Same non-identifying fact-table duty as the actor FK. `is_active = false` is the retire path: it keeps the producer row and the history that `SUM(engagement_score)` will use. `RESTRICT` makes that the only retire path while events exist. A producer with **no** events can still be hard-deleted. |
| `producer_catalog.producer_id` | `producer.producer_id` | **CASCADE** | The ERD marks this relationship identifying (`--`): the junction row *is* the membership and has no identity apart from `(producer_id, catalog_id)`. A producer hard-delete is already gated by `event.producer_id RESTRICT`, so it only succeeds when there is no fact-table history. Leftover tags of that producer are then meaningless. The blast radius is one producer’s memberships. |
| `producer_catalog.catalog_id` | `catalog.catalog_id` | **RESTRICT** | `--` on the ERD means this FK is part of the junction PK; it does not require `CASCADE`. Both junction FKs already prevent orphans. Catalog is **shared reference data**: one topic classifies many producers. `ON DELETE CASCADE` here would turn `DELETE FROM catalog WHERE catalog_name = 'Sports'` into a mass untag: every Sports membership would vanish, producers would remain, and later “filter by catalog” queries would undercount. `RESTRICT` forces an explicit two-step retirement: untag (or re-tag) first, then delete the catalog row. That friction is the protection. |
| `catalog.parent_catalog_id` | `catalog.catalog_id` | **RESTRICT** | The relationship is non-identifying (`..`) and optional (`|o`): a topic has at most one parent. `RESTRICT` refuses deletion of a parent that still has children, so `Sports` cannot disappear while `Basketball` still names it. Children are re-parented or removed first. `ON DELETE SET NULL` would flatten the subtree into new top-level topics. `ON DELETE CASCADE` would delete the descendant topics along with the parent. |

The two junction actions are deliberately asymmetric. Deleting one producer can cascade that producer’s tags. Deleting one catalog must not cascade tags for every producer in the taxonomy. The parent-topic action is restricted for the same reason the catalog side of the junction is restricted: a topic delete is an edit someone makes on purpose, not a side effect.

### Rejected alternatives

- **`ON DELETE CASCADE` on `event.actor_id` or `event.producer_id`.** Treats engagement history as disposable child rows. The ERD is non-identifying (`..`), and `event` is the fact table later units aggregate. `is_active` would also be pointless if a producer delete wiped every event about them.
- **`ON DELETE SET NULL` or `SET DEFAULT` on the event or junction FKs.** `SET NULL` would fail the `NOT NULL` / primary-key constraints at delete time and would make event parents optional, contradicting `||`. `SET DEFAULT` would need sentinel rows (“unknown actor”, “unknown producer”) that are not in the model.
- **`ON DELETE CASCADE` on `producer_catalog.catalog_id`.** Same end state as untag-then-delete, but the mass untag is implicit in the dimension delete. `--` is already satisfied by the composite PK.
- **`ON DELETE RESTRICT` on `producer_catalog.producer_id`.** Only adds ceremony. Tags of a producer who already has no events do not need to outlive that producer.
- **`ON DELETE SET NULL` on `catalog.parent_catalog_id`.** Deleting `Entertainment` would detach every child and make each one a top-level topic. The taxonomy would flatten without a chosen new parent.
- **`ON DELETE CASCADE` on `catalog.parent_catalog_id`.** Deleting a parent topic would delete its descendant topics. A single topic delete would take the subtree with it.
