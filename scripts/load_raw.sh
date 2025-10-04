#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 3 ]; then
  echo "Usage: $0 <table> <comma-separated-cols> <file.csv|.csv.gz>" >&2
  exit 2
fi
TABLE="$1"; COLS="$2"; FILE="$3"
if [ ! -f "$FILE" ]; then
  echo "No such file: $FILE" >&2
  exit 2
fi
if [[ "$FILE" =~ \.gz$ ]]; then
  SQL="\\copy ${TABLE}(${COLS}) from program 'gzip -dc \"${FILE}\"' csv header"
else
  SQL="\\copy ${TABLE}(${COLS}) from '${FILE}' csv header"
fi
scripts/run_sql.sh -c "$SQL"
