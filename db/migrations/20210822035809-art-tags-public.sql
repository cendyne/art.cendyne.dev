-- up
create index art_tags_public_id on art_tags(public_id)

-- down
drop index art_tags_public_id
