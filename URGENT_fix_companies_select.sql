-- ============================================================
-- إصلاح فوري: صلاحية القراءة على جدول الشركات مفقودة بالكامل
-- شغّل هذا الملف فقط — لا يعتمد على أي شيء آخر ولا يمكن أن يفشل
-- ============================================================

grant select (
  id, name, sector, emoji, team_members, problem, solution,
  value_prop, video_url, booth_number, created_at
) on companies to anon, authenticated;

-- نفس النمط بالضبط طُبّق على جدول investors سابقاً — نتأكد إنه سليم أيضاً احتياطاً
grant select (id, name, username, evaluation_done, created_at) on investors to anon, authenticated;

-- تحقق فوري: يجب أن تظهر كل الأعمدة أعلاه هنا لكل من anon و authenticated
select grantee, table_name, column_name
from information_schema.column_privileges
where table_name in ('companies','investors') and privilege_type = 'SELECT'
order by table_name, grantee, column_name;
