-- up
create table tag (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  tag text unique not null,
  prefix text,
  suffix text
)

-- down
drop table tag