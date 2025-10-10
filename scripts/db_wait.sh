#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SKIP_ENV_FILE:-}" ] && [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DB_MODE="${DB_MODE:-container-bind}"

# Resolve docker compose CLI upfront for container-based fallbacks
COMPOSE_CMD=()
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  fi
fi

PROFILE_ARGS=()
DB_SERVICE_NAME="postgres"
case "$DB_MODE" in
  container-nobind)
    PROFILE_ARGS+=(--profile db-local-nobind)
    DB_SERVICE_NAME="postgres_nobind"
    ;;
  host|remote)
    DB_SERVICE_NAME=""
    ;;
  *)
    PROFILE_ARGS+=(--profile db-local-bind)
    DB_SERVICE_NAME="postgres"
    ;;
esac

HOST="${PGHOST:-localhost}"
PORT="${PGPORT:-5433}"
USER="${PGUSER:-appuser}"
DB="${PGDATABASE:-appdb}"
SSL="${PGSSLMODE:-disable}"
PASS="${PGPASSWORD:-changeme}"

if [ "$DB_MODE" = "remote" ]; then
  HOST="${REMOTE_PGHOST:-localhost}"
  PORT="${REMOTE_PGPORT:-5432}"
  USER="${REMOTE_PGUSER:-appuser}"
  DB="${REMOTE_PGDATABASE:-appdb}"
  SSL="${REMOTE_PGSSLMODE:-require}"
  PASS="${REMOTE_PGPASSWORD:-changeme}"
fi

host_check_attempted=0
if command -v pg_isready >/dev/null 2>&1; then
  host_check_attempted=1
  echo "Waiting for Postgres at ${HOST}:${PORT} ..."
  for _ in $(seq 1 120); do
    if PGSSLMODE="$SSL" PGPASSWORD="$PASS" \
      pg_isready -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" >/dev/null 2>&1; then
      echo "Postgres is ready."
      exit 0
    fi
    sleep 1
  done
else
  # No local client available; advise user but continue with container fallback.
  echo "pg_isready not found locally; skipping direct host check." >&2
fi

# Container fallback covers local Docker workflows or missing host clients.
if [ -n "$DB_SERVICE_NAME" ] && [ ${#COMPOSE_CMD[@]} -gt 0 ] && \
   "${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" ps "$DB_SERVICE_NAME" >/dev/null 2>&1; then
  if [ $host_check_attempted -eq 1 ]; then
    echo "Host check timed out; trying inside the container..."
  else
    echo "Checking Postgres readiness inside the container..."
  fi
  for _ in $(seq 1 60); do
    if "${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" exec -T "$DB_SERVICE_NAME" \
         pg_isready -h localhost -p 5432 \
         -U "${POSTGRES_USER:-appuser}" \
         -d "${POSTGRES_DB:-appdb}" >/dev/null 2>&1; then
      echo "Postgres is ready (container)."
      exit 0
    fi
    sleep 1
  done
fi

echo "Timeout waiting for Postgres"
exit 1
