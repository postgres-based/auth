
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 <<EOSQL
-- fail on the first error
\set ON_ERROR_STOP on

CREATE ROLE authenticator WITH NOINHERIT NOLOGIN;

CREATE DATABASE auth_db WITH CONNECTION LIMIT = -1;

\c auth_db

-- create a schema in the database "auth_db"

CREATE SCHEMA auth AUTHORIZATION authenticator;

ALTER ROLE authenticator SET search_path = auth;

-- also an index (pk_user) will be created with the same name as the constraint 
CREATE TABLE auth.user (
    id integer GENERATED ALWAYS AS IDENTITY (CACHE 500), -- CACHE 500 are sequence props, you can specifiy
    cr_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user PRIMARY KEY (id)
);

-- moving table to new owner also moves sequence to new owner
-- "pg_indexes" does not have ownership information but can imagine this is moved to new owner aswell
alter table auth.user owner to authenticator;

CREATE TABLE auth.user_prop_types (
    type VARCHAR(10) NOT NULL,
    CONSTRAINT user_prop_types_pk
        PRIMARY KEY (type)
);

alter table auth.user_prop_types owner to authenticator;

CREATE TABLE auth.user_props (
    fk_user_id integer NOT NULL,
    type VARCHAR(10) NOT NULL,
    value VARCHAR(256) NOT NULL,
    tombstone BOOLEAN DEFAULT FALSE,
    cr_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT user_props_fk
        FOREIGN KEY (fk_user_id) REFERENCES auth.user(id) ON DELETE CASCADE,
    CONSTRAINT user_props_types_fk    
     FOREIGN KEY (type) REFERENCES auth.user_prop_types(type) ON DELETE CASCADE
);
-- do not schema prefix for indexes
CREATE INDEX user_props_idx ON auth.user_props(UPPER(type), fk_user_id);
CREATE INDEX user_props_idx2 ON auth.user_props(fk_user_id, UPPER(type));

alter table auth.user_props owner to authenticator;

CREATE TABLE auth.user_props_bin (
    fk_user_id integer NOT NULL,
    type VARCHAR(10) NOT NULL,
    value bytea NOT NULL,
    CONSTRAINT user_props_bin_fk
        FOREIGN KEY (fk_user_id) REFERENCES auth.user(id) ON DELETE CASCADE,
    CONSTRAINT user_props_bin_types_fk    
        FOREIGN KEY (type) REFERENCES auth.user_prop_types(type) ON DELETE CASCADE    
);

CREATE INDEX user_props_bin_idx ON auth.user_props_bin(UPPER(type), fk_user_id);
CREATE INDEX user_props_bin_idx2 ON auth.user_props_bin(fk_user_id, UPPER(type));

alter table auth.user_props_bin owner to authenticator;

-- 
-- postgres=# select * from pg_indexes view where tablespace = 'auth_storage';
--  schemaname |    tablename    |      indexname      |  tablespace  |                                               indexdef
-- ------------+-----------------+---------------------+--------------+-------------------------------------------------------------------------------------------------------
--  auth       | user            | pk_user             | auth_storage | CREATE UNIQUE INDEX pk_user ON auth."user" USING btree (id)
--  auth       | user_prop_types | user_prop_types_pk  | auth_storage | CREATE UNIQUE INDEX user_prop_types_pk ON auth.user_prop_types USING btree (type)
--  auth       | user_props      | user_props_idx      | auth_storage | CREATE INDEX user_props_idx ON auth.user_props USING btree (upper((type)::text), fk_user_id)
--  auth       | user_props      | user_props_idx2     | auth_storage | CREATE INDEX user_props_idx2 ON auth.user_props USING btree (fk_user_id, upper((type)::text))
--  auth       | user_props_bin  | user_props_bin_idx  | auth_storage | CREATE INDEX user_props_bin_idx ON auth.user_props_bin USING btree (upper((type)::text), fk_user_id)
--  auth       | user_props_bin  | user_props_bin_idx2 | auth_storage | CREATE INDEX user_props_bin_idx2 ON auth.user_props_bin USING btree (fk_user_id, upper((type)::text))
-- (6 rows)
-- 
EOSQL
