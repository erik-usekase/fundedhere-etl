-- sql/phase2/002_core_mviews.sql
SET search_path = core, public;

CREATE MATERIALIZED VIEW IF NOT EXISTS core.mv_external_accounts AS
SELECT
  r.beneficiary_bank_account_number       AS va_number,
  core.to_numeric_safe(r.buy_amount)      AS buy_amount,
  NULLIF(r.buy_currency,'')               AS buy_currency,
  core.to_tstz_safe(r.created_date)       AS created_at_utc,
  to_char(core.to_date_safe(r.created_date), 'YYYY-MM') AS period_ym
FROM raw.external_accounts r;

CREATE INDEX IF NOT EXISTS ix_mv_extacc_va ON core.mv_external_accounts(va_number);
CREATE INDEX IF NOT EXISTS ix_mv_extacc_period ON core.mv_external_accounts(period_ym);

CREATE MATERIALIZED VIEW IF NOT EXISTS core.mv_va_txn AS
WITH typed AS (
  SELECT
    r.sender_virtual_account_id,
    r.sender_virtual_account_number          AS sender_va,
    NULLIF(r.sender_note_id,'')              AS sender_note_id,
    r.receiver_virtual_account_id,
    r.receiver_virtual_account_number        AS receiver_va,
    NULLIF(r.receiver_note_id,'')            AS receiver_note_id,
    core.to_numeric_safe(r.receiver_va_opening_balance) AS r_opening_bal,
    core.to_numeric_safe(r.receiver_va_closing_balance) AS r_closing_bal,
    core.to_numeric_safe(r.amount)           AS amount,
    core.to_tstz_safe(r.date)                AS occurred_at_utc,
    lower(coalesce(r.remarks,''))            AS remarks
  FROM raw.va_txn r
),
cat AS (
  SELECT t.*, c.category_code
  FROM typed t
  LEFT JOIN LATERAL (
    SELECT m.category_code
    FROM ref.remarks_category_map m
    WHERE (CASE WHEN m.is_regex THEN t.remarks ~* m.raw_pattern ELSE t.remarks = lower(m.raw_pattern) END)
    ORDER BY m.priority ASC
    LIMIT 1
  ) c ON true
),
map_va AS (
  SELECT c.*,
         nsvm.sku_id      AS sku_from_recv_va,
         nsvm.merchant_id AS merch_from_recv_va
  FROM cat c
  LEFT JOIN ref.note_sku_va_map nsvm
    ON nsvm.va_number = c.receiver_va
),
map_all AS (
  SELECT m.*,
         COALESCE(m.sku_from_recv_va) AS sku_id,
         COALESCE(m.merch_from_recv_va) AS merchant_id,
         COALESCE(m.receiver_va, m.sender_va) AS va_number
  FROM map_va m
)
SELECT
  va_number,
  sku_id,
  merchant_id,
  category_code,
  amount,
  occurred_at_utc,
  to_char(occurred_at_utc::date, 'YYYY-MM') AS period_ym,
  remarks
FROM map_all;

CREATE INDEX IF NOT EXISTS ix_mv_vatxn_va ON core.mv_va_txn(va_number);
CREATE INDEX IF NOT EXISTS ix_mv_vatxn_sku ON core.mv_va_txn(sku_id);
CREATE INDEX IF NOT EXISTS ix_mv_vatxn_cat ON core.mv_va_txn(category_code);
CREATE INDEX IF NOT EXISTS ix_mv_vatxn_period ON core.mv_va_txn(period_ym);

CREATE MATERIALIZED VIEW IF NOT EXISTS core.mv_repmt_sku AS
SELECT
  NULLIF(r.merchant,'') AS merchant_name,
  NULLIF(r.sku_id,'')   AS sku_id,
  core.to_numeric_safe(r.acquirer_fees_expected)  AS acquirer_fees_expected,
  core.to_numeric_safe(r.acquirer_fees_paid)      AS acquirer_fees_paid,
  core.to_numeric_safe(r.fh_admin_fees_expected)  AS fh_admin_fees_expected,
  core.to_numeric_safe(r.fh_admin_fees_paid)      AS fh_admin_fees_paid,
  core.to_numeric_safe(r.int_difference_expected) AS int_difference_expected,
  core.to_numeric_safe(r.int_difference_paid)     AS int_difference_paid,
  core.to_numeric_safe(r.sr_principal_expected)   AS sr_principal_expected,
  core.to_numeric_safe(r.sr_principal_paid)       AS sr_principal_paid,
  core.to_numeric_safe(r.sr_interest_expected)    AS sr_interest_expected,
  core.to_numeric_safe(r.sr_interest_paid)        AS sr_interest_paid,
  core.to_numeric_safe(r.jr_principal_expected)   AS jr_principal_expected,
  core.to_numeric_safe(r.jr_principal_paid)       AS jr_principal_paid,
  core.to_numeric_safe(r.jr_interest_expected)    AS jr_interest_expected,
  core.to_numeric_safe(r.jr_interest_paid)        AS jr_interest_paid,
  core.to_numeric_safe(r.spar_merchant)           AS spar_merchant,
  core.to_numeric_safe(r.additional_interests_paid_to_fh) AS additional_interests_paid_to_fh
FROM raw.repmt_sku r;

CREATE INDEX IF NOT EXISTS ix_mv_repmt_sku ON core.mv_repmt_sku(sku_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS core.mv_repmt_sales AS
SELECT
  NULLIF(r.merchant,'') AS merchant_name,
  NULLIF(r.sku_id,'')   AS sku_id,
  core.to_numeric_safe(r.total_funds_inflow) AS total_funds_inflow,
  core.to_numeric_safe(r.sales_proceeds)     AS sales_proceeds,
  NULLIF(r.l2e,'')      AS l2e
FROM raw.repmt_sales r;

CREATE INDEX IF NOT EXISTS ix_mv_repmt_sales ON core.mv_repmt_sales(sku_id);
