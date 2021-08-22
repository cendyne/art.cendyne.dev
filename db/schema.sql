CREATE TABLE schema_migrations (version text primary key)
CREATE TABLE art (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  path text not null
)
CREATE TABLE art_tags (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  tag text not null,
  art_id integer not null,
  foreign key (art_id) references art(id) on update cascade
)