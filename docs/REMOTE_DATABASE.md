# Remote Database Configuration

_Using external PostgreSQL for raw data and view storage_

## Overview

This guide explains how to configure the FundedHere ETL to work with a **remote PostgreSQL database** instead of the local Docker database. This is useful for:

- **Production deployments** - Use managed PostgreSQL (AWS RDS, Azure, GCP Cloud SQL)
- **Shared team database** - Multiple users accessing same data
- **Centralized data warehouse** - ETL feeds into existing infrastructure
- **Cloud-native architecture** - Separate compute from storage

---

## Architecture Options

### Option 1: Remote Database Only (Full Cloud)

```
CSV Files (local)
    ↓
ETL Container (local)
    ↓
Remote PostgreSQL ← Query from anywhere
```

**Use case:** Production deployment, team collaboration

### Option 2: Hybrid (Local ETL, Remote Storage)

```
CSV Files (local)
    ↓
Local Docker ETL
    ↓
Remote PostgreSQL ← Query from anywhere
```

**Use case:** Development with production data access

### Option 3: Local Dev + Remote Backup

```
CSV Files (local)
    ↓
Local PostgreSQL (Docker)
    ↓ (periodic sync)
Remote PostgreSQL (backup/reporting)
```

**Use case:** Local dev, remote analytics

---

## Setup Instructions

### Prerequisites

1. **PostgreSQL 16+** database accessible via network
2. **Connection details:**
   - Host/IP address
   - Port (default: 5432)
   - Database name
   - Username/password
   - SSL settings

### Step 1: Configure Environment

Create or edit `.env` file:

```bash
# Remote Database Configuration
DB_MODE=remote
PGHOST=your-database.example.com
PGPORT=5432
PGDATABASE=fundedhere_etl
PGUSER=etl_user
PGPASSWORD=your-secure-password
PGSSLMODE=require

# Local CSV data location
INC_DATA_DIR=./data/inc_data
```

**DB_MODE options:**
- `container-bind` - Local Docker with volume mount (default)
- `remote` - External PostgreSQL server
- `host` - PostgreSQL on host machine (not Docker)

**SSL Mode options:**
- `disable` - No SSL (local dev only)
- `require` - SSL required (production recommended)
- `verify-ca` - Verify SSL certificate
- `verify-full` - Full certificate verification

### Step 2: Initialize Remote Schema

```bash
# Bootstrap database schema
make container-etl-load
```

Or manually:

```bash
# 1. Create schemas
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f initdb/001_create_schemas.sql
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f initdb/002_create_tables.sql
# ... (all initdb/*.sql files)

# 2. Create views
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f sql/phase2/010_mart_views.sql
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f sql/phase2/020_mart_level2.sql
```

### Step 3: Load Data

```bash
# Using container (recommended)
make container-etl-load

# Or using Python CLI (requires uv)
uv run fundedhere-etl prep
uv run fundedhere-etl bootstrap
uv run fundedhere-etl load --mode parallel
uv run fundedhere-etl load-mapping
uv run fundedhere-etl refresh
```

### Step 4: Verify Connection

```bash
# Check row counts
make counts

# Query views
make sql CMD="SELECT COUNT(*) FROM mart.v_level1;"
```

---

## Connection Examples

### AWS RDS PostgreSQL

```bash
# .env
DB_MODE=remote
PGHOST=mydb.abc123.us-east-1.rds.amazonaws.com
PGPORT=5432
PGDATABASE=fundedhere_etl
PGUSER=admin
PGPASSWORD=your-password
PGSSLMODE=require
```

### Azure Database for PostgreSQL

```bash
# .env
DB_MODE=remote
PGHOST=myserver.postgres.database.azure.com
PGPORT=5432
PGDATABASE=fundedhere_etl
PGUSER=adminuser@myserver
PGPASSWORD=your-password
PGSSLMODE=require
```

### GCP Cloud SQL

```bash
# .env (using public IP)
DB_MODE=remote
PGHOST=35.123.45.67
PGPORT=5432
PGDATABASE=fundedhere_etl
PGUSER=postgres
PGPASSWORD=your-password
PGSSLMODE=require
```

### Supabase

```bash
# .env
DB_MODE=remote
PGHOST=db.projectref.supabase.co
PGPORT=5432
PGDATABASE=postgres
PGUSER=postgres
PGPASSWORD=your-supabase-password
PGSSLMODE=require
```

---

## Security Best Practices

### 1. Use Strong Authentication

```bash
# Generate strong password
openssl rand -base64 32

# Use dedicated ETL user (not root/admin)
CREATE USER etl_user WITH PASSWORD 'strong-password-here';
GRANT CONNECT ON DATABASE fundedhere_etl TO etl_user;
GRANT USAGE ON SCHEMA raw, ref, core, mart TO etl_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw, ref TO etl_user;
GRANT SELECT ON ALL TABLES IN SCHEMA core, mart TO etl_user;
```

### 2. Enable SSL/TLS

**Require SSL in .env:**
```bash
PGSSLMODE=require
```

**Verify SSL is active:**
```bash
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT ssl.version FROM pg_stat_ssl ssl JOIN pg_stat_activity act ON ssl.pid = act.pid WHERE act.usename = current_user;"
```

### 3. Network Security

- **Whitelist IPs:** Only allow connections from known IPs
- **VPN/Private Network:** Use VPN or private subnet
- **Firewall Rules:** Restrict port 5432 access
- **Jump Box:** Access via bastion host for added security

### 4. Credential Management

**Option A: Environment variables (development)**
```bash
export PGPASSWORD=your-password
make container-etl-load
```

**Option B: .pgpass file (recommended)**
```bash
# ~/.pgpass (chmod 0600)
hostname:port:database:username:password
```

**Option C: Secrets manager (production)**
```bash
# AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id fundedhere/db --query SecretString

# Azure Key Vault
az keyvault secret show --vault-name myvault --name db-password

# Google Secret Manager
gcloud secrets versions access latest --secret="db-password"
```

---

## Performance Tuning

### Connection Pooling

For production, consider using PgBouncer:

```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    environment:
      DATABASES_HOST: remote-db.example.com
      DATABASES_PORT: 5432
      DATABASES_DBNAME: fundedhere_etl
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 100
      DEFAULT_POOL_SIZE: 20
    ports:
      - "6432:5432"
```

Update .env:
```bash
PGHOST=localhost
PGPORT=6432  # PgBouncer port
```

### Optimize Data Transfer

```bash
# Compress CSV files before transfer
gzip data/inc_data/*.csv

# Use parallel loading
make container-etl-load  # Automatically uses parallel mode
```

### Index Optimization

```sql
-- Add indexes for common queries (run on remote DB)
CREATE INDEX CONCURRENTLY idx_va_txn_receiver 
  ON raw.va_txn(receiver_virtual_account_id);

CREATE INDEX CONCURRENTLY idx_va_txn_sender 
  ON raw.va_txn(sender_virtual_account_id);

CREATE INDEX CONCURRENTLY idx_va_txn_date 
  ON raw.va_txn(CAST(date AS DATE));
```

---

## Troubleshooting

### Connection Refused

```bash
# Test basic connectivity
telnet $PGHOST $PGPORT

# Test PostgreSQL connection
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"
```

**Common causes:**
- Firewall blocking port 5432
- Database not accepting remote connections
- Wrong host/port in configuration
- VPN not connected

**Fix:**
```bash
# Check postgresql.conf (on remote server)
listen_addresses = '*'

# Check pg_hba.conf (on remote server)
host    all    all    0.0.0.0/0    md5
```

### SSL/TLS Errors

```bash
# Error: "SSL connection required"
# Fix: Set PGSSLMODE=require in .env

# Error: "certificate verify failed"
# Fix: Use PGSSLMODE=require (not verify-ca) or add CA cert
```

### Permission Denied

```bash
# Error: "permission denied for schema raw"
# Fix: Grant permissions
GRANT USAGE ON SCHEMA raw, ref, core, mart TO etl_user;
GRANT ALL ON ALL TABLES IN SCHEMA raw, ref TO etl_user;
```

### Slow Performance

```bash
# Check network latency
ping $PGHOST

# Check query performance
EXPLAIN ANALYZE SELECT * FROM mart.v_level1 LIMIT 10;

# Consider:
# - Using PgBouncer for connection pooling
# - Adding indexes (see Performance Tuning section)
# - Increasing work_mem on remote database
# - Using materialized views instead of regular views
```

---

## Monitoring

### Query Performance

```sql
-- Enable query logging (remote DB)
ALTER DATABASE fundedhere_etl SET log_min_duration_statement = 1000; -- Log queries > 1s

-- Check slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Connection Status

```sql
-- Check active connections
SELECT datname, usename, client_addr, state
FROM pg_stat_activity
WHERE datname = 'fundedhere_etl';

-- Check connection limits
SELECT * FROM pg_settings WHERE name = 'max_connections';
```

### Data Health

```bash
# Automated health check
make counts

# Expected output:
#   raw.external_accounts:  2,718 rows
#   raw.va_txn:            28,599 rows
#   raw.repmt_sku:            366 rows
#   raw.repmt_sales:          366 rows
#   mart.v_level1:            366 rows
#   mart.v_level2a:           366 rows
#   mart.v_level2b:           366 rows
```

---

## Backup and Recovery

### Backup Remote Database

```bash
# Full backup
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > backup_$(date +%Y%m%d).sql

# Schema only
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE --schema-only > schema_backup.sql

# Data only (specific tables)
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE \
  -t raw.va_txn -t raw.repmt_sku -t raw.repmt_sales -t raw.external_accounts \
  > data_backup.sql
```

### Restore from Backup

```bash
# Restore full backup
psql -h $PGHOST -U $PGUSER -d $PGDATABASE < backup_20251105.sql

# Restore schema only
psql -h $PGHOST -U $PGUSER -d $PGDATABASE < schema_backup.sql
```

### Automated Backups

```bash
# Cron job example (daily backup at 2 AM)
0 2 * * * /usr/bin/pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE | gzip > /backups/fundedhere_$(date +\%Y\%m\%d).sql.gz
```

---

## Migration Between Environments

### Local to Remote

```bash
# 1. Backup local data
docker exec app-postgres pg_dump -U appuser appdb > local_backup.sql

# 2. Configure remote connection (.env)
DB_MODE=remote
PGHOST=remote-db.example.com

# 3. Restore to remote
psql -h $PGHOST -U $PGUSER -d $PGDATABASE < local_backup.sql
```

### Remote to Local

```bash
# 1. Backup remote data
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > remote_backup.sql

# 2. Start local database
make up-wait

# 3. Restore to local
docker exec -i app-postgres psql -U appuser -d appdb < remote_backup.sql
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: ETL Pipeline

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  etl:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure remote database
        run: |
          echo "DB_MODE=remote" >> .env
          echo "PGHOST=${{ secrets.DB_HOST }}" >> .env
          echo "PGUSER=${{ secrets.DB_USER }}" >> .env
          echo "PGPASSWORD=${{ secrets.DB_PASSWORD }}" >> .env
          echo "PGSSLMODE=require" >> .env
      
      - name: Download CSV files
        run: |
          # Download from S3, Azure Blob, etc.
          aws s3 cp s3://mybucket/monthly-data/ data/inc_data/ --recursive
      
      - name: Run ETL
        run: make container-etl-load
      
      - name: Verify
        run: make counts
```

---

## Additional Resources

- [Architecture Overview](EXISTING_ANALYSIS.md)
- [Local Docker Setup](QUICKSTART.md)
- [Database Tools Setup](DATABASE_TOOLS.md)
- [View Optimization](VIEW_OPTIMIZATION.md)
- [Multi-Period Loading](MULTI_PERIOD.md)

---

_For questions or issues with remote database setup, see the troubleshooting section or check logs in `.build/`._
