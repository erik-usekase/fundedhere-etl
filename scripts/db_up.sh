#!/usr/bin/env bash
set -euo pipefail
if [ -f ".env" ]; then set -a; . ./.env; set +a; fi
DB_MODE="${DB_MODE:-container-bind}"
EFFECTIVE_DATA_DIR="${DATA_DIR:-./data}"
mkdir -p "${EFFECTIVE_DATA_DIR}" "${EFFECTIVE_DATA_DIR}/pgdata" "${EFFECTIVE_DATA_DIR}/inc_data"
case "$DB_MODE" in
  container-bind)   docker compose --profile db-local-bind up -d ;;
  container-nobind) docker compose --profile db-local-nobind up -d ;;
  host)   echo "DB_MODE=host: using local Postgres at ${PGHOST:-localhost}:${PGPORT:-5433} (no container)" ;;
  remote) echo "DB_MODE=remote: using remote Postgres at ${REMOTE_PGHOST:-?}:${REMOTE_PGPORT:-5432} (no container)" ;;
  *) echo "Unknown DB_MODE: $DB_MODE" >&2; exit 2 ;;
esac
