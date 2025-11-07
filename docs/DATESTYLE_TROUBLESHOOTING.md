# Date Format Troubleshooting

## Error: "date/time field value out of range"

If you see this error on a remote PostgreSQL host:
```
ERROR:  date/time field value out of range: "29-09-25"
HINT:  Perhaps you need a different "datestyle" setting.
SQL state: 22008
```

### Root Cause

The CSV files contain dates in **M/D/YYYY format** (e.g., `9/29/2025` = September 29, 2025).

PostgreSQL databases with **DMY (Day/Month/Year)** datestyle will misinterpret this as:
- Day: 9
- Month: 29 → **ERROR** (no month 29)

### Solutions

#### Option 1: Set Database Datestyle (Recommended)

Connect to your remote PostgreSQL host and run:

```sql
-- Set for the entire database (persistent)
ALTER DATABASE your_database_name SET datestyle = 'ISO, MDY';

-- Reconnect to the database for the setting to take effect
\c your_database_name

-- Verify the setting
SHOW datestyle;
-- Should show: ISO, MDY
```

#### Option 2: Set Session Datestyle

If you can't modify database settings, set it per session:

```sql
-- At the start of your SQL session
SET datestyle = 'ISO, MDY';

-- Then run your ETL scripts
\i initdb/000_schemas.sql
-- etc.
```

#### Option 3: Update Connection String

For remote database connections via environment variables:

```bash
export PGDATESTYLE="ISO, MDY"
# or
export PGOPTIONS="-c datestyle=ISO,MDY"

# Then run your ETL commands
make container-etl-load
```

### Verification

After applying the fix, verify dates are parsed correctly:

```sql
-- Test date parsing
SELECT 
  '9/29/2025'::date as parsed_date,
  EXTRACT(month FROM '9/29/2025'::date) as month,
  EXTRACT(day FROM '9/29/2025'::date) as day;

-- Expected output:
-- parsed_date: 2025-09-29
-- month: 9
-- day: 29
```

### Why This Matters

| Datestyle | Interprets 9/29/2025 As | Result |
|-----------|-------------------------|--------|
| **MDY** (correct) | Month 9, Day 29, Year 2025 | ✓ Sept 29, 2025 |
| **DMY** (wrong) | Day 9, Month 29, Year 2025 | ✗ ERROR (no month 29) |

### CSV Date Format Reference

All CSV files in this project use **M/D/YYYY format**:
- `external_accounts_2025-09.csv`: Created Date, Completed Date → `9/29/2025`
- `va_txn_2025-09.csv`: Date → `9/29/2025`
- `repmt_sku_2025-09.csv`: Date fields → `9/29/2025`
- `repmt_sales_2025-09.csv`: Date fields → `9/29/2025`

### Quick Reference

```bash
# Check current datestyle on remote host
psql -h your-host -U appuser -d appdb -c "SHOW datestyle;"

# Set datestyle and reload data
psql -h your-host -U appuser -d appdb -c "ALTER DATABASE appdb SET datestyle = 'ISO, MDY';"

# Reconnect and verify
psql -h your-host -U appuser -d appdb -c "SHOW datestyle;"
```

### Notes

1. **Local Docker**: Already configured correctly via `initdb/000_schemas.sql`
2. **Remote Hosts**: Must configure manually as shown above
3. **View Scripts**: Now include `SET datestyle = 'ISO, MDY';` for session-level safety
4. **Connection Poolers**: May require setting `PGDATESTYLE` environment variable

### See Also

- [PostgreSQL Date/Time Types Documentation](https://www.postgresql.org/docs/current/datatype-datetime.html)
- [docs/REMOTE_DATABASE.md](REMOTE_DATABASE.md) - Remote database setup guide
