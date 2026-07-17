-- ============================================================
-- ترقية: تسجيل الشركات الذاتي + تشديد أمني إضافي
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

-- عمود رمز الوصول (يختاره فريق الشركة بنفسه)
alter table companies add column if not exists access_code_hash text;

-- دوال التسجيل الذاتي
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

-- تشديد أمني: منع قراءة access_code_hash من المتصفح (نفس أسلوب كلمات مرور المستثمرين)
revoke select on companies from anon, authenticated;
grant select (id, name, sector, emoji, team_members, problem, solution, value_prop, video_url, booth_number, created_at) on companies to anon, authenticated;

-- تحقق: access_code_hash يجب ألا يظهر في هذه القائمة (يعني anon ما يقدر يقرأه)
select column_name from information_schema.column_privileges
where table_name = 'companies' and grantee = 'anon' and privilege_type = 'SELECT'
order by column_name;
