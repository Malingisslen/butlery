#!/usr/bin/env node
// F2-R01 · SPÅRBARHET FÖR DE FALSKA 1,00-VÄRDENA.
//
// Kör: node tools/contrast-reconcile.mjs --fore=<raw> --efter=<raw> [--out=<fil>]
//
// Metodrättningen tar bort ett mätfel, och då måste varje borttaget tal kunna
// förklaras. Kravet är INTE att exakt 146 rader försvinner: den nya modellen
// hittar flera text-runs per kontroll och kan därför ändra evidenspopulationen
// på egen hand. Kravet är att INGEN gammal 1,00-rad bara försvinner.
//
// Varje gammalt fall får exakt en förklaring:
//   ersatt-av-textrun     kontrollen har synlig text som nu mäts på sin målare
//   notApplicable         kontrollen målar ingen synlig text (ikonkontroll)
//   unknown               synlig text finns men kvoten kan inte reduceras
//   exempt-disabled       positivt verifierat inaktiv
//   OFÖRKLARAD            kontrollen gick inte att återfinna — fail closed
//
// Nyckeln är kontrollens identitet, inte dess plats i listan: artefakt,
// viewport, roll, tillgängligt namn och löpnummer inom den gruppen.

import { readFileSync, writeFileSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const FORE = arg('fore'), EFTER = arg('efter'), OUT = arg('out');
if (!FORE || !EFTER) { console.error('✖ ange --fore=<raw> --efter=<raw>'); process.exit(2); }

function kontroller(fil) {
  const D = JSON.parse(readFileSync(fil, 'utf8'));
  const ut = new Map();
  for (const r of D.results) {
    if (r.probe) continue;
    for (const a of r.artifacts) {
      const räknare = new Map();
      for (const c of a.controls || []) {
        const bas = [a.id, r.profile.id, c.role, c.name].join(' ‖ ');
        const n = räknare.get(bas) || 0;
        räknare.set(bas, n + 1);
        ut.set(bas + ' #' + n, c);
      }
    }
  }
  return ut;
}

const före = kontroller(FORE);
const efter = kontroller(EFTER);

const gamlaEttor = [...före.entries()].filter(([, c]) => c.contrast === 1);
const rader = [];
for (const [nyckel, g] of gamlaEttor) {
  const n = efter.get(nyckel);
  let förklaring, detalj;
  if (!n) { förklaring = 'OFÖRKLARAD'; detalj = 'kontrollen finns inte i efterkörningen'; }
  else if (n.contrastApplicability === 'notApplicable:noVisibleText') {
    förklaring = 'notApplicable'; detalj = 'kontrollen målar ingen synlig text'; }
  else if (n.contrastApplicability === 'unknown') {
    förklaring = 'unknown'; detalj = n.contrastWhy || 'kvoten kan inte reduceras'; }
  else if (n.contrastApplicability === 'exempt:disabled') {
    förklaring = 'exempt-disabled'; detalj = 'kvot ' + n.contrast + ' · grund ' + n.disabledBasis; }
  else if (n.contrastStatus === 'measured' && n.textRuns_st > 0) {
    förklaring = 'ersatt-av-textrun';
    detalj = n.textRuns_st + ' run(s) · kvot ' + n.contrast +
      ' · målare är kontrollen: ' + n.textRuns.every(t => t.malareArKontrollen); }
  else { förklaring = 'OFÖRKLARAD'; detalj = 'oväntad status ' + n.contrastStatus; }
  rader.push({ nyckel, gammalKvot: g.contrast, förklaring, detalj,
    nyKvot: n ? n.contrast : null, nyApplicability: n ? n.contrastApplicability : null });
}

const per = {};
for (const r of rader) per[r.förklaring] = (per[r.förklaring] || 0) + 1;
const oförklarade = rader.filter(r => r.förklaring === 'OFÖRKLARAD');

// Kvarvarande 1,00-värden i den NYA körningen. Ett sådant är inte automatiskt
// fel — men det får aldrig komma från kontrollens egen ärvda färg.
const nyaEttor = [...efter.entries()].filter(([, c]) => c.contrast === 1);
const nyaEttorFrånContainer = nyaEttor.filter(([, c]) =>
  (c.textRuns || []).some(t => t.ratio === 1 && t.malareArKontrollen === true));

const doc = {
  $schema: 'butlery-kontrastavstamning/1',
  kontroll: 'CHK-R-01',
  $regel: 'Inget gammalt 1,00-värde får försvinna utan spårbar förklaring. Antalet rader behöver INTE vara oförändrat — den nya modellen kan hitta flera text-runs per kontroll.',
  gamla_ettor_st: gamlaEttor.length,
  forklaringar: per,
  oforklarade_st: oförklarade.length,
  oforklarade: oförklarade.slice(0, 20),
  nya_ettor_st: nyaEttor.length,
  nya_ettor_fran_container_st: nyaEttorFrånContainer.length,
  status: oförklarade.length === 0 && nyaEttorFrånContainer.length === 0 ? 'godkänd' : 'FÄLLD',
  rader
};
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('AVSTÄMNING gamla 1,00-värden: ' + gamlaEttor.length);
for (const [k, v] of Object.entries(per).sort((a, b) => b[1] - a[1]))
  console.log('  ' + k.padEnd(22) + v);
console.log('  oförklarade            ' + oförklarade.length);
for (const r of oförklarade.slice(0, 10)) console.log('    ✖ ' + r.nyckel + ' — ' + r.detalj);
console.log('kvarvarande 1,00 i nya körningen: ' + nyaEttor.length +
  ' · varav från kontrollens egen färg: ' + nyaEttorFrånContainer.length);
console.log('AVSTÄMNING status=' + doc.status);
process.exit(doc.status === 'godkänd' ? 0 : 1);
