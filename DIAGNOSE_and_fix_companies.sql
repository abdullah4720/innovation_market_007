-- ============================================================
-- تشخيص شامل + إصلاح دفاعي لمشكلة عدم ظهور الشركات
-- شغّل هذا الملف كاملاً، ثم انسخ لي كل النتائج اللي تطلع تحت
-- ============================================================

-- 1) هل الجدول فيه بيانات أصلاً؟ (بصلاحية المالك، بدون قيود RLS)
select count(*) as companies_count from companies;

-- 2) هل RLS مفعّل على الجدول؟
select relrowsecurity as rls_enabled
from pg_class where relname = 'companies';

-- 3) ما هي سياسات RLS الحالية على الجدول؟
select policyname, cmd, qual
from pg_policies
where tablename = 'companies';

-- 4) ما الأعمدة اللي يملك anon صلاحية قراءتها فعلياً؟
select column_name
from information_schema.column_privileges
where table_name = 'companies' and grantee = 'anon' and privilege_type = 'SELECT'
order by column_name;

-- ============================================================
-- إصلاح دفاعي: نعيد تأكيد كل شيء بغض النظر عن الحالة الحالية
-- ============================================================

-- إعادة تأكيد صلاحية القراءة على الأعمدة
grant select (
  id, name, sector, emoji, team_members, problem, solution,
  value_prop, video_url, booth_number, created_at
) on companies to anon, authenticated;

-- التأكد من تفعيل RLS
alter table companies enable row level security;

-- إعادة إنشاء سياسة القراءة العامة (تُحذف أولاً لتفادي خطأ "موجودة مسبقاً")
drop policy if exists "public read companies" on companies;
create policy "public read companies" on companies for select using (true);

-- ============================================================
-- تحقق نهائي بعد الإصلاح
-- ============================================================
select column_name
from information_schema.column_privileges
where table_name = 'companies' and grantee = 'anon' and privilege_type = 'SELECT'
order by column_name;
