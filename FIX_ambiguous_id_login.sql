-- ============================================================
-- إصلاح: خطأ "column reference id is ambiguous" عند الدخول مرة ثانية
-- السبب: الدالة تُرجع جدولاً فيه عمود اسمه "id"، وهذا يخلق متغيّراً
-- ضمنياً بنفس الاسم "id" داخل الدالة، فيتعارض مع عمود investors.id
-- عند استخدامه بدون توضيح داخل جملة UPDATE ... WHERE.
-- شغّل هذا الملف كاملاً في SQL Editor لإصلاحها فوراً.
-- ============================================================

create or replace function investor_login_or_register(p_name text, p_project_number text, p_pin text)
returns table(id uuid, name text)
language plpgsql security definer as $$
declare
  v_id uuid;
  v_hash text;
  v_name text;
begin
  select investors.id, investors.password_hash, investors.name
    into v_id, v_hash, v_name
  from investors
  where lower(trim(investors.name)) = lower(trim(p_name))
  limit 1;

  if v_id is null then
    insert into investors(name, username, password_hash, project_number)
    values (
      trim(p_name),
      lower(trim(p_name)) || '-' || substr(gen_random_uuid()::text, 1, 6),
      crypt(trim(p_pin), gen_salt('bf', 8)),
      nullif(trim(p_project_number), '')
    )
    returning investors.id, investors.name into v_id, v_name;
    return query select v_id, v_name;
  elsif v_hash is null then
    update investors set password_hash = crypt(trim(p_pin), gen_salt('bf', 8)), project_number = nullif(trim(p_project_number), '') where investors.id = v_id;
    return query select v_id, v_name;
  else
    if v_hash = crypt(trim(p_pin), v_hash) then
      update investors set project_number = nullif(trim(p_project_number), '') where investors.id = v_id;
      return query select v_id, v_name;
    else
      raise exception 'الرمز غير صحيح لهذا الاسم';
    end if;
  end if;
end;
$$;

grant execute on function investor_login_or_register(text,text,text) to anon, authenticated;

-- تحقق: يجب أن تظهر الدالة هنا
select routine_name from information_schema.routines where routine_name = 'investor_login_or_register';
