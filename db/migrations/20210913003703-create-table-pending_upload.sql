-- up
create table pending_upload (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  public_id text unique not null,
  job_id text,
  file_id integer not null
)

-- down
drop table pending_upload