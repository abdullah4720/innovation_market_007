-- ============================================================
-- ترقية شاملة واحدة — تجمع كل التحديثات السابقة في ملف واحد
-- آمن للتشغيل عدة مرات، ولا يؤثر على أي بيانات موجودة
-- شغّل هذا الملف كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

-- 1) عمود الملاحظات على التقييمات (رسالة المستثمر للفريق)
alter table evaluations add column if not exists notes text;

-- 2) عمود الملاحظات على الزيارات (تذكير خاص للمستثمر أثناء الاستكشاف)
alter table visits add column if not exists notes text;

-- 3) علامة "أنهى المستثمر التقييم بنفسه"
alter table investors add column if not exists evaluation_done boolean not null default false;

create or replace function mark_evaluation_done(p_investor_id uuid)
returns void
language sql security definer as $$
  update investors set evaluation_done = true where id = p_investor_id;
$$;
grant execute on function mark_evaluation_done(uuid) to anon, authenticated;

grant select (id, name, username, evaluation_done, created_at) on investors to anon, authenticated;

-- 4) الميزانية الافتراضية 5000
update event_state set investor_budget = 5000 where id = 1 and investor_budget = 1000;
-- (لن يُغيّر شيئاً لو كنت قد عدّلتها يدوياً لقيمة أخرى بالفعل)

-- 5) الإصلاح الحرج: صلاحيات UPDATE المفقودة (سبب فشل الحفظ الصامت)
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'evaluations' and policyname = 'public update evaluations') then
    create policy "public update evaluations" on evaluations for update using (true);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'watchlist' and policyname = 'public update watchlist') then
    create policy "public update watchlist" on watchlist for update using (true);
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'visits' and policyname = 'public update visits') then
    create policy "public update visits" on visits for update using (true);
  end if;
end $$;

-- ============================================================
-- تحقق نهائي — شغّل هذا الجزء لوحده لمراجعة حالة قاعدتك الآن
-- ============================================================

-- أعمدة evaluations الحالية (يجب أن تشمل notes)
select 'evaluations columns' as check_name, column_name, data_type
from information_schema.columns where table_name = 'evaluations'
union all
-- أعمدة visits الحالية (يجب أن تشمل notes)
select 'visits columns', column_name, data_type
from information_schema.columns where table_name = 'visits'
union all
-- أعمدة investors الحالية (يجب أن تشمل evaluation_done)
select 'investors columns', column_name, data_type
from information_schema.columns where table_name = 'investors'
order by check_name, column_name;

-- كل السياسات الحالية على الجداول الحرجة (يجب أن تشمل update لكل من الثلاثة)
select tablename, policyname, cmd
from pg_policies
where tablename in ('evaluations','watchlist','visits')
order by tablename, cmd;

-- الميزانية الحالية
select investor_budget from event_state where id = 1;
