# Relation schemas

Logical relation schemas for the five-role social media database.

Constraints that protect these relations are in [`constraints.md`](constraints.md).

```text
actor(
	actor_id: bigint,
	display_name: text
)
Primary key: actor_id

producer(
	producer_id: bigint,
	display_name: text,
	is_active: boolean,
	follower_count: integer
)
Primary key: producer_id

event(
	event_id: bigint,
	actor_id: bigint,
	producer_id: bigint,
	event_type: text,
	occurred_at: timestamptz,
	engagement_score: numeric(10, 2)
)
Primary key: event_id
Foreign keys: actor_id references actor,
			  producer_id references producer

catalog(
	catalog_id: bigint,
	catalog_name: text
)
Primary key: catalog_id

producer_catalog(
	producer_id: bigint,
	catalog_id: bigint
)
Primary key: (producer_id, catalog_id)
Foreign keys: producer_id references producer,
			  catalog_id references catalog
```
