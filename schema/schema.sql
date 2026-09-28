-- =================================================================
-- EX 603 Assignment 2 – schema.sql
-- Theme:  social media
-- Author: Jansen Rensma
-- Target: PostgreSQL 14+
-- =================================================================
-- Reset. Reverse creation order, so no dependency blocks a drop.
-- WARNING hides the "does not exist, skipping" notice on the first run.
SET client_min_messages TO WARNING;

DROP TABLE IF EXISTS event CASCADE;
DROP TABLE IF EXISTS producer_catalog CASCADE;
DROP TABLE IF EXISTS producer CASCADE;
DROP TABLE IF EXISTS catalog CASCADE;
DROP TABLE IF EXISTS actor CASCADE;

-- ----------------------------------------------------------------
-- 1. actor – first, because it references nothing.
-- ----------------------------------------------------------------
CREATE TABLE actor (
    actor_id      INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name  VARCHAR(50) NOT NULL,
    CONSTRAINT pk_actor PRIMARY KEY (actor_id),
    CONSTRAINT chk_actor_display_name
        CHECK (length(btrim(display_name)) > 0)
);

-- ----------------------------------------------------------------
-- 2. catalog – only a self-reference, which PostgreSQL accepts in
--    this CREATE TABLE. Top-level topics leave parent_catalog_id null.
-- ----------------------------------------------------------------
CREATE TABLE catalog (
    catalog_id         INTEGER GENERATED ALWAYS AS IDENTITY,
    catalog_name       VARCHAR(40) NOT NULL,
    parent_catalog_id  INTEGER,
    CONSTRAINT pk_catalog PRIMARY KEY (catalog_id),
    CONSTRAINT uq_catalog_name UNIQUE (catalog_name),
    CONSTRAINT fk_catalog_parent
        FOREIGN KEY (parent_catalog_id) REFERENCES catalog (catalog_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_catalog_name
        CHECK (length(btrim(catalog_name)) > 0),
    CONSTRAINT chk_catalog_not_self_parent
        CHECK (parent_catalog_id IS DISTINCT FROM catalog_id)
);

-- ----------------------------------------------------------------
-- 3. producer – references nothing, so it is created before the
--    junction and the fact table that point at it.
-- ----------------------------------------------------------------
CREATE TABLE producer (
    producer_id     INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name    VARCHAR(50)  NOT NULL,
    is_active       BOOLEAN      NOT NULL,
    follower_count  INTEGER      NOT NULL,
    CONSTRAINT pk_producer PRIMARY KEY (producer_id),
    CONSTRAINT chk_producer_display_name
        CHECK (length(btrim(display_name)) > 0),
    CONSTRAINT chk_producer_follower_count
        CHECK (follower_count >= 0)
);

-- ----------------------------------------------------------------
-- 4. producer_catalog – resolves the M:N between producer and catalog.
--    Both parents already exist. The primary key is the pair of
--    foreign keys, not a new id.
-- ----------------------------------------------------------------
CREATE TABLE producer_catalog (
    producer_id  INTEGER NOT NULL,
    catalog_id   INTEGER NOT NULL,
    CONSTRAINT pk_producer_catalog PRIMARY KEY (producer_id, catalog_id),
    CONSTRAINT fk_producer_catalog_producer
        FOREIGN KEY (producer_id) REFERENCES producer (producer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_producer_catalog_catalog
        FOREIGN KEY (catalog_id) REFERENCES catalog (catalog_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 5. event – last. It references actor and producer, both created
--    above, and it does not reference catalog.
-- ----------------------------------------------------------------
CREATE TABLE event (
    event_id          INTEGER GENERATED ALWAYS AS IDENTITY,
    actor_id          INTEGER      NOT NULL,
    producer_id       INTEGER      NOT NULL,
    event_type        VARCHAR(32)  NOT NULL,
    occurred_at       TIMESTAMP    NOT NULL,
    engagement_score  NUMERIC(3,2) NOT NULL,
    CONSTRAINT pk_event PRIMARY KEY (event_id),
    CONSTRAINT fk_event_actor
        FOREIGN KEY (actor_id) REFERENCES actor (actor_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_producer
        FOREIGN KEY (producer_id) REFERENCES producer (producer_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_event_event_type
        CHECK (length(btrim(event_type)) > 0),
    CONSTRAINT chk_event_engagement_score
        CHECK (engagement_score >= 0)
);
