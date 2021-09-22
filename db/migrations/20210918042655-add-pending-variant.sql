-- up
alter table pending_upload_item add column variant text not null default ''

-- down
alter table pending_upload_item drop column variant
