-- up
create table art_file (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  art_id integer not null,
  file_id integer not null
)

-- down
drop table art_file