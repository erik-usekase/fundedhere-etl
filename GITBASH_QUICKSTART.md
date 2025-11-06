# Git Bash Quick Start

## The Problem You Had

```
. .env
: command not found
: command not found
```

**Cause:** Windows line endings (CRLF) in files - Git Bash expects Unix line endings (LF)

## The Fix (Already Applied)

All files have been fixed with Unix (LF) line endings:
- ✅ `.env` - Fixed
- ✅ All shell scripts (`.sh`) - Fixed
- ✅ All SQL files (`.sql`) - Fixed
- ✅ `Makefile` - Fixed
- ✅ `.gitattributes` - Created (prevents future issues)
- ✅ `scripts/setup_gitbash.sh` - Created (one-command fix)

## Verify It's Fixed

```bash
# In Git Bash
cd /mnt/d/temp/fundedhere-etl

# Test sourcing .env (should have no errors)
source .env
echo "✓ Success!"

# Verify files have LF endings
file .env
# Should show: ASCII text (NOT "with CRLF line terminators")
```

## Run the ETL Pipeline (Git Bash Compatible)

```bash
# Step 1: Start database (30 seconds)
make up-wait

# Step 2: Initialize database (1 minute)
make bootstrap
make enable-optimized-views
make deploy-period-views

# Step 3: Load CSV data (30 seconds)
make load-fast

# Step 4: Generate mappings (10 seconds)
make prep-map
make load-mapping

# Step 5: Refresh views (5 seconds)
make refresh-optimized

# Step 6: Start web interface (5 seconds)
make webapp-up

# Step 7: Access web page
# Open browser: http://localhost:8080
```

## One-Line Full Setup

```bash
cd /mnt/d/temp/fundedhere-etl && \
  make up-wait && \
  make bootstrap && \
  make enable-optimized-views && \
  make deploy-period-views && \
  make load-fast && \
  make prep-map && \
  make load-mapping && \
  make refresh-optimized && \
  make webapp-up && \
  echo "" && \
  echo "✓ Complete! Open http://localhost:8080"
```

**Time:** ~3 minutes

## Alternative: If Make Doesn't Work

Some Git Bash installations don't have `make`. Use scripts directly:

```bash
# Database
bash scripts/db_up.sh && bash scripts/db_wait.sh

# Bootstrap
bash scripts/bootstrap_db.sh

# Deploy views
bash scripts/run_sql.sh -f sql/phase2/000_optimized_refresh.sql
bash scripts/run_sql.sh -f sql/phase2/010_mart_views_optimized.sql
bash scripts/run_sql.sh -f sql/phase2/025_period_views.sql

# Load data
bash scripts/load_all_parallel.sh data/inc_data

# Mappings
python scripts/prep_note_sku_map.py
bash scripts/load_note_sku_va_map.sh data/inc_data/note_sku_va_map_prepped.csv

# Refresh
bash scripts/run_sql.sh -f scripts/sql-utils/refresh_core.sql

# Web interface
docker compose --profile webapp up -d

# Access: http://localhost:8080
```

## If You Get Errors Again

**Fix line endings (any time):**
```bash
# Quick fix
bash scripts/setup_gitbash.sh

# Or manually
sed -i 's/\r$//' .env
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;
```

**Verify fix:**
```bash
file .env
# Should show: ASCII text
# NOT: ASCII text, with CRLF line terminators
```

## Configure Git to Prevent Future Issues

```bash
# One-time global setting
git config --global core.autocrlf input

# Verify
git config --global core.autocrlf
# Should show: input
```

This tells Git to always use LF (Unix) line endings, even on Windows.

## Common Commands

```bash
# Start everything
make up-wait && make webapp-up

# Stop everything
make down

# View logs
make logs              # Database
make webapp-logs       # Web interface

# Run SQL
make sql CMD="SELECT COUNT(*) FROM mart.v_level1;"

# Test connection
make psql-host

# Check data
make counts
make periods-list

# Restart web interface
make webapp-down && make webapp-up
```

## Troubleshooting

### `: command not found`
```bash
bash scripts/setup_gitbash.sh
```

### `make: command not found`
```bash
# Option 1: Install Make
# Download: https://gnuwin32.sourceforge.net/packages/make.htm
# Or use scripts directly (see "Alternative" section above)

# Option 2: Use aliases
alias mk='make'
mk up-wait
```

### `docker: command not found`
```bash
# Start Docker Desktop from Windows Start menu
# Wait 30 seconds for startup
docker ps
```

### `Permission denied`
```bash
chmod +x scripts/*.sh
```

### `could not translate host name "postgres"`
```bash
# Check .env has correct settings
cat .env
# Should show: DB_MODE=host, PGHOST=localhost, PGPORT=5433
```

## Files Created/Fixed

- ✅ `.env` - Database connection config (LF endings)
- ✅ `.gitattributes` - Enforces LF endings for all text files
- ✅ `scripts/setup_gitbash.sh` - One-command setup/fix script
- ✅ `scripts/*.sh` - All shell scripts converted to LF
- ✅ `sql/**/*.sql` - All SQL files converted to LF
- ✅ `docs/GITBASH_SETUP.md` - Complete Git Bash guide
- ✅ `docs/CONNECTION_FIX.md` - Connection troubleshooting
- ✅ Updated `README.md` - Added Git Bash section

## Documentation

- **Quick Start** - This file (GITBASH_QUICKSTART.md)
- **Complete Guide** - [docs/GITBASH_SETUP.md](docs/GITBASH_SETUP.md)
- **Connection Issues** - [docs/CONNECTION_FIX.md](docs/CONNECTION_FIX.md)
- **Test Runs** - [docs/TEST_RUNS.md](docs/TEST_RUNS.md)
- **Main README** - [README.md](README.md)

## Success Checklist

- [ ] `.env` file loads without errors (`source .env`)
- [ ] Docker is running (`docker ps`)
- [ ] Database starts (`make up-wait`)
- [ ] Connection works (`make psql-host`)
- [ ] Data loads (`make load-fast`)
- [ ] Web interface accessible (http://localhost:8080)

## Need Help?

1. Run: `bash scripts/setup_gitbash.sh`
2. Check: `file .env` (should show "ASCII text")
3. Verify: `source .env` (should have no errors)
4. Test: `make psql-host` (should show PostgreSQL version)
5. Review: [docs/GITBASH_SETUP.md](docs/GITBASH_SETUP.md)

**Everything should now work in Git Bash!** 🎉
