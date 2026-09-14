# Constraints

Rules that protect the five-role social media database. Relation schemas are in [`schema-definition.md`](schema-definition.md).

These rules keep rows identifiable, keep values in range, and keep every foreign key pointing at a real parent. Surrogate `bigint` keys are treated as immutable, so `ON UPDATE` is left at the PostgreSQL default (`NO ACTION`).

## Entity integrity

Every column in the five relations is `NOT NULL`. The ERD already requires this for the four foreign keys: `||` means “exactly one parent,” and the junction columns are part of a composite primary key.

| Table | Constraint | Protects |
| --- | --- | --- |
| `actor` | `PRIMARY KEY (actor_id)` | One identity per actor. |
| `producer` | `PRIMARY KEY (producer_id)` | One identity per producer. |
| `event` | `PRIMARY KEY (event_id)` | One identity per recorded action. The grain is the surrogate key, not a natural `(actor, producer, timestamp)` tuple, so two actions in the same tick are allowed. |
| `catalog` | `PRIMARY KEY (catalog_id)` | One identity per topic. |
| `catalog` | `UNIQUE (catalog_name)` | Topic labels are a controlled vocabulary. Two rows named `Sports` would split filters and joins. Uniqueness is exact-match on `text` (`Sports` and `sports` are different labels). |
| `producer_catalog` | `PRIMARY KEY (producer_id, catalog_id)` | One membership per producer–topic pair; both columns are therefore `NOT NULL`. |

`display_name` is a label, not a login. It is `NOT NULL` but not `UNIQUE` on `actor` or `producer`.

## Domain integrity

`NOT NULL` still allows `''`. The checks below reject empty and space-only strings (`btrim` strips spaces, not tabs or newlines), and they keep the numeric columns that later units will filter or aggregate from going negative.

| Table | Constraint | Protects |
| --- | --- | --- |
| `actor` | `CHECK (length(btrim(display_name)) > 0)` | An actor always has a real display name. |
| `producer` | `CHECK (length(btrim(display_name)) > 0)` | A producer always has a real display name. |
| `producer` | `CHECK (follower_count >= 0)` | Follower counts cannot go negative. Zero is valid for a new account. |
| `catalog` | `CHECK (length(btrim(catalog_name)) > 0)` | A topic always has a real name. |
| `event` | `CHECK (length(btrim(event_type)) > 0)` | Every action has a non-empty type label. |
| `event` | `CHECK (engagement_score >= 0)` | Aggregations (`SUM` / `AVG`) must not ingest negative scores. Zero is a valid “no engagement” fact. |

`is_active` is `boolean NOT NULL`. That already limits it to true or false; no extra `CHECK` is required. `event_type` stays open text: the platform is generic social media, and a closed `IN (...)` list would freeze the action vocabulary before later units exist. `numeric(10, 2)` already caps the scale of `engagement_score`.

No `CHECK (occurred_at <= now())`. That rule breaks historical loads, demos, and ordinary clock skew.

## Referential integrity

There are four foreign keys. `ON DELETE SET NULL` would fail at delete time on all four: the event FKs are `NOT NULL` (`||` on the ERD) and the junction FKs are part of the primary key. It would also change event cardinality from “exactly one parent” to optional.

`RESTRICT` is written explicitly instead of relying on PostgreSQL’s default `NO ACTION`. For a non-deferrable constraint the failed `DELETE` looks the same; `RESTRICT` also cannot be deferred. The name is the policy.

| Child | Parent | ON DELETE | Justification |
| --- | --- | --- | --- |
| `event.actor_id` | `actor.actor_id` | **RESTRICT** | Each event has exactly one actor, but the event is a fact with its own key, not a component of the actor. Deleting an actor must not erase likes, views, or other actions that later units will count and sum. `RESTRICT` refuses the delete while any events still point at that actor. Account removal, if needed, is an update (anonymize `display_name`) that keeps the primary key so events still join. |
| `event.producer_id` | `producer.producer_id` | **RESTRICT** | Same non-identifying fact-table duty as the actor FK. `is_active = false` is the retire path: it keeps the producer row and the history that `SUM(engagement_score)` will use. `RESTRICT` makes that the only retire path while events exist. A producer with **no** events can still be hard-deleted. |
| `producer_catalog.producer_id` | `producer.producer_id` | **CASCADE** | The ERD marks this relationship identifying (`--`): the junction row *is* the membership and has no identity apart from `(producer_id, catalog_id)`. A producer hard-delete is already gated by `event.producer_id RESTRICT`, so it only succeeds when there is no fact-table history. Leftover tags of that producer are then meaningless. The blast radius is one producer’s memberships. |
| `producer_catalog.catalog_id` | `catalog.catalog_id` | **RESTRICT** | `--` on the ERD means this FK is part of the junction PK; it does not require `CASCADE`. Both junction FKs already prevent orphans. Catalog is **shared reference data**: one topic classifies many producers. `ON DELETE CASCADE` here would turn `DELETE FROM catalog WHERE catalog_name = 'Sports'` into a mass untag: every Sports membership would vanish, producers would remain, and later “filter by catalog” queries would undercount. `RESTRICT` forces an explicit two-step retirement: untag (or re-tag) first, then delete the catalog row. That friction is the protection. |

The two junction actions are deliberately asymmetric. Deleting one producer can cascade that producer’s tags. Deleting one catalog must not cascade tags for every producer in the taxonomy.

### Rejected alternatives

- **`ON DELETE CASCADE` on `event.actor_id` or `event.producer_id`.** Treats engagement history as disposable child rows. The ERD is non-identifying (`..`), and `event` is the fact table later units aggregate. `is_active` would also be pointless if a producer delete wiped every event about them.
- **`ON DELETE SET NULL` or `SET DEFAULT` on any of the four FKs.** `SET NULL` would fail the `NOT NULL` / primary-key constraints at delete time and would make event parents optional, contradicting `||`. `SET DEFAULT` would need sentinel rows (“unknown actor”, “unknown producer”) that are not in the model.
- **`ON DELETE CASCADE` on `producer_catalog.catalog_id`.** Same end state as untag-then-delete, but the mass untag is implicit in the dimension delete. `--` is already satisfied by the composite PK.
- **`ON DELETE RESTRICT` on `producer_catalog.producer_id`.** Only adds ceremony. Tags of a producer who already has no events do not need to outlive that producer.
