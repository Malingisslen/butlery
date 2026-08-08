#!/usr/bin/env node
// F2-R02 · INTEGRITETSKONTROLL AV VERIFIERADE TRAFFYTOR.
//
// Kör: node tools/hit-overlap-audit.mjs [--out=<fil>]
//
// En traffyta kan klara 48 x 48 och anda overlappa en annan kontrolls
// traffyta. Da tar den ena klick som var avsedda for den andra, och bagge
// matningarna ser gronа ut var for sig. Den har kontrollen letar just det.
//
// VERKLIG overlapp kraver att bagge ytorna kan traffas SAMTIDIGT. Tva
// rektanglar kan overlappa i sidkoordinater utan att overlappa pa skarmen:
// om den ena ligger i en scrollande behallare och just nu ar bortscrollad
// moter de aldrig varandra. En sadan trafflista vore falsklarm, och verktyget
// skiljer darfor pa samma port och synlig i sin port.
//
// Kontrollen andrar aldrig agarskapsmodellen. Den prover de traffytor som
// redan ar verifierade.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9210 + (process.pid % 120);

const EXPR = `(() => {
  const R = el => { const r = el.getBoundingClientRect();
    return { x:+r.left.toFixed(2), y:+r.top.toFixed(2), w:+r.width.toFixed(2), h:+r.height.toFixed(2),
             right:+r.right.toFixed(2), bottom:+r.bottom.toFixed(2) }; };
  // Den yta kontrollen FAKTISKT ager: self ger elementet, target ger noden.
  const agarElement = c => {
    const h = c.getAttribute('data-hit') || '';
    if (h === 'self') return c;
    const m = h.match(/^target:(.+)$/);
    if (!m) return null;
    const t = [...document.querySelectorAll('[data-hit-target]')]
      .filter(e => e.getAttribute('data-hit-target') === m[1]);
    return t.length === 1 ? t[0] : null;
  };
  const port = el => { let n = el.parentElement;
    while (n && n !== document.documentElement) {
      const c = getComputedStyle(n);
      if (/hidden|clip|auto|scroll/.test(c.overflowY + c.overflowX)) return n;
      n = n.parentElement; }
    return null; };
  const synlig = (el, p) => { if (!p) return true;
    const e = R(el), q = R(p);
    return e.bottom > q.y + 0.01 && e.y < q.bottom - 0.01 &&
           e.right > q.x + 0.01 && e.x < q.right - 0.01; };

  const ut = { artefakter: 0, verifierade: 0, par: [] };
  for (const it of document.querySelectorAll('.sc-item')) {
    ut.artefakter++;
    const v = [];
    for (const c of it.querySelectorAll('[data-a11y-role]')) {
      const a = agarElement(c);
      if (!a) continue;
      v.push({ el: a, namn: c.getAttribute('data-a11y-name'), roll: c.getAttribute('data-a11y-role'),
        r: R(a), p: port(a) });
    }
    ut.verifierade += v.length;
    for (let i = 0; i < v.length; i++) for (let j = i + 1; j < v.length; j++) {
      // Samma agarelement for tva kontroller ar en agarskapskollision, inte
      // en geometrisk overlapp — den redovisas separat.
      if (v[i].el === v[j].el) {
        ut.par.push({ art: it.id, typ: 'delad agaryta', a: v[i].namn, b: v[j].namn,
          rollA: v[i].roll, rollB: v[j].roll, overlapp: null, verklig: true });
        continue;
      }
      const A = v[i].r, B = v[j].r;
      const ow = Math.min(A.right, B.right) - Math.max(A.x, B.x);
      const oh = Math.min(A.bottom, B.bottom) - Math.max(A.y, B.y);
      if (ow <= 0.01 || oh <= 0.01) continue;
      const sammaPort = v[i].p === v[j].p;
      const bagge = synlig(v[i].el, v[i].p) && synlig(v[j].el, v[j].p);
      ut.par.push({ art: it.id, typ: 'geometrisk overlapp',
        a: v[i].namn, b: v[j].namn, rollA: v[i].roll, rollB: v[j].roll,
        overlapp: { w: +ow.toFixed(2), h: +oh.toFixed(2), area: +(ow * oh).toFixed(1) },
        rektA: A, rektB: B, sammaPort, baggeSynliga: bagge,
        verklig: sammaPort && bagge });
    }
  }
  return ut;
})()`;

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-overlap'), 'about:blank'],
  { stdio: 'ignore' });
let par = [], artefakter = 0, verifierade = 0, verktygsfel = null;
try {
  let ws = null;
  for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('Chrome startade aldrig');
  const sock = new WebSocket(ws);
  await new Promise(r => { sock.onopen = r; });
  let id = 0; const p = new Map();
  sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const res = p.get(j.id); p.delete(j.id); res(j.result); } };
  const call = (m, pr = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: pr, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(650);
    const r = await s('Runtime.evaluate', { expression: EXPR, returnByValue: true });
    if (r.exceptionDetails) throw new Error('skriptet kastade i ' + f);
    const v = r.result.value;
    artefakter += v.artefakter; verifierade += v.verifierade;
    par.push(...v.par.map(x => ({ ...x, fil: f })));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('OVERLAPP-AUDIT status=VERKTYGSFEL'); process.exit(2);
}

const verkliga = par.filter(x => x.verklig);
const falsklarm = par.filter(x => !x.verklig);
const doc = { $schema: 'butlery-overlap-audit/1', kontroll: 'CHK-R-02',
  $regel: 'En traffyta som klarar 48 x 48 kan anda overlappa en annan kontrolls traffyta. Overlapp raknas som VERKLIG bara nar bagge ytorna kan traffas samtidigt: samma klippande eller scrollande port, och bagge synliga i den.',
  artefakter_st: artefakter, verifierade_traffytor_st: verifierade,
  verkliga_overlapp_st: verkliga.length,
  falsklarm_st: falsklarm.length,
  $falsklarmNot: 'Par vars sidkoordinater overlappar men som ligger i olika portar, eller dar den ena ar bortscrollad. De moter aldrig varandra pa skarmen.',
  berorda_artefakter: [...new Set(verkliga.map(x => x.art))],
  verkliga: verkliga, falsklarm: falsklarm.slice(0, 40),
  status: verkliga.length ? 'FÄLLD' : 'godkänd' };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('OVERLAPP-AUDIT · ' + artefakter + ' artefakter · ' + verifierade + ' verifierade traffytor');
console.log('  verkliga overlappande par : ' + verkliga.length);
console.log('  falsklarm (olika port eller bortscrollad) : ' + falsklarm.length);
for (const x of verkliga.slice(0, 25))
  console.log('  ✖ ' + x.art.padEnd(18) + JSON.stringify((x.a || '').slice(0, 24)).padEnd(28) +
    ' × ' + JSON.stringify((x.b || '').slice(0, 24)).padEnd(28) +
    (x.overlapp ? x.overlapp.w + '×' + x.overlapp.h + ' = ' + x.overlapp.area + ' px²' : x.typ));
console.log('OVERLAPP-AUDIT status=' + doc.status);
process.exit(verkliga.length ? 1 : 0);
