#!/usr/bin/env bash
# Wrapper script - calls Python-based ETL
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Call Python CLI (parallel load with truncate)
uv run fundedhere-etl load --mode parallel --truncate
