#!/usr/bin/env bash
set -euo pipefail
docker compose --profile db-local-bind down || true
docker compose --profile db-local-nobind down || true
