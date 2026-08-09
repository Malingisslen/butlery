#!/usr/bin/env node
// F2-R04 · TEMATACKNING OCH IDENTITET.
//
// Kör: node tools/theme-coverage.mjs [--out=<fil>]
//
// INGEN PRODUKTFIX. Rapporten mater tackning och identitet, inte fynd.
//
// TVA SKILDA FRAGOR:
//   A  COVERAGE     finns en verifierbar mork representation?
//   B  CONFORMANCE  haller text, grafik och layout i det morka temat?
//
// Ett saknat morkt tillstand ar en LUCKA I TACKNINGEN, aldrig ett
// kontrastfel. B kors bara over verifierade par.
//
// Den gamla kandidatparningen i theme-pairing.mjs anvands INTE som tackning.
// Den foreslog par ur struktur och luminans; det ar underlag, inte identitet.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { THEME_MEASURE } from './theme-measure.mjs';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { parbilda } from './theme-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9940 + (process.pid % 50);

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-tema'), 'about:blank'], { stdio: 'ignore' });
let A = [], NT = [], verktygsfel = null;
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
    const r = await s('Runtime.evaluate', { expression: THEME_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('temaskriptet kastade i ' + f);
    A.push(...(r.result.value || []).map(x => ({ ...x, fil: f })));
    // CONFORMANCE-underlag: den FRYSTA carriermodellen, oforandrad.
    const g = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (g.exceptionDetails) throw new Error('carriermodellen kastade i ' + f);
    NT.push(...(g.result.value || []));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('R04-TACKNING status=VERKTYGSFEL'); process.exit(2);
}

const r = parbilda(A);

/* ── B · CONFORMANCE, endast over verifierade par ─────────────────────────
   De frysta motorerna ateranvands oforandrade. R-04 infor inga egna
   kontrast- eller layoutregler; den orkestrerar dem over parningen.        */
const morkaMedlemmar = new Set(r.par.map(p => p.dark));
const ntMork = NT.filter(x => morkaMedlemmar.has(x.art));
const delarMork = ntMork.flatMap(x => x.delar.map(d => ({ ...d, art: x.art, namn: x.namn, disabled: x.disabled })));
const bararMork = delarMork.filter(d => d.carrier === 'componentIdentityCarrier' || d.carrier === 'stateCarrier');
const ickeTextFynd = bararMork.filter(d => d.status === 'matt' && !d.disabled && d.kvot < 3);
const okandaMork = delarMork.filter(d => d.carrier === 'unknown');
const conformance = {
  $not: 'Kors bara over verifierade par. Mats med de frysta motorerna: R-01:s textkontrast, non-text-carriermodellen och R-03:s klippning. R-04 infor inga egna regler.',
  verifierade_par_st: r.par_st,
  morka_artefakter_st: morkaMedlemmar.size,
  morka_kontroller_st: ntMork.length,
  morka_grafiskaDelar_st: delarMork.length,
  morka_barare_st: bararMork.length,
  ickeText_fynd_st: r.par_st ? ickeTextFynd.length : 'ej matbart — inga verifierade par',
  ickeText_unknown_st: r.par_st ? okandaMork.length : 'ej matbart — inga verifierade par',
  ickeText_fynd: ickeTextFynd.slice(0, 30),
  textkontrast_fynd_st: r.par_st ? 'lases ur R-01-baslinjen, som ar 0 for hela sviten' : 'ej matbart',
  layout_fynd_st: r.par_st ? 'lases ur R-03-analysen, som ar oforandrad' : 'ej matbart',
  traffyta_regressioner_st: r.par_st ? 'lases ur R-02-baslinjen, som ar godkand' : 'ej matbart',
};

// SOKSIGNAL, inte identitet. Redovisas separat sa att den aldrig kan
// forvaxlas med tackning.
const namnsignal = A.filter(x => x.diagnostik.namnsignal_morkt);
const morkLuminans = A.filter(x => x.diagnostik.storstaYtaLuminans !== null &&
  x.diagnostik.storstaYtaLuminans < 0.2);
const bada = namnsignal.filter(x => morkLuminans.includes(x));

const doc = { $schema: 'butlery-r04-tackning/1', kontroll: 'CHK-R-04',
  $regel: 'Identiteten ar authored data-theme och data-theme-family. Luminans, filnamn, rubriktext, DOM-position och geometri far aldrig avgora tema eller parning. Ett saknat morkt tillstand ar en coveragelucka, aldrig ett kontrastfel.',
  $enheter: { artefakter: 'sc-item', temafamiljer: 'samma skarm, tillstand och variant i tva teman',
    par: 'en light och en dark i samma familj' },
  A_tackning: {
    artefakter_totalt: r.artefakter_st,
    deklarerade_st: r.deklarerade_st,
    unknown_st: r.unknown_st,
    notApplicable_neutral_st: r.neutral_st,
    temafamiljer_st: r.familjer_st,
    parade_st: r.par_st,
    enbartLight_st: r.enbartLight_st,
    enbartDark_st: r.enbartDark_st,
    tvetydiga_st: r.tvetydiga_st,
    tackning_procent: r.artefakter_st ? +(100 * r.deklarerade_st / r.artefakter_st).toFixed(1) : 0,
    invariant_ok: r.invariant_ok,
    par: r.par, enbartLight: r.enbartLight, enbartDark: r.enbartDark,
    tvetydiga: r.tvetydiga, unknown_exempel: r.unknown.slice(0, 20),
  },
  B_conformance: conformance,
  $soksignaler: {
    $not: 'UNDERLAG for migrationen, aldrig identitet och aldrig tackning.',
    artefaktid_innehaller_morkt_st: namnsignal.length,
    artefaktid_innehaller_morkt: namnsignal.map(x => x.art),
    storsta_yta_luminans_under_0_2_st: morkLuminans.length,
    bada_signalerna_st: bada.length,
    bada_signalerna: bada.map(x => x.art),
  },
  alla_artefakter: A,
  status: r.deklarerade_st === r.artefakter_st && r.unknown_st === 0 ? 'tackning komplett' : 'TACKNING OFULLSTANDIG',
};
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

const rad = (e, t, u) => console.log('  ' + e.padEnd(32) + String(t).padStart(5) + '  ' + u);
console.log('A · TEMATACKNING');
rad('artefakter totalt', r.artefakter_st, 'artefakter');
rad('  med giltig deklaration', r.deklarerade_st, 'artefakter');
rad('  unknown', r.unknown_st, 'artefakter');
rad('  notApplicable (neutral)', r.neutral_st, 'artefakter');
console.log('    tackning ' + doc.A_tackning.tackning_procent + ' %' +
  (r.invariant_ok ? '  ✔ invariant' : '  ✖ INVARIANT BRUTEN'));
rad('temafamiljer', r.familjer_st, 'familjer');
rad('  parade light+dark', r.par_st, 'par');
rad('  enbart light', r.enbartLight_st, 'familjer');
rad('  enbart dark', r.enbartDark_st, 'familjer');
rad('  tvetydiga', r.tvetydiga_st, 'familjer');
console.log('');
console.log('B · DARK CONFORMANCE');
console.log('  verifierade par ' + r.par_st +
  (r.par_st ? '' : ' — ingenting att mata. Det ar INTE ett godkannande.'));
console.log('');
console.log('SOKSIGNALER, ej identitet och ej tackning');
console.log('  artefaktid innehaller "morkt"   ' + namnsignal.length);
console.log('  storsta ytans luminans < 0,2    ' + morkLuminans.length);
console.log('  bada signalerna                 ' + bada.length);
console.log('');
console.log('R04-TACKNING status=' + doc.status);
process.exit(doc.status === 'tackning komplett' ? 0 : 1);
