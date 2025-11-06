# Git Bash Setup Guide for Windows

## Quick Fix

If you're seeing errors like `: command not found`, run this:

```bash
# Run the setup script
bash scripts/setup_gitbash.sh

# Or manually fix line endings
sed -i 's/\r$//' .env
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;
```

## Overview

Git Bash on Windows requires special handling for:
- **Line endings** (CRLF vs LF)
- **Path conversion** (Windows paths vs Unix paths)
- **Docker integration** (Docker Desktop for Windows)

## Prerequisites

### 1. Install Required Software

**Git Bash** (includes Bash, sed, grep, etc.):
```powershell
# PowerShell (as Administrator)
winget install Git.Git
```

**Docker Desktop for Windows**:
```powershell
winget install Docker.DockerDesktop
```

**Make for Windows** (optional but recommended):
```powershell
winget install GnuWin32.Make
```

Or download from: https://gnuwin32.sourceforge.net/packages/make.htm

**PostgreSQL Client Tools** (optional):
```powershell
winget install PostgreSQL.PostgreSQL
```

### 2. Verify Installation

Open **Git Bash** and run:

```bash
# Check versions
bash --version
docker --version
make --version    # if installed
psql --version    # if installed

# Check Docker is running
docker ps
```

## Setup Steps

### Step 1: Clone Repository

```bash
# In Git Bash
cd /d/temp  # or wherever you want the project
git clone <repo-url>
cd fundedhere-etl
```

### Step 2: Run Setup Script

```bash
# Fix all line endings and verify environment
bash scripts/setup_gitbash.sh
```

**Expected output:**
```
✓ Detected Git Bash on Windows
✓ Fixed .env
✓ Fixed all .sh files
✓ Fixed all .sql files
✓ Docker found
✓ Docker Compose found
✓ Docker daemon is running
✓ Setup Complete!
```

### Step 3: Configure Git (One-time)

```bash
# Use LF line endings (not CRLF)
git config --global core.autocrlf input

# Verify
git config --global core.autocrlf
# Should show: input
```

### Step 4: Verify .env File

```bash
# Check .env exists and has correct format
cat .env

# Should show (without any ^M characters):
DB_MODE=host
PGHOST=localhost
PGPORT=5433
...
```

### Step 5: Test Connection

```bash
# Start database
make up-wait

# Test connection
make psql-host
```

**Expected:**
```
server_time          | version
---------------------+------------------
2025-11-01 05:42:45  | PostgreSQL 16.10
```

## Common Issues and Fixes

### Issue 1: `: command not found`

**Cause:** CRLF line endings in shell scripts or .env

**Fix:**
```bash
# Fix all files
bash scripts/setup_gitbash.sh

# Or manually:
sed -i 's/\r$//' .env
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;
```

**Verify:**
```bash
# Check for CRLF (should show "ASCII text", not "CRLF")
file .env
file scripts/run_sql.sh
```

### Issue 2: `make: command not found`

**Cause:** Make not installed

**Fix Option 1 - Install Make:**
```bash
# In PowerShell (as Admin)
winget install GnuWin32.Make

# Add to PATH: C:\Program Files (x86)\GnuWin32\bin
```

**Fix Option 2 - Use scripts directly:**
```bash
# Instead of: make up-wait
bash scripts/db_up.sh && bash scripts/db_wait.sh

# Instead of: make bootstrap
bash scripts/bootstrap_db.sh

# Instead of: make load-fast
bash scripts/load_all_parallel.sh data/inc_data
```

### Issue 3: Docker connection refused

**Cause:** Docker Desktop not running

**Fix:**
```bash
# Start Docker Desktop (from Start menu)
# Wait ~30 seconds for startup

# Verify
docker ps
```

### Issue 4: Path conversion issues

**Cause:** Git Bash converting paths like `/d/temp` to `D:\temp`

**Fix:**
```bash
# Use Windows-style paths with forward slashes
export MSYS_NO_PATHCONV=1

# Or use double slashes
//d/temp/fundedhere-etl
```

**Add to ~/.bashrc:**
```bash
echo 'export MSYS_NO_PATHCONV=1' >> ~/.bashrc
source ~/.bashrc
```

### Issue 5: Permission denied on scripts

**Cause:** Scripts not executable

**Fix:**
```bash
# Make all scripts executable
chmod +x scripts/*.sh

# Or for individual script
chmod +x scripts/run_sql.sh
```

### Issue 6: PostgreSQL client not found

**Cause:** psql not in PATH

**Fix:**
```bash
# Option 1: Install PostgreSQL
# Download from: https://www.postgresql.org/download/windows/

# Option 2: Use Docker exec
docker exec -it app-postgres psql -U appuser -d appdb

# Option 3: Add to PATH (if already installed)
export PATH="$PATH:/c/Program Files/PostgreSQL/16/bin"
```

## Git Configuration

### Recommended Git Settings

```bash
# Use LF line endings
git config --global core.autocrlf input

# Use simple push (current branch only)
git config --global push.default simple

# Set editor (optional)
git config --global core.editor "vim"

# Show whitespace issues
git config --global core.whitespace trailing-space,space-before-tab

# Verify all settings
git config --global --list
```

### .gitattributes (Already Included)

The project includes `.gitattributes` to enforce LF line endings:

```gitattributes
* text=auto eol=lf
*.sh text eol=lf
*.sql text eol=lf
.env* text eol=lf
```

This prevents CRLF issues for all contributors.

## Working with Make Commands

### If Make is Installed

```bash
# Use normally
make up-wait
make bootstrap
make load-fast
```

### If Make is NOT Installed

**Alternative 1: Use bash directly**
```bash
# Database
bash scripts/db_up.sh && bash scripts/db_wait.sh  # make up-wait
bash scripts/db_down.sh                            # make down
bash scripts/db_logs.sh                            # make logs

# Bootstrap
bash scripts/bootstrap_db.sh                       # make bootstrap

# Loading
bash scripts/load_all_parallel.sh data/inc_data   # make load-fast
bash scripts/load_multi_period.sh data/inc_data replace  # make load-multi-period

# SQL
bash scripts/run_sql.sh -c "SELECT 1"             # make sql CMD="SELECT 1"
bash scripts/run_sql.sh -f some.sql               # make sqlf FILE=some.sql
```

**Alternative 2: Create bash aliases**
```bash
# Add to ~/.bashrc
alias mk-up='bash scripts/db_up.sh && bash scripts/db_wait.sh'
alias mk-down='bash scripts/db_down.sh'
alias mk-bootstrap='bash scripts/bootstrap_db.sh'
alias mk-load='bash scripts/load_all_parallel.sh data/inc_data'

# Reload
source ~/.bashrc

# Use
mk-up
mk-bootstrap
mk-load
```

## Docker Desktop Configuration

### Enable WSL 2 Backend (Recommended)

1. Open Docker Desktop
2. Settings → General
3. Enable: "Use the WSL 2 based engine"
4. Apply & Restart

### Resource Limits

For better performance:

1. Settings → Resources
2. CPUs: 4+ cores
3. Memory: 4GB+ RAM
4. Swap: 2GB

## Complete Workflow for Git Bash

```bash
# 1. Clone and setup
cd /d/temp
git clone <repo-url>
cd fundedhere-etl
bash scripts/setup_gitbash.sh

# 2. Place CSV files
cp /path/to/csvs/*.csv data/inc_data/

# 3. Start database
make up-wait
# or: bash scripts/db_up.sh && bash scripts/db_wait.sh

# 4. Initialize
make bootstrap
# or: bash scripts/bootstrap_db.sh

# 5. Load data
make load-fast
# or: bash scripts/load_all_parallel.sh data/inc_data

# 6. Generate mappings
make prep-map && make load-mapping
# or: python scripts/prep_note_sku_map.py && bash scripts/load_note_sku_va_map.sh

# 7. Refresh views
make refresh-optimized
# or: bash scripts/run_sql.sh -f scripts/sql-utils/refresh_core.sql

# 8. Start web interface
make webapp-up
# or: docker compose --profile webapp up -d

# 9. Access
# Open browser: http://localhost:8080
```

## Troubleshooting Checklist

Run this checklist if you have issues:

```bash
# 1. Check line endings
file .env                    # Should be: ASCII text (NOT "with CRLF")
file scripts/run_sql.sh      # Should be: ASCII text

# 2. Fix if needed
sed -i 's/\r$//' .env
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;

# 3. Check Docker
docker ps                    # Should list containers

# 4. Check database
docker ps | grep postgres    # Should show app-postgres running

# 5. Test connection
bash scripts/run_sql.sh -c "SELECT 1"

# 6. Check environment
cat .env                     # Should show DB_MODE=host, PGHOST=localhost

# 7. Re-source .env
source .env
```

## Performance Tips for Windows

### Use WSL 2 Instead of Git Bash (Optional)

For better performance, consider using WSL 2 (Windows Subsystem for Linux):

```powershell
# PowerShell (as Administrator)
wsl --install Ubuntu

# Then work inside WSL
wsl
cd /mnt/d/temp/fundedhere-etl
```

Benefits:
- Native Linux performance
- Better Docker integration
- No path conversion issues
- No CRLF issues

### Keep Files on Windows Partition

If using Git Bash, keep project on Windows partition (not /c/ mount):

```bash
# Good: Fast
cd /d/temp/fundedhere-etl

# Slower: Cross-mount access
cd /c/Users/yourname/projects/fundedhere-etl
```

## Quick Reference

```bash
# Setup
bash scripts/setup_gitbash.sh

# Fix line endings
sed -i 's/\r$//' .env
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Verify
file .env          # Should show: ASCII text

# Test
make psql-host     # or: bash scripts/run_sql.sh -c "SELECT 1"

# Start
make up-wait && make bootstrap && make load-fast

# Stop
make down

# Web interface
make webapp-up
# Open: http://localhost:8080
```

## Getting Help

If you're still having issues:

1. Check the error message carefully
2. Look for `^M` characters (indicates CRLF)
3. Run `bash scripts/setup_gitbash.sh` again
4. Check Docker Desktop is running
5. Verify .env file settings
6. Review logs: `make logs` or `docker logs app-postgres`

## Related Documentation

- **[CONNECTION_FIX.md](CONNECTION_FIX.md)** - Database connection troubleshooting
- **[README.md](../README.md)** - Main project documentation
- **[TEST_RUNS.md](TEST_RUNS.md)** - Test commands and workflows
