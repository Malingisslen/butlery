#!/usr/bin/env node
// F2-R02 · INTEGRITETSKONTROLL AV VERIFIERADE TRAFFYTOR.
//
// Kör: node tools/hit-overlap-audit.mjs [--out=<fil>]
//
// En traffyta kan klara 48 x 48 och anda ta klick som var avsedda for
// grannen. Bagge matningarna ser da gronа ut var for sig.
//
// TVA SKILDA BEGREPP, och bara det andra ar ett produktfel:
//
//   geometricOverlap        rektanglarna skar varandra.
//   simultaneousHitOverlap  tva sjalvstandiga kontroller ar SAMTIDIGT
//                           traffbara i samma interaktionslager, och deras
//                           traffytor skar varandra.
//
// Skillnaden avgors av webblasarens EGEN traffning, inte av en gissning:
// elementsFromPoint fragas i den overlappande ytan. Svarar den bara med den
// ena kontrollen ligger den andra bakom ett hogre lager och kan inte traffas
// dar. Det ar ett avsiktligt overlager, inte ett fel.
//
// Ingen artefaktspecifik logik. Ingen id-lista. Utfallet kommer ur mataren.
// Saknas evidens ar utfallet unresolved — aldrig godkant.

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
  const R = el => { const r = el.getBoundingClientRect();
    return { x:+r.left.toFixed(2), y:+r.top.toFixed(2), w:+r.width.toFixed(2), h:+r.height.toFixed(2),
             right:+r.right.toFixed(2), bottom:+r.bottom.toFixed(2) }; };
  // Ytan kontrollen FAKTISKT ager: self ger elementet, target ger noden.
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
    const e = R(el), q = R(p);
    return e.bottom > q.y + 0.01 && e.y < q.bottom - 0.01 &&
           e.right > q.x + 0.01 && e.x < q.right - 0.01; };

  // Vem traffas HAR? Webblasarens egen traffning, inte var tolkning.
  function traffas(A, B, snitt) {
    const pts = [];
    for (const fx of [0.25, 0.5, 0.75]) for (const fy of [0.25, 0.5, 0.75])
      pts.push([snitt.x + snitt.w * fx, snitt.y + snitt.h * fy]);
    let iA = 0, iB = 0, annat = 0, utanfor = 0;
    for (const [x, y] of pts) {
      if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) { utanfor++; continue; }
      const kedja = document.elementsFromPoint(x, y);
      if (!kedja.length) { utanfor++; continue; }
      // Det OVERSTA elementet avgor. Ligger det i A traffas A, i B traffas B.
      const topp = kedja[0];
      if (A.contains(topp) || topp === A) iA++;
      else if (B.contains(topp) || topp === B) iB++;
      else annat++;
    }
    return { punkter: pts.length, traffarA: iA, traffarB: iB, traffarAnnat: annat, utanforVyn: utanfor };
  }

 // Traffningen kraver att snittet rullas in i vyn. Scrollagen maste
  // aterstallas efter varje par — annars blir resultatet beroende av i
  // vilken ordning paren provades, och det ar inget matvarde.
  const scrollbara = [...document.querySelectorAll("*")].filter(e => e.scrollTop > 0 ||
    /auto|scroll/.test(getComputedStyle(e).overflowY));
  const spara = () => scrollbara.map(e => [e, e.scrollTop, e.scrollLeft])
    .concat([[document.scrollingElement, document.scrollingElement.scrollTop, document.scrollingElement.scrollLeft]]);
  const aterstall = s => { for (const [e, t, l] of s) { e.scrollTop = t; e.scrollLeft = l; } };

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
      if (v[i].el === v[j].el) {
        ut.par.push({ art: it.id, typ: 'delad agaryta', a: v[i].namn, b: v[j].namn,
          geometricOverlap: true, simultaneousHitOverlap: true,
          adjudication: 'sharedOwner', evidens: 'tva kontroller pekar ut samma agaryta' });
        continue;
      }
      const A = v[i].r, B = v[j].r;
      const ow = Math.min(A.right, B.right) - Math.max(A.x, B.x);
      const oh = Math.min(A.bottom, B.bottom) - Math.max(A.y, B.y);
      if (ow <= 0.01 || oh <= 0.01) continue;
      const snitt = { x: Math.max(A.x, B.x), y: Math.max(A.y, B.y), w: ow, h: oh };

      // Kan de over huvud taget vara samtidigt synliga?
      const aSyn = synligIPort(v[i].el, v[i].p), bSyn = synligIPort(v[j].el, v[j].p);
      if (!aSyn || !bSyn) {
        ut.par.push({ art: it.id, typ: 'geometrisk overlapp', a: v[i].namn, b: v[j].namn,
          rollA: v[i].roll, rollB: v[j].roll,
          overlapp: { w: +ow.toFixed(2), h: +oh.toFixed(2), area: +(ow * oh).toFixed(1) },
          geometricOverlap: true, simultaneousHitOverlap: false,
          adjudication: 'differentScrollState',
          evidens: 'minst en av ytorna ar bortscrollad i sin port och kan inte traffas samtidigt som den andra',
          aSynlig: aSyn, bSynlig: bSyn });
        continue;
      }

      // Rulla in snittet i vyn och fraga webblasaren vem som traffas.
      const laget = spara();
      v[i].el.scrollIntoView({ block: 'center' });
      const A2 = R(v[i].el), B2 = R(v[j].el);
      const ow2 = Math.min(A2.right, B2.right) - Math.max(A2.x, B2.x);
      const oh2 = Math.min(A2.bottom, B2.bottom) - Math.max(A2.y, B2.y);
      const t = (ow2 > 0.01 && oh2 > 0.01)
        ? traffas(v[i].el, v[j].el, { x: Math.max(A2.x, B2.x), y: Math.max(A2.y, B2.y), w: ow2, h: oh2 })
        : null;

      aterstall(laget);
      let sim = null, adj = 'unresolved', ev = 'traffningen kunde inte avgoras';
      if (t && t.utanforVyn === t.punkter) { sim = null; adj = 'unresolved'; ev = 'snittet gick inte att rulla in i vyn'; }
      else if (t && t.traffarA > 0 && t.traffarB > 0) {
        sim = true; adj = 'produktfel';
        ev = 'bagge kontrollerna traffas inom den overlappande ytan (' + t.traffarA + ' respektive ' + t.traffarB + ' av ' + t.punkter + ' punkter)';
      } else if (t && (t.traffarA > 0) !== (t.traffarB > 0)) {
        sim = false; adj = 'intentionalOverlay';
        ev = 'endast ' + (t.traffarA > 0 ? 'den ovre' : 'den andra') + ' kontrollen traffas i den overlappande ytan; den underliggande ligger bakom ett hogre lager och ar inte traffbar dar';
      } else if (t && t.traffarAnnat === t.punkter - t.utanforVyn && t.punkter > t.utanforVyn) {
        sim = null; adj = 'unresolved';
        ev = 'ett tredje element ligger overst i hela snittet — agarskapet i ytan gar inte att avgora';
      }
      ut.par.push({ art: it.id, typ: 'geometrisk overlapp', a: v[i].namn, b: v[j].namn,
        rollA: v[i].roll, rollB: v[j].roll,
        overlapp: { w: +ow.toFixed(2), h: +oh.toFixed(2), area: +(ow * oh).toFixed(1) },
        geometricOverlap: true, simultaneousHitOverlap: sim, adjudication: adj,
        evidens: ev, traffning: t });
    }
  }
  return ut;
})()`;

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
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
      const r = await s('Runtime.evaluate', { expression: OVERLAP_AUDIT, returnByValue: true });
      if (r.exceptionDetails) throw new Error('skriptet kastade i ' + f + ': ' + JSON.stringify(r.exceptionDetails).slice(0, 200));
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

  const fel = par.filter(x => x.simultaneousHitOverlap === true);
  const olost = par.filter(x => x.simultaneousHitOverlap === null);
  const avsiktliga = par.filter(x => x.adjudication === 'intentionalOverlay');
  const scroll = par.filter(x => x.adjudication === 'differentScrollState');
  const doc = { $schema: 'butlery-overlap-audit/2', kontroll: 'CHK-R-02',
    $regel: 'geometricOverlap ar att rektanglarna skar varandra. simultaneousHitOverlap ar att bagge kontrollerna faktiskt kan traffas i samma yta. Endast det andra ar ett produktfel. Skillnaden avgors av webblasarens egen traffning, aldrig av en artefaktlista.',
    artefakter_st: artefakter, verifierade_traffytor_st: verifierade,
    geometricOverlap_st: par.length,
    simultaneousHitOverlap_st: fel.length,
    intentionalOverlay_st: avsiktliga.length,
    differentScrollState_st: scroll.length,
    unresolved_st: olost.length,
    berorda_artefakter: [...new Set(fel.map(x => x.art))],
    produktfel: fel, unresolved: olost, avsiktliga, olikaScroll: scroll,
    status: (fel.length + olost.length) ? 'FÄLLD' : 'godkänd' };
  if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

  console.log('OVERLAPP-AUDIT · ' + artefakter + ' artefakter · ' + verifierade + ' verifierade traffytor');
  console.log('  geometricOverlap        ' + par.length);
  console.log('  simultaneousHitOverlap  ' + fel.length + '   ← enda produktfelet');
  console.log('  intentionalOverlay      ' + avsiktliga.length);
  console.log('  differentScrollState    ' + scroll.length);
  console.log('  unresolved              ' + olost.length);
  for (const x of [...fel, ...olost].slice(0, 20))
    console.log('  ✖ ' + x.art.padEnd(18) + JSON.stringify((x.a || '').slice(0, 22)).padEnd(26) +
      ' × ' + JSON.stringify((x.b || '').slice(0, 22)).padEnd(26) + x.adjudication);
  for (const x of avsiktliga)
    console.log('  · ' + x.art.padEnd(18) + JSON.stringify((x.a || '').slice(0, 22)).padEnd(26) +
      ' × ' + JSON.stringify((x.b || '').slice(0, 22)).padEnd(26) + 'avsiktligt overlager');
  console.log('OVERLAPP-AUDIT status=' + doc.status);
  process.exit(doc.status === 'godkänd' ? 0 : 1);
}
