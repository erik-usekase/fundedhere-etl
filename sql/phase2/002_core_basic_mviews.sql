-- sql/phase2/002_core_basic_mviews.sql
SET search_path = core, public;

-- (Re)create external accounts MV
DROP MATERIALIZED VIEW IF EXISTS core.mv_external_accounts;
CREATE MATERIALIZED VIEW core.mv_external_accounts AS
SELECT
  btrim(e.beneficiary_bank_account_number)            AS va_number,
  core.to_numeric_safe(e.buy_amount)                   AS buy_amount,
  btrim(e.buy_currency)                                AS buy_currency,
  core.to_tstz_safe(e.created_date)                    AS created_at_utc,
  to_char(core.to_tstz_safe(e.created_date)::date,'YYYY-MM') AS period_ym
FROM raw.external_accounts e;

CREATE INDEX IF NOT EXISTS ix_mv_ext_va     ON core.mv_external_accounts(va_number);
CREATE INDEX IF NOT EXISTS ix_mv_ext_period ON core.mv_external_accounts(period_ym);

-- (Re)create Repayment-SKU MV (expectations by SKU)
DROP MATERIALIZED VIEW IF EXISTS core.mv_repmt_sku;
CREATE MATERIALIZED VIEW core.mv_repmt_sku AS
SELECT
  btrim(s.merchant)                           AS merchant_name,
  btrim(s.sku_id)                             AS sku_id,
  core.to_numeric_safe(s.acquirer_fees_expected)      AS acquirer_fees_expected,
  core.to_numeric_safe(s.acquirer_fees_paid)          AS acquirer_fees_paid,
  core.to_numeric_safe(s.fh_admin_fees_expected)      AS fh_admin_fees_expected,
  core.to_numeric_safe(s.fh_admin_fees_paid)          AS fh_admin_fees_paid,
  core.to_numeric_safe(s.int_difference_expected)     AS int_difference_expected,
  core.to_numeric_safe(s.int_difference_paid)         AS int_difference_paid,
  core.to_numeric_safe(s.sr_principal_expected)       AS sr_principal_expected,
  core.to_numeric_safe(s.sr_principal_paid)           AS sr_principal_paid,
  core.to_numeric_safe(s.sr_interest_expected)        AS sr_interest_expected,
  core.to_numeric_safe(s.sr_interest_paid)            AS sr_interest_paid,
  core.to_numeric_safe(s.jr_principal_expected)       AS jr_principal_expected,
  core.to_numeric_safe(s.jr_principal_paid)           AS jr_principal_paid,
  core.to_numeric_safe(s.jr_interest_expected)        AS jr_interest_expected,
  core.to_numeric_safe(s.jr_interest_paid)            AS jr_interest_paid,
  core.to_numeric_safe(s.spar_merchant)               AS spar_merchant,
  core.to_numeric_safe(s.additional_interests_paid_to_fh) AS additional_interests_paid_to_fh
FROM raw.repmt_sku s;

CREATE INDEX IF NOT EXISTS ix_mv_sku_id ON core.mv_repmt_sku(sku_id);

-- (Re)create Repayment-Sales Proceeds MV (UI inflows by SKU)
DROP MATERIALIZED VIEW IF EXISTS core.mv_repmt_sales;
CREATE MATERIALIZED VIEW core.mv_repmt_sales AS
SELECT
  btrim(r.merchant)                           AS merchant_name,
  btrim(r.sku_id)                             AS sku_id,
  core.to_numeric_safe(r.total_funds_inflow)  AS total_funds_inflow,
  core.to_numeric_safe(r.sales_proceeds)      AS sales_proceeds,
  core.to_numeric_safe(r.l2e)                 AS l2e
FROM raw.repmt_sales r;

CREATE INDEX IF NOT EXISTS ix_mv_sales_sku_id ON core.mv_repmt_sales(sku_id);
