#!/usr/bin/env bash
set -euo pipefail

step() { echo -e "\n\033[1;34m== $* ==\033[0m"; }

step "Counts BEFORE (may be zero after a clean reset)"
make counts || true

step "Bootstrap merchant"
make sqlf FILE=scripts/sql-tests/t10_bootstrap_merchant.sql

step "Bootstrap SKU + VA map"
make sqlf FILE=scripts/sql-tests/t20_bootstrap_sku_and_map.sql

step "Refresh typed/mart layers"
make sqlf FILE=scripts/sql-tests/refresh.sql

step "Level 1 preview (if view exists)"
make sqlf FILE=scripts/sql-tests/level1_count.sql || true
make sqlf FILE=scripts/sql-tests/level1_pretty.sql || true

step "Flows after Option-B (if installed)"
make sqlf FILE=scripts/sql-tests/flows_after_option_b.sql || true

step "Level 2 preview"
make sqlf FILE=scripts/sql-tests/level2a_preview.sql || true

step "Category audit"
make sqlf FILE=scripts/sql-tests/category_audit_top50.sql || true
