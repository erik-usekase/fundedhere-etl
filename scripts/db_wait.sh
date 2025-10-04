#!/usr/bin/env bash
set -euo pipefail
if [ -f ".env" ]; then set -a; . ./.env; set +a; fi

DB_MODE="${DB_MODE:-container-bind}"

# Prefer host check (fast). If it fails, try inside the container.
if [ "$DB_MODE" = "remote" ]; then
  HOST="${REMOTE_PGHOST:-localhost}"; PORT="${REMOTE_PGPORT:-5432}"
  USER="${REMOTE_PGUSER:-appuser}"; DB="${REMOTE_PGDATABASE:-appdb}"
  SSL="${REMOTE_PGSSLMODE:-require}"; PASS="${REMOTE_PGPASSWORD:-changeme}"
else
  HOST="${PGHOST:-localhost}"; PORT="${PGPORT:-5433}"
  USER="${PGUSER:-appuser}"; DB="${PGDATABASE:-appdb}"
  SSL="${PGSSLMODE:-disable}"; PASS="${PGPASSWORD:-changeme}"
fi

echo "Waiting for Postgres at ${HOST}:${PORT} ..."
for i in $(seq 1 120); do
  if PGSSLMODE="$SSL" PGPASSWORD="$PASS" pg_isready -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" >/dev/null 2>&1; then
    echo "Postgres is ready."; exit 0
  fi
  sleep 1
done

# Fallback: check inside the container (handles missing/incorrect host port mapping)
echo "Host check timed out; trying inside the container..."
if docker compose ps postgres >/dev/null 2>&1; then
  for i in $(seq 1 60); do
    if docker compose exec -T postgres pg_isready -h localhost -p 5432 -U "${POSTGRES_USER:-appuser}" -d "${POSTGRES_DB:-appdb}" >/dev/null 2>&1; then
      echo "Postgres is ready (container)."; exit 0
    fi
    sleep 1
  done
fi

echo "Timeout waiting for Postgres"; exit 1
