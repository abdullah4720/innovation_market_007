-- ============================================================
-- MASTER MIGRATION — ملف واحد شامل لكل التحديثات
-- آمن للتشغيل بأي وقت، بغض النظر عن أي تحديثات سابقة شغّلتها
-- أو لم تشغّلها من قبل. شغّله كاملاً في SQL Editor.
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- 1) الأعمدة المفقودة على كل جدول
-- ============================================================

-- event_state: الميزانية والإعدادات العامة
alter table event_state add column if not exists investor_budget int not null default 5000;
alter table event_state add column if not exists min_investment_per_company int not null default 100;
alter table event_state add column if not exists max_investment_per_company int not null default 5000;
alter table event_state add column if not exists min_companies_required int not null default 1;
alter table event_state add column if not exists winner_count int not null default 3;
alter table event_state add column if not exists winner_formula text not null default 'composite';
alter table event_state add column if not exists evaluation_frozen boolean not null default false;
alter table event_state add column if not exists results_hidden boolean not null default false;
alter table event_state add column if not exists registration_open boolean not null default true;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'event_state_winner_formula_check') then
    alter table event_state add constraint event_state_winner_formula_check
      check (winner_formula in ('composite','investment_only'));
  end if;
end $$;

-- companies: رمز وصول فريق الشركة
alter table companies add column if not exists access_code_hash text;

-- رقم المشروع صار إلزامياً (يُقارَن برقم مشروع المستثمر لمنع الاستثمار الذاتي)
update companies set booth_number = 'غير محدد' where booth_number is null or trim(booth_number) = '';
alter table companies alter column booth_number set not null;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'companies_booth_number_not_empty') then
    alter table companies add constraint companies_booth_number_not_empty check (trim(booth_number) <> '');
  end if;
end $$;

-- investors: يوزرنيم/باسورد قديم + علامة إنهاء التقييم؛ الباسورد صار اختيارياً
alter table investors add column if not exists evaluation_done boolean not null default false;
alter table investors add column if not exists project_number text;
alter table investors alter column password_hash drop not null;

-- visits: ملاحظات خاصة أثناء الاستكشاف
alter table visits add column if not exists notes text;

-- evaluations: ملاحظات المستثمر للفريق
alter table evaluations add column if not exists notes text;

-- ============================================================
-- 2) كل الدوال (RPC) — create or replace آمن دائماً
-- ============================================================

create or replace function create_investor(p_name text, p_username text, p_password text)
returns table(id uuid, name text, username text)
language plpgsql security definer as $$
begin
  return query
  insert into investors(name, username, password_hash)
  values (p_name, lower(trim(p_username)), null)
  returning investors.id, investors.name, investors.username;
end;
$$;

create or replace function verify_investor(p_username text, p_password text)
returns table(id uuid, name text)
language plpgsql security definer as $$
begin
  return query
  select investors.id, investors.name
  from investors
  where investors.username = lower(trim(p_username))
    and investors.password_hash is not null
    and investors.password_hash = crypt(trim(p_password), investors.password_hash);
end;
$$;

create or replace function admin_count()
returns bigint
language sql security definer as $$
  select count(*) from admin_accounts;
$$;

create or replace function create_admin(p_username text, p_password text)
returns table(id uuid, username text)
language plpgsql security definer as $$
begin
  return query
  insert into admin_accounts(username, password_hash)
  values (lower(trim(p_username)), crypt(trim(p_password), gen_salt('bf', 8)))
  returning admin_accounts.id, admin_accounts.username;
end;
$$;

create or replace function verify_admin(p_username text, p_password text)
returns table(id uuid, username text)
language plpgsql security definer as $$
begin
  return query
  select admin_accounts.id, admin_accounts.username
  from admin_accounts
  where admin_accounts.username = lower(trim(p_username))
    and admin_accounts.password_hash = crypt(trim(p_password), admin_accounts.password_hash);
end;
$$;

create or replace function mark_evaluation_done(p_investor_id uuid)
returns void
language sql security definer as $$
  update investors set evaluation_done = true where id = p_investor_id;
$$;

-- دخول المستثمر بالاسم + رقم المشروع + رمز بسيط (PIN): تسجيل ذاتي فوري لأي اسم جديد،
-- ويدعم أيضاً أسماء أضافها المنظّم مسبقاً بلا رمز (يُحدَّد أول دخول)
-- رقم المشروع حقل إضافي فقط يُحفظ مع بيانات المستثمر، بدون أي تأثير على صلاحياته
drop function if exists investor_login_or_register(text,text);
drop function if exists investor_login_or_register(text,text,text);

create function investor_login_or_register(p_name text, p_project_number text, p_pin text)
returns table(id uuid, name text, project_number text)
language plpgsql security definer as $$
declare
  v_id uuid;
  v_hash text;
  v_name text;
  v_project text;
  v_registration_open boolean;
begin
  select investors.id, investors.password_hash, investors.name
    into v_id, v_hash, v_name
  from investors
  where lower(trim(investors.name)) = lower(trim(p_name))
  limit 1;

  if v_id is null then
    select registration_open into v_registration_open from event_state where event_state.id = 1;
    if coalesce(v_registration_open, true) = false then
      raise exception 'التسجيل مغلق حالياً. تواصل مع منظّم الفعالية.';
    end if;
    v_project := nullif(trim(p_project_number), '');
    insert into investors(name, username, password_hash, project_number)
    values (
      trim(p_name),
      lower(trim(p_name)) || '-' || substr(gen_random_uuid()::text, 1, 6),
      crypt(trim(p_pin), gen_salt('bf', 8)),
      v_project
    )
    returning investors.id, investors.name into v_id, v_name;
    return query select v_id, v_name, v_project;
  elsif v_hash is null then
    v_project := nullif(trim(p_project_number), '');
    update investors set password_hash = crypt(trim(p_pin), gen_salt('bf', 8)), project_number = v_project where investors.id = v_id;
    return query select v_id, v_name, v_project;
  else
    if v_hash = crypt(trim(p_pin), v_hash) then
      v_project := coalesce(nullif(trim(p_project_number), ''), (select project_number from investors where investors.id = v_id));
      update investors set project_number = v_project where investors.id = v_id;
      return query select v_id, v_name, v_project;
    else
      raise exception 'الرمز غير صحيح لهذا الاسم';
    end if;
  end if;
end;
$$;

-- تسجيل الشركات الذاتي
create or replace function register_company(
  p_name text, p_sector text, p_emoji text, p_team_members text,
  p_problem text, p_solution text, p_value_prop text, p_video_url text,
  p_booth_number text, p_access_code text
)
returns table(id uuid, name text)
language plpgsql security definer as $$
begin
  return query
  insert into companies(name, sector, emoji, team_members, problem, solution, value_prop, video_url, booth_number, access_code_hash)
  values (
    trim(p_name), p_sector, coalesce(nullif(trim(p_emoji),''), '🚀'), p_team_members,
    p_problem, p_solution, p_value_prop, p_video_url, p_booth_number,
    crypt(trim(p_access_code), gen_salt('bf', 8))
  )
  returning companies.id, companies.name;
end;
$$;

create or replace function verify_company_access(p_name text, p_access_code text)
returns table(id uuid, name text)
language plpgsql security definer as $$
begin
  return query
  select companies.id, companies.name
  from companies
  where lower(trim(companies.name)) = lower(trim(p_name))
    and companies.access_code_hash is not null
    and companies.access_code_hash = crypt(trim(p_access_code), companies.access_code_hash);
end;
$$;

create or replace function update_company_profile(
  p_company_id uuid, p_access_code text,
  p_sector text, p_emoji text, p_team_members text,
  p_problem text, p_solution text, p_value_prop text, p_video_url text, p_booth_number text
)
returns void
language plpgsql security definer as $$
begin
  update companies set
    sector = p_sector,
    emoji = coalesce(nullif(trim(p_emoji),''), emoji),
    team_members = p_team_members,
    problem = p_problem,
    solution = p_solution,
    value_prop = p_value_prop,
    video_url = p_video_url,
    booth_number = p_booth_number
  where id = p_company_id
    and access_code_hash is not null
    and access_code_hash = crypt(trim(p_access_code), access_code_hash);

  if not found then
    raise exception 'رمز الوصول غير صحيح أو الشركة غير موجودة';
  end if;
end;
$$;

grant execute on function create_investor(text,text,text) to anon, authenticated;
grant execute on function verify_investor(text,text) to anon, authenticated;
grant execute on function admin_count() to anon, authenticated;
grant execute on function create_admin(text,text) to anon, authenticated;
grant execute on function verify_admin(text,text) to anon, authenticated;
grant execute on function mark_evaluation_done(uuid) to anon, authenticated;
grant execute on function investor_login_or_register(text,text,text) to anon, authenticated;
grant execute on function register_company(text,text,text,text,text,text,text,text,text,text) to anon, authenticated;
grant execute on function verify_company_access(text,text) to anon, authenticated;
grant execute on function update_company_profile(uuid,text,text,text,text,text,text,text,text,text) to anon, authenticated;

-- ============================================================
-- 3) كل سياسات RLS — بأسلوب آمن يتحقق قبل الإنشاء
-- ============================================================

alter table event_state enable row level security;
alter table companies enable row level security;
alter table admin_accounts enable row level security;
alter table investors enable row level security;
alter table visits enable row level security;
alter table watchlist enable row level security;
alter table evaluations enable row level security;

create or replace function _ensure_policy(p_table text, p_name text, p_cmd text, p_definition text) returns void as $$
begin
  if not exists (select 1 from pg_policies where tablename = p_table and policyname = p_name) then
    execute format('create policy %I on %I for %s using (%s)', p_name, p_table, p_cmd, p_definition);
  end if;
end;
$$ language plpgsql;

select _ensure_policy('event_state', 'public read event_state', 'select', 'true');
select _ensure_policy('event_state', 'public update event_state', 'update', 'true');

select _ensure_policy('companies', 'public read companies', 'select', 'true');
select _ensure_policy('companies', 'public update companies', 'update', 'true');
select _ensure_policy('companies', 'public delete companies', 'delete', 'true');

select _ensure_policy('visits', 'public read visits', 'select', 'true');
select _ensure_policy('visits', 'public update visits', 'update', 'true');

select _ensure_policy('watchlist', 'public read watchlist', 'select', 'true');
select _ensure_policy('watchlist', 'public update watchlist', 'update', 'true');
select _ensure_policy('watchlist', 'public delete watchlist', 'delete', 'true');

select _ensure_policy('evaluations', 'public read evaluations', 'select', 'true');
select _ensure_policy('evaluations', 'public update evaluations', 'update', 'true');

select _ensure_policy('investors', 'public read investor names', 'select', 'true');

-- سياسات INSERT (تحتاج "with check" بدل "using" — تُضاف يدوياً بدون الدالة أعلاه)
do $$
begin
  if not exists (select 1 from pg_policies where tablename='companies' and policyname='public write companies') then
    create policy "public write companies" on companies for insert with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='visits' and policyname='public write visits') then
    create policy "public write visits" on visits for insert with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='watchlist' and policyname='public write watchlist') then
    create policy "public write watchlist" on watchlist for insert with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='evaluations' and policyname='public write evaluations') then
    create policy "public write evaluations" on evaluations for insert with check (true);
  end if;
end $$;

drop function _ensure_policy(text,text,text,text);

-- ============================================================
-- 4) الصلاحيات على مستوى الأعمدة (إخفاء كلمات المرور ورموز الوصول)
-- ============================================================

revoke select on companies from anon, authenticated;
grant select (id, name, sector, emoji, team_members, problem, solution, value_prop, video_url, booth_number, created_at) on companies to anon, authenticated;

revoke select on investors from anon, authenticated;
grant select (id, name, username, evaluation_done, project_number, created_at) on investors to anon, authenticated;
revoke insert, update, delete on investors from anon, authenticated;

revoke all on admin_accounts from anon, authenticated;

-- ============================================================
-- 5) تفعيل التحديثات اللحظية (آمن التكرار)
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='event_state'
  ) then
    alter publication supabase_realtime add table event_state;
  end if;
  if not exists (
    select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='visits'
  ) then
    alter publication supabase_realtime add table visits;
  end if;
  if not exists (
    select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='evaluations'
  ) then
    alter publication supabase_realtime add table evaluations;
  end if;
end $$;

-- ============================================================
-- 6) تحقق نهائي — راجع هذه النتائج للتأكد أن كل شيء تم بنجاح
-- ============================================================
select 'event_state columns' as check_name, string_agg(column_name, ', ') as result
from information_schema.columns where table_name='event_state'
union all
select 'functions installed', string_agg(routine_name, ', ')
from information_schema.routines
where routine_name in ('create_investor','verify_investor','investor_login_or_register','register_company','verify_company_access','update_company_profile','mark_evaluation_done','admin_count','create_admin','verify_admin')
union all
select 'update policies present', string_agg(tablename||':'||policyname, ', ')
from pg_policies where cmd='UPDATE' and tablename in ('visits','watchlist','evaluations','companies','event_state')
union all
select 'investors columns', string_agg(column_name, ', ')
from information_schema.columns where table_name='investors';
