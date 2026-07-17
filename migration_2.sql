-- ============================================================
-- ترقية: ملاحظات الاستكشاف الخاصة + إنهاء التقييم + رفع الميزانية
-- شغّل هذا فقط (بدون إعادة تشغيل schema.sql كاملاً)
-- ============================================================

-- 1) ملاحظات خاصة للمستثمر أثناء الاستكشاف (تذكير شخصي قبل التقييم)
alter table visits add column if not exists notes text;

do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'visits' and policyname = 'public update visits'
  ) then
    create policy "public update visits" on visits for update using (true);
  end if;
end $$;

-- 2) علامة "أنهى المستثمر التقييم بنفسه"
alter table investors add column if not exists evaluation_done boolean not null default false;

create or replace function mark_evaluation_done(p_investor_id uuid)
returns void
language sql security definer as $$
  update investors set evaluation_done = true where id = p_investor_id;
$$;
grant execute on function mark_evaluation_done(uuid) to anon, authenticated;

-- السماح بقراءة العمود الجديد ضمن ما هو مسموح أصلاً من أعمدة investors
grant select (id, name, username, evaluation_done, created_at) on investors to anon, authenticated;

-- 3) رفع الميزانية الافتراضية إلى 5000 (لو ما عدّلتها يدوياً من قبل)
update event_state set investor_budget = 5000 where id = 1;
-- إن كنت قد ضبطتها يدوياً مسبقاً لقيمة غير 1000 وتريد تجاهل هذا التحديث، احذف السطر أعلاه.
