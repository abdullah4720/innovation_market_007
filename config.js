/* ============================================================
   Innovation Marketplace — إعدادات الاتصال بقاعدة البيانات
   ============================================================
   عدّل القيمتين التاليتين ببيانات مشروعك في Supabase
   (Project Settings → API)
   إن تُركتا فارغتين، يعمل الموقع تلقائياً في "وضع العرض التجريبي"
   (بيانات وهمية محفوظة في الذاكرة فقط، لتجربة الموقع قبل الربط).
   ============================================================ */
const SUPABASE_URL = "https://oskafesmbjxjbanrmurn.supabase.co";      // مثال: https://xxxxxxxx.supabase.co
const SUPABASE_ANON_KEY = "sb_publishable_r9f4t3k-SW6NTYEv8bS3UQ_floV4BxH";  // مفتاح anon public

const DEMO_MODE = !SUPABASE_URL || !SUPABASE_ANON_KEY;

/* ---------- تهيئة Supabase (عند توفر الإعدادات) ---------- */
let supabaseClient = null;
if (!DEMO_MODE) {
  supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

/* ============================================================
   وضع العرض التجريبي — مخزن بيانات وهمي في المتصفح
   ============================================================ */
const DEMO_SEED_COMPANIES = [
  { id:"c1", name:"Green Energy", sector:"الطاقة", emoji:"🌞",
    team_members:"سارة العتيبي، فيصل القحطاني، نورة الدوسري",
    problem:"ارتفاع فاقد الطاقة في المباني السكنية القديمة بسبب ضعف العزل والمراقبة.",
    solution:"نظام استشعار ذكي يراقب استهلاك الطاقة لحظياً ويقترح تعديلات تلقائية لتقليل الفاقد.",
    value_prop:"خفض فاتورة الكهرباء حتى 30% دون تدخل يدوي من المستخدم.",
    video_url:"", booth_number:"A1" },
  { id:"c2", name:"Med AI", sector:"الصحة", emoji:"🩺",
    team_members:"عبدالله المطيري، ريم الشمري",
    problem:"تأخر تشخيص أمراض الشبكية لدى مرضى السكري في المناطق النائية.",
    solution:"نموذج ذكاء اصطناعي يحلل صور قاع العين ويصدر تقرير أولي خلال ثوانٍ.",
    value_prop:"تقليل زمن الكشف المبكر من أسابيع إلى دقائق بدقة تفوق 90%.",
    video_url:"", booth_number:"A2" },
  { id:"c3", name:"Smart Farm", sector:"الزراعة", emoji:"🌱",
    team_members:"خالد الحربي، منى العنزي، تركي الرشيدي",
    problem:"هدر كبير في مياه الري بالمزارع الصغيرة بسبب الجدولة اليدوية.",
    solution:"وحدة ري ذكية تعتمد على رطوبة التربة الفعلية وتوقعات الطقس.",
    value_prop:"توفير يصل إلى 40% من استهلاك المياه في الموسم الواحد.",
    video_url:"", booth_number:"B1" },
  { id:"c4", name:"EduPath", sector:"التعليم", emoji:"🎓",
    team_members:"لمى الغامدي، ياسر السبيعي",
    problem:"صعوبة تحديد المسار التعليمي المناسب لكل طالب حسب قدراته الفعلية.",
    solution:"منصة تقيّم مهارات الطالب وتبني له خطة تعلم تكيفية أسبوعية.",
    value_prop:"رفع نسبة إكمال المسارات التعليمية بنسبة 25%.",
    video_url:"", booth_number:"B2" },
  { id:"c5", name:"LogiTrack", sector:"اللوجستيات", emoji:"📦",
    team_members:"بندر العصيمي، هند الزهراني",
    problem:"ضعف تتبع الشحنات الداخلية بين فروع الشركات الصغيرة.",
    solution:"نظام تتبع لحظي بالباركود يعمل بدون اتصال إنترنت دائم.",
    value_prop:"تقليل الشحنات المفقودة أو المتأخرة بنسبة 50%.",
    video_url:"", booth_number:"C1" }
];

function loadDemoStore(){
  const raw = window.__IM_DEMO_STORE__;
  if (raw) return raw;
  const store = {
    event_state: {
      phase: "explore", investor_budget: 5000,
      min_investment_per_company: 100, max_investment_per_company: 5000,
      min_companies_required: 1, winner_count: 3, winner_formula: 'composite',
      evaluation_frozen: false, results_hidden: false, registration_open: true
    },
    companies: JSON.parse(JSON.stringify(DEMO_SEED_COMPANIES)),
    investors: [
      { id: 'demo-inv-1', name: 'مستثمر تجريبي 1', username: 'demo-inv-1', pin: null, evaluation_done: false },
      { id: 'demo-inv-2', name: 'مستثمر تجريبي 2', username: 'demo-inv-2', pin: null, evaluation_done: false }
    ],
    visits: [],
    watchlist: [],
    evaluations: []
  };
  window.__IM_DEMO_STORE__ = store;
  return store;
}
const demoStore = DEMO_MODE ? loadDemoStore() : null;

function uid(){ return 'id-' + Math.random().toString(36).slice(2,10); }

/* ============================================================
   طبقة بيانات موحّدة — تعمل فوق Supabase أو وضع العرض التجريبي
   ============================================================ */
const DB = {
  async getPhase(){
    if (DEMO_MODE) return demoStore.event_state.phase;
    const { data, error } = await supabaseClient.from('event_state').select('phase').eq('id',1).single();
    if (error) throw error;
    return data?.phase || 'explore';
  },
  async setPhase(phase){
    if (DEMO_MODE){ demoStore.event_state.phase = phase; return; }
    const { error } = await supabaseClient.from('event_state').update({ phase, updated_at: new Date().toISOString() }).eq('id',1);
    if (error) throw error;
  },
  async getBudget(){
    if (DEMO_MODE) return demoStore.event_state.investor_budget ?? 5000;
    const { data, error } = await supabaseClient.from('event_state').select('investor_budget').eq('id',1).single();
    if (error) throw error;
    return data?.investor_budget ?? 5000;
  },
  async setBudget(amount){
    amount = Math.max(0, parseInt(amount) || 0);
    if (DEMO_MODE){ demoStore.event_state.investor_budget = amount; return; }
    const { error } = await supabaseClient.from('event_state').update({ investor_budget: amount, updated_at: new Date().toISOString() }).eq('id',1);
    if (error) throw error;
  },
  async getSettings(){
    const defaults = {
      investor_budget: 5000, min_investment_per_company: 100, max_investment_per_company: 5000,
      min_companies_required: 1, winner_count: 3, winner_formula: 'composite',
      evaluation_frozen: false, results_hidden: false, registration_open: true
    };
    if (DEMO_MODE) return { ...defaults, ...demoStore.event_state };
    const { data, error } = await supabaseClient.from('event_state')
      .select('investor_budget,min_investment_per_company,max_investment_per_company,min_companies_required,winner_count,winner_formula,evaluation_frozen,results_hidden,registration_open')
      .eq('id',1).single();
    if (error) throw error;
    return { ...defaults, ...data };
  },
  async setSettings(settings){
    const clean = {
      investor_budget: Math.max(0, parseInt(settings.investor_budget) || 0),
      min_investment_per_company: Math.max(0, parseInt(settings.min_investment_per_company) || 0),
      max_investment_per_company: Math.max(0, parseInt(settings.max_investment_per_company) || 0),
      min_companies_required: Math.max(0, parseInt(settings.min_companies_required) || 0),
      winner_count: Math.max(1, parseInt(settings.winner_count) || 1),
      winner_formula: (settings.winner_formula === 'investment_only') ? 'investment_only' : 'composite',
      evaluation_frozen: !!settings.evaluation_frozen,
      results_hidden: !!settings.results_hidden,
      registration_open: settings.registration_open === false ? false : true
    };
    if (DEMO_MODE){ Object.assign(demoStore.event_state, clean); return; }
    const { error } = await supabaseClient.from('event_state').update({ ...clean, updated_at: new Date().toISOString() }).eq('id',1);
    if (error) throw error;
  },
  onPhaseChange(cb){
    let lastPhase = null;
    const maybeNotify = (p)=>{ if (p !== lastPhase){ lastPhase = p; cb(p); } };
    if (DEMO_MODE){ setInterval(()=>maybeNotify(demoStore.event_state.phase), 1500); return; }
    supabaseClient.channel('event_state_ch')
      .on('postgres_changes', { event:'UPDATE', schema:'public', table:'event_state' }, payload=>{
        maybeNotify(payload.new.phase);
      }).subscribe();
    setInterval(async ()=>{ try{ maybeNotify(await DB.getPhase()); }catch(err){ /* يُعاد المحاولة في الدورة التالية */ } }, 4000);
  },

  async getCompanies(){
    if (DEMO_MODE) return demoStore.companies;
    const { data, error } = await supabaseClient.from('companies')
      .select('id,name,sector,emoji,team_members,problem,solution,value_prop,video_url,booth_number,created_at')
      .order('created_at');
    if (error) throw error;
    return data || [];
  },
  async addCompany(c){
    if (DEMO_MODE){ c.id = uid(); demoStore.companies.push(c); return c; }
    const { data, error } = await supabaseClient.from('companies').insert(c)
      .select('id,name,sector,emoji,team_members,problem,solution,value_prop,video_url,booth_number,created_at')
      .single();
    if (error) throw error;
    return data;
  },
  async deleteCompany(id){
    if (DEMO_MODE){ demoStore.companies = demoStore.companies.filter(c=>c.id!==id); return; }
    const { error } = await supabaseClient.from('companies').delete().eq('id', id);
    if (error) throw error;
  },

  /* ============================================================
     تسجيل الشركات الذاتي — بواسطة فريق الشركة نفسه، بدون لوحة تحكم
     محمي برمز وصول يختاره الفريق؛ يُقارن داخل قاعدة البيانات فقط
     ============================================================ */
  async registerCompany(fields, accessCode){
    accessCode = String(accessCode).trim();
    if (!accessCode) throw new Error('الرجاء اختيار رمز وصول');
    if (DEMO_MODE){
      const id = uid();
      const co = { id, ...fields, access_code: accessCode };
      demoStore.companies.push(co);
      return { id, name: co.name };
    }
    const { data, error } = await supabaseClient.rpc('register_company', {
      p_name: fields.name, p_sector: fields.sector||'', p_emoji: fields.emoji||'',
      p_team_members: fields.team_members||'', p_problem: fields.problem||'',
      p_solution: fields.solution||'', p_value_prop: fields.value_prop||'',
      p_video_url: fields.video_url||'', p_booth_number: fields.booth_number||'',
      p_access_code: accessCode
    });
    if (error) throw error;
    return data && data[0];
  },
  async verifyCompanyAccess(name, accessCode){
    name = String(name).trim();
    accessCode = String(accessCode).trim();
    if (DEMO_MODE){
      const co = demoStore.companies.find(c=>c.name.trim().toLowerCase()===name.toLowerCase() && c.access_code===accessCode);
      return co ? { id: co.id, name: co.name } : null;
    }
    const { data, error } = await supabaseClient.rpc('verify_company_access', { p_name: name, p_access_code: accessCode });
    if (error) throw error;
    return (data && data[0]) || null;
  },
  async updateCompanyProfile(companyId, accessCode, fields){
    accessCode = String(accessCode).trim();
    if (DEMO_MODE){
      const co = demoStore.companies.find(c=>c.id===companyId && c.access_code===accessCode);
      if (!co) throw new Error('رمز الوصول غير صحيح');
      Object.assign(co, fields);
      return;
    }
    const { error } = await supabaseClient.rpc('update_company_profile', {
      p_company_id: companyId, p_access_code: accessCode,
      p_sector: fields.sector||'', p_emoji: fields.emoji||'', p_team_members: fields.team_members||'',
      p_problem: fields.problem||'', p_solution: fields.solution||'', p_value_prop: fields.value_prop||'',
      p_video_url: fields.video_url||'', p_booth_number: fields.booth_number||''
    });
    if (error) throw error;
  },

  async createInvestor(name, username, password){
    username = String(username).trim().toLowerCase();
    if (DEMO_MODE){
      if (demoStore.investors.find(i=>i.username===username)) throw new Error('اسم المستخدم مستخدم مسبقاً');
      const inv = { id: uid(), name, username, pin: null };
      demoStore.investors.push(inv);
      return { id: inv.id, name: inv.name, username: inv.username };
    }
    const { data, error } = await supabaseClient.rpc('create_investor', { p_name: name, p_username: username, p_password: '' });
    if (error) throw error;
    return data && data[0];
  },
  async verifyInvestor(username, password){
    username = String(username).trim().toLowerCase();
    password = String(password).trim();
    if (DEMO_MODE){
      const inv = demoStore.investors.find(i=>i.username===username && i.password===password);
      return inv ? { id: inv.id, name: inv.name } : null;
    }
    const { data, error } = await supabaseClient.rpc('verify_investor', { p_username: username, p_password: password });
    if (error) throw error;
    return (data && data[0]) || null;
  },
  async adminCount(){
    if (DEMO_MODE) return demoStore.admins ? demoStore.admins.length : 0;
    const { data, error } = await supabaseClient.rpc('admin_count');
    if (error) throw error;
    return data || 0;
  },
  async createAdmin(username, password){
    username = String(username).trim().toLowerCase();
    password = String(password).trim();
    if (DEMO_MODE){
      demoStore.admins = demoStore.admins || [];
      if (demoStore.admins.find(a=>a.username===username)) throw new Error('اسم المستخدم مستخدم مسبقاً');
      demoStore.admins.push({ id: uid(), username, password });
      return { username };
    }
    const { data, error } = await supabaseClient.rpc('create_admin', { p_username: username, p_password: password });
    if (error) throw error;
    return data && data[0];
  },
  async verifyAdmin(username, password){
    username = String(username).trim().toLowerCase();
    password = String(password).trim();
    if (DEMO_MODE){
      demoStore.admins = demoStore.admins || [];
      const a = demoStore.admins.find(a=>a.username===username && a.password===password);
      return a ? { id: a.id, username: a.username } : null;
    }
    const { data, error } = await supabaseClient.rpc('verify_admin', { p_username: username, p_password: password });
    if (error) throw error;
    return (data && data[0]) || null;
  },

  async addVisit(investor_id, company_id){
    if (DEMO_MODE){
      if (!demoStore.visits.find(v=>v.investor_id===investor_id && v.company_id===company_id))
        demoStore.visits.push({ id:uid(), investor_id, company_id, visited_at:new Date().toISOString(), notes:null });
      return;
    }
    const { error } = await supabaseClient.from('visits').upsert({ investor_id, company_id }, { onConflict:'investor_id,company_id' });
    if (error) throw error;
  },
  async setVisitNotes(investor_id, company_id, notes){
    notes = (notes||'').trim() || null;
    if (DEMO_MODE){
      const v = demoStore.visits.find(v=>v.investor_id===investor_id && v.company_id===company_id);
      if (v) v.notes = notes;
      return;
    }
    const { error } = await supabaseClient.from('visits').update({ notes }).match({ investor_id, company_id });
    if (error) throw error;
  },
  async getVisits(investor_id){
    if (DEMO_MODE) return demoStore.visits.filter(v=>v.investor_id===investor_id);
    const { data, error } = await supabaseClient.from('visits').select('*').eq('investor_id', investor_id);
    if (error) throw error;
    return data || [];
  },
  async getAllVisits(){
    if (DEMO_MODE) return demoStore.visits;
    const { data, error } = await supabaseClient.from('visits').select('*');
    if (error) throw error;
    return data || [];
  },

  async toggleWatch(investor_id, company_id, on){
    if (DEMO_MODE){
      demoStore.watchlist = demoStore.watchlist.filter(w=>!(w.investor_id===investor_id && w.company_id===company_id));
      if (on) demoStore.watchlist.push({ id:uid(), investor_id, company_id });
      return;
    }
    if (on){
      const { error } = await supabaseClient.from('watchlist').upsert({ investor_id, company_id }, { onConflict:'investor_id,company_id' });
      if (error) throw error;
    }else{
      const { error } = await supabaseClient.from('watchlist').delete().match({ investor_id, company_id });
      if (error) throw error;
    }
  },
  async getWatchlist(investor_id){
    if (DEMO_MODE) return demoStore.watchlist.filter(w=>w.investor_id===investor_id);
    const { data, error } = await supabaseClient.from('watchlist').select('*').eq('investor_id', investor_id);
    if (error) throw error;
    return data || [];
  },

  async submitEvaluation(ev){
    if (DEMO_MODE){
      demoStore.evaluations = demoStore.evaluations.filter(e=>!(e.investor_id===ev.investor_id && e.company_id===ev.company_id));
      demoStore.evaluations.push({ id:uid(), ...ev, submitted_at:new Date().toISOString() });
      return;
    }
    const { error } = await supabaseClient.from('evaluations').upsert(ev, { onConflict:'investor_id,company_id' });
    if (error) throw error;
  },
  async getEvaluations(investor_id){
    if (DEMO_MODE) return demoStore.evaluations.filter(e=>e.investor_id===investor_id);
    const { data, error } = await supabaseClient.from('evaluations').select('*').eq('investor_id', investor_id);
    if (error) throw error;
    return data || [];
  },
  async getAllEvaluations(){
    if (DEMO_MODE) return demoStore.evaluations;
    const { data, error } = await supabaseClient.from('evaluations').select('*');
    if (error) throw error;
    return data || [];
  },
  async markEvaluationDone(investor_id){
    if (DEMO_MODE){
      const inv = demoStore.investors.find(i=>i.id===investor_id);
      if (inv) inv.evaluation_done = true;
      return;
    }
    const { error } = await supabaseClient.rpc('mark_evaluation_done', { p_investor_id: investor_id });
    if (error) throw error;
  },

  async getAllInvestors(){
    if (DEMO_MODE) return demoStore.investors;
    const { data, error } = await supabaseClient.from('investors').select('id,name,username,evaluation_done,created_at');
    if (error) throw error;
    return data || [];
  },

  /* دخول المستثمر بالاسم + رمز بسيط (PIN):
     أول مرة يُدخل فيها اسم جديد، يُنشأ حساب تلقائياً بنفس الرمز.
     أي دخول لاحق بنفس الاسم يتطلب نفس الرمز — يمنع انتحال شخص لاسم غيره. */
  async investorLogin(name, projectNumber, pin){
    name = String(name).trim();
    projectNumber = String(projectNumber||'').trim();
    pin = String(pin).trim();
    if (!name) throw new Error('الرجاء إدخال الاسم');
    if (!pin) throw new Error('الرجاء إدخال الرمز');
    if (DEMO_MODE){
      const existing = demoStore.investors.find(i => i.name.trim().toLowerCase() === name.toLowerCase());
      if (!existing){
        if (demoStore.event_state.registration_open === false){
          throw new Error('التسجيل مغلق حالياً. تواصل مع منظّم الفعالية.');
        }
        const inv = { id: uid(), name, username: 'guest-'+uid(), pin, project_number: projectNumber||null };
        demoStore.investors.push(inv);
        return { id: inv.id, name: inv.name, project_number: inv.project_number };
      }
      if (existing.pin == null){
        existing.pin = pin; // أول دخول: يحدّد رمزه الآن
        existing.project_number = projectNumber||existing.project_number||null;
        return { id: existing.id, name: existing.name, project_number: existing.project_number };
      }
      if (existing.pin !== pin) throw new Error('الرمز غير صحيح لهذا الاسم');
      existing.project_number = projectNumber||existing.project_number||null;
      return { id: existing.id, name: existing.name, project_number: existing.project_number };
    }
    const { data, error } = await supabaseClient.rpc('investor_login_or_register', { p_name: name, p_project_number: projectNumber, p_pin: pin });
    if (error) throw error;
    return data && data[0];
  },

  /* وضع الدخول المفتوح القديم (بدون أي رمز) — أُبقي عليه كمرجع احتياطي غير مستخدم حالياً. */
  async findOrCreateInvestorByName(name){
    name = String(name).trim();
    if (!name) throw new Error('الرجاء إدخال الاسم');
    const all = await this.getAllInvestors();
    const existing = all.find(i => i.name.trim().toLowerCase() === name.toLowerCase());
    if (existing) return { id: existing.id, name: existing.name };
    const username = 'guest-' + Math.random().toString(36).slice(2,8);
    const password = Math.random().toString(36).slice(2,10);
    const created = await this.createInvestor(name, username, password);
    return { id: created.id, name };
  }
};

function toast(msg){
  let t = document.querySelector('.toast');
  if (!t){ t = document.createElement('div'); t.className='toast'; document.body.appendChild(t); }
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(window.__toastTimer);
  window.__toastTimer = setTimeout(()=>t.classList.remove('show'), 2200);
}

/* ============================================================
   عناصر الهوية البصرية المشتركة — مستوحاة من نشرة حاضنة ابتكار 5
   ============================================================ */

/* ---------- نظام أيقونات SVG (بأسلوب Lucide) بدل الإيموجي ---------- */
const ICON_PATHS = {
  rocket: '<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>',
  wallet: '<path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/>',
  'check-circle': '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  star: '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
  'alert-triangle': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
  'file-text': '<path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><line x1="10" y1="9" x2="8" y2="9"/>',
  trophy: '<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>',
  medal: '<path d="M7.21 15 2.66 7.14a2 2 0 0 1 .13-2.2L4.4 2.8A2 2 0 0 1 6 2h12a2 2 0 0 1 1.6.8l1.6 2.14a2 2 0 0 1 .14 2.2L16.79 15"/><circle cx="12" cy="17" r="5"/><path d="M12 18v-2h-.5"/>',
  crown: '<path d="m11.562 3.266.417.836a1 1 0 0 0 1.822-.001l.416-.834a.5.5 0 0 1 .786-.14L18.9 6.02a.5.5 0 0 0 .795-.14l1.135-2.267a.5.5 0 0 1 .943.223l-1.3 10.94a1 1 0 0 1-1 .89H4.529a1 1 0 0 1-1-.89l-1.3-10.94a.5.5 0 0 1 .943-.223L4.31 5.88a.5.5 0 0 0 .795.14l3.9-3.888a.5.5 0 0 1 .786.14Z"/><path d="M5 21h14"/>',
  sparkles: '<path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/>',
  'bar-chart': '<path d="M3 3v18h18"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>',
  'message-circle': '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
  save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2Z"/><path d="M17 21v-8H7v8"/><path d="M7 3v5h8"/>',
  compass: '<circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/>',
  'map-pin': '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
  key: '<path d="m15.5 7.5 2.3 2.3a1 1 0 0 0 1.4 0l2.1-2.1a1 1 0 0 0 0-1.4L19 4"/><path d="m21 2-9.6 9.6"/><circle cx="7.5" cy="15.5" r="5.5"/>',
  lock: '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  'eye-off': '<path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" y1="2" x2="22" y2="22"/>',
  ban: '<circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/>',
  lightbulb: '<path d="M15 14c.2-1 .7-1.7 1.5-2.5A6 6 0 1 0 6.5 11.5c.7.8 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
  'help-circle': '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
  'arrow-left': '<line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>',
  'arrow-right': '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>',
  'building-2': '<path d="M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z"/><path d="M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2"/><path d="M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2"/><path d="M10 6h4"/><path d="M10 10h4"/><path d="M10 14h4"/><path d="M10 18h4"/>',
  smile: '<circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>',
  x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  search: '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
  'log-out': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>',
  settings: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  edit: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
  'trending-up': '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/>',
  target: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>'
};
function icon(name, opts){
  opts = opts || {};
  const size = opts.size || 18;
  const stroke = opts.stroke || 2;
  const filled = !!opts.filled;
  const cls = opts.class ? ' ' + opts.class : '';
  const body = ICON_PATHS[name] || '';
  const fillAttr = filled ? 'currentColor' : 'none';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="${fillAttr}" stroke="currentColor" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round" class="im-icon${cls}" style="vertical-align:-4px; flex-shrink:0;">${body}</svg>`;
}

const BRAND_COLORS = ['#9A05B9','#FCC342','#00BF9D','#63D653'];
function ticksHTML(count){
  count = count || 26;
  let out = '';
  for (let i=0;i<count;i++){
    const color = BRAND_COLORS[i % BRAND_COLORS.length];
    const h = 8 + ((i*7)%3===0 ? 14 : (i*5)%2===0 ? 9 : 5);
    out += `<span style="height:${h}px;background:${color}"></span>`;
  }
  return `<div class="brand-ticks">${out}</div>`;
}
function logoLockup(dark){
  const cls = dark ? 'logo-lockup on-dark' : 'logo-lockup';
  const boxCls = dark ? 'logo-num-box on-dark' : 'logo-num-box';
  return `
    <div class="${cls}">
      <div class="${boxCls}">5</div>
      <div class="logo-text">
        <b>حاضنة ابتكار</b>
        <span class="en">Innovation Incubator</span>
      </div>
    </div>`;
}
function phaseColor(p){
  return p==='explore' ? getComputedCssVar('--phase-explore')
       : p==='evaluation' ? getComputedCssVar('--phase-evaluation')
       : getComputedCssVar('--phase-results');
}
function getComputedCssVar(name){
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

/* ============================================================
   توليد بيانات دخول (لإضافة المستثمرين دفعة واحدة من لوحة التحكم)
   ============================================================ */
function genUsername(seq){
  return 'INV-' + String(seq).padStart(3,'0');
}
function genPassword(){
  return String(Math.floor(100000 + Math.random()*900000)); // رمز رقمي من 6 خانات
}
