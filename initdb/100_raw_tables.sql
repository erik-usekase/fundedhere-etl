-- (a) External Accounts (Merchant)
create table if not exists raw.external_accounts (
  source_file text,
  load_at timestamptz not null default now(),
  beneficiary_bank_account_number text,
  buy_amount                      text,
  buy_currency                    text,
  created_date                    text
);

-- (b) VA Transaction Report (All)
create table if not exists raw.va_txn (
  source_file text,
  load_at timestamptz not null default now(),
  sender_virtual_account_id       text,
  sender_virtual_account_number   text,
  sender_note_id                  text,
  receiver_virtual_account_id     text,
  receiver_virtual_account_number text,
  receiver_note_id                text,
  receiver_va_opening_balance     text,
  receiver_va_closing_balance     text,
  amount                          text,
  date                            text,
  remarks                         text
);

-- (c) Repmt-SKU (UI Data)
create table if not exists raw.repmt_sku (
  source_file text,
  load_at timestamptz not null default now(),
  merchant                         text,
  sku_id                           text,
  acquirer_fees_expected           text,
  acquirer_fees_paid               text,
  fh_admin_fees_expected           text,
  fh_admin_fees_paid               text,
  int_difference_expected          text,
  int_difference_paid              text,
  sr_principal_expected            text,
  sr_principal_paid                text,
  sr_interest_expected             text,
  sr_interest_paid                 text,
  jr_principal_expected            text,
  jr_principal_paid                text,
  jr_interest_expected             text,
  jr_interest_paid                 text,
  spar_merchant                    text,
  additional_interests_paid_to_fh  text
);

-- (d) Repmt-Sales Proceeds (UI Data)
create table if not exists raw.repmt_sales (
  source_file text,
  load_at timestamptz not null default now(),
  merchant            text,
  sku_id              text,
  total_funds_inflow  text,
  sales_proceeds      text,
  l2e                 text
);
