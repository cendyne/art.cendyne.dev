-- up
create unique index art_tags_tag on art_tags(tag, art_id)

-- down
drop index art_tags_tag