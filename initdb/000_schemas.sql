-- Set datestyle to ISO for YYYY-MM-DD format (matches Excel exports)
ALTER DATABASE appdb SET datestyle = 'ISO, MDY';

-- Layered schemas
create schema if not exists raw;
create schema if not exists ref;
create schema if not exists core;
create schema if not exists mart;
