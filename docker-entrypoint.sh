#!/usr/bin/env bash
set -euo pipefail

# Allow users to override data dirs via env if they want
DATA_DIR=${DATA_DIR:-/app/data}
INC_DIR=${INC_DIR:-$DATA_DIR/inc_data}
PGDATA_DIR=${PGDATA_DIR:-$DATA_DIR/pgdata}

mkdir -p "$INC_DIR" "$PGDATA_DIR"

exec "$@"
