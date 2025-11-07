-- Set datestyle to ISO, MDY to handle M/D/YYYY format from CSV exports
-- This MUST match the CSV date format (9/29/2025 = September 29, 2025)
-- Without this setting, databases with DMY default will fail on dates like 9/29/2025
ALTER DATABASE appdb SET datestyle = 'ISO, MDY';

-- Layered schemas
create schema if not exists raw;
create schema if not exists ref;
create schema if not exists core;
create schema if not exists mart;
