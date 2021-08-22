-- up
create index tag_prefix_suffix on tag(prefix, suffix)

-- down
drop index tag_prefix_suffix