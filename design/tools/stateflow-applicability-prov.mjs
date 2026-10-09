#!/usr/bin/env node
// BUTLERY · BLOCK 283 · METODPROV.  AP283-01 … AP283-07
//
// Arbetar pa en KOPIA av kallan utanfor reporoten. Produkten ror vi aldrig.
// Kor: node tools/stateflow-applicability-prov.mjs --out=<katalog utanfor repot>

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = arg('root') || '.';
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve(ROOT) + '\\') || outAbs.startsWith(resolve(ROOT) + '/')) {
  console.error('✖ --out maste ligga utanfor reporoten'); process.exit(2); }
if (existsSync(outAbs)) rmSync(outAbs, { recursive: true, force: true });
mkdirSync(outAbs, { recursive: true });

const BYGG = resolve(join(ROOT, 'tools/stateflow-applicability.mjs'));
const KALLA = resolve(join(ROOT, 'fas2/stateflow-applicability.json'));

const resultat = [];
const prov = (id, vad, ok, detalj) => {
  resultat.push({ id, vad, godkand: !!ok });
  console.log((ok ? '✔' : '✖') + ' ' + id + '  ' + vad + (detalj ? '\n     ' + detalj : ''));
};
const kor = (kallfil, detalj) => JSON.parse(execFileSync(process.execPath,
  [BYGG, '--root=' + ROOT, '--kalla=' + kallfil, ...(detalj ? ['--detalj=' + detalj] : [])],
  { encoding: 'utf8', maxBuffer: 1 << 26 }));
const korRatt = kallfil => {
  try { execFileSync(process.execPath, [BYGG, '--root=' + ROOT, '--kalla=' + kallfil],
    { encoding: 'utf8', stdio: 'pipe', maxBuffer: 1 << 26 }); return null; }
  catch (e) { return String(e.stderr || e.message); }
};
const kopia = (namn, muterare) => {
  const p = join(outAbs, namn + '.json');
  const k = JSON.parse(readFileSync(KALLA, 'utf8'));
  muterare(k);
  writeFileSync(p, JSON.stringify(k, null, 1));
  return p;
};
// Kallan bar sina egna forvantade varden och byggaren sjalvkontrollerar mot dem.
// Ett prov som MED FLIT andrar en status maste darfor lyfta just de forvantningar
// mutationen bryter — annars faller bygget pa sjalvkontrollen i stallet for pa det
// provet mater. Identitetsforvantningarna lamnas kvar.
const nollaSjalvkontroll = k => { delete k.forvantat.REQUIRED; delete k.forvantat.UNSPECIFIED;
  delete k.forvantat.NYA_REQUIRED; delete k.forvantat.STATUS_FINGERPRINT;
  delete k.forvantat.UNVERIFIABLE; delete k.forvantat.NOT_REQUIRED; };

const BAS = kor(KALLA);
const BAS_CSR = kor(KALLA, 'csr');

/* AP283-01 · omkastad kallordning lamnar identiteter oforandrade */
{
  const p = kopia('ap01', k => { k.kontrolltillstand.reverse(); k.overgangar.reverse(); });
  const r = kor(p);
  prov('AP283-01', 'omkastad kallordning: identiteter stabila',
    r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT &&
    r.STATUS_FINGERPRINT === BAS.STATUS_FINGERPRINT,
    'identitet ' + r.IDENTITY_FINGERPRINT);
}

/* AP283-02 · andrad status traffar exakt en rad */
{
  const p = kopia('ap02', k => { nollaSjalvkontroll(k);
    k.kontrolltillstand.find(x => x.ROW_ID === 'CSR::ROLE::button::PRESSED').NEW_STATUS = 'UNVERIFIABLE'; });
  const r = kor(p), c = kor(p, 'csr');
  const diff = c.filter((x, i) => x.NEW_STATUS !== BAS_CSR[i].NEW_STATUS);
  prov('AP283-02', 'andrad status paverkar exakt en rad',
    diff.length === 1 && diff[0].ROW_ID === 'CSR::ROLE::button::PRESSED' &&
    r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT,
    diff.length + ' rad (' + (diff[0] || {}).ROW_ID + ') · identitet oforandrad');
}

/* AP283-03 · irrelevant formulering andrar ingen rad */
{
  const p = kopia('ap03', k => { k.$om = 'omskriven prosa utan betydelse';
    k.kontrolltillstand[0].EVIDENCE += ' (omformulerad)';
    k.produktbeslut.$d10 += ' (omformulerad)'; });
  const r = kor(p);
  prov('AP283-03', 'irrelevant formulering andrar ingen rad',
    r.STATUS_FINGERPRINT === BAS.STATUS_FINGERPRINT &&
    r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT, 'statusavtryck oforandrat');
}

/* AP283-04 · ett normativt state tillagt ger exakt en andrad applicability */
{
  const p = kopia('ap04', k => { nollaSjalvkontroll(k);
    const r0 = k.kontrolltillstand.find(x => x.ROW_ID === 'CSR::ROLE::tab::DISABLED');
    r0.NEW_STATUS = 'REQUIRED'; r0.SOURCE = ['komponentark']; r0.SOURCE_LOCATION = 'prov'; });
  const c = kor(p, 'csr');
  const diff = c.filter((x, i) => x.NEW_STATUS !== BAS_CSR[i].NEW_STATUS);
  prov('AP283-04', 'normativt state tillagt: exakt en andrad applicability',
    diff.length === 1 && diff[0].ROW_ID === 'CSR::ROLE::tab::DISABLED' && diff[0].NEW_STATUS === 'REQUIRED',
    diff.length + ' rad · ' + (diff[0] || {}).ROW_ID);
}

/* AP283-05 · en borttagen kallrad faller stangt i stallet for att gissa */
{
  const p = kopia('ap05', k => {
    k.kontrolltillstand = k.kontrolltillstand.filter(x => x.ROW_ID !== 'CSR::ROLE::textbox::DISABLED'); });
  const fel = korRatt(p);
  prov('AP283-05', 'borttagen kallrad faller stangt i stallet for att gissa',
    !!fel && /saknar beslut/.test(fel),
    fel ? (fel.split('\n').find(l => /FAIL CLOSED/.test(l)) || '').slice(0, 92) : 'byggde utan att klaga');
}

/* AP283-06 · applicability far inte rora Block 282:s mappning */
{
  const p = kopia('ap06', k => { nollaSjalvkontroll(k);
    k.kontrolltillstand.find(x => x.ROW_ID === 'CSR::ROLE::button::FOCUSED').NEW_STATUS = 'NOT_REQUIRED'; });
  const b = kor(p).BLOCK_282_READONLY;
  prov('AP283-06', 'target/view-mappningen ororad av state-applicability',
    b.MAPPING_FINGERPRINT === BAS.BLOCK_282_READONLY.MAPPING_FINGERPRINT &&
    b.VIEW_SCREENS === BAS.BLOCK_282_READONLY.VIEW_SCREENS &&
    b.FRAME_SCREENS === BAS.BLOCK_282_READONLY.FRAME_SCREENS &&
    JSON.stringify(b.FLOW_REPRESENTATION) === JSON.stringify(BAS.BLOCK_282_READONLY.FLOW_REPRESENTATION),
    'mapping ' + b.MAPPING_FINGERPRINT + ' · ' + b.VIEW_SCREENS + '/' + b.FRAME_SCREENS);
}

/* AP283-07 · status ingar inte i persistent identitet */
{
  const p = kopia('ap07', k => { nollaSjalvkontroll(k);
    k.kontrolltillstand.forEach(x => { x.NEW_STATUS = 'UNVERIFIABLE';
      if (!x.SOURCE || !x.SOURCE.length) x.SOURCE = ['evidensmatris']; }); });
  const r = kor(p);
  prov('AP283-07', 'status ingar inte i persistent identitet',
    r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT &&
    r.STATUS_FINGERPRINT !== BAS.STATUS_FINGERPRINT,
    'identitet ' + r.IDENTITY_FINGERPRINT + ' (oforandrad) · status ' + r.STATUS_FINGERPRINT + ' (andrad)');
}

const g = resultat.filter(r => r.godkand).length;
writeFileSync(join(outAbs, 'ap283-prov.json'), JSON.stringify(
  { $schema: 'butlery-ap283-prov/1', godkanda: g, av: resultat.length, resultat }, null, 1) + '\n');
console.log('\nAP283-PROV status=' + (g === resultat.length ? 'godkand' : 'UNDERKAND') +
  ' godkanda=' + g + ' av ' + resultat.length);
process.exit(g === resultat.length ? 0 : 1);
