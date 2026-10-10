#!/usr/bin/env node
// F2-E02 · MÄTER de åtta affordansleden mot den riktiga renderingen.
//
// Kör: node tools/preview-affordance.mjs [--out=<fil>]
//
// Metodcommiten (effect-adjudication.mjs · AFFORDANSKRAV) säger VILKA led som
// krävs för att en klippt preview ska få heta `begransad-preview-med-affordans`
// i stället för `innehall-dolt-utan-affordans`. Den säger ingenting om huruvida
// leden är uppfyllda. Det här verktyget avgör den frågan, och bara den.
//
// Varje led är ett MÄTT utfall, inte en utsaga. Sex av åtta läses ur den
// renderade sidan i samma headless Chrome och samma viewport som R-03 använder
// (--force-device-scale-factor=2 påverkar layouten och får inte utelämnas).
// De två som inte är geometri — att tillståndsparet är beslutat och att
// previewen är normativt tillåten — läses ur artifacts.json respektive
// evidensmatris.md, alltså ur det som redan är committat, aldrig ur en flagga
// som den här körningen sätter själv.
//
// FAIL CLOSED: allt som inte kunde mätas är false. Ett led som inte gick att
// avgöra är inte uppfyllt. Verktyget skriver aldrig `true` som standardvärde.

import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { AFFORDANSKRAV } from './effect-adjudication.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out') || 'fas2/affordansbevis.json';
const CHROME = process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Paret som prövas. Kollapsad artefakt, dess kontroll, och den expanderade.
const PAR = {
  fil: 'Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html',
  kollapsad: 'kompkalla',
  expanderad: 'kompkallahel',
  kontrollNamn: 'Visa hela',
  screenId: 'receptkalla'
};

/* ── Led som läses ur committad data, inte ur den här körningen ──────────── */

function beslutade() {
  const A = JSON.parse(readFileSync('artifacts.json', 'utf8')).artifacts;
  const hitta = id => A.find(a => a.sourceElementId === id && a.sourceFile === PAR.fil) || null;
  const k = hitta(PAR.kollapsad), e = hitta(PAR.expanderad);
  const beslutad = a => !!a && a.classificationState === 'decided' &&
    a.screenId === PAR.screenId && a.activationBlockers.length === 0;
  return {
    collapsedState: beslutad(k) && k.stateId === 'kollapsad',
    expandedArtifact: beslutad(e) && e.stateId === 'expanderad' &&
      e.lineageFrom === PAR.kollapsad,
    _slots: { kollapsad: k && k.stateId, expanderad: e && e.stateId,
              lineageFrom: e && e.lineageFrom }
  };
}

// Previewen är tillåten bara om ett NORMATIVT beslut säger det.
//
// Läses som DEKLARERADE FÄLT, inte som prosa. En fritextsökning hade gjort
// beslutet till en fråga om formulering: en mening som säger motsatsen
// innehåller samma ord som en som säger saken. Beslutsblocket bär därför en
// tabell med namngivna fält, och bara `previewAllowed = true` i det block som
// gäller den här artefakten räknas.
function normativtTillaten() {
  const P = 'evidensmatris.md';
  if (!existsSync(P)) return { avsiktligPreview: false, _rad: null };
  const txt = readFileSync(P, 'utf8');
  // Beslutsblocken avgränsas av rubriknivån de står på.
  const block = txt.split(/^###\s+/m)
    .filter(b => /^Normativt affordansbeslut/.test(b));
  const falt = (b, namn) => {
    const m = b.match(new RegExp('^\\|\\s*' + namn + '\\s*\\|\\s*(.+?)\\s*\\|\\s*$', 'm'));
    return m ? m[1].replace(/\*/g, '').trim() : null;
  };
  const mitt = block.find(b => falt(b, 'artifact') === '`' + PAR.kollapsad + '`');
  if (!mitt) return { avsiktligPreview: false, _rad: null };
  const tillaten = falt(mitt, 'previewAllowed') === 'true' &&
                   falt(mitt, 'hiddenContentRequiresAffordance') === 'true';
  return {
    avsiktligPreview: tillaten,
    _rad: 'previewAllowed=' + falt(mitt, 'previewAllowed') +
          ' · hiddenContentRequiresAffordance=' + falt(mitt, 'hiddenContentRequiresAffordance') +
          ' · preferredAffordance=' + falt(mitt, 'preferredAffordance')
  };
}

/* ── Led som mäts i den riktiga renderingen ─────────────────────────────── */

const MATNING = `(() => {
  const svar = { fel: null };
  const kol = document.getElementById(${JSON.stringify(PAR.kollapsad)});
  const exp = document.getElementById(${JSON.stringify(PAR.expanderad)});
  if (!kol || !exp) { svar.fel = 'artefakt saknas'; return svar; }

  // 1 · Kontrollen finns, och den är en kontroll — roll, namn och tillstånd.
  const ctl = kol.querySelector('[data-a11y-name=' + JSON.stringify(${JSON.stringify(PAR.kontrollNamn)}) + ']');
  svar.expandControl = !!ctl;
  svar.controlRollNamnState = !!ctl &&
    ctl.getAttribute('data-a11y-role') === 'button' &&
    !!ctl.getAttribute('data-a11y-name') &&
    !!ctl.getAttribute('data-a11y-state');
  svar.control = ctl ? {
    roll: ctl.getAttribute('data-a11y-role'),
    namn: ctl.getAttribute('data-a11y-name'),
    state: ctl.getAttribute('data-a11y-state')
  } : null;

  // 2 · Kontrollen är NÅBAR utan att användaren först måste scrolla.
  //     Mätt mot scrollporten, inte mot elementets egen box: att ett element
  //     finns i DOM:en säger ingenting om att det syns.
  svar.controlNabar = false;
  if (ctl) {
    const ram = kol.querySelector('.sc-phone');
    const ark = [...ram.querySelectorAll('div')].find(d => /82%/.test(d.getAttribute('style') || ''));
    const reg = ark && ark.children[2] && ark.children[2].children[0];
    if (reg) {
      const T = ctl.getBoundingClientRect(), R = reg.getBoundingClientRect();
      const cr = getComputedStyle(reg), ct = getComputedStyle(ctl);
      const bt = parseFloat(cr.borderTopWidth) || 0, bb = parseFloat(cr.borderBottomWidth) || 0;
      const portTop = R.top + bt, portBottom = R.bottom - bb;
      const inne = T.top >= portTop - 1e-9 && T.bottom <= portBottom + 1e-9 &&
                   T.left >= R.left - 1e-9 && T.right <= R.right + 1e-9;
      svar.controlNabar = inne && reg.scrollTop === 0 &&
        ct.display !== 'none' && ct.visibility === 'visible';
      svar.natal = {
        scrollTop: reg.scrollTop,
        portBottom_minus_kontrollBottom: portBottom - T.bottom,
        portTop_minus_kontrollTop: portTop - T.top
      };
    }
  }

  // 3 · Det expanderade tillståndet visar SAMMA logiska innehåll, inte en
  //     annan text som råkar ligga bredvid.
  const kall = n => {
    const d = [...n.querySelectorAll('div')].find(x => /ui-monospace/.test(getComputedStyle(x).fontFamily));
    return d ? { txt: (d.textContent || '').replace(/\\s+/g, ' ').trim(),
                 scrollH: d.scrollHeight, clientH: d.clientHeight,
                 overflowY: getComputedStyle(d).overflowY,
                 maxHeight: getComputedStyle(d).maxHeight } : null;
  };
  const a = kall(kol), b = kall(exp);
  svar.kallblock = { kollapsad: a, expanderad: b };
  svar.sammaLogiskaInnehall = !!a && !!b && b.txt.length >= a.txt.length &&
    b.txt.startsWith(a.txt.slice(0, Math.min(60, a.txt.length)));

  // 4 · Fulltexten är faktiskt nåbar i det expanderade tillståndet: inget
  //     kvarvarande överskott, ingen kvarvarande klippning.
  svar.fulltextNabar = !!b && b.scrollH <= b.clientH && !/hidden|clip/.test(b.overflowY);
  return svar;
})()`;

async function mat() {
  const port = 9940 + (process.pid % 40);
  const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
    '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
    '--force-device-scale-factor=2',
    '--user-data-dir=' + (process.env.TEMP || '.') + '/chrome-affordans', 'about:blank'],
    { stdio: 'ignore' });
  try {
    let ws = null;
    for (let k = 0; k < 60 && !ws; k++) {
      await sleep(250);
      try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {}
    }
    if (!ws) return { fel: 'chrome svarade inte' };
    const sock = new WebSocket(ws);
    await new Promise(r => { sock.onopen = r; });
    let id = 0; const vantar = new Map();
    sock.onmessage = m => {
      const j = JSON.parse(m.data);
      if (j.id && vantar.has(j.id)) { const res = vantar.get(j.id); vantar.delete(j.id); res(j.result); }
    };
    const call = (m, p = {}, s) => new Promise(res => {
      const n = ++id; vantar.set(n, res);
      sock.send(JSON.stringify({ id: n, method: m, params: p, ...(s ? { sessionId: s } : {}) }));
    });
    const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
    const s = (m, p) => call(m, p, sessionId);
    await s('Page.enable');
    await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
    await s('Page.navigate', { url: pathToFileURL(resolve(PAR.fil)).href });
    await sleep(500);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(1400);
    const r = await s('Runtime.evaluate', { returnByValue: true, expression: MATNING });
    return (r && r.result && r.result.value) || { fel: 'ingen mätning' };
  } finally { chrome.kill(); }
}

/* ── Sammanställning ────────────────────────────────────────────────────── */

const m = await mat();
const d = beslutade();
const n = normativtTillaten();
const ratt = { ...d, ...n, ...m };

// Fail closed: bara uttryckligt true räknas. Allt annat — false, undefined,
// ett led som verktyget inte kände till — är icke uppfyllt.
const previewAffordance = {};
for (const k of AFFORDANSKRAV) previewAffordance[k] = ratt[k] === true;
const saknade = AFFORDANSKRAV.filter(k => previewAffordance[k] !== true);

const doc = {
  $schema: 'butlery-affordansbevis/1',
  kontroll: 'CHK-R-AFF-01',
  matt: new Date().toISOString().slice(0, 10),
  par: PAR,
  previewAffordance,
  verifierad: saknade.length === 0,
  saknade,
  matning: {
    kontroll: m.control || null,
    natal: m.natal || null,
    kallblock: m.kallblock || null,
    fel: m.fel || null
  },
  beslutsunderlag: { slots: d._slots, normativRad: n._rad },
  metod: 'headless Chrome · 390×844 · deviceScaleFactor 2 · document.fonts.ready inväntad'
};
writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('AFFORDANSBEVIS verifierad=' + doc.verifierad +
  ' uppfyllda=' + (AFFORDANSKRAV.length - saknade.length) + ' av ' + AFFORDANSKRAV.length +
  (saknade.length ? ' saknade=' + JSON.stringify(saknade) : ''));
if (m.natal) console.log('  kontrollens marginal i scrollporten: ' +
  m.natal.portBottom_minus_kontrollBottom.toFixed(5) + ' px vid scrollTop ' + m.natal.scrollTop);
if (m.kallblock && m.kallblock.expanderad) console.log('  expanderat källblock: scrollH ' +
  m.kallblock.expanderad.scrollH + ' · clientH ' + m.kallblock.expanderad.clientH +
  ' · overflow-y ' + m.kallblock.expanderad.overflowY);
process.exit(doc.verifierad ? 0 : 1);
