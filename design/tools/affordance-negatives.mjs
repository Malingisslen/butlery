#!/usr/bin/env node
// F2-E03 · Negativa prov för CHK-R-AFF-01. Muterar en KOPIA av de verkliga indata och
// kräver att varje mutation fäller exakt det led den angriper.
import { mkdirSync, cpSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const SRC = process.cwd();
const HTML = 'Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html';
const BAS = (process.env.TEMP || '.') + '/butlery-affordans-negativa';

const MUT = [
  ['N-A1', 'kontrollen borttagen ur den kollapsade artefakten',
    ['expandControl', 'controlRollNamnState', 'controlNabar'],
    d => { const p = d + '/' + HTML; let s = readFileSync(p, 'utf8');
      const i = s.indexOf('id="kompkalla"'), j = s.indexOf('id="kompkallahel"');
      // Mutationen maste tala attribut FORE style. Den forsta versionen band
      // sig vid '<span style=' och slutade bita nar data-hit skrevs in vid
      // traffyte-migrationen — negativprovet foll da utan att nagot skydd var
      // trasigt. Skyddet ar oforandrat; det var mutationen som slutade mutera.
      const del = s.slice(i, j).replace(/<span[^>]*style="display:inline-flex[^]*?<\/span>/, '');
      writeFileSync(p, s.slice(0, i) + del + s.slice(j)); }],

  ['N-A2', 'kontrollen saknar data-a11y-state', ['controlRollNamnState'],
    d => { const p = d + '/' + HTML; let s = readFileSync(p, 'utf8');
      const i = s.indexOf('id="kompkalla"'), j = s.indexOf('id="kompkallahel"');
      const del = s.slice(i, j).replace(' data-a11y-state="collapsed"', '');
      writeFileSync(p, s.slice(0, i) + del + s.slice(j)); }],

  ['N-A3', 'previewen höjd igen så kontrollen hamnar under vikningen', ['controlNabar'],
    d => { const p = d + '/' + HTML; let s = readFileSync(p, 'utf8');
      const i = s.indexOf('id="kompkalla"'), j = s.indexOf('id="kompkallahel"');
      const del = s.slice(i, j).replace('max-height:115px', 'max-height:150px');
      writeFileSync(p, s.slice(0, i) + del + s.slice(j)); }],

  ['N-A4', 'expanderade artefakten oklassificerad i registret', ['expandedArtifact'],
    d => { const p = d + '/artifacts.json'; const A = JSON.parse(readFileSync(p, 'utf8'));
      const a = A.artifacts.find(x => x.sourceElementId === 'kompkallahel');
      a.classificationState = 'draft'; a.activationBlockers = ['obeslutad'];
      writeFileSync(p, JSON.stringify(A, null, 2) + '\n'); }],

  ['N-A5', 'härledningen till det kollapsade tillståndet kapad', ['expandedArtifact'],
    d => { const p = d + '/artifacts.json'; const A = JSON.parse(readFileSync(p, 'utf8'));
      A.artifacts.find(x => x.sourceElementId === 'kompkallahel').lineageFrom = null;
      writeFileSync(p, JSON.stringify(A, null, 2) + '\n'); }],

  ['N-A6', 'normativa beslutet säger previewAllowed false', ['avsiktligPreview'],
    d => { const p = d + '/evidensmatris.md'; let s = readFileSync(p, 'utf8');
      writeFileSync(p, s.replace('| previewAllowed | **true** |', '| previewAllowed | **false** |')); }],

  ['N-A7', 'expanderade tillståndet klipper fortfarande innehållet', ['fulltextNabar'],
    d => { const p = d + '/' + HTML; let s = readFileSync(p, 'utf8');
      const i = s.indexOf('id="kompkallahel"');
      const del = s.slice(i).replace('padding:12px;margin-top:8px;font:400 11.5px',
        'padding:12px;margin-top:8px;max-height:90px;overflow:hidden;font:400 11.5px');
      writeFileSync(p, s.slice(0, i) + del); }],

  ['N-A8', 'expanderade tillståndet visar en annan text', ['sammaLogiskaInnehall'],
    d => { const p = d + '/' + HTML; let s = readFileSync(p, 'utf8');
      const i = s.indexOf('id="kompkallahel"');
      const del = s.slice(i).replace('Pannbiffar med lök', 'Nagot helt annat innehall');
      writeFileSync(p, s.slice(0, i) + del); }]
];

let godkanda = 0;
const rader = [];
for (const [id, namn, forvantade, mutera] of MUT) {
  const d = BAS + '/' + id;
  rmSync(d, { recursive: true, force: true });
  mkdirSync(d, { recursive: true });
  for (const f of [HTML, 'artifacts.json', 'evidensmatris.md', 'selection-contexts.json'])
    cpSync(SRC + '/' + f, d + '/' + f);
  cpSync(SRC + '/tools', d + '/tools', { recursive: true });
  mutera(d);
  let ut = '';
  try { ut = execFileSync(process.execPath, ['tools/preview-affordance.mjs',
    '--out=' + d + '/bevis.json'], { cwd: d, encoding: 'utf8' }); }
  catch (e) { ut = (e.stdout || '') + (e.stderr || ''); }
  let bevis = null;
  try { bevis = JSON.parse(readFileSync(d + '/bevis.json', 'utf8')); } catch {}
  const saknade = bevis ? bevis.saknade : null;
  const ok = !!bevis && bevis.verifierad === false &&
    forvantade.every(k => saknade.includes(k)) &&
    saknade.every(k => forvantade.includes(k));
  if (ok) godkanda++;
  rader.push({ id, namn, forvantade, saknade, godkant: ok });
  console.log((ok ? '✔ ' : '✖ ') + id + '  ' + namn);
  console.log('     förväntade fällda led: ' + JSON.stringify(forvantade));
  console.log('     faktiskt fällda led:   ' + JSON.stringify(saknade));
}
writeFileSync(SRC + '/fas2/affordans-negativa-prov.json', JSON.stringify({
  $schema: 'butlery-affordans-negativa/1', kontroll: 'CHK-R-AFF-01',
  godkanda, total: MUT.length, prov: rader,
  status: godkanda === MUT.length ? 'godkänd' : 'FÄLLD'
}, null, 1) + '\n');
console.log('AFFORDANS-NEGATIVA status=' + (godkanda === MUT.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + godkanda + ' av ' + MUT.length);
