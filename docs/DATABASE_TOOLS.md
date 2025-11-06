# Connecting Database Tools (pgAdmin, HeidiSQL, DBeaver, etc.)

The PostgreSQL database is exposed on **port 5433** to avoid conflicts with any local PostgreSQL instance running on the default port 5432.

## Connection Settings

Use these credentials to connect from any PostgreSQL client tool:

| Setting   | Value          | Notes                                    |
|-----------|----------------|------------------------------------------|
| **Host**  | `localhost`    | Or `127.0.0.1` or your machine's IP      |
| **Port**  | `5433`         | **Not** the default 5432                 |
| **Database** | `appdb`     | Main application database                |
| **Username** | `appuser`   | Application user                         |
| **Password** | `changeme`  | Default password (change in production!) |
| **SSL Mode** | `disable`   | SSL not required for local development   |

## Popular Tools Configuration

### pgAdmin 4

1. Right-click **Servers** → **Register** → **Server**
2. **General** tab:
   - Name: `FundedHere ETL (Local)`
3. **Connection** tab:
   - Host: `localhost`
   - Port: `5433`
   - Maintenance database: `appdb`
   - Username: `appuser`
   - Password: `changeme`
   - Save password: ✓ (optional)
4. **SSL** tab:
   - SSL mode: `Disable`

### HeidiSQL

1. Click **New** session
2. **Settings** tab:
   - Network type: `PostgreSQL (TCP/IP)`
   - Hostname / IP: `127.0.0.1`
   - User: `appuser`
   - Password: `changeme`
   - Port: `5433`
   - Database: `appdb`
3. Click **Open** to connect

### DBeaver

1. Click **New Database Connection** (plug icon)
2. Select **PostgreSQL**
3. **Main** tab:
   - Host: `localhost`
   - Port: `5433`
   - Database: `appdb`
   - Username: `appuser`
   - Password: `changeme`
4. **Test Connection** → **Finish**

### DataGrip (JetBrains)

1. **Database** → **New** → **Data Source** → **PostgreSQL**
2. **General** tab:
   - Host: `localhost`
   - Port: `5433`
   - Database: `appdb`
   - User: `appuser`
   - Password: `changeme`
3. Click **Test Connection** → **OK**

### psql (Command Line)

```bash
# Connect from host machine
psql -h localhost -p 5433 -U appuser -d appdb

# Or using environment variables (already set in .env)
psql

# Connect from inside Docker container
docker exec -it app-postgres psql -U appuser -d appdb
```

## Useful Schemas and Views

Once connected, explore these key database objects:

### Schemas
- **`raw`** - Raw CSV data tables (external_accounts, va_txn, repmt_sku, repmt_sales)
- **`ref`** - Reference/lookup tables (merchant, sku, note_sku_va_map)
- **`core`** - Intermediate materialized views for performance
- **`mart`** - Final reporting views (v_level1, v_level2a, v_level2b)

### Key Views
```sql
-- Sheet 1: Account-level reconciliation (366 SKUs)
SELECT * FROM mart.v_level1 LIMIT 10;

-- Sheet 2a: Transaction waterfall (366 SKUs)
SELECT * FROM mart.v_level2a LIMIT 10;

-- Sheet 2b: Payment component summary (366 SKUs)
SELECT * FROM mart.v_level2b LIMIT 10;

-- Check row counts
SELECT 'raw.va_txn' as table_name, COUNT(*) FROM raw.va_txn
UNION ALL
SELECT 'raw.external_accounts', COUNT(*) FROM raw.external_accounts
UNION ALL
SELECT 'mart.v_level1', COUNT(*) FROM mart.v_level1;
```

## Troubleshooting

### Connection Refused

**Problem**: Client can't connect to `localhost:5433`

**Solutions**:
1. Check database is running: `docker ps | grep postgres`
2. If not running: `make up` or `make up-wait`
3. Check firewall isn't blocking port 5433
4. Try `127.0.0.1` instead of `localhost`

### "Password authentication failed"

**Problem**: Wrong credentials

**Solutions**:
1. Verify credentials in `.env` file
2. Default is `appuser` / `changeme`
3. Restart database if you changed .env: `make down && make up-wait`

### "Database does not exist"

**Problem**: Schema hasn't been initialized

**Solutions**:
1. Run bootstrap: `uv run fundedhere-etl bootstrap`
2. Or run full pipeline: `make container-etl-verify`
3. Check with: `docker exec app-postgres psql -U appuser -l`

## Remote Access (Team Members)

To allow remote connections from other machines on your network:

1. Find your IP address:
   ```bash
   # Windows
   ipconfig

   # Linux/Mac
   ip addr show
   ```

2. Share these credentials with your team:
   - Host: `<your-ip-address>` (e.g., `192.168.1.100`)
   - Port: `5433`
   - Database: `appdb`
   - Username: `appuser`
   - Password: `changeme`

3. Ensure firewall allows incoming connections on port 5433

## Security Notes

⚠️ **For Development Only**

The default credentials (`appuser`/`changeme`) are for **local development only**.

For production/shared environments:
1. Change password in `.env`: `POSTGRES_PASSWORD=<strong-password>`
2. Restart database: `make down && make up-wait`
3. Enable SSL: Set `PGSSLMODE=require` in `.env`
4. Never commit `.env` file with production credentials to git

## Port Conflicts

If port 5433 is already in use, change it in `.env`:

```bash
# .env
POSTGRES_PORT=5434  # or any available port
```

Then restart: `make down && make up-wait`
