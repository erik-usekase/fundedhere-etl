-- Set datestyle to handle DD-MM-YY format in CSVs
ALTER DATABASE appdb SET datestyle = 'DMY';

-- Layered schemas
create schema if not exists raw;
create schema if not exists ref;
create schema if not exists core;
create schema if not exists mart;
