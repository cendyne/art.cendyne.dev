-- up
create index art_file_index2 on art_file(file_id, art_id)

-- down
drop index art_file_index2
