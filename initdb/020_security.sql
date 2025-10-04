-- Simple read-only role (change password in real envs)
do $$
begin
  if not exists (select 1 from pg_roles where rolname='app_reader') then
    create role app_reader login password 'changeme';
  end if;
end$$;

grant usage on schema raw, ref, core, mart to app_reader;
grant select on all tables in schema raw, ref, core, mart to app_reader;
alter default privileges in schema raw, ref, core, mart
  grant select on tables to app_reader;
