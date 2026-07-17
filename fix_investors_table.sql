-- ============================================================
-- إصلاح جدول investors — يضيف الأعمدة الناقصة إن لزم فقط
-- آمن للتشغيل بأي وقت، حتى لو الجدول سليم أصلاً (لن يكرر أي شيء)
-- ============================================================

-- حذف أي صفوف تجريبية قديمة ناقصة (من نسخة سابقة بدون اسم مستخدم)
delete from investors where username is null;

-- إضافة الأعمدة الناقصة إن لم تكن موجودة
alter table investors add column if not exists username text;
alter table investors add column if not exists password_hash text;

-- التأكد من تفرّد اسم المستخدم
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'investors_username_key'
  ) then
    alter table investors add constraint investors_username_key unique (username);
  end if;
end $$;

-- جعل العمودين إلزاميين
alter table investors alter column username set not null;
alter table investors alter column password_hash set not null;

-- التأكد من صلاحيات القراءة/التنفيذ (تكرارها آمن)
grant select (id, name, username, created_at) on investors to anon, authenticated;
grant execute on function create_investor(text,text,text) to anon, authenticated;
grant execute on function verify_investor(text,text) to anon, authenticated;

-- تحقق سريع: يعرض أعمدة الجدول الحالية للتأكيد
select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'investors'
order by ordinal_position;
