-- up
create index art_public_id on art(public_id)

-- down
drop index art_public_id
