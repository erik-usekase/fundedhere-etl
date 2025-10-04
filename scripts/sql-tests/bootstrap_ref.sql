insert into ref.sku(sku_id, merchant_id)
values ('NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','f1c92aad-31c7-4fd3-9250-358a1d85fb7c')
on conflict do nothing;

insert into ref.note_sku_va_map(note_id,sku_id,va_number,merchant_id) values
('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633926172','f1c92aad-31c7-4fd3-9250-358a1d85fb7c'),
('44','NON-STICK GRILL PAN-30CM-1288-636-d7igw7vTBR','8850633781134','f1c92aad-31c7-4fd3-9250-358a1d85fb7c')
on conflict do nothing;
