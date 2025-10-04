# SQL Test Scripts

Run with:
  make sqlf FILE=scripts/sql-tests/<script>.sql

Useful ones:
  - refresh.sql                 : Refresh core materialized views
  - level1_pretty.sql           : Formatted Level-1 output
  - level1_count.sql            : Row count for Level-1
  - chain_status.sql            : Pipeline counts (mappings/external/sales/inflow/level1)
  - category_breakdown.sql      : Counts by VA transaction category
  - top_va_pulled.sql           : Top VA numbers by pulled amount
  - v_level1_export_view.sql    : Creates a pretty export view
  - v_level1_export_select.sql  : Selects from the export view
  - mappings_check.sql          : Shows mapping rows and whether the VA exists in external
  - remarks_add_merchant_repayment.sql : Adds a forgiving mapping for "merchant repayment"
