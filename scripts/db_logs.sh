#!/usr/bin/env bash
set -euo pipefail
docker compose logs -f postgres || docker compose logs -f postgres_nobind || true
