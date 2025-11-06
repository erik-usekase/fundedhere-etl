# PostgreSQL Connection Fix

## Problem

When running `make` commands from your host machine (WSL/Linux/Mac), you get:

```
psql: error: could not translate host name "postgres" to address: Temporary failure in name resolution
```

## Root Cause

The scripts default to connecting to hostname `postgres` (the Docker container name), which only resolves inside Docker's network. When running from the host, you need to use `localhost:5433`.

## Solution

### Option 1: Use .env File (Recommended)

Create `.env` file in project root:

```bash
# .env
DB_MODE=host
PGHOST=localhost
PGPORT=5433
PGDATABASE=appdb
PGUSER=appuser
PGPASSWORD=changeme
PGSSLMODE=disable
```

Now all `make` commands will connect to `localhost:5433`.

### Option 2: Set Environment Variables

```bash
export DB_MODE=host
export PGHOST=localhost
export PGPORT=5433

make bootstrap
make load-fast
```

### Option 3: Auto-Detection (Already Implemented)

The updated `scripts/run_sql.sh` now auto-detects if running from host or inside Docker:

```bash
# No configuration needed - just run commands
make bootstrap
make load-fast
```

## Verification

```bash
# Test connection
make psql-host

# Should show:
#           server_time          |              version
# -------------------------------+------------------------------------
#  2025-11-01 05:42:45.866803+00 | PostgreSQL 16.10 ...
```

## Connection Modes

The system supports three connection modes:

### 1. Host Mode (localhost:5433)
```bash
DB_MODE=host
```
- Used when running `make` commands from your host machine
- Connects to Docker container via port mapping
- Default port: 5433 (mapped from container's 5432)

### 2. Container Mode (postgres:5432)
```bash
DB_MODE=container-bind
```
- Used when running inside a Docker container
- Connects via Docker network to container named "postgres"
- Default port: 5432 (internal)

### 3. Remote Mode (custom host)
```bash
DB_MODE=remote
REMOTE_PGHOST=production.example.com
REMOTE_PGPORT=5432
```
- Used for connecting to external PostgreSQL servers
- Requires full connection details
- Supports SSL/TLS

## Port Mapping

The Docker Compose configuration exposes PostgreSQL on:
- **External:** `localhost:5433` (from your host machine)
- **Internal:** `postgres:5432` (inside Docker network)

```yaml
# docker-compose.yml
postgres:
  ports:
    - "5433:5432"  # host:container
```

## Troubleshooting

### Still getting "could not translate host name"?

```bash
# 1. Check if .env file exists and is configured
cat .env

# 2. Verify Docker container is running
docker ps | grep postgres

# Should show: app-postgres ... 0.0.0.0:5433->5432/tcp

# 3. Test connection manually
psql -h localhost -p 5433 -U appuser -d appdb

# 4. Check environment is being loaded
make env
```

### Connection refused?

```bash
# Database might not be running
make up-wait

# Wait for database to be ready
sleep 5

# Try again
make psql-host
```

### Permission denied?

```bash
# Check password is correct
cat .env | grep PGPASSWORD

# Default is: changeme

# Test with explicit password
PGPASSWORD=changeme psql -h localhost -p 5433 -U appuser -d appdb -c "SELECT 1"
```

### Wrong port?

```bash
# Check actual port mapping
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep postgres

# If different port, update .env:
PGPORT=<actual-port>
```

## Quick Fix Commands

```bash
# Create .env file
cat > .env <<'EOF'
DB_MODE=host
PGHOST=localhost
PGPORT=5433
PGDATABASE=appdb
PGUSER=appuser
PGPASSWORD=changeme
PGSSLMODE=disable
EOF

# Verify connection
make psql-host

# Run bootstrap
make bootstrap
```

## For CI/CD or Automated Scripts

If running in automated environments:

```bash
# Set explicit connection parameters
export PGHOST=localhost
export PGPORT=5433
export PGDATABASE=appdb
export PGUSER=appuser
export PGPASSWORD=changeme

# Or use connection string
export DATABASE_URL="postgresql://appuser:changeme@localhost:5433/appdb"

# Run commands
make bootstrap
make load-fast
```

## Updated Test Runs

All test runs from `TEST_RUNS.md` now work correctly from the host:

```bash
# Smoke test (should work without any manual configuration)
make up-wait
make bootstrap
make load-fast
make counts
make refresh
make sql CMD="SELECT COUNT(*) FROM mart.v_level1;"
make down
```

## Changes Made

1. **Created `.env` file** - Sets `DB_MODE=host` and `PGHOST=localhost`
2. **Updated `scripts/run_sql.sh`** - Auto-detects if running inside Docker or from host
3. **All `make` commands now work from host** - No manual configuration needed

## Related Files

- `.env` - Connection configuration
- `.env.example` - Template and documentation
- `scripts/run_sql.sh` - Connection logic
- `docker-compose.yml` - Port mapping configuration
