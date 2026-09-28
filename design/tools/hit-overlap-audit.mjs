#!/usr/bin/env node
// F2-R02 · INTEGRITETSKONTROLL AV VERIFIERADE TRAFFYTOR.
//
// Kör: node tools/hit-overlap-audit.mjs [--out=<fil>]
//
// FRAGAN AR INTE "vem vinner punkten". Den fragan ar cirkular: i varje
// DOM-overlapp vinner exakt ett element i varje punkt, sa den kan aldrig
// avsloja ett fel. Fyra negativa prov faller den modellen, och den ar borta.
//
// Fragan ar i stallet: FORLORAR en kontroll delar av sin egen deklarerade
// traffyta till en annan sjalvstandig kontroll?
//
//   lostOwnHitArea = area(H(C) ∩ H(D)) for tva SKILDA semantiska kontroller
//
// Ar den arean storre an noll konkurrerar de om samma yta. Ingen
// z-index-vinnare gor det acceptabelt.
//
// Geometrisk overlapp klassas forst efter RELATION:
//   sameActiveLayer      bagge samtidigt aktiva i samma lager  → produktfynd
//   intentionalOverlay   underlaget ar BELAGT suspenderat      → inte fynd
//   notSimultaneous      kan aldrig vara synliga samtidigt     → inte fynd
//   unresolved           relationen kan inte belaggas          → inte godkant
//
// Overlager kraver POSITIV evidens. Att ligga sist i DOM, ha hogre z-index
// eller vinna traffningen ar ingen evidens. Ingen artefaktlista finns.
//
// Separat fraga: isOwnTargetHitTestable. En kontroll vars egen yta har
// pointer-events: none kan inte godkannas darfor att nagot under den tar
// klicket — det ar ett fel pa den ovre kontrollens egen aktiveringsyta.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9210 + (process.pid % 120);

export const OVERLAP_AUDIT = `(() => {
  const D = el => el.getBoundingClientRect();     // orundad DOMRect
  const fx = n => +n.toFixed(3);
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
  const synligIPort = (el, p) => { if (!p) return true;
    const e = D(el), q = D(p);
    return e.bottom > q.top + 0.001 && e.top < q.bottom - 0.001 &&
           e.right > q.left + 0.001 && e.left < q.right - 0.001; };

  // Egen traffbarhet: pointer-events pa ytan sjalv eller nagon forfader.
  const traffbar = el => { let n = el;
    while (n && n !== document.documentElement) {
      if (getComputedStyle(n).pointerEvents === 'none') return false;
      n = n.parentElement; }
    return true; };

  // POSITIV evidens for att underlaget ar suspenderat i detta tillstand.
  // Bara uttalade markorer duger. DOM-ordning, z-index och traffning gor det
  // inte. Saknas markoren ar relationen unresolved, aldrig intentional.
  const SUSPENDERAD = /(suspended|blocked|inert|bakom|overlay-blocked)/i;
  const suspenderad = el => { let n = el;
    while (n && n !== document.documentElement) {
      if (n.hasAttribute('inert')) return { ja: true, via: 'inert', pa: n.tagName.toLowerCase() };
      if (n.getAttribute('aria-hidden') === 'true') return { ja: true, via: 'aria-hidden', pa: n.tagName.toLowerCase() };
      const st = n.getAttribute('data-a11y-state') || '';
      if (SUSPENDERAD.test(st)) return { ja: true, via: 'data-a11y-state=' + st, pa: n.tagName.toLowerCase() };
      const lg = n.getAttribute('data-layer-state') || '';
      if (SUSPENDERAD.test(lg)) return { ja: true, via: 'data-layer-state=' + lg, pa: n.tagName.toLowerCase() };
      n = n.parentElement; }
    return { ja: false, via: null, pa: null };
  };

  const ut = { artefakter: 0, verifierade: 0, ejTraffbara: [], par: [] };
  for (const it of document.querySelectorAll('.sc-item')) {
    ut.artefakter++;
    const v = [];
    for (const c of it.querySelectorAll('[data-a11y-role]')) {
      const a = agarElement(c);
      if (!a) continue;
      const rr = D(a);
      v.push({ c, el: a, namn: c.getAttribute('data-a11y-name'), roll: c.getAttribute('data-a11y-role'),
        r: { x: fx(rr.left), y: fx(rr.top), w: fx(rr.width), h: fx(rr.height),
             right: fx(rr.right), bottom: fx(rr.bottom), area: fx(rr.width * rr.height) },
        p: port(a), traffbar: traffbar(a) });
    }
    ut.verifierade += v.length;
    for (const x of v) if (!x.traffbar)
      ut.ejTraffbara.push({ art: it.id, namn: x.namn, roll: x.roll,
        evidens: 'pointer-events: none pa ytan eller en forfader — den egna aktiveringsytan ar inte traffbar' });

    for (let i = 0; i < v.length; i++) for (let j = i + 1; j < v.length; j++) {
      const A = v[i], B = v[j];
      // SAMMA KONTROLLIDENTITET. En glyf och dess agare, eller tva
      // kontroller som pekar ut samma yta, jamfors inte som tva ytor.
      if (A.el === B.el) {
        ut.par.push({ art: it.id, a: A.namn, b: B.namn, relation: 'sharedOwner',
          geometricOverlap: true, produktfynd: true,
          evidens: 'tva skilda semantiska kontroller pekar ut samma agaryta' });
        continue;
      }
      if (A.el.contains(B.el) || B.el.contains(A.el)) {
        ut.par.push({ art: it.id, a: A.namn, b: B.namn, relation: 'nestedOwners',
          geometricOverlap: true, produktfynd: true,
          evidens: 'den ena ytan ligger inuti den andra — tva sjalvstandiga kontroller kan inte dela yta pa det sattet' });
        continue;
      }
      const iw = Math.min(A.r.right, B.r.right) - Math.max(A.r.x, B.r.x);
      const ih = Math.min(A.r.bottom, B.r.bottom) - Math.max(A.r.y, B.r.y);
      if (!(iw > 0 && ih > 0)) continue;          // ingen tolerans: >0 racker
      const area = iw * ih;

      const samtidigt = synligIPort(A.el, A.p) && synligIPort(B.el, B.p);
      const sA = suspenderad(A.el), sB = suspenderad(B.el);
      let relation, fynd, ev;
      if (!samtidigt) {
        relation = 'notSimultaneous'; fynd = false;
        ev = 'minst en av ytorna ar bortscrollad i sin port och kan inte vara aktiv samtidigt som den andra';
      } else if (sA.ja !== sB.ja) {
        relation = 'intentionalOverlay'; fynd = false;
        ev = 'underlaget ar belagt suspenderat via ' + (sA.ja ? sA.via : sB.via) +
             ' — det ligger i ett lagre interaktionslager och ar inte aktivt inom den tackta ytan';
      } else if (sA.ja && sB.ja) {
        relation = 'unresolved'; fynd = false;
        ev = 'bagge ytorna ar markta suspenderade — lagerrelationen gar inte att avgora';
      } else {
        // Ingen lagerevidens alls. Da kan vi inte pasta overlager, men vi kan
        // heller inte pasta att de ar samtidigt aktiva. Fail closed.
        relation = 'unresolved'; fynd = false;
        ev = 'ingen uttalad lagerevidens: inget inert, aria-hidden eller state-markering visar att underlaget ar suspenderat. Relationen kan inte belaggas.';
      }
      ut.par.push({ art: it.id, a: A.namn, b: B.namn, rollA: A.roll, rollB: B.roll,
        geometricOverlap: true, relation, produktfynd: fynd, evidens: ev,
        rektA: A.r, rektB: B.r,
        intersection: { w: fx(iw), h: fx(ih), area: fx(area) },
        lostOwnHitArea: { A: fx(area / A.r.area), B: fx(area / B.r.area) },
        samtidigtSynliga: samtidigt,
        suspenderadA: sA, suspenderadB: sB });
    }
  }
  return ut;
})()`;

// sameActiveLayer kan bara pastas nar bagge ar bevisat aktiva. Sa lange
// ritningarna saknar lagermarkorer blir utfallet unresolved i stallet, och
// det ar avsiktligt: ett obelagt produktfynd ar lika fel som ett obelagt
// godkannande.

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
  const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
    '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
    '--force-device-scale-factor=2',
    '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-overlap'), 'about:blank'],
    { stdio: 'ignore' });
  let par = [], ejTraff = [], artefakter = 0, verifierade = 0, verktygsfel = null;
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
      const r = await s('Runtime.evaluate', { expression: OVERLAP_AUDIT, returnByValue: true });
      if (r.exceptionDetails) throw new Error('skriptet kastade i ' + f + ': ' + JSON.stringify(r.exceptionDetails).slice(0, 200));
      const v = r.result.value;
      artefakter += v.artefakter; verifierade += v.verifierade;
      par.push(...v.par.map(x => ({ ...x, fil: f })));
      ejTraff.push(...v.ejTraffbara.map(x => ({ ...x, fil: f })));
    }
  } catch (e) { verktygsfel = e.message; }
  finally { try { chrome.kill(); } catch {} }

  if (verktygsfel) {
    console.log('VERKTYGSFEL: ' + verktygsfel);
    console.log('OVERLAPP-AUDIT status=VERKTYGSFEL'); process.exit(2);
  }

  const per = {}; for (const x of par) per[x.relation] = (per[x.relation] || 0) + 1;
  const fynd = par.filter(x => x.produktfynd);
  const olost = par.filter(x => x.relation === 'unresolved');
  const doc = { $schema: 'butlery-overlap-audit/3', kontroll: 'CHK-R-02',
    $regel: 'lostOwnHitArea = arean av snittet mellan tva SKILDA semantiska kontrollers traffytor. Ar den storre an noll konkurrerar de om samma yta. Ingen z-index-vinnare gor det acceptabelt, och ingen tolerans finns. Overlager kraver POSITIV evidens for att underlaget ar suspenderat.',
    artefakter_st: artefakter, verifierade_traffytor_st: verifierade,
    geometricOverlap_st: par.length,
    relationer: per,
    produktfynd_st: fynd.length,
    unresolved_st: olost.length,
    egenYtaEjTraffbar_st: ejTraff.length,
    egenYtaEjTraffbar: ejTraff,
    produktfynd: fynd, unresolved: olost, alla: par,
    status: (fynd.length + olost.length + ejTraff.length) ? 'FÄLLD' : 'godkänd' };
  if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

  console.log('OVERLAPP-AUDIT · ' + artefakter + ' artefakter · ' + verifierade + ' verifierade traffytor');
  console.log('  geometricOverlap        ' + par.length);
  console.log('  relationer              ' + JSON.stringify(per));
  console.log('  produktfynd             ' + fynd.length);
  console.log('  unresolved              ' + olost.length);
  console.log('  egen yta ej traffbar    ' + ejTraff.length);
  for (const x of [...fynd, ...olost].slice(0, 20))
    console.log('  · ' + x.art.padEnd(16) + JSON.stringify((x.a || '').slice(0, 22)).padEnd(26) +
      ' × ' + JSON.stringify((x.b || '').slice(0, 22)).padEnd(26) + x.relation +
      (x.intersection ? '  ' + x.intersection.w + '×' + x.intersection.h + ' = ' + x.intersection.area : ''));
  console.log('OVERLAPP-AUDIT status=' + doc.status);
  process.exit(doc.status === 'godkänd' ? 0 : 1);
}
