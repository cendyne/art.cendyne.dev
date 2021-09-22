-- up
create index original_upload_file_id on original_upload(file_id)

-- down
drop index original_upload_file_id
