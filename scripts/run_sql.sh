#!/usr/bin/env bash
set -euo pipefail

# Optionally load .env (skipped when SKIP_ENV_FILE=1 is present or PGHOST already defined)
if [ -z "${SKIP_ENV_FILE:-}" ] && [ -f ".env" ] && [ -z "${PGHOST:-}" ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DB_MODE="${DB_MODE:-container-bind}"

# Respect explicit PG* overrides; otherwise choose sensible defaults per mode
if [ -z "${PGHOST:-}" ] || [ -z "${PGPORT:-}" ]; then
  case "$DB_MODE" in
    remote)
      PGHOST="${PGHOST:-${REMOTE_PGHOST:-localhost}}"
      PGPORT="${PGPORT:-${REMOTE_PGPORT:-5432}}"
      PGDATABASE="${PGDATABASE:-${REMOTE_PGDATABASE:-appdb}}"
      PGUSER="${PGUSER:-${REMOTE_PGUSER:-appuser}}"
      PGPASSWORD="${PGPASSWORD:-${REMOTE_PGPASSWORD:-changeme}}"
      PGSSLMODE="${PGSSLMODE:-${REMOTE_PGSSLMODE:-require}}"
      ;;
    host)
      PGHOST="${PGHOST:-localhost}"
      PGPORT="${PGPORT:-5433}"
      PGDATABASE="${PGDATABASE:-appdb}"
      PGUSER="${PGUSER:-appuser}"
      PGPASSWORD="${PGPASSWORD:-changeme}"
      PGSSLMODE="${PGSSLMODE:-disable}"
      ;;
    container-nobind|container-bind|*)
      PGHOST="${PGHOST:-postgres}"
      PGPORT="${PGPORT:-5432}"
      PGDATABASE="${PGDATABASE:-appdb}"
      PGUSER="${PGUSER:-appuser}"
      PGPASSWORD="${PGPASSWORD:-changeme}"
      PGSSLMODE="${PGSSLMODE:-disable}"
      ;;
  esac
fi

export PAGER=cat
export PSQL_PAGER=cat

# Custom GUC passthroughs
declare -A PSQL_GUCS
if [ -n "${FAIL_ON_LEVEL1_VARIANCE:-}" ]; then
  PSQL_GUCS["etlsuite.fail_on_level1_variance"]="$FAIL_ON_LEVEL1_VARIANCE"
fi

# Determine invocation strategy
if command -v psql >/dev/null 2>&1; then
  PSQL=(psql -X -v ON_ERROR_STOP=1 --pset=pager=off -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE")
else
  if [ "$DB_MODE" = "remote" ] || [ "$DB_MODE" = "host" ]; then
    echo "psql is not installed locally and DB_MODE=$DB_MODE. Install PostgreSQL client tools or run inside the Docker wrapper." >&2
    exit 2
  fi
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    echo "psql is not available and Docker Compose is missing. Install one of them to run SQL commands." >&2
    exit 2
  fi
  PSQL=("${COMPOSE_CMD[@]}" exec -T postgres env \
    PGPASSWORD="$PGPASSWORD" \
    PGDATABASE="$PGDATABASE" \
    PGUSER="$PGUSER" \
    PGSSLMODE="$PGSSLMODE" \
    psql -X -v ON_ERROR_STOP=1 --pset=pager=off -h localhost -p 5432 -U "$PGUSER" -d "$PGDATABASE")
fi

for guc in "${!PSQL_GUCS[@]}"; do
  PSQL+=("-c" "select set_config('$guc', '${PSQL_GUCS[$guc]}', false);")
done

usage(){ echo "Usage: $0 [-c SQL] [-f file.sql] [-v name=value]"; exit 2; }

SQL_CMD=""
SQL_FILE=""
EXTRA_ARGS=()

while getopts ":c:f:v:" opt; do
  case "$opt" in
    c) SQL_CMD="$OPTARG" ;;
    f) SQL_FILE="$OPTARG" ;;
    v) EXTRA_ARGS+=("-v" "$OPTARG") ;;
    *) usage ;;
  esac
done

export PGPASSWORD PGSSLMODE PGHOST PGPORT PGDATABASE PGUSER

if [ -n "$SQL_CMD" ]; then
  "${PSQL[@]}" "${EXTRA_ARGS[@]}" -c "$SQL_CMD"
elif [ -n "$SQL_FILE" ]; then
  if [ ! -f "$SQL_FILE" ]; then
    echo "No such file: $SQL_FILE" >&2
    exit 2
  fi
  "${PSQL[@]}" "${EXTRA_ARGS[@]}" -f "$SQL_FILE"
else
  usage
fi
