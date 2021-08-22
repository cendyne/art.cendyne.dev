-- up
create index art_file_index on art_file(art_id, file_id)

-- down
drop index art_file_index
