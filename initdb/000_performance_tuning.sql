-- Performance tuning for fundedhere-etl bulk CSV loading
-- These settings optimize for large data imports

-- Memory settings for bulk operations
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET maintenance_work_mem = '256MB';

-- Checkpoint settings for bulk loads
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';

-- Parallel query settings (for aggregations on large tables)
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
ALTER SYSTEM SET max_parallel_workers = 8;
ALTER SYSTEM SET max_worker_processes = 8;

-- Enable parallel operations
ALTER SYSTEM SET parallel_leader_participation = on;
ALTER SYSTEM SET min_parallel_table_scan_size = '8MB';
ALTER SYSTEM SET min_parallel_index_scan_size = '512kB';

-- Autovacuum tuning (less aggressive during bulk loads)
ALTER SYSTEM SET autovacuum_max_workers = 2;
ALTER SYSTEM SET autovacuum_naptime = '1min';

-- Logging for performance monitoring (optional, comment out if too verbose)
-- ALTER SYSTEM SET log_min_duration_statement = '1000';  -- Log queries > 1s
-- ALTER SYSTEM SET log_statement = 'mod';  -- Log all data modifications

-- Apply settings (requires reload)
SELECT pg_reload_conf();

-- Create indexes after initial load for better performance
-- These will be created by separate migration scripts when needed
