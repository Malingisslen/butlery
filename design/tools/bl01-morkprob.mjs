// Kor: node tools/bl01-morkprob.mjs <rot> <utfil utanfor repot>
// R · Mork mätning: tvingar data-theme="dark" på varje ram och letar textkörningar med
// färgparet text rgb(147,164,141) på yta rgb(74,92,67) (beslut B4). Läser bara.
import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
const [, , ROT, UT] = process.argv;
const { SCOPE_KOD, KEDJA_KOD } = await import(pathToFileURL(ROT + '/tools/conformance-scope.mjs').href);
const filer = readdirSync(ROT).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)).sort();
const port = 20400 + (process.pid % 300);
const profil = mkdtempSync(join(tmpdir(), 'mork-'));
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new', '--remote-debugging-port=' + port, '--disable-gpu', '--no-first-run',
   '--allow-file-access-from-files', '--force-device-scale-factor=1', '--user-data-dir=' + profil, 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
try {
  let ws; for (let i = 0; i < 80 && !ws; i++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/list')).json()).find(t => t.type === 'page').webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('chrome');
  const sock = new WebSocket(ws); await new Promise(r => sock.addEventListener('open', r));
  let id = 0; const pend = new Map();
  sock.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } });
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pend.set(i, r); sock.send(JSON.stringify({ id: i, method, params })); });
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false });
  const ut = [];
  for (const f of filer) {
    await send('Page.navigate', { url: pathToFileURL(resolve(ROT, f)).href });
    await send('Runtime.evaluate', { expression: '(async()=>{ if(document.readyState!=="complete") await new Promise(r=>addEventListener("load",r,{once:true})); await document.fonts.ready; return 1 })()', awaitPromise: true });
    await sleep(150);
    const r = await send('Runtime.evaluate', { returnByValue: true, expression: '(() => {\n' + SCOPE_KOD + '\n' + KEDJA_KOD + '\n' +
      'for (const it of document.querySelectorAll(".sc-item")) it.setAttribute("data-theme","dark");\n' +
      'const TEXT="rgb(147, 164, 141)", YTA="rgb(74, 92, 67)";\n' +
      'const ut=[];\n' +
      'for (const it of document.querySelectorAll(".sc-item")) {\n' +
      '  const produkt=[...it.querySelectorAll("*")].filter(el=>losScope(kedjaFor(el,it)).scope==="product");\n' +
      '  const ord=new Map(produkt.map((e,i)=>[e,i]));\n' +
      '  produkt.forEach((el,i)=>{\n' +
      '    const cs=getComputedStyle(el); if (cs.color!==TEXT) return;\n' +
      '    let own=""; for (const n of el.childNodes) if(n.nodeType===3) own+=n.textContent;\n' +
      '    if (!own.trim()) return;\n' +
      '    let p=el, yta=null; while(p&&p!==it){ const c=getComputedStyle(p).backgroundColor; if(c&&c!=="rgba(0, 0, 0, 0)"){ yta=c; break; } p=p.parentElement; }\n' +
      '    if (yta!==YTA) return;\n' +
      '    const anc=[]; let q=el.parentElement; while(q&&q!==it){ if(ord.has(q)) anc.push(ord.get(q)); q=q.parentElement; }\n' +
      '    ut.push({art:it.id, ordProd:i, tag:el.tagName.toLowerCase(), tpl:el.getAttribute("data-dc-tpl"), occ:el.getAttribute("data-occurrence"), elId:el.id||null, role:el.getAttribute("data-a11y-role"), name:el.getAttribute("data-a11y-name"), comp:el.getAttribute("data-component"), icon:el.getAttribute("data-icon"), hit:el.getAttribute("data-hit"), inDecl:!!(el.parentElement&&el.parentElement.closest("[data-a11y-role]")&&it.contains(el.parentElement.closest("[data-a11y-role]"))), own:own.replace(/[ \\t\\n\\r]+/g," ").trim().slice(0,80), text:(el.textContent||"").replace(/[ \\t\\n\\r]+/g," ").trim().slice(0,80), fg:cs.color, bg:yta, anc:anc});\n' +
      '  });\n' +
      '}\n' +
      'return ut; })()' });
    const v = r.result && r.result.result && r.result.result.value;
    if (!Array.isArray(v)) throw new Error('mork matning misslyckades i ' + f + ' ' + JSON.stringify(r).slice(0, 200));
    for (const x of v) ut.push(Object.assign({}, x, { fil: f }));
  }
  sock.close();
  writeFileSync(UT, JSON.stringify(ut, null, 1));
  const perRam = {}; for (const x of ut) perRam[x.art] = (perRam[x.art] || 0) + 1;
  console.log('forekomster med farparet:', ut.length, '| ramar:', Object.keys(perRam).length);
  console.log(JSON.stringify(perRam, null, 1));
} finally { try { chrome.kill(); } catch {} await sleep(300); try { rmSync(profil, { recursive: true, force: true }); } catch {} }
