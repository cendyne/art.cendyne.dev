-- up
create table file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  path text unique not null,
  digest text unique not null,
  original_name text,
  content_type text
)

-- down
drop table file