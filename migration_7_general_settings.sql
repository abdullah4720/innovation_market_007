-- ============================================================
-- ترقية: الإعدادات العامة (حدود الاستثمار، عدد الفائزين، معادلة الفوز)
-- شغّل هذا كاملاً في SQL Editor بمشروع Supabase
-- ============================================================

alter table event_state add column if not exists min_investment_per_company int not null default 100;
alter table event_state add column if not exists max_investment_per_company int not null default 5000;
alter table event_state add column if not exists min_companies_required int not null default 1;
alter table event_state add column if not exists winner_count int not null default 3;
alter table event_state add column if not exists winner_formula text not null default 'composite';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'event_state_winner_formula_check'
  ) then
    alter table event_state add constraint event_state_winner_formula_check
      check (winner_formula in ('composite','investment_only'));
  end if;
end $$;

-- تحقق: يعرض الإعدادات الحالية بعد الترقية
select investor_budget, min_investment_per_company, max_investment_per_company,
       min_companies_required, winner_count, winner_formula
from event_state where id = 1;
