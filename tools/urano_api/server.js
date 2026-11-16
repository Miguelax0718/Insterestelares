// URANO · API REST de referencia (Node + PostgreSQL)
// Uso:  cd tools/urano_api && npm install && DATABASE_URL=postgres://usuario:clave@host:5432/urano npm start
// Sirve web/ en http://localhost:8000 (APOLO en /apolo/) y la API en http://localhost:8000/api
const http = require('http'), fs = require('fs'), path = require('path');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const PORT = process.env.PORT || 8000, ROOT = path.resolve(process.env.STATIC_DIR || path.join(__dirname, '..', '..', 'web'));
const q = (sql, p = []) => pool.query(sql, p).then(r => r.rows);

const crewOut = c => ({ id: c.id, name: c.name, role: c.role, initials: c.initials, color: c.color, age: c.age,
  weight: +c.weight_kg, height: +c.height_m, dose: +c.dose_msv, hr: c.heart_rate, bp: c.blood_pressure,
  water: c.water_ml_today, waterGoal: c.water_goal_ml, sleep: +c.sleep_hours, sessions: c.resistance_sessions_week,
  energy: c.energy_pct, protein: c.protein_pct, mood: c.mood, exMin: c.exercise_min_today, exGoal: c.exercise_goal_min });

const routes = [
  ['GET', /^\/api\/crew$/, async () => (await q('select * from crew order by sort_order')).map(crewOut)],
  ['POST', /^\/api\/crew$/, async (_, c) => { await q(`insert into crew (id, sort_order, name, role, initials, color, age, weight_kg, height_m, dose_msv, heart_rate, blood_pressure,
      water_ml_today, water_goal_ml, sleep_hours, resistance_sessions_week, energy_pct, protein_pct, mood, exercise_min_today, exercise_goal_min) values ($1,99,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)`,
      [c.id, c.name, c.role, c.initials, c.color, c.age, c.weight, c.height, c.dose || 0, c.hr, c.bp, c.water || 0, c.waterGoal || 2500, c.sleep, c.sessions || 0, c.energy || 0, c.protein || 0, c.mood ?? 2, c.exMin || 0, c.exGoal || 90]); return null; }],
  ['GET', /^\/api\/mission$/, async () => { const [m] = await q('select * from mission limit 1');
    const ev = await q('select day, class from solar_events where mission_id=$1 order by day', [m.id]);
    return { name: m.name, day: m.current_day, total: m.total_days, doseLimit: +m.dose_limit_msv, start: m.start_date.toISOString().slice(0,10), sampleTimes: m.sample_times, events: ev.map(e => ({ day: e.day, cls: e.class })) }; }],
  ['GET', /^\/api\/crew\/([\w-]+)$/, async ([id]) => crewOut((await q('select * from crew where id=$1', [id]))[0])],
  ['GET', /^\/api\/crew\/([\w-]+)\/samples$/, async ([id]) => {
    const rows = await q(`select s.id, s.mission_day, s.taken_at, s.method, json_object_agg(v.biomarker_id, v.value) as vals
      from samples s join sample_values v on v.sample_id=s.id where s.crew_id=$1 group by s.id order by s.taken_at`, [id]);
    return rows.map(r => ({ id: r.id, crewId: id, day: r.mission_day, takenAt: r.taken_at, method: r.method,
      values: Object.fromEntries(Object.entries(r.vals).map(([k, v]) => [k, +v])) })); }],
  ['GET', /^\/api\/crew\/([\w-]+)\/recommendations$/, async ([id]) => q('select id, module, priority, text, why, done from recommendations where crew_id=$1 order by created_at, id', [id])],
  ['GET', /^\/api\/crew\/([\w-]+)\/alerts$/, async ([id]) => (await q('select * from alerts where crew_id=$1 order by created_at desc, id', [id]))
    .map(a => ({ id: a.id, severity: a.severity, module: a.module, title: a.title, cause: a.cause, action: a.action, time: a.time_label, status: a.status }))],
  ['GET', /^\/api\/crew\/([\w-]+)\/ranges$/, async ([id]) => Object.fromEntries((await q('select biomarker_id, lo, hi from personal_ranges where crew_id=$1', [id])).map(r => [r.biomarker_id, { lo: +r.lo, hi: +r.hi }]))],
  ['PATCH', /^\/api\/recommendations\/([\w-]+)$/, async ([id], b) => { await q('update recommendations set done=$2 where id=$1', [id, !!b.done]); return null; }],
  ['PATCH', /^\/api\/alerts\/([\w-]+)$/, async ([id], b) => { await q('update alerts set status=$2 where id=$1', [id, b.status]); return null; }],
  ['POST', /^\/api\/crew\/([\w-]+)\/exercise$/, async ([id], b) => { const min = b.min | 0; if (!['fuerza','bici','cinta'].includes(b.type) || min < 1 || min > 300) throw Object.assign(new Error('Ejercicio inválido'), { status: 400 });
    await q('insert into exercise_log(crew_id, type, minutes) values ($1,$2,$3)', [id, b.type, min]); return null; }],
  ['POST', /^\/api\/crew\/([\w-]+)\/water$/, async ([id], b) => { const ml = b.ml | 0; if (ml < 1 || ml > 3000) throw Object.assign(new Error('Cantidad inválida'), { status: 400 });
    await q('insert into water_log(crew_id, ml) values ($1,$2)', [id, ml]); return null; }],
  ['POST', /^\/api\/crew\/([\w-]+)\/samples$/, async ([id], b) => { await q('insert into sample_requests(crew_id, payload) values ($1,$2)', [id, b]); return null; }],
];

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2', '.json': 'application/json' };
http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.end();
  const url = req.url.split('?')[0];
  if (url.startsWith('/api/')) {
    for (const [m, re, fn] of routes) { const hit = url.match(re);
      if (hit && m === req.method) {
        let body = ''; for await (const c of req) body += c;
        try { const out = await fn(hit.slice(1), body ? JSON.parse(body) : {});
          if (out === null) { res.statusCode = 204; return res.end(); }
          if (out === undefined) { res.statusCode = 404; return res.end('{}'); }
          res.setHeader('Content-Type', 'application/json'); return res.end(JSON.stringify(out));
        } catch (e) { console.error(e); res.statusCode = e.status || 500; return res.end(JSON.stringify({ error: e.message })); } } }
    res.statusCode = 404; return res.end('{"error":"ruta no encontrada"}');
  }
  let file = path.join(ROOT, decodeURIComponent(url));
  if (file.startsWith(ROOT) && fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.statusCode = 404; return res.end('No encontrado'); }
  res.setHeader('Content-Type', MIME[path.extname(file)] || 'application/octet-stream'); fs.createReadStream(file).pipe(res);
}).listen(PORT, () => console.log(`URANO en http://localhost:${PORT}  ·  API en /api`));
