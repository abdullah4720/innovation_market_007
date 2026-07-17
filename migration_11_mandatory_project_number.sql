-- ============================================================
-- ترقية: رقم المشروع صار إلزامياً لكل شركة
-- (يحتاجه النظام إلزامياً للمقارنة مع رقم مشروع المستثمر
-- ومنعه من الاستثمار في مشروعه الخاص)
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

-- تعبئة أي شركات قديمة بدون رقم مشروع بقيمة مؤقتة (حدّثها يدوياً لاحقاً من لوحة التحكم إن لزم)
update companies set booth_number = 'غير محدد' where booth_number is null or trim(booth_number) = '';

-- فرض الإلزامية على مستوى القاعدة
alter table companies alter column booth_number set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'companies_booth_number_not_empty') then
    alter table companies add constraint companies_booth_number_not_empty check (trim(booth_number) <> '');
  end if;
end $$;

-- تحقق: يجب ألا تظهر أي شركة هنا (يعني كلها فيها رقم مشروع صحيح الآن)
select id, name from companies where booth_number is null or trim(booth_number) = '';
