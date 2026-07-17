-- ============================================================
-- ترقية: إرجاع التسجيل الذاتي (مع الإبقاء على رمز PIN)
-- أي اسم جديد كلياً الآن ينشئ حساباً تلقائياً بالرمز المُدخل،
-- وأسماء المنظّم المضافة مسبقاً (بلا رمز) تبقى تعمل كالسابق.
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

create or replace function investor_login_or_register(p_name text, p_pin text)
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
    insert into investors(name, username, password_hash)
    values (
      trim(p_name),
      lower(trim(p_name)) || '-' || substr(gen_random_uuid()::text, 1, 6),
      crypt(trim(p_pin), gen_salt('bf', 8))
    )
    returning investors.id, investors.name into v_id, v_name;
    return query select v_id, v_name;
  elsif v_hash is null then
    update investors set password_hash = crypt(trim(p_pin), gen_salt('bf', 8)) where id = v_id;
    return query select v_id, v_name;
  else
    if v_hash = crypt(trim(p_pin), v_hash) then
      return query select v_id, v_name;
    else
      raise exception 'الرمز غير صحيح لهذا الاسم';
    end if;
  end if;
end;
$$;

grant execute on function investor_login_or_register(text,text) to anon, authenticated;

select routine_name from information_schema.routines where routine_name = 'investor_login_or_register';
