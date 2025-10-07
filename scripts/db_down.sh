#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Neither 'docker compose' nor 'docker-compose' is available." >&2
  exit 2
fi

"${COMPOSE_CMD[@]}" --profile db-local-bind down || true
"${COMPOSE_CMD[@]}" --profile db-local-nobind down || true
