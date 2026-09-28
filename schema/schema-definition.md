# Relation schemas

Logical relation schemas for the five-role social media database. These types match `schema.sql`.

Constraints that protect these relations are in [`constraints.md`](constraints.md).

```text
actor(
	actor_id: integer,
	display_name: varchar(50)
)
Primary key: actor_id

producer(
	producer_id: integer,
	display_name: varchar(50),
	is_active: boolean,
	follower_count: integer
)
Primary key: producer_id

event(
	event_id: integer,
	actor_id: integer,
	producer_id: integer,
	event_type: varchar(32),
	occurred_at: timestamp,
	engagement_score: numeric(3, 2)
)
Primary key: event_id
Foreign keys: actor_id references actor,
			  producer_id references producer

catalog(
	catalog_id: integer,
	catalog_name: varchar(40),
	parent_catalog_id: integer
)
Primary key: catalog_id
Foreign key: parent_catalog_id references catalog, nullable

producer_catalog(
	producer_id: integer,
	catalog_id: integer
)
Primary key: (producer_id, catalog_id)
Foreign keys: producer_id references producer,
			  catalog_id references catalog
```
