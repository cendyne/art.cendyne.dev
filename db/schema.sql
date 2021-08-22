CREATE TABLE schema_migrations (version text primary key)
CREATE TABLE art (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  path text not null
)
CREATE TABLE tag (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  tag text unique not null,
  prefix text,
  suffix text
)
CREATE TABLE art_tags (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  art_id integer not null,
  tag_id integer not null,
  foreign key (art_id) references art(id) on update cascade,
  foreign key (tag_id) references tag(id) on update cascade
)
CREATE TABLE short_id (
  id integer primary key,
  public_id text unique
)
CREATE UNIQUE INDEX art_tags_tag on art_tags(tag_id, art_id)

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
CREATE INDEX tag_prefix_suffix on tag(prefix, suffix)
