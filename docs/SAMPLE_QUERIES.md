# Sample Queries - FundedHere ETL Views

## Quick Start - View Excel Sheet Data

### Sheet 1 - Simple View (8 Columns)
```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Account Number\",
  \"Merchant\",
  \"Amount Pulled\",
  \"Amount Received\",
  \"Variance\",
  \"Sales Proceeds\"
FROM mart.v_level1
ORDER BY \"Amount Received\" DESC
LIMIT 10;"
```

### Sheet 2a - Detailed View (6 Columns)
```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Received\",
  \" Amount Distributed Down the Repayment Waterfall\" AS \"Waterfall\",
  \"Fund Transferred to Other SKU\" AS \"Transfers\",
  \"Variance\"
FROM mart.v_level2a
ORDER BY \"Amount Received\" DESC
LIMIT 10;"
```

### Sheet 2b - Detailed View (12 Columns)
```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Received\",
  \"Variance\"
FROM mart.v_level2b
ORDER BY \"Amount Received\" DESC
LIMIT 10;"
```

---

## Sheet 1 (v_level1) - Cash Flow Summary

**Excel Source:** `(1) Formula & Output)` sheet
**Columns:** 8 total
**Purpose:** Compare Amount Received vs Amount Pulled from external accounts

### Column Mapping

| # | Column Name | Excel Formula | Description |
|---|-------------|---------------|-------------|
| 1 | SKU ID | UNIQUE filter | Unique SKU identifier |
| 2 | Account Number | From mapping table | Virtual account number |
| 3 | Merchant | XLOOKUP | Merchant name |
| 4 | Amount Pulled | SUMIFS(external_accounts.buy_amount) | Amount pulled from external accounts |
| 5 | Amount Received | SUMIFS(va_txn WHERE remarks='merchant-repayment') | Repayment received from merchant |
| 6 | Variance | Amount Received - Amount Pulled | Difference (usually 0) |
| 7 | Sales Proceeds | XLOOKUP(repmt_sales) | Sales proceeds from repmt_sales table |
| 8 | Variance (2) | Sales Proceeds - Amount Pulled | Alternative variance |

### Key Statistics

```bash
# Total SKUs and variance distribution
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  COUNT(*) AS total_skus,
  COUNT(CASE WHEN \"Variance\" = 0 THEN 1 END) AS variance_zero,
  COUNT(CASE WHEN \"Variance\" <> 0 THEN 1 END) AS variance_non_zero,
  MIN(\"Variance\") AS min_variance,
  MAX(\"Variance\") AS max_variance,
  ROUND(AVG(\"Variance\")::numeric, 2) AS avg_variance
FROM mart.v_level1;"
```

**Expected Results:**
- Total SKUs: 366
- Variance = 0: 363 SKUs (99%)
- Non-zero variance: 3 SKUs (small negative values)

### Find SKUs with Non-Zero Variance

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Pulled\",
  \"Amount Received\",
  \"Variance\",
  \"Sales Proceeds\"
FROM mart.v_level1
WHERE \"Variance\" <> 0
ORDER BY \"Variance\";"
```

### Top 10 by Amount Received

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  ROUND(\"Amount Received\"::numeric, 2) AS \"Amount Received\",
  ROUND(\"Variance\"::numeric, 2) AS \"Variance\"
FROM mart.v_level1
WHERE \"Amount Received\" > 0
ORDER BY \"Amount Received\" DESC
LIMIT 10;"
```

### Search by Merchant

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Pulled\",
  \"Amount Received\",
  \"Variance\"
FROM mart.v_level1
WHERE \"Merchant\" LIKE '%Sdn Bhd%'
ORDER BY \"Amount Received\" DESC;"
```

### Test SKU Verification

```bash
# Should show variance = 0.00
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT * FROM mart.v_level1
WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';"
```

**Expected Result:**
- Amount Pulled: 1012.48
- Amount Received: 1012.48
- Variance: 0.00
- Sales Proceeds: 1012.48

---

## Sheet 2a (v_level2a) - Detailed Reconciliation

**Excel Source:** `(2a) Formula & Output)` sheet
**Columns:** 6 main columns (+ 52 detail columns)
**Purpose:** Detailed breakdown of Amount Received vs Waterfall distribution + Transfers

### Column Mapping (Main Columns)

| # | Column Name | Excel Formula | Description |
|---|-------------|---------------|-------------|
| 1 | SKU ID | UNIQUE filter | Unique SKU identifier |
| 2 | Merchant | XLOOKUP | Merchant name |
| 3 | Amount Received | SUMIFS(va_txn WHERE remarks<>'note-issued-transfer-to-sku') | ALL inflows except note transfers |
| 4 | Amount Distributed | SUM of 10 waterfall categories | Total paid to investors/fees |
| 5 | Fund Transferred to Other SKU | SUMIFS WHERE remarks='transfer-to-another-sku' | Transfers out |
| 6 | Variance | Amount Received - Waterfall - Transfers | Should be 0 |

### Test SKU Verification (Sheet 2a)

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Received\",
  \" Amount Distributed Down the Repayment Waterfall\" AS \"Waterfall\",
  \"Fund Transferred to Other SKU\" AS \"Transfers\",
  \"Variance\"
FROM mart.v_level2a
WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';"
```

**Expected Result:**
- Amount Received: 15,284.44 (ALL inflows)
- Waterfall: 1,186.43
- Transfers: 14,098.01
- Variance: 0.00

---

## Sheet 2b (v_level2b) - Alternative Reconciliation

**Excel Source:** `(2b) Formula & Output)` sheet
**Columns:** 12 columns
**Purpose:** Similar to Sheet 2a but with different presentation

### Test SKU Verification (Sheet 2b)

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  \"SKU ID\",
  \"Merchant\",
  \"Amount Received\",
  \"Variance\"
FROM mart.v_level2b
WHERE \"SKU ID\" = '4 HOLE EGG PAN-1288-636-92rxuDoq6U';"
```

---

## Comparison Queries

### Sheet 1 vs Sheet 2a: Amount Received Difference

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  s1.\"SKU ID\",
  s1.\"Merchant\",
  s1.\"Amount Received\" AS \"Sheet1_Received\",
  s2a.\"Amount Received\" AS \"Sheet2a_Received\",
  (s2a.\"Amount Received\" - s1.\"Amount Received\") AS \"Difference\"
FROM mart.v_level1 s1
JOIN mart.v_level2a s2a ON s1.\"SKU ID\" = s2a.\"SKU ID\"
WHERE (s2a.\"Amount Received\" - s1.\"Amount Received\") > 0
ORDER BY \"Difference\" DESC
LIMIT 10;"
```

**Why Different?**
- Sheet 1: Only `merchant-repayment` transactions
- Sheet 2a: ALL inflows except `note-issued-transfer-to-sku`

---

## Raw Data Queries

### Check External Accounts for SKU

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  beneficiary_bank_account_number,
  buy_amount,
  created_date
FROM raw.external_accounts
WHERE beneficiary_bank_account_number = '8850633654198'
ORDER BY created_date;"
```

### Check VA Transactions for SKU

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  date,
  remarks,
  amount,
  receiver_virtual_account_id
FROM raw.va_txn
WHERE receiver_virtual_account_id = '4 HOLE EGG PAN-1288-636-92rxuDoq6U'
  AND remarks = 'merchant-repayment'
ORDER BY date;"
```

### Row Counts

```bash
docker exec app-postgres psql -U appuser -d appdb -c "
SELECT
  'external_accounts' AS table_name, COUNT(*) AS row_count FROM raw.external_accounts
UNION ALL
SELECT 'va_txn', COUNT(*) FROM raw.va_txn
UNION ALL
SELECT 'repmt_sku', COUNT(*) FROM raw.repmt_sku
UNION ALL
SELECT 'repmt_sales', COUNT(*) FROM raw.repmt_sales
UNION ALL
SELECT 'v_level1', COUNT(*) FROM mart.v_level1
UNION ALL
SELECT 'v_level2a', COUNT(*) FROM mart.v_level2a
UNION ALL
SELECT 'v_level2b', COUNT(*) FROM mart.v_level2b;"
```

**Expected:**
- external_accounts: 2,718 rows
- va_txn: 28,599 rows
- repmt_sku: 366 rows
- repmt_sales: 366 rows
- v_level1: 366 rows
- v_level2a: 366 rows
- v_level2b: 366 rows

---

## pgAdmin Queries (Raw SQL)

These queries can be copied directly into pgAdmin:

### Sheet 1 - Top 5 by Amount
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Pulled"::numeric, 2) AS "Amount Pulled",
  ROUND("Amount Received"::numeric, 2) AS "Amount Received",
  ROUND("Variance"::numeric, 2) AS "Variance"
FROM mart.v_level1
WHERE "Amount Received" > 0
ORDER BY "Amount Received" DESC
LIMIT 5;
```

### Sheet 2a - Top 5 by Amount
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received"::numeric, 2) AS "Amount Received",
  ROUND(" Amount Distributed Down the Repayment Waterfall"::numeric, 2) AS "Waterfall",
  ROUND("Fund Transferred to Other SKU"::numeric, 2) AS "Transfers",
  ROUND("Variance"::numeric, 2) AS "Variance"
FROM mart.v_level2a
ORDER BY "Amount Received" DESC
LIMIT 5;
```

### Sheet 2b - Top 5 by Amount
```sql
SELECT
  "SKU ID",
  "Merchant",
  ROUND("Amount Received"::numeric, 2) AS "Amount Received",
  ROUND("Variance"::numeric, 2) AS "Variance"
FROM mart.v_level2b
ORDER BY "Amount Received" DESC
LIMIT 5;
```

---

## Connection Info (pgAdmin)

**Host:** localhost
**Port:** 5433
**Database:** appdb
**User:** appuser
**Password:** changeme

---

_For more details on view definitions, see `sql/phase2/010_mart_views.sql` (Sheet 1) and `sql/phase2/020_mart_level2.sql` (Sheets 2a/2b)._
