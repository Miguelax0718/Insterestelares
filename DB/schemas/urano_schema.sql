-- =====================================================================
--  URANO · Esquema de base de datos (PostgreSQL / Supabase)
--  Ejecuta este archivo y después DB/samples/urano_seed.sql para tener los datos demo.
-- =====================================================================

create table if not exists mission (
  id             int primary key default 1,
  name           text not null,
  current_day    int  not null,
  total_days     int  not null,
  dose_limit_msv numeric not null default 600,
  start_date     date not null
);

create table if not exists solar_events (
  id         serial primary key,
  mission_id int references mission(id) default 1,
  day        int  not null,
  class      text not null            -- 'Clase C', 'Clase M', 'Clase X'
);

create table if not exists crew (
  id                       text primary key,   -- 'ana', 'leo'...
  sort_order               int  default 0,
  name                     text not null,
  role                     text not null,
  initials                 text not null,
  color                    text not null,      -- color del avatar (hex)
  age                      int,
  weight_kg                numeric,
  height_m                 numeric,
  dose_msv                 numeric default 0,  -- dosis acumulada (dosímetro)
  heart_rate               int,                -- wearable
  blood_pressure           text,
  water_ml_today           int default 0,
  water_goal_ml            int default 2500,
  sleep_hours              numeric,
  resistance_sessions_week int default 0,
  energy_pct               int default 0,      -- % de la meta de energía de hoy
  protein_pct              int default 0,
  mood                     int default 2       -- 0 a 4
);

-- Catálogo de biomarcadores. El id es el que usa la app (vol, ca, ntx...).
create table if not exists biomarkers (
  id         text primary key,
  name       text not null,
  unit       text,
  decimals   int  default 0,
  is_boolean boolean default false,  -- true = positivo/negativo (1/0)
  default_lo numeric,                -- rango normal por defecto
  default_hi numeric,
  scale_min  numeric,                -- extremos de la barra de rango
  scale_max  numeric
);

-- Rango personal de cada tripulante (línea base). Si no hay fila, se usa el rango por defecto.
create table if not exists personal_ranges (
  crew_id      text references crew(id) on delete cascade,
  biomarker_id text references biomarkers(id),
  lo numeric not null,
  hi numeric not null,
  primary key (crew_id, biomarker_id)
);

-- Una fila por muestra de orina...
create table if not exists samples (
  id          text primary key,
  crew_id     text references crew(id) on delete cascade,
  mission_day int  not null,
  taken_at    timestamptz not null,
  method      text check (method in ('sensor','tira','manual'))
);
-- ...y una fila por cada valor medido en esa muestra.
create table if not exists sample_values (
  sample_id    text references samples(id) on delete cascade,
  biomarker_id text references biomarkers(id),
  value        numeric not null,
  primary key (sample_id, biomarker_id)
);
create index if not exists samples_crew_time on samples(crew_id, taken_at);

create table if not exists recommendations (
  id         text primary key,
  crew_id    text references crew(id) on delete cascade,
  module     text not null,   -- hidratacion, renal, osea, radiacion, inmunidad, cardio, estres, metabolismo
  priority   text check (priority in ('Alta','Media','Baja')),
  text       text not null,
  why        text,
  done       boolean default false,
  created_at timestamptz default now()
);

create table if not exists alerts (
  id         text primary key,
  crew_id    text references crew(id) on delete cascade,
  severity   text check (severity in ('warn','crit')),
  module     text not null,
  title      text not null,
  cause      text,
  action     text,
  time_label text,
  status     text check (status in ('active','resolved')) default 'active',
  created_at timestamptz default now()
);

-- Cada clic en el vaso de agua guarda 250 ml aquí y suma al total del día.
create table if not exists water_log (
  id        serial primary key,
  crew_id   text references crew(id) on delete cascade,
  ml        int not null,
  logged_at timestamptz default now()
);
create or replace function add_water() returns trigger as $$
begin
  update crew set water_ml_today = water_ml_today + new.ml where id = new.crew_id;
  return new;
end $$ language plpgsql;
drop trigger if exists water_log_add on water_log;
create trigger water_log_add after insert on water_log for each row execute function add_water();

-- Cuando alguien registra una muestra nueva en la app, el contexto llega aquí.
-- El equipo de cálculos la procesa y crea la fila en samples + sample_values.
create table if not exists sample_requests (
  id         serial primary key,
  crew_id    text references crew(id) on delete cascade,
  payload    jsonb,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------
--  SOLO PARA EL HACKATHON (Supabase): permitir que la app lea y escriba
--  con la clave pública. No lo uses así con datos médicos reales.
-- ---------------------------------------------------------------------
do $$ declare t text; begin
  foreach t in array array['mission','solar_events','crew','biomarkers','personal_ranges','samples','sample_values','recommendations','alerts','water_log','sample_requests'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists demo_all on %I', t);
    execute format('create policy demo_all on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;
