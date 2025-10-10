#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <make-target> [additional make args...]" >&2
  echo "Example: $0 etl-verify" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DB_MODE="${DB_MODE:-container-bind}"
AUTO_DB_SHUTDOWN="${AUTO_DB_SHUTDOWN:-0}"

EFFECTIVE_DATA_DIR="${DATA_DIR:-$PROJECT_ROOT/data}"
mkdir -p "${EFFECTIVE_DATA_DIR}" "${EFFECTIVE_DATA_DIR}/inc_data" "${EFFECTIVE_DATA_DIR}/pgdata"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Neither 'docker compose' nor 'docker-compose' is available. Install Docker Desktop or the Docker Compose CLI." >&2
  exit 2
fi

PROFILE_ARGS=(--profile cli)
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
    ;;
esac

FORWARD_ENV=(CMD FILE SRC OUT SOURCE TARGET ARGS FAIL_ON_LEVEL1_VARIANCE SHOW_PREVIEW)
RUN_ENV_ARGS=()
MAKE_OVERRIDE_ARGS=()
for var in "${FORWARD_ENV[@]}"; do
  if [ -n "${!var-}" ]; then
    RUN_ENV_ARGS+=(-e "$var")
  fi
done

QUIET_DEFAULT="${QUIET:-1}"
RUN_ENV_ARGS+=(-e QUIET="$QUIET_DEFAULT")
MAKE_OVERRIDE_ARGS+=("QUIET=$QUIET_DEFAULT")

SKIP_BUILD="${SKIP_BUILD:-0}"
if [ "$SKIP_BUILD" != "1" ]; then
  "${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" build etl
fi

DB_STARTED_BY_WRAPPER=0
cleanup() {
  if [ "$DB_STARTED_BY_WRAPPER" = "1" ] && [ "$AUTO_DB_SHUTDOWN" = "1" ]; then
    ./scripts/db_down.sh
  fi
}
trap cleanup EXIT

if [ "${1:-}" != "help" ] && [ -n "$DB_SERVICE_NAME" ]; then
  PG_CONTAINER=$("${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" ps -q "$DB_SERVICE_NAME" 2>/dev/null || true)
  if [ -z "$PG_CONTAINER" ]; then
    echo "Postgres container is not running. Bootstrapping it now..."
    ./scripts/db_up.sh
    ./scripts/db_wait.sh
    PG_CONTAINER=$("${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" ps -q "$DB_SERVICE_NAME" 2>/dev/null || true)
    if [ -z "$PG_CONTAINER" ]; then
      echo "Failed to start Postgres container. Check Docker logs." >&2
      exit 3
    fi
    DB_STARTED_BY_WRAPPER=1
  fi
fi

if [ -n "$DB_SERVICE_NAME" ]; then
  RUN_ENV_ARGS+=(-e PGHOST=postgres)
  RUN_ENV_ARGS+=(-e PGPORT=5432)
  RUN_ENV_ARGS+=(-e PGSSLMODE=disable)
  RUN_ENV_ARGS+=(-e PGUSER=${POSTGRES_USER:-appuser})
  RUN_ENV_ARGS+=(-e PGDATABASE=${POSTGRES_DB:-appdb})
  RUN_ENV_ARGS+=(-e PGPASSWORD=${POSTGRES_PASSWORD:-changeme})
  RUN_ENV_ARGS+=(-e DB_MODE=container-bind)
  RUN_ENV_ARGS+=(-e SKIP_ENV_FILE=1)
  MAKE_OVERRIDE_ARGS+=("PGHOST=postgres")
  MAKE_OVERRIDE_ARGS+=("PGPORT=5432")
  MAKE_OVERRIDE_ARGS+=("PGSSLMODE=disable")
  MAKE_OVERRIDE_ARGS+=("PGUSER=${POSTGRES_USER:-appuser}")
  MAKE_OVERRIDE_ARGS+=("PGDATABASE=${POSTGRES_DB:-appdb}")
  MAKE_OVERRIDE_ARGS+=("PGPASSWORD=${POSTGRES_PASSWORD:-changeme}")
  MAKE_OVERRIDE_ARGS+=("DB_MODE=container-bind")
fi

"${COMPOSE_CMD[@]}" "${PROFILE_ARGS[@]}" run --rm "${RUN_ENV_ARGS[@]}" etl make "${MAKE_OVERRIDE_ARGS[@]}" "$@"

if [ "$DB_STARTED_BY_WRAPPER" = "1" ] && [ "$AUTO_DB_SHUTDOWN" != "1" ]; then
  cat <<EOF

Postgres is still running (started by scripts/etl_make.sh).
Use 'make down' when you are finished to release port ${POSTGRES_PORT:-5433}.
EOF
fi
