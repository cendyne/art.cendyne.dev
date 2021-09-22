CREATE TABLE schema_migrations (version text primary key)
CREATE TABLE art (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  name text not null
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

CREATE TABLE file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  path text unique not null,
  digest text unique not null,
  original_name text,
  content_type text,
  size integer not null
)
CREATE INDEX tag_prefix_suffix on tag(prefix, suffix)

CREATE TABLE art_file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  art_id integer not null,
  file_id integer not null
)
CREATE INDEX art_file_index on art_file(art_id, file_id)

CREATE INDEX art_file_index2 on art_file(file_id, art_id)

CREATE TABLE pending_upload (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  public_id text unique not null,
  job_id text,
  file_id integer not null
)
CREATE TABLE pending_upload_item (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  pending_upload_id integer not null,
  public_id text unique not null,
  file_id integer
, content_type text not null default 'application/octet-stream', variant text not null default '')