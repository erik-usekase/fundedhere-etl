-- Merchants & SKUs
create table if not exists ref.merchant (
  merchant_id uuid primary key default gen_random_uuid(),
  merchant_name text unique not null,
  merchant_name_norm text generated always as
    (lower(regexp_replace(merchant_name, '\s+', ' ', 'g'))) stored
);

create table if not exists ref.sku (
  sku_id text primary key,
  merchant_id uuid not null references ref.merchant(merchant_id)
);

-- Join glue across feeds
-- NOTE: no UNIQUE constraint with expressions; we add a UNIQUE INDEX after the table.
drop table if exists ref.note_sku_va_map cascade;
create table ref.note_sku_va_map (
  note_id     text,
  sku_id      text references ref.sku(sku_id),
  va_number   text,                  -- normalized virtual/bank account number
  merchant_id uuid references ref.merchant(merchant_id),
  valid_from  date,
  valid_to    date
);

-- Enforce uniqueness across the trio using a unique index on expressions
create unique index if not exists ux_note_sku_va_map_composite
  on ref.note_sku_va_map (coalesce(note_id,''), coalesce(va_number,''), coalesce(sku_id,''));

-- Helpful lookup indexes
create index if not exists ix_ref_note on ref.note_sku_va_map (note_id);
create index if not exists ix_ref_va   on ref.note_sku_va_map (va_number);
create index if not exists ix_ref_sku  on ref.note_sku_va_map (sku_id);

-- Map VA remarks to business categories for Level 2 waterfall
-- category_code examples:
--  'merchant_repayment','mgmt_fee','admin_fee','int_diff',
--  'sr_prin','sr_int','jr_prin','jr_int','spar','xfer_sku','top_up','other'
create table if not exists ref.remarks_category_map (
  raw_pattern   text not null,   -- literal or regex pattern
  category_code text not null,
  is_regex      boolean not null default false,
  priority      int not null default 100,
  constraint remarks_category_map_key unique (raw_pattern, category_code)
);

-- Seed a few safe defaults (edit/expand later)
insert into ref.remarks_category_map(raw_pattern,category_code,is_regex,priority)
values
  ('merchant-repayment','merchant_repayment',false,10),
  ('fh-admin-fee','admin_fee',false,20),
  ('management fee','mgmt_fee',true,30),
  ('sr interest','sr_int',true,40),
  ('sr principal','sr_prin',true,40),
  ('jr interest','jr_int',true,50),
  ('jr principal','jr_prin',true,50),
  ('spar','spar',true,60)
on conflict do nothing;
