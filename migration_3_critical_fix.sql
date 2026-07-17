-- ============================================================
-- إصلاح حرج: التقييمات لا تُحفظ في قاعدة البيانات
-- ============================================================
-- السبب: عملية "upsert" (المستخدمة عند إرسال تقييم أو إضافة
-- شركة للمتابعة) تتطلب من Postgres صلاحية "تحديث" (UPDATE) على
-- الجدول حتى لو كان السطر جديداً تماماً (بسبب صياغة
-- "ON CONFLICT DO UPDATE"). الجدولان evaluations وwatchlist
-- كان فيهما سياسة "قراءة" و"إضافة" فقط بدون سياسة "تحديث"،
-- فكانت كل عملية upsert ترفضها قاعدة البيانات بصمت.
-- شغّل هذا الملف كاملاً في SQL Editor لإصلاح المشكلة فوراً.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'evaluations' and policyname = 'public update evaluations'
  ) then
    create policy "public update evaluations" on evaluations for update using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'watchlist' and policyname = 'public update watchlist'
  ) then
    create policy "public update watchlist" on watchlist for update using (true);
  end if;
end $$;

-- تحقق سريع: يعرض كل السياسات الحالية على الجدولين للتأكيد
select tablename, policyname, cmd
from pg_policies
where tablename in ('evaluations','watchlist')
order by tablename, cmd;
