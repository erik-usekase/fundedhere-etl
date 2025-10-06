# ──────────────────────────────────────────────────────────────────────────────
# Minimal Makefile — delegates logic to ./scripts/*
# ──────────────────────────────────────────────────────────────────────────────

# Load .env if present
ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
endif

# Defaults
EFFECTIVE_DATA_DIR := $(if $(strip $(DATA_DIR)),$(DATA_DIR),./data)
INC_DIR := $(EFFECTIVE_DATA_DIR)/inc_data

.RECIPEPREFIX := >
.SILENT:

# ──────────────────────────────────────────────────────────────────────────────
# Lifecycle (compose or host/remote handled in scripts)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: prep-data up up-wait down logs env psql-host sql sqlf refresh counts

prep-data:
> mkdir -p "$(EFFECTIVE_DATA_DIR)/pgdata" "$(INC_DIR)"

up: prep-data
> scripts/db_up.sh

up-wait: up
> scripts/db_wait.sh

down:
> scripts/db_down.sh

logs:
> scripts/db_logs.sh

env:
> echo "DATA_DIR=$(DATA_DIR)  EFFECTIVE_DATA_DIR=$(EFFECTIVE_DATA_DIR)"
> echo "INC_DIR=$(INC_DIR)"
> echo "DB_MODE=${DB_MODE:-container-bind}"
> echo "PGHOST=$(PGHOST) PGPORT=$(PGPORT) PGDATABASE=$(PGDATABASE) PGUSER=$(PGUSER) PGSSLMODE=$(PGSSLMODE)"
> echo "REMOTE_PGHOST=$(REMOTE_PGHOST) REMOTE_PGPORT=$(REMOTE_PGPORT) REMOTE_PGDATABASE=$(REMOTE_PGDATABASE) REMOTE_PGUSER=$(REMOTE_PGUSER) REMOTE_PGSSLMODE=$(REMOTE_PGSSLMODE)"

psql-host:
> scripts/run_sql.sh -c "select now() as server_time, version();"

sql:
> test -n "$(CMD)" || { echo "Usage: make sql CMD='select 1'"; exit 2; }
> scripts/run_sql.sh -c "$(CMD)"

sqlf:
> test -n "$(FILE)" || { echo "Usage: make sqlf FILE=path.sql"; exit 2; }
> scripts/run_sql.sh -f "$(FILE)"

refresh:
> scripts/run_sql.sh -f scripts/sql-utils/refresh_core.sql

counts:
> scripts/run_sql.sh -f scripts/sql-utils/counts.sql

# ──────────────────────────────────────────────────────────────────────────────
# CSV prep (uses Python utilities under ./scripts/)
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: preview-cols prep-external prep-vatxn prep-repmt-sku prep-repmt-sales prep-all prep-map

preview-cols:
> test -n "$(FILE)" || { echo "Usage: make preview-cols FILE=path.csv"; exit 2; }
> python3 scripts/preview_cols.py "$(FILE)"

prep-external:
> test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-external SRC=in.csv OUT=out.csv"; exit 2; }
> python3 scripts/prep_external.py "$(SRC)" "$(OUT)"

prep-vatxn:
> test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-vatxn SRC=in.csv OUT=out.csv"; exit 2; }
> python3 scripts/prep_vatxn.py "$(SRC)" "$(OUT)"

prep-repmt-sku:
> test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-repmt-sku SRC=in.csv OUT=out.csv"; exit 2; }
> python3 scripts/prep_repmt_sku.py "$(SRC)" "$(OUT)"

prep-repmt-sales:
> test -n "$(SRC)" -a -n "$(OUT)" || { echo "Usage: make prep-repmt-sales SRC=in.csv OUT=out.csv"; exit 2; }
> python3 scripts/prep_repmt_sales.py "$(SRC)" "$(OUT)"

prep-all:
> ./scripts/prep_all.sh "$(INC_DIR)"

prep-map:
> python3 scripts/prep_note_sku_map.py \
    --source "$(if $(strip $(SOURCE)),$(SOURCE),$(INC_DIR)/Sample Files((1) Formula & Output).csv)" \
    --output "$(if $(strip $(OUT)),$(OUT),$(INC_DIR)/note_sku_va_map_prepped.csv)"

# ──────────────────────────────────────────────────────────────────────────────
# CSV loaders — column lists handled by scripts/load_raw.sh
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: load-external load-vatxn load-repmt-sku load-repmt-sales load-all load-all-fresh load-mapping test-health test-level1

load-external:
> test -n "$(FILE)" || { echo "Usage: make load-external FILE=path.csv[.gz]"; exit 2; }
> scripts/load_raw.sh raw.external_accounts "beneficiary_bank_account_number,buy_amount,buy_currency,created_date" "$(FILE)"

load-vatxn:
> test -n "$(FILE)" || { echo "Usage: make load-vatxn FILE=path.csv[.gz]"; exit 2; }
> scripts/load_raw.sh raw.va_txn "sender_virtual_account_id,sender_virtual_account_number,sender_note_id,receiver_virtual_account_id,receiver_virtual_account_number,receiver_note_id,receiver_va_opening_balance,receiver_va_closing_balance,amount,date,remarks" "$(FILE)"

load-repmt-sku:
> test -n "$(FILE)" || { echo "Usage: make load-repmt-sku FILE=path.csv[.gz]"; exit 2; }
> scripts/load_raw.sh raw.repmt_sku "merchant,sku_id,acquirer_fees_expected,acquirer_fees_paid,fh_admin_fees_expected,fh_admin_fees_paid,int_difference_expected,int_difference_paid,sr_principal_expected,sr_principal_paid,sr_interest_expected,sr_interest_paid,jr_principal_expected,jr_principal_paid,jr_interest_expected,jr_interest_paid,spar_merchant,additional_interests_paid_to_fh" "$(FILE)"

load-repmt-sales:
> test -n "$(FILE)" || { echo "Usage: make load-repmt-sales FILE=path.csv[.gz]"; exit 2; }
> scripts/load_raw.sh raw.repmt_sales "merchant,sku_id,total_funds_inflow,sales_proceeds,l2e" "$(FILE)"

load-mapping:
> scripts/load_note_sku_va_map.sh "$(if $(strip $(FILE)),$(FILE),$(INC_DIR)/note_sku_va_map_prepped.csv)"

# Load only PREPPED CSVs (explicit; avoids picking up raw files)
load-all:
> echo "Loading PREPPED CSVs from $(INC_DIR)"
> test -f "$(INC_DIR)/external_accounts_prepped.csv" || { echo "Missing external_accounts_prepped.csv"; exit 2; }
> test -f "$(INC_DIR)/va_txn_prepped.csv"          || { echo "Missing va_txn_prepped.csv"; exit 2; }
> test -f "$(INC_DIR)/repmt_sku_prepped.csv"       || { echo "Missing repmt_sku_prepped.csv"; exit 2; }
> test -f "$(INC_DIR)/repmt_sales_prepped.csv"     || { echo "Missing repmt_sales_prepped.csv"; exit 2; }
> $(MAKE) load-external    FILE="$(INC_DIR)/external_accounts_prepped.csv"
> $(MAKE) load-vatxn       FILE="$(INC_DIR)/va_txn_prepped.csv"
> $(MAKE) load-repmt-sku   FILE="$(INC_DIR)/repmt_sku_prepped.csv"
> $(MAKE) load-repmt-sales FILE="$(INC_DIR)/repmt_sales_prepped.csv"

# Truncate then load-all (clean reload)
load-all-fresh:
> scripts/run_sql.sh -c "truncate raw.external_accounts, raw.va_txn, raw.repmt_sku, raw.repmt_sales;"
> $(MAKE) load-all

# Quick health checks
test-health:
> scripts/run_sql.sh -f scripts/sql-tests/chain_status.sql

test-level1:
> scripts/run_sql.sh -f scripts/sql-tests/level1_pretty.sql
