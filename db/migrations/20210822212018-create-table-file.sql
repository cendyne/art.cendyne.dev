-- up
create table file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  path text unique not null,
  digest text unique not null,
  original_name text,
  content_type text,
  size integer not null
)

-- down
drop table file