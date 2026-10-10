#!/usr/bin/env node
// F2-A04 · RENDERNEUTRALITETSPROV för en klassificeringsändring.
//
// Kör: node tools/render-neutrality.mjs --fore=<fil> --efter=<fil> [--out=<fil>]
//
// En artefaktdelning ändrar med nödvändighet DOM-trädets containment: en ram
// blir två. Frågan är därför inte om trädet är identiskt, utan om NÅGOT
// RENDERAT ÄR ANNORLUNDA. Provet mäter varje enhetsram (.sc-phone) och varje
// kontroll i båda versionerna och kräver att de är identiska på:
//
//   · geometri  — rektangel i CSS-pixlar
//   · CSS       — den beräknade stil som påverkar layout och färg
//   · text      — allt textinnehåll
//   · a11y      — roll, namn, tillstånd
//   · SVG       — varje ikons attribut och banor
//
// Ramarna identifieras av sitt INNEHÅLL, inte av vilken artefakt de ligger i —
// annars vore provet cirkulärt: en delning flyttar per definition ramar mellan
// artefakter.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const FORE = arg('fore'), EFTER = arg('efter'), OUT = arg('out');
if (!FORE || !EFTER) { console.error('✖ ange --fore=<fil> --efter=<fil>'); process.exit(2); }

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

const MATA = `(() => {
  const cssFält = ['display','position','width','height','padding','margin','border',
    'color','backgroundColor','fontSize','fontWeight','fontFamily','lineHeight',
    'letterSpacing','textAlign','flexDirection','justifyContent','alignItems','gap',
    'overflow','overflowX','overflowY','textOverflow','webkitLineClamp','opacity',
    'borderRadius','boxSizing','whiteSpace','fontStyle','textDecorationLine'];
  const beskriv = el => {
    const c = getComputedStyle(el), r = el.getBoundingClientRect();
    const css = {}; for (const k of cssFält) css[k] = c[k];
    return {
      tag: el.tagName.toLowerCase(),
      rect: [+r.width.toFixed(2), +r.height.toFixed(2)],
      css,
      text: (el.textContent || '').replace(/\\s+/g, ' ').trim(),
      a11y: { roll: el.getAttribute('data-a11y-role') || null,
              namn: el.getAttribute('data-a11y-name') || null,
              tillstand: el.getAttribute('data-a11y-state') || null },
      svg: [...el.querySelectorAll('svg')].map(s =>
        [...s.attributes].map(a => a.name + '=' + a.value).sort().join(';') + '||' +
        [...s.querySelectorAll('*')].map(p => p.tagName + ':' +
          [...p.attributes].map(a => a.name + '=' + a.value).sort().join(',')).join('|'))
    };
  };
  // Enhetsramar är den renderade ytan. Deras innehåll är det användaren ser.
  const ramar = [...document.querySelectorAll('.sc-phone')].map(beskriv);
  const kontroller = [...document.querySelectorAll('[data-a11y-role]')].map(beskriv);
  return { ramar, kontroller,
    artefakter: [...document.querySelectorAll('.sc-item')].map(i => i.id),
    nastade: [...document.querySelectorAll('.sc-item')]
      .filter(i => i.parentElement && i.parentElement.closest('.sc-item'))
      .map(i => i.id + ' inuti ' + i.parentElement.closest('.sc-item').id) };
})()`;

const port = 9970 + (process.pid % 25);
const profil = mkdtempSync(join(tmpdir(), 'neutral-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + profil, 'about:blank'], { stdio: 'ignore' });

let wsUrl = null;
for (let i = 0; i < 60 && !wsUrl; i++) {
  await sleep(250);
  try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {}
}
if (!wsUrl) { console.error('✖ verktygsfel: Chrome startade aldrig'); chrome.kill(); process.exit(2); }
const ws = new WebSocket(wsUrl);
await new Promise(r => { ws.onopen = r; });
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
await s('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false });

async function mät(fil) {
  await s('Page.navigate', { url: pathToFileURL(fil).href });
  await sleep(1500);
  const r = await s('Runtime.evaluate', { expression: MATA, returnByValue: true });
  if (r.exceptionDetails || !r.result.value) throw new Error('mätningen misslyckades för ' + fil);
  return r.result.value;
}

const a = await mät(FORE), b = await mät(EFTER);
chrome.kill();

const sha = v => createHash('sha256').update(JSON.stringify(v)).digest('hex');
// Ramarna matchas på sitt INNEHÅLL (texten), inte på ordning eller ägare.
const nyckel = x => sha(x.text + '|' + JSON.stringify(x.rect));
const index = list => { const m = new Map(); for (const x of list) m.set(nyckel(x), x); return m; };

const avvikelser = [];
function jämför(namn, la, lb) {
  const ia = index(la), ib = index(lb);
  for (const [k, x] of ia) {
    if (!ib.has(k)) { avvikelser.push(namn + ': försvann — ' + x.tag + ' "' + x.text.slice(0, 50) + '"'); continue; }
    const y = ib.get(k);
    for (const fält of ['rect', 'css', 'text', 'a11y', 'svg'])
      if (sha(x[fält]) !== sha(y[fält]))
        avvikelser.push(namn + ' ' + fält + ' ändrades: ' + x.tag + ' "' + x.text.slice(0, 40) + '"');
  }
  for (const [k, y] of ib)
    if (!ia.has(k)) avvikelser.push(namn + ': tillkom — ' + y.tag + ' "' + y.text.slice(0, 50) + '"');
}
jämför('enhetsram', a.ramar, b.ramar);
jämför('kontroll', a.kontroller, b.kontroller);

const tillkomna = b.artefakter.filter(x => !a.artefakter.includes(x));
const borttagna = a.artefakter.filter(x => !b.artefakter.includes(x));

const rapport = {
  $regel: 'En delning ändrar med nödvändighet vilken artefakt en ram tillhör. Provet mäter därför RENDERAT RESULTAT per ram och kontroll, matchat på innehåll, inte på ägare.',
  fore: FORE, efter: EFTER,
  enhetsramar_st: { fore: a.ramar.length, efter: b.ramar.length },
  kontroller_st: { fore: a.kontroller.length, efter: b.kontroller.length },
  artefakter_st: { fore: a.artefakter.length, efter: b.artefakter.length },
  tillkomna_artefakter: tillkomna,
  borttagna_artefakter: borttagna,
  nastade_artefakter: { fore: a.nastade, efter: b.nastade },
  jamforda_falt: ['rect (css-px)', 'beräknad CSS (33 egenskaper)', 'text', 'a11y roll/namn/tillstånd', 'svg attribut och banor'],
  avvikelser,
  status: avvikelser.length === 0 && b.nastade.length === 0 ? 'renderneutral' : 'EJ RENDERNEUTRAL'
};

if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1));
console.log('NEUTRALITET status=' + rapport.status +
  ' ramar=' + a.ramar.length + '→' + b.ramar.length +
  ' kontroller=' + a.kontroller.length + '→' + b.kontroller.length +
  ' artefakter=' + a.artefakter.length + '→' + b.artefakter.length +
  ' avvikelser=' + avvikelser.length +
  ' nästade_efter=' + b.nastade.length);
if (tillkomna.length) console.log('  + tillkomna artefakt-id: ' + tillkomna.join(', '));
if (borttagna.length) console.log('  − borttagna artefakt-id: ' + borttagna.join(', '));
for (const d of avvikelser.slice(0, 20)) console.log('  ✖ ' + d);
process.exit(rapport.status === 'renderneutral' ? 0 : 1);
