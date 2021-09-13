-- up
create table pending_upload_item (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  pending_upload_id integer not null,
  public_id text unique not null,
  file_id integer
)

-- down
drop table pending_upload_item