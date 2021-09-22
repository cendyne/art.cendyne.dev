-- up
create table original_upload (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  file_id integer not null
)

-- down
drop table original_upload