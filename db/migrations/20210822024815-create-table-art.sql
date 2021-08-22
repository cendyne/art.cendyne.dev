-- up
create table art (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  path text not null
)

-- down
drop table art