-- scripts/sql-tests/level2a_preview.sql
SELECT
  "SKU ID",
  "Merchant",
  "Amount Received",
  "Management Fee Paid",
  "Administrative Fee Paid",
  "Interest Difference Paid",
  "Senior Principal Paid",
  "Senior Interest Paid",
  "Junior Principal Paid",
  "Junior Interest Paid",
  "SPAR Paid",
  "Amount Distributed Down the Repayment Waterfall",
  "Management Fee Expected",
  "Administrative Fee Expected",
  "Interest Difference Expected",
  "Senior Principal Expected",
  "Senior Interest Expected",
  "Junior Principal Expected",
  "Junior Interest Expected",
  "SPAR Expected",
  "Management Fee Outstanding",
  "Administrative Fee Outstanding",
  "Interest Difference Outstanding",
  "Senior Principal Outstanding",
  "Senior Interest Outstanding",
  "Junior Principal Outstanding",
  "Junior Interest Outstanding",
  "Fund Transferred to Other SKU",
  "Fund Transferred from Other SKU"
FROM mart.v_level2a
ORDER BY 1
LIMIT 100;
