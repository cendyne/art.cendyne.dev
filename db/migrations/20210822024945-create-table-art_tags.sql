-- up
create table art_tags (
  id integer primary key,
  created_at integer not null default(strftime('%s', 'now')),
  updated_at integer,
  tag text not null,
  art_id integer not null,
  foreign key (art_id) references art(id) on update cascade
)

-- down
drop table art_tags