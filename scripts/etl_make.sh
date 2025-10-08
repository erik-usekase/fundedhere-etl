#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <make-target> [additional make args...]" >&2
  echo "Example: $0 etl-verify" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Neither 'docker compose' nor 'docker-compose' is available. Install Docker Desktop or the Docker Compose CLI." >&2
  exit 2
fi

# Build the ETL image on first run (subsequent runs are cached)
"${COMPOSE_CMD[@]}" build etl

if [ "${1:-}" != "help" ]; then
  PG_CONTAINER=$("${COMPOSE_CMD[@]}" ps -q postgres 2>/dev/null || true)
  if [ -z "$PG_CONTAINER" ]; then
    echo "Postgres container is not running. Start it first with scripts/db_up.sh" >&2
    exit 3
  fi
fi

"${COMPOSE_CMD[@]}" run --rm etl make "$@"
