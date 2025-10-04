#!/usr/bin/env bash
set -euo pipefail
echo -e "\n\033[1;35m== Insert demo outflows and refresh ==\033[0m"
make sqlf FILE=scripts/sql-tests/t80_insert_outflow_sample.sql
make sqlf FILE=scripts/sql-tests/refresh.sql
echo -e "\n\033[1;35m== Level 2 preview after outflows ==\033[0m"
make sqlf FILE=scripts/sql-tests/level2a_preview.sql
