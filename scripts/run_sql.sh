#!/usr/bin/env bash
set -euo pipefail

# Load .env if present
if [ -f ".env" ]; then set -a; . ./.env; set +a; fi

DB_MODE="${DB_MODE:-container-bind}"

# Always print straight to the shell (no pager) and ignore ~/.psqlrc
export PAGER=cat
export PSQL_PAGER=cat

if [ "$DB_MODE" = "remote" ]; then
  PGHOST="${REMOTE_PGHOST:-localhost}"
  PGPORT="${REMOTE_PGPORT:-5432}"
  PGDATABASE="${REMOTE_PGDATABASE:-appdb}"
  PGUSER="${REMOTE_PGUSER:-appuser}"
  PGPASSWORD="${REMOTE_PGPASSWORD:-changeme}"
  PGSSLMODE="${REMOTE_PGSSLMODE:-require}"
else
  PGHOST="${PGHOST:-localhost}"
  PGPORT="${PGPORT:-5433}"
  PGDATABASE="${PGDATABASE:-appdb}"
  PGUSER="${PGUSER:-appuser}"
  PGPASSWORD="${PGPASSWORD:-changeme}"
  PGSSLMODE="${PGSSLMODE:-disable}"
fi

# -X ignore ~/.psqlrc, --pset=pager=off disables pager at psql level
PSQL=(psql -X -v ON_ERROR_STOP=1 --pset=pager=off -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE")

usage(){ echo "Usage: $0 [-c SQL] [-f file.sql]"; exit 2; }

SQL_CMD=""
SQL_FILE=""

while getopts ":c:f:" opt; do
  case "$opt" in
    c) SQL_CMD="$OPTARG" ;;
    f) SQL_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done

export PGPASSWORD PGSSLMODE

if [ -n "$SQL_CMD" ]; then
  "${PSQL[@]}" -c "$SQL_CMD"
elif [ -n "$SQL_FILE" ]; then
  if [ ! -f "$SQL_FILE" ]; then
    echo "No such file: $SQL_FILE" >&2
    exit 2
  fi
  "${PSQL[@]}" -f "$SQL_FILE"
else
  usage
fi
