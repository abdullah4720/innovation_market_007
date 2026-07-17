-- ============================================================
-- ترقية: ضوابط إضافية للوحة التحكم
-- (تجميد التقييم، إخفاء النتائج مؤقتاً، إيقاف تسجيل مستثمرين جدد)
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

alter table event_state add column if not exists evaluation_frozen boolean not null default false;
alter table event_state add column if not exists results_hidden boolean not null default false;
alter table event_state add column if not exists registration_open boolean not null default true;

-- تحديث دالة الدخول لتمنع تسجيل أسماء جديدة عندما يكون التسجيل مغلقاً
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

grant execute on function investor_login_or_register(text,text,text) to anon, authenticated;

-- تحقق: يجب أن تظهر الأعمدة الثلاثة الجديدة هنا
select evaluation_frozen, results_hidden, registration_open from event_state where id = 1;
