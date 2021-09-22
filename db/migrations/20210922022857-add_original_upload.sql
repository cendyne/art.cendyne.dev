-- up
alter table art add column original_upload_id integer

-- down
alter table art drop column original_upload_id
