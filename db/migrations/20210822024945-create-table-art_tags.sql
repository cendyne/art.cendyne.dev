-- up
create table art_tags (
  id integer primary key,
  public_id text unique not null,
  created_at integer not null default(strftime('%s', 'now')),
  art_id integer not null,
  tag_id integer not null,
  foreign key (art_id) references art(id) on update cascade,
  foreign key (tag_id) references tag(id) on update cascade
)

-- down
drop table art_tags