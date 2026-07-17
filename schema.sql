-- ============================================================
-- Innovation Marketplace | Digital Demo Day
-- حاضنة ابتكار 5 — قاعدة بيانات Supabase (مع نظام دخول احترافي)
-- شغّل هذا الملف كاملاً في Supabase SQL Editor
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";   -- لتشفير كلمات المرور (bcrypt)

-- ============================================================
-- الجداول
-- ============================================================

-- حالة الفعالية (صف واحد فقط يتحكم بالمرحلة الحالية)
create table if not exists event_state (
  id int primary key default 1,
  phase text not null default 'explore' check (phase in ('explore','evaluation','results')),
  investor_budget int not null default 5000,
  min_investment_per_company int not null default 100,
  max_investment_per_company int not null default 5000,
  min_companies_required int not null default 1,
  winner_count int not null default 3,
  winner_formula text not null default 'composite' check (winner_formula in ('composite','investment_only')),
  evaluation_frozen boolean not null default false, -- تجميد التقييم: يمنع أي تقييمات/استثمارات جديدة حتى لو المرحلة "تقييم"
  results_hidden boolean not null default false, -- إخفاء النتائج مؤقتاً حتى لو المرحلة "نتائج"
  registration_open boolean not null default true, -- السماح بتسجيل مستثمرين جدد بأسماء لم تُستخدم من قبل
  updated_at timestamptz default now()
);
insert into event_state (id, phase) values (1, 'explore')
  on conflict (id) do nothing;

-- ترقية لقواعد بيانات أُنشئت قبل إضافة نظام الميزانية والإعدادات العامة
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
  if not exists (
    select 1 from pg_constraint where conname = 'event_state_winner_formula_check'
  ) then
    alter table event_state add constraint event_state_winner_formula_check
      check (winner_formula in ('composite','investment_only'));
  end if;
end $$;

-- الشركات / الفرق المشاركة
create table if not exists companies (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  sector text,
  emoji text default '🚀',
  team_members text,
  problem text,
  solution text,
  value_prop text,
  video_url text,
  booth_number text not null, -- رقم المشروع: إلزامي، يُقارَن برقم مشروع المستثمر لمنع الاستثمار الذاتي
  access_code_hash text, -- رمز وصول يختاره فريق الشركة نفسه لتعديل بياناتهم لاحقاً
  created_at timestamptz default now()
);

-- ترقية لقواعد بيانات أُنشئت قبل إضافة التسجيل الذاتي للشركات
alter table companies add column if not exists access_code_hash text;

-- ترقية لقواعد بيانات أُنشئت قبل إلزامية رقم المشروع: نعبّئ القيم الفارغة أولاً ثم نفرض الإلزامية
update companies set booth_number = 'غير محدد' where booth_number is null or trim(booth_number) = '';
alter table companies alter column booth_number set not null;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'companies_booth_number_not_empty') then
    alter table companies add constraint companies_booth_number_not_empty check (trim(booth_number) <> '');
  end if;
end $$;

-- حسابات المنظّمين (لوحة التحكم)
create table if not exists admin_accounts (
  id uuid primary key default uuid_generate_v4(),
  username text unique not null,
  password_hash text not null,
  created_at timestamptz default now()
);

-- المستثمرون (المشاركون) — الاسم يضيفه المنظّم مسبقاً، والمستثمر يحدّد رمزه (PIN) بنفسه أول مرة يدخل
create table if not exists investors (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  username text unique not null,
  password_hash text, -- فارغ حتى يحدّد المستثمر رمزه أول مرة يدخل
  evaluation_done boolean not null default false, -- هل أنهى المستثمر مرحلة التقييم بنفسه؟
  project_number text, -- حقل إضافي يُدخله المستثمر (بدون أي تأثير على صلاحياته)
  created_at timestamptz default now()
);

-- ترقية لقواعد بيانات أُنشئت قبل هذا التغيير
alter table investors alter column password_hash drop not null;

-- ترقية لقواعد بيانات أُنشئت قبل إضافة علامة "إنهاء التقييم"
alter table investors add column if not exists evaluation_done boolean not null default false;

-- ترقية لقواعد بيانات أُنشئت قبل إضافة حقل رقم المشروع
alter table investors add column if not exists project_number text;

-- الزيارات المؤكدة للأجنحة
create table if not exists visits (
  id uuid primary key default uuid_generate_v4(),
  investor_id uuid references investors(id) on delete cascade,
  company_id uuid references companies(id) on delete cascade,
  visited_at timestamptz default now(),
  notes text, -- ملاحظات المستثمر الخاصة أثناء الاستكشاف (تذكير شخصي قبل مرحلة التقييم)
  unique (investor_id, company_id)
);

-- ترقية لقواعد بيانات أُنشئت قبل إضافة حقل الملاحظات
alter table visits add column if not exists notes text;

-- قائمة المتابعة (Watchlist)
create table if not exists watchlist (
  id uuid primary key default uuid_generate_v4(),
  investor_id uuid references investors(id) on delete cascade,
  company_id uuid references companies(id) on delete cascade,
  added_at timestamptz default now(),
  unique (investor_id, company_id)
);

-- التقييمات النهائية
create table if not exists evaluations (
  id uuid primary key default uuid_generate_v4(),
  investor_id uuid references investors(id) on delete cascade,
  company_id uuid references companies(id) on delete cascade,
  innovation int check (innovation between 1 and 5),
  market_size int check (market_size between 1 and 5),
  team int check (team between 1 and 5),
  feasibility int check (feasibility between 1 and 5),
  investability int check (investability between 1 and 5),
  investment_amount int not null,
  notes text,
  submitted_at timestamptz default now(),
  unique (investor_id, company_id)
);

-- ترقية لقواعد بيانات أُنشئت قبل إضافة حقل الملاحظات
alter table evaluations add column if not exists notes text;

-- ============================================================
-- دوال الدخول الآمن (Password Verification RPC)
-- كلمة المرور تُشفَّر وتُقارن بالكامل داخل قاعدة البيانات؛
-- الواجهة (المتصفح) لا ترى ولا تستقبل أي "password_hash" إطلاقاً.
-- ============================================================

-- إنشاء حساب مستثمر (تستخدمها لوحة تحكم المنظّم فقط)
create or replace function create_investor(p_name text, p_username text, p_password text)
returns table(id uuid, name text, username text)
language plpgsql security definer as $$
begin
  return query
  insert into investors(name, username, password_hash)
  values (p_name, lower(trim(p_username)), null) -- الرمز يحدّده المستثمر بنفسه أول دخول
  returning investors.id, investors.name, investors.username;
end;
$$;

-- التحقق من دخول مستثمر (نظام قديم بمستخدم/كلمة مرور — غير مستخدم حالياً، أُبقي عليه للتوافق)
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

-- عدد حسابات المنظّمين (لمعرفة إن كان يلزم إنشاء أول حساب)
create or replace function admin_count()
returns bigint
language sql security definer as $$
  select count(*) from admin_accounts;
$$;

-- إنشاء حساب منظّم (يُستخدم مرة واحدة عند أول تشغيل، أو لإضافة منظّمين آخرين)
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

-- التحقق من دخول منظّم
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

-- يسمح للمستثمر بتعليم نفسه بأنه أنهى مرحلة التقييم (بدون صلاحية تعديل أي عمود آخر)
create or replace function mark_evaluation_done(p_investor_id uuid)
returns void
language sql security definer as $$
  update investors set evaluation_done = true where id = p_investor_id;
$$;

grant execute on function create_investor(text,text,text) to anon, authenticated;
grant execute on function verify_investor(text,text) to anon, authenticated;
grant execute on function admin_count() to anon, authenticated;
grant execute on function create_admin(text,text) to anon, authenticated;
grant execute on function verify_admin(text,text) to anon, authenticated;
grant execute on function mark_evaluation_done(uuid) to anon, authenticated;

-- ============================================================
-- دخول المستثمر بالاسم + رمز بسيط (PIN) — سهل وميسّر
-- أول مرة يُدخل فيها اسم جديد، يُنشأ له حساب تلقائياً بنفس الرمز.
-- أي مرة لاحقة بنفس الاسم، يجب إدخال نفس الرمز.
-- ============================================================
-- ============================================================
-- دخول المستثمر بالاسم + رقم المشروع (حقل إضافي بلا تأثير على الصلاحيات) + رمز بسيط (PIN):
-- - اسم جديد كلياً: يُنشأ له حساب تلقائياً بهذا الاسم والرمز (تسجيل ذاتي).
-- - اسم أضافه المنظّم مسبقاً بدون رمز: يُقفَل الرمز عليه أول دخول.
-- - اسم له رمز مُحدَّد مسبقاً: يجب إدخال نفس الرمز بالضبط.
-- ملاحظة: نحذف النسخة القديمة (بدون رقم المشروع) لأن توقيع الدالة تغيّر
-- ============================================================
drop function if exists investor_login_or_register(text,text);

drop function if exists investor_login_or_register(text, text, text);
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
    -- اسم جديد كلياً: تسجيل ذاتي فوري، إلا إذا كان التسجيل مغلقاً
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
    -- موجود مسبقاً (أضافه المنظّم) لكن بلا رمز: يحدّده الآن ويُقفل عليه
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

grant execute on function investor_login_or_register(text,text,text) to anon, authenticated;

-- ============================================================
-- تسجيل الشركات الذاتي (بدون لوحة تحكم) — بواسطة فريق الشركة نفسه
-- محمي برمز وصول يختاره الفريق عند التسجيل، ولا يُقرأ أبداً من المتصفح
-- (يُقارن داخل قاعدة البيانات فقط، بنفس أسلوب كلمات مرور المستثمرين)
-- ============================================================

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

grant execute on function register_company(text,text,text,text,text,text,text,text,text,text) to anon, authenticated;
grant execute on function verify_company_access(text,text) to anon, authenticated;
grant execute on function update_company_profile(uuid,text,text,text,text,text,text,text,text,text) to anon, authenticated;

-- ============================================================
-- Row Level Security
-- ============================================================
alter table event_state enable row level security;
alter table companies enable row level security;
alter table admin_accounts enable row level security;
alter table investors enable row level security;
alter table visits enable row level security;
alter table watchlist enable row level security;
alter table evaluations enable row level security;

create policy "public read event_state" on event_state for select using (true);
create policy "public update event_state" on event_state for update using (true);

create policy "public read companies" on companies for select using (true);
create policy "public write companies" on companies for insert with check (true);
create policy "public update companies" on companies for update using (true);
create policy "public delete companies" on companies for delete using (true);

-- منع قراءة رمز وصول الشركة المشفّر من المتصفح إطلاقاً (نفس أسلوب كلمات مرور المستثمرين)
-- نلغي أولاً أي صلاحية قراءة عامة على الجدول كاملاً (Supabase يمنحها افتراضياً)
-- قبل تحديد الأعمدة المسموح بقراءتها فقط
revoke select on companies from anon, authenticated;
grant select (id, name, sector, emoji, team_members, problem, solution, value_prop, video_url, booth_number, created_at) on companies to anon, authenticated;

-- ملاحظة: لا توجد أي سياسة SELECT مباشرة على admin_accounts أو investors —
-- الوصول إليهما يتم حصراً عبر دوال RPC أعلاه (SECURITY DEFINER) التي لا
-- تُعيد أبداً عمود password_hash. هذا يمنع أي إمكانية لقراءة كلمات المرور
-- المشفّرة من المتصفح حتى لو امتلك أحدهم مفتاح anon.

create policy "public read visits" on visits for select using (true);
create policy "public write visits" on visits for insert with check (true);
create policy "public update visits" on visits for update using (true);

create policy "public read watchlist" on watchlist for select using (true);
create policy "public write watchlist" on watchlist for insert with check (true);
create policy "public update watchlist" on watchlist for update using (true);
create policy "public delete watchlist" on watchlist for delete using (true);

create policy "public read evaluations" on evaluations for select using (true);
create policy "public write evaluations" on evaluations for insert with check (true);
create policy "public update evaluations" on evaluations for update using (true);

-- نحتاج قراءة أسماء/عدد المستثمرين لعرض الإحصاءات في لوحة التحكم (بدون كلمات المرور)
create policy "public read investor names" on investors for select using (true);
-- سياسة الإدخال المباشر على investors مُقفلة عمداً؛ الإدخال يتم فقط عبر create_investor()

-- نلغي أولاً أي صلاحية قراءة عامة على الجدول كاملاً (Supabase يمنحها افتراضياً)
-- قبل تحديد الأعمدة المسموح بقراءتها فقط (لإخفاء password_hash تماماً)
revoke select on investors from anon, authenticated;
grant select (id, name, username, evaluation_done, project_number, created_at) on investors to anon, authenticated;
revoke insert, update, delete on investors from anon, authenticated;
revoke all on admin_accounts from anon, authenticated;

-- تفعيل التحديثات اللحظية (Realtime)
alter publication supabase_realtime add table event_state;
alter publication supabase_realtime add table visits;
alter publication supabase_realtime add table evaluations;
