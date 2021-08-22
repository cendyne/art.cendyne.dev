-- up
create table short_id (
  id integer primary key,
  public_id text unique
)

-- down
drop table short_id