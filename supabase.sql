-- Duo shared budget — schema v2 (idempotent)
create extension if not exists pgcrypto with schema extensions;

-- ───────────── Tables ─────────────
create table if not exists public.household (
  id            int primary key default 1 check (id = 1),
  currency      text not null default '€' check (char_length(currency) between 1 and 4),
  cycle_starter text not null default 'any' check (cycle_starter in ('A','B','any')),
  updated_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now()
);

create table if not exists public.household_secret (
  id              int primary key default 1 check (id = 1),
  passphrase_hash text not null,
  created_at      timestamptz not null default now()
);

create table if not exists public.members (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  slot         text not null unique check (slot in ('A','B')),
  display_name text not null check (char_length(display_name) between 1 and 24),
  joined_at    timestamptz not null default now()
);

create table if not exists public.join_attempts (
  id      bigint generated always as identity primary key,
  user_id uuid not null,
  at      timestamptz not null default now()
);

create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  amount       numeric(12,2) not null check (amount > 0),
  category     text not null check (category in ('groceries','dining','utilities','transport','entertainment','misc')),
  description  text not null default '' check (char_length(description) <= 140),
  spent_on     date not null default current_date,
  paid_by      text not null check (paid_by in ('A','B')),
  source       text not null default 'manual' check (source in ('manual','email','bank')),
  external_ref text unique,
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_by   uuid references auth.users(id) on delete set null,
  updated_at   timestamptz,
  deleted_by   uuid references auth.users(id) on delete set null,
  deleted_at   timestamptz
);
create index if not exists expenses_spent_on_idx on public.expenses (spent_on desc);

create table if not exists public.incomes (
  id           uuid primary key default gen_random_uuid(),
  amount       numeric(12,2) not null check (amount > 0),
  earner       text not null check (earner in ('A','B')),
  label        text not null default 'Salary' check (char_length(label) between 1 and 40),
  received_on  date not null default current_date,
  starts_cycle boolean not null default true,
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_by   uuid references auth.users(id) on delete set null,
  updated_at   timestamptz,
  deleted_by   uuid references auth.users(id) on delete set null,
  deleted_at   timestamptz
);
create index if not exists incomes_received_on_idx on public.incomes (received_on desc);

create table if not exists public.budgets (
  category       text not null check (category in ('groceries','dining','utilities','transport','entertainment','misc')),
  effective_from date not null,
  amount         numeric(12,2) not null check (amount >= 0),
  updated_by     uuid references auth.users(id) on delete set null,
  updated_at     timestamptz not null default now(),
  primary key (category, effective_from)
);

create table if not exists public.activity_log (
  id        bigint generated always as identity primary key,
  at        timestamptz not null default now(),
  actor     uuid references auth.users(id) on delete set null,
  entity    text not null,          -- 'expenses' | 'incomes' | 'budgets' | 'household' | 'members'
  action    text not null,          -- 'add' | 'edit' | 'delete' | 'restore'
  entity_id text not null,
  data      jsonb not null
);
create index if not exists activity_log_at_idx on public.activity_log (at desc);

-- Seed: default budgets effective from the beginning of time; household row
insert into public.budgets (category, effective_from, amount) values
  ('groceries','2000-01-01',500), ('dining','2000-01-01',200), ('utilities','2000-01-01',250),
  ('transport','2000-01-01',150), ('entertainment','2000-01-01',100), ('misc','2000-01-01',100)
on conflict (category, effective_from) do nothing;
insert into public.household (id) values (1) on conflict (id) do nothing;

-- ───────────── Helper functions ─────────────
create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members where user_id = auth.uid());
$$;

create or replace function public.household_status() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'exists',       exists (select 1 from public.household_secret),
    'member_count', (select count(*) from public.members),
    'my_slot',      (select slot from public.members where user_id = auth.uid())
  );
$$;

create or replace function public.create_household(p_passphrase text, p_display_name text, p_currency text default '€')
returns text language plpgsql security definer set search_path = public, extensions as $$
begin
  if auth.uid() is null then raise exception 'DUO_NOT_AUTHENTICATED'; end if;
  if exists (select 1 from public.household_secret) then raise exception 'DUO_HOUSEHOLD_EXISTS'; end if;
  if p_passphrase is null or char_length(p_passphrase) < 8 then raise exception 'DUO_PASSPHRASE_TOO_SHORT'; end if;
  if p_display_name is null or char_length(trim(p_display_name)) not between 1 and 24 then raise exception 'DUO_BAD_NAME'; end if;
  insert into public.household_secret (id, passphrase_hash) values (1, crypt(p_passphrase, gen_salt('bf', 10)));
  update public.household set currency = coalesce(nullif(trim(p_currency), ''), '€') where id = 1;
  insert into public.members (user_id, slot, display_name) values (auth.uid(), 'A', trim(p_display_name));
  return 'A';
end $$;

create or replace function public.join_household(p_passphrase text, p_display_name text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare v_hash text; v_slot text;
begin
  if auth.uid() is null then raise exception 'DUO_NOT_AUTHENTICATED'; end if;
  select slot into v_slot from public.members where user_id = auth.uid();
  if v_slot is not null then return v_slot; end if;
  if (select count(*) from public.join_attempts where user_id = auth.uid() and at > now() - interval '15 minutes') >= 5 then
    raise exception 'DUO_TOO_MANY_ATTEMPTS';
  end if;
  -- Global cap too, so creating many throwaway accounts doesn't help guess the passphrase
  if (select count(*) from public.join_attempts where at > now() - interval '15 minutes') >= 20 then
    raise exception 'DUO_TOO_MANY_ATTEMPTS';
  end if;
  insert into public.join_attempts (user_id) values (auth.uid());
  select passphrase_hash into v_hash from public.household_secret where id = 1;
  if v_hash is null then raise exception 'DUO_NO_HOUSEHOLD'; end if;
  -- Wrong passphrase RETURNS (not raises) so the attempt row above is committed and counted.
  if crypt(p_passphrase, v_hash) <> v_hash then return 'DUO_WRONG_PASSPHRASE'; end if;
  if exists (select 1 from public.members where slot = 'B') then raise exception 'DUO_HOUSEHOLD_FULL'; end if;
  if p_display_name is null or char_length(trim(p_display_name)) not between 1 and 24 then raise exception 'DUO_BAD_NAME'; end if;
  insert into public.members (user_id, slot, display_name) values (auth.uid(), 'B', trim(p_display_name));
  delete from public.join_attempts where user_id = auth.uid();
  return 'B';
end $$;

-- ───────────── Server-side stamping (cannot be spoofed by the client) ─────────────
create or replace function public.stamp_row() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
    new.updated_by := null; new.updated_at := null;
    new.deleted_by := null; new.deleted_at := null;
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_by := auth.uid();
    new.updated_at := now();
    if old.deleted_at is null and new.deleted_at is not null then
      new.deleted_by := auth.uid(); new.deleted_at := now();
    elsif new.deleted_at is null then
      new.deleted_by := null;
    else
      new.deleted_by := old.deleted_by; new.deleted_at := old.deleted_at;
    end if;
  end if;
  return new;
end $$;

create or replace function public.stamp_updated() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end $$;

create or replace function public.log_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_new jsonb; v_old jsonb; v_action text; v_row jsonb; v_id text;
begin
  v_new := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  v_old := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  if tg_op = 'INSERT' then v_action := 'add';
  elsif tg_op = 'DELETE' then v_action := 'delete';
  elsif (v_old->>'deleted_at') is null and (v_new->>'deleted_at') is not null then v_action := 'delete';
  elsif (v_old->>'deleted_at') is not null and (v_new->>'deleted_at') is null then v_action := 'restore';
  else v_action := 'edit';
  end if;
  v_row := coalesce(v_new, v_old);
  v_id  := coalesce(v_row->>'id', v_row->>'user_id', (v_row->>'category') || '@' || (v_row->>'effective_from'));
  insert into public.activity_log (actor, entity, action, entity_id, data)
  values (auth.uid(), tg_table_name, v_action, v_id,
          jsonb_build_object('new', v_new, 'old', case when v_action = 'edit' then v_old end));
  return coalesce(new, old);
end $$;

drop trigger if exists expenses_stamp  on public.expenses;
drop trigger if exists incomes_stamp   on public.incomes;
drop trigger if exists budgets_stamp   on public.budgets;
drop trigger if exists household_stamp on public.household;
create trigger expenses_stamp  before insert or update on public.expenses  for each row execute function public.stamp_row();
create trigger incomes_stamp   before insert or update on public.incomes   for each row execute function public.stamp_row();
create trigger budgets_stamp   before insert or update on public.budgets   for each row execute function public.stamp_updated();
create trigger household_stamp before update            on public.household for each row execute function public.stamp_updated();

drop trigger if exists expenses_log  on public.expenses;
drop trigger if exists incomes_log   on public.incomes;
drop trigger if exists budgets_log   on public.budgets;
drop trigger if exists household_log on public.household;
drop trigger if exists members_log   on public.members;
create trigger expenses_log  after insert or update on public.expenses  for each row execute function public.log_change();
create trigger incomes_log   after insert or update on public.incomes   for each row execute function public.log_change();
create trigger budgets_log   after insert or update on public.budgets   for each row execute function public.log_change();
create trigger household_log after update            on public.household for each row execute function public.log_change();
create trigger members_log   after insert or update on public.members   for each row execute function public.log_change();

-- ───────────── Row Level Security ─────────────
alter table public.household        enable row level security;
alter table public.household_secret enable row level security;
alter table public.members          enable row level security;
alter table public.join_attempts    enable row level security;
alter table public.expenses         enable row level security;
alter table public.incomes          enable row level security;
alter table public.budgets          enable row level security;
alter table public.activity_log     enable row level security;

revoke all on public.household, public.household_secret, public.members, public.join_attempts,
              public.expenses, public.incomes, public.budgets, public.activity_log from anon;
revoke all on public.household_secret, public.join_attempts from authenticated;

revoke all on public.household, public.members, public.expenses, public.incomes, public.budgets, public.activity_log from authenticated;
grant select on public.household, public.members, public.expenses, public.incomes, public.budgets, public.activity_log to authenticated;
grant insert, update on public.expenses, public.incomes, public.budgets to authenticated;
revoke update on public.household, public.members from authenticated;
grant update (currency, cycle_starter) on public.household to authenticated;
grant update (display_name) on public.members to authenticated;

drop policy if exists duo_household_select on public.household;
drop policy if exists duo_household_update on public.household;
drop policy if exists duo_members_select   on public.members;
drop policy if exists duo_members_update   on public.members;
drop policy if exists duo_expenses_select  on public.expenses;
drop policy if exists duo_expenses_insert  on public.expenses;
drop policy if exists duo_expenses_update  on public.expenses;
drop policy if exists duo_incomes_select   on public.incomes;
drop policy if exists duo_incomes_insert   on public.incomes;
drop policy if exists duo_incomes_update   on public.incomes;
drop policy if exists duo_budgets_select   on public.budgets;
drop policy if exists duo_budgets_insert   on public.budgets;
drop policy if exists duo_budgets_update   on public.budgets;
drop policy if exists duo_activity_select  on public.activity_log;

create policy duo_household_select on public.household for select to authenticated using (public.is_member());
create policy duo_household_update on public.household for update to authenticated using (public.is_member()) with check (public.is_member());
create policy duo_members_select   on public.members   for select to authenticated using (public.is_member());
create policy duo_members_update   on public.members   for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy duo_expenses_select  on public.expenses  for select to authenticated using (public.is_member());
create policy duo_expenses_insert  on public.expenses  for insert to authenticated with check (public.is_member());
create policy duo_expenses_update  on public.expenses  for update to authenticated using (public.is_member()) with check (public.is_member());
create policy duo_incomes_select   on public.incomes   for select to authenticated using (public.is_member());
create policy duo_incomes_insert   on public.incomes   for insert to authenticated with check (public.is_member());
create policy duo_incomes_update   on public.incomes   for update to authenticated using (public.is_member()) with check (public.is_member());
create policy duo_budgets_select   on public.budgets   for select to authenticated using (public.is_member());
create policy duo_budgets_insert   on public.budgets   for insert to authenticated with check (public.is_member());
create policy duo_budgets_update   on public.budgets   for update to authenticated using (public.is_member()) with check (public.is_member());
create policy duo_activity_select  on public.activity_log for select to authenticated using (public.is_member());

drop function if exists public.record_join_failure();
revoke all on function public.is_member(), public.household_status(), public.create_household(text,text,text),
                       public.join_household(text,text) from public, anon;
grant execute on function public.is_member(), public.household_status(), public.create_household(text,text,text),
                          public.join_household(text,text) to authenticated;
revoke all on function public.stamp_row(), public.stamp_updated(), public.log_change() from public, anon, authenticated;
-- household_status is also callable before sign-in so the setup screen can verify the schema
grant execute on function public.household_status() to anon;

-- ───────────── Realtime ─────────────
alter table public.expenses     replica identity full;
alter table public.incomes      replica identity full;
alter table public.budgets      replica identity full;
alter table public.household    replica identity full;
alter table public.members      replica identity full;

do $$
declare t text;
begin
  foreach t in array array['expenses','incomes','budgets','household','members','activity_log'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
