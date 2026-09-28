# Entity-relationship diagram

Logical schema for the five-role social media database. Crow’s-foot markers show cardinality on both sides of every relationship. Types match `schema.sql`.

```mermaid
erDiagram
    direction LR
    actor {
        integer actor_id PK
        varchar display_name "varchar(50)"
    }

    producer {
        integer producer_id PK
        varchar display_name "varchar(50)"
        boolean is_active
        integer follower_count
    }

    event {
        integer event_id PK
        integer actor_id FK
        integer producer_id FK
        varchar event_type "varchar(32)"
        timestamp occurred_at
        numeric engagement_score "numeric(3, 2)"
    }

    catalog {
        integer catalog_id PK
        varchar catalog_name "varchar(40)"
        integer parent_catalog_id FK "nullable"
    }

    producer_catalog["producer_catalog (junction)"] {
        integer producer_id PK, FK
        integer catalog_id PK, FK
    }

    actor ||..o{ event : "performs"
    producer ||..o{ event : "receives"
    producer ||--o{ producer_catalog : "has membership in"
    catalog ||--o{ producer_catalog : "classifies"
    catalog |o..o{ catalog : "is parent of"
```

## Relationships and cardinality

| Parent | Child | Cardinality | Identifying | Meaning |
| --- | --- | --- | --- | --- |
| `actor` | `event` | one to zero-or-more (`\|\|` … `o{`) | No (`..`) | Each event is performed by exactly one actor. An actor may have no events. |
| `producer` | `event` | one to zero-or-more (`\|\|` … `o{`) | No (`..`) | Each event is about exactly one producer. A producer may have no events. |
| `producer` | `producer_catalog` | one to zero-or-more (`\|\|` … `o{`) | Yes (`--`) | Each junction row names exactly one producer. A producer may have no catalog tags. |
| `catalog` | `producer_catalog` | one to zero-or-more (`\|\|` … `o{`) | Yes (`--`) | Each junction row names exactly one catalog. A catalog may have no producers. |
| `catalog` | `catalog` | zero-or-one to zero-or-more (`\|o` … `o{`) | No (`..`) | A topic has at most one parent topic and may have many child topics. `parent_catalog_id` is null for a top-level topic. |

`producer_catalog` is the many-to-many junction: a producer may belong to many catalogs, and a catalog may classify many producers.

## Marker key

| Token | Meaning |
| --- | --- |
| `\|\|` | exactly one |
| `\|o` | zero or one |
| `o{` | zero or more |
| `..` | non-identifying (child has its own primary key) |
| `--` | identifying (foreign key is part of the child’s primary key) |
