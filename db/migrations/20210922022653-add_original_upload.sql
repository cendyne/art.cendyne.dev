-- up
alter table pending_upload add column original_upload_id integer

-- down
alter table pending_upload drop column original_upload_id
