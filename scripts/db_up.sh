#!/usr/bin/env bash
set -euo pipefail
if [ -z "${SKIP_ENV_FILE:-}" ] && [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Neither 'docker compose' nor 'docker-compose' is available. Install Docker Desktop or the Docker Compose CLI." >&2
  exit 2
fi

DB_MODE="${DB_MODE:-container-bind}"
EFFECTIVE_DATA_DIR="${DATA_DIR:-./data}"
mkdir -p "${EFFECTIVE_DATA_DIR}" "${EFFECTIVE_DATA_DIR}/pgdata" "${EFFECTIVE_DATA_DIR}/inc_data"

case "$DB_MODE" in
  container-bind)   "${COMPOSE_CMD[@]}" --profile db-local-bind up -d ;;
  container-nobind) "${COMPOSE_CMD[@]}" --profile db-local-nobind up -d ;;
  host)   echo "DB_MODE=host: using local Postgres at ${PGHOST:-localhost}:${PGPORT:-5433} (no container)" ;;
  remote) echo "DB_MODE=remote: using remote Postgres at ${REMOTE_PGHOST:-?}:${REMOTE_PGPORT:-5432} (no container)" ;;
  *) echo "Unknown DB_MODE: $DB_MODE" >&2; exit 2 ;;
esac
