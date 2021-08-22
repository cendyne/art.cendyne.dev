CREATE TABLE schema_migrations (version text primary key)
CREATE TABLE art (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  path text not null
)
CREATE TABLE art_tags (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  tag text not null,
  art_id integer not null,
  foreign key (art_id) references art(id) on update cascade
)
CREATE TABLE short_id (
  id integer primary key,
  public_id text unique
)
CREATE UNIQUE INDEX art_tags_tag on art_tags(tag, art_id)

CREATE INDEX art_public_id on art(public_id)

CREATE INDEX art_tags_public_id on art_tags(public_id)

CREATE UNIQUE INDEX art_path on art(path)

CREATE TABLE file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  path text unique not null,
  digest text unique not null,
  original_name text,
  content_type text
)