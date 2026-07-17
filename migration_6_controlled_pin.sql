-- ============================================================
-- ترقية: منع ازدواجية الحسابات — الاسم يُضاف من المنظّم فقط،
-- والمستثمر يحدّد رمزه (PIN) بنفسه أول مرة يدخل بها فقط.
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

-- السماح بترك رمز المرور فارغاً حتى يحدّده المستثمر بنفسه
alter table investors alter column password_hash drop not null;

-- تحديث دالة إضافة مستثمر (تُستخدم من لوحة التحكم) بحيث لا تضع رمزاً عشوائياً بعد الآن
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

-- تحديث دالة الدخول: ترفض أي اسم غير مضاف مسبقاً، وتقفل الرمز أول استخدام
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
    raise exception 'هذا الاسم غير مسجّل. تواصل مع منظّم الفعالية لإضافتك.';
  end if;

  if v_hash is null then
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

-- ============================================================
-- ملاحظة مهمة: أي حسابات مستثمرين أنشأها النظام تلقائياً سابقاً
-- (بأسماء أدخلها المشاركون بأنفسهم، من إصدار سابق) ستبقى موجودة،
-- ويقدر أصحابها الدخول بها بنفس أسمائهم (سيُطلب منهم تحديد رمز
-- أول مرة إذا لم يحدّدوه من قبل). لا حاجة لحذفها يدوياً.
-- ============================================================

-- تحقق: يجب أن تظهر الدوال الثلاث هنا
select routine_name from information_schema.routines
where routine_name in ('create_investor','investor_login_or_register','verify_investor');
