#!/usr/bin/env node
// F2-T01 · TRIAGE av de kvarvarande verifierade R-03-felinstanserna.
//
// Kör: node tools/residual-triage.mjs --r03=<r03.json> --out=<katalog utanför repot>
//
// MÄTER OCH BINDER TILL KÄLLA. Ingen fix, ingen ändring av produktskärmar och
// ingen ändring av kanoniska id.
//
// TVÅ BEGREPP SOM INTE FÅR BLANDAS IHOP:
//
//   symptomGroup     en normaliserad FELSIGNATUR, t.ex. "div · klippning ·
//                    överskott N px i y med overflow-y: hidden". Den säger att
//                    två fel SER LIKA UT. Den säger ingenting om orsaken.
//
//   sourceRootCause  en BELAGD gemensam källa: samma kodrad, samma komponent,
//                    samma token eller samma layoutregel. Två visuellt lika fel
//                    i olika kod får två skilda sourceRootCause. Två olika
//                    symptom får dela sourceRootCause om samma kodbeslut
//                    orsakar dem.
//
// INTENTIONALITET KRÄVER POSITIV EVIDENS. Att CSS-raden råkar använda
// line-clamp, ellipsis eller overflow:hidden är inget bevis för avsikt.

import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';

const RAD_BRYT = new RegExp(String.fromCharCode(13) + String.fromCharCode(63) + String.fromCharCode(10));
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const R03 = arg('r03'), OUT = arg('out');
if (!R03 || !OUT) { console.error('✖ ange --r03=<r03.json> --out=<katalog>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2);
}
mkdirSync(outAbs, { recursive: true });
mkdirSync(join(outAbs, 'utsnitt'), { recursive: true });

const R = JSON.parse(readFileSync(R03, 'utf8'));
const instanser = R.produkt.felinstanser;
const fynd = new Map(R.produkt.verifierade_elementfynd.map(f => [f.findingId, f]));
const REG = JSON.parse(readFileSync('artifacts.json', 'utf8'));
const LC = JSON.parse(readFileSync('layout-contract.json', 'utf8'));
const filFör = id => (REG.artifacts.find(a => a.sourceElementId === id) || {}).sourceFile || null;
const profilFör = id => (REG.artifacts.find(a => a.sourceElementId === id) || {}).viewportProfile || null;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

/* ── Mätskript: oberoende geometri per angiven nodsökväg ────────────────── */
const DJUPMAT = pathsJson => `(() => {
  const begär = ${pathsJson};
  const nod = (rot, p) => { let n = rot; for (const k of (p === 'rot' ? [] : p.split('/').map(Number))) n = n && n.children[k]; return n; };
  const ut = [];
  for (const b of begär) {
    const rot = document.getElementById(b.artefakt);
    const el = rot && nod(rot, b.path);
    if (!el) { ut.push({ ...b, fel: 'noden hittades inte' }); continue; }
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    // SIGNAL 1 · scroll mot client, heltal enligt spec.
    const s1 = { scrollW: el.scrollWidth, clientW: el.clientWidth, scrollH: el.scrollHeight, clientH: el.clientHeight,
                 överX: el.scrollWidth - el.clientWidth, överY: el.scrollHeight - el.clientHeight };
    // SIGNAL 2 · barnens rektanglar mot förälderns klientbox, i bråkdelar.
    const barn = [...el.children].map(k => {
      const kr = k.getBoundingClientRect();
      return { tag: k.tagName.toLowerCase(), cls: (k.getAttribute('class') || ''),
        rect: [kr.left, kr.top, kr.width, kr.height],
        underKant: kr.bottom - (r.top + el.clientTop + el.clientHeight),
        högerOm: kr.right - (r.left + el.clientLeft + el.clientWidth) };
    });
    // SIGNAL 3 · pseudoelement och kant kan förklara sub-pixelöverskott.
    const före = getComputedStyle(el, '::before'), efter = getComputedStyle(el, '::after');
    const pseudo = { före: före.content !== 'none' ? före.content + ' h=' + före.height : null,
                     efter: efter.content !== 'none' ? efter.content + ' h=' + efter.height : null };
    // SIGNAL 4 · textens egen radhöjd mot boxen, för trunkeringsfall.
    const range = document.createRange(); range.selectNodeContents(el);
    let textRect = null;
    try { const tr = range.getBoundingClientRect(); textRect = [tr.left, tr.top, tr.width, tr.height]; } catch (e) {}
    range.detach && range.detach();
    ut.push({ ...b,
      rect: [r.left, r.top, r.width, r.height],
      css: { overflow: cs.overflow, overflowX: cs.overflowX, overflowY: cs.overflowY,
             textOverflow: cs.textOverflow, webkitLineClamp: cs.webkitLineClamp,
             whiteSpace: cs.whiteSpace, display: cs.display, height: cs.height, maxHeight: cs.maxHeight,
             width: cs.width, maxWidth: cs.maxWidth, lineHeight: cs.lineHeight, fontSize: cs.fontSize,
             borderTopWidth: cs.borderTopWidth, borderBottomWidth: cs.borderBottomWidth,
             paddingTop: cs.paddingTop, paddingBottom: cs.paddingBottom, transform: cs.transform,
             boxSizing: cs.boxSizing },
      s1, barn, pseudo, textRect,
      clipIntent: el.getAttribute('data-clip-intent') || null,
      roll: el.getAttribute('data-a11y-role') || null,
      namn: el.getAttribute('data-a11y-name') || null,
      text: (el.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 160),
      outerHTML: el.outerHTML.slice(0, 700),
      // Klippande förfader och hela kedjan upp till artefaktroten.
      kedja: (() => {
        const ut = []; let n = el.parentElement;
        while (n && n !== rot) {
          const c = getComputedStyle(n);
          ut.push({ tag: n.tagName.toLowerCase(), cls: n.getAttribute('class') || '',
            overflow: c.overflow + '/' + c.overflowX + '/' + c.overflowY,
            klipper: /hidden|clip/.test(c.overflow + c.overflowX + c.overflowY),
            höjd: c.height, rect: (rr => [rr.width, rr.height])(n.getBoundingClientRect()) });
          n = n.parentElement;
        }
        return ut;
      })(),
      klippandeForfader: (() => {
        let n = el.parentElement;
        while (n && n !== rot) {
          const c = getComputedStyle(n);
          if (/hidden|clip/.test(c.overflow + c.overflowX + c.overflowY))
            return { tag: n.tagName.toLowerCase(), cls: n.getAttribute('class') || '',
                     overflow: c.overflow + '/' + c.overflowX + '/' + c.overflowY,
                     inlineStyle: (n.getAttribute('style') || '').slice(0, 240) };
          n = n.parentElement;
        }
        return null;
      })()
    });
  }
  return ut;
})()`;

/* ── Vilka noder ska mätas ───────────────────────────────────────────────── */
const RAW = JSON.parse(readFileSync(arg('raw') || R03.replace(/r03\.json$/, 'render-raw.json'), 'utf8'));
const pathFör = new Map();
for (const r of RAW.results) {
  if (r.probe) continue;
  for (const a of r.artifacts)
    for (const m of ['r03a', 'r03b', 'r03c', 'r03d'])
      for (const t of (a[m] || []))
        if (t.klass === 'verifierad') pathFör.set(a.id + '‖' + t.elementKey, { path: t.path || 'rot', profil: r.profile.id });
}

const begär = [];
for (const i of instanser)
  for (const fid of i.findingIds) {
    const f = fynd.get(fid);
    const p = pathFör.get(i.artefakt + '‖' + f.elementKey);
    begär.push({ instansId: i.instansId, findingId: fid, artefakt: i.artefakt,
      elementKey: f.elementKey, path: p ? p.path : 'rot', profil: p ? p.profil : 'compact-390' });
  }

/* ── Kör ─────────────────────────────────────────────────────────────────── */
const perFil = new Map();
for (const b of begär) {
  const fil = filFör(b.artefakt);
  if (!fil) continue;
  if (!perFil.has(fil)) perFil.set(fil, []);
  perFil.get(fil).push(b);
}

const profil = mkdtempSync(join(tmpdir(), 'triage-'));
const port = 9990 + (process.pid % 9);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2', '--user-data-dir=' + profil, 'about:blank'], { stdio: 'ignore' });
let mätningar = [], verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) {
    await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {}
  }
  if (!wsUrl) throw new Error('Chrome startade aldrig');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP-anslutning misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const j = JSON.parse(m.data);
    if (j.id && pend.has(j.id)) { const { res } = pend.get(j.id); pend.delete(j.id); res(j.result); } };
  const call = (m, p = {}, s) => new Promise(res => {
    const i = ++id; pend.set(i, { res });
    ws.send(JSON.stringify({ id: i, method: m, params: p, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable');

  for (const [fil, poster] of perFil) {
    const p = LC.profiles.find(x => x.id === poster[0].profil) || { width: 390, height: 844 };
    await s('Emulation.setDeviceMetricsOverride', { width: p.width, height: p.height, deviceScaleFactor: 2, mobile: false });
    await s('Page.navigate', { url: pathToFileURL(resolve(fil)).href });
    await sleep(400);
    // Vänta på typsnitten som harnesset gör. Utan den väntan mäts en annan
    // layout än den skarpa körningen, och triagen skulle motsäga sitt eget
    // underlag utan att något faktiskt skilde sig.
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(1200);
    const r = await s('Runtime.evaluate', { expression: DJUPMAT(JSON.stringify(poster)), returnByValue: true });
    if (r.exceptionDetails || !r.result.value) throw new Error('mätningen misslyckades för ' + fil);
    mätningar.push(...r.result.value.map(x => ({ ...x, fil })));

    // Utsnitt per instans: den klippande boxen med marginal.
    for (const m of r.result.value) {
      if (!m.rect) continue;
      const [x, y, w, h] = m.rect;
      const marg = 24;
      try {
        const shot = await s('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true,
          clip: { x: Math.max(0, x - marg), y: Math.max(0, y - marg), width: w + marg * 2, height: h + marg * 2, scale: 1 } });
        writeFileSync(join(outAbs, 'utsnitt', (m.instansId.replace(/[^\wåäöÅÄÖ-]+/g, '_') + '__' + m.path.replace(/\//g, '-') + '.png')),
          Buffer.from(shot.data, 'base64'));
      } catch (e) { /* utsnitt är evidens, inte mätning — ett misslyckat utsnitt fäller inte triagen */ }
    }
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} try { rmSync(profil, { recursive: true, force: true }); } catch {} }

if (verktygsfel) {
  console.error('✖ VERKTYGSFEL: ' + verktygsfel);
  console.log('TRIAGE status=verktygsfel');
  process.exit(2);
}

/* ── Källbindning: hitta raden i filen ───────────────────────────────────── */
function källrad(fil, outerHTML) {
  const rader = readFileSync(fil, 'utf8').split(RAD_BRYT);
  const öppning = (outerHTML.match(/^<[^>]+>/) || [''])[0];
  // Flera kandidatnycklar, mest särskiljande först. En enda sökterm missade
  // varje rad vars stilattribut bryts annorlunda i källan än i DOM:en.
  const kandidater = [];
  const st = (öppning.match(/style="([^"]+)"/) || [])[1];
  if (st) {
    for (const bit of st.split(';').map(x => x.trim()).filter(x => x.length > 12))
      kandidater.push(bit);
    kandidater.push(st.slice(0, 60));
  }
  const namn = (öppning.match(/data-a11y-name="[^"]+"/) || [])[0];
  if (namn) kandidater.unshift(namn);
  const inner = outerHTML.replace(/^<[^>]+>/, '').replace(/<[^>]+>/g, ' ').replace(/s+/g, ' ').trim().slice(0, 40);
  if (inner.length > 12) kandidater.push(inner);
  for (const k of kandidater) {
    for (let i = 0; i < rader.length; i++)
      if (rader[i].includes(k)) return { rad: i + 1, utdrag: rader[i].trim().slice(0, 260), sökt: k.slice(0, 70) };
  }
  return { rad: null, utdrag: null, sökt: kandidater.slice(0, 2) };
}

for (const m of mätningar) if (m.outerHTML) m.källa = källrad(m.fil, m.outerHTML);

writeFileSync(join(outAbs, 'triage-matning.json'), JSON.stringify({ mätningar }, null, 1));
console.log('TRIAGE mätta_noder=' + mätningar.length + ' filer=' + perFil.size +
  ' utsnitt=' + mätningar.filter(m => m.rect).length + ' verktygsfel=0');
for (const m of mätningar)
  console.log('  ' + m.artefakt.padEnd(15) + m.path.padEnd(10) +
    ' överY=' + m.s1.överY + ' överX=' + m.s1.överX +
    ' rad=' + (m.källa && m.källa.rad) + '  ' + (m.css.overflow + '/' + m.css.webkitLineClamp).slice(0, 28));
