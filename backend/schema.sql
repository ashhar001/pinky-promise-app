-- schema.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT    NOT NULL,
  email       TEXT    UNIQUE NOT NULL,
  password    TEXT    NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);