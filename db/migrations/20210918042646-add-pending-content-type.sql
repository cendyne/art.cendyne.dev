-- up
alter table pending_upload_item add column content_type text not null default 'application/octet-stream'

-- down
alter table pending_upload_item drop column content_type
