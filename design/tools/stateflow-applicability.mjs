#!/usr/bin/env node
// BUTLERY · BLOCK 283 · NORMATIV APPLICABILITY.  READ-ONLY BYGGARE.
//
// KANONISK INDATA: fas2/stateflow-applicability.json.
// Inga normativa beslut ar hardkodade har — byggaren validerar och aggregerar,
// den avgor ingenting. HTML-rapporter ar aldrig indata.
//
// FAIL CLOSED
//   · Block 282:s frysta fingeravtryck maste reproduceras exakt
//   · varje rad i Block 282:s kontrolltillstands- och overgangspopulation
//     maste tackas av kallan, exakt en gang
//   · en status som inte ar UNSPECIFIED maste bara minst en kand kalla
//   · status ingar aldrig i identiteten
//
// Kor: node tools/stateflow-applicability.mjs [--root=.] [--detalj=csr|tr]

import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = arg('root') || '.';
const KALLA = arg('kalla') || join(ROOT, 'fas2/stateflow-applicability.json');
const K = JSON.parse(readFileSync(KALLA, 'utf8'));
if (K.$schema !== 'butlery-stateflow-applicability/1')
  throw new Error('FAIL CLOSED: okant schema: ' + K.$schema);

const BYGG = join(ROOT, 'tools/stateflow-population.mjs');
const kor = d => JSON.parse(execFileSync(process.execPath,
  [BYGG, '--root=' + ROOT, ...(d ? ['--detalj=' + d] : [])],
  { encoding: 'utf8', maxBuffer: 1 << 26 }));

/* ── A · BLOCK 282 READ-ONLY-GRIND ─────────────────────────────────────── */
const POP = kor(null);
const F = K.forvantat.BLOCK_282;
const kontroll = [
  ['POPULATION_FINGERPRINT', POP.POPULATION_FINGERPRINT, F.POPULATION_FINGERPRINT],
  ['IDENTITY_FINGERPRINT', POP.IDENTITY_FINGERPRINT, F.IDENTITY_FINGERPRINT],
  ['MAPPING_FINGERPRINT', POP.MAPPNINGSREVISION.MAPPING_FINGERPRINT, F.MAPPING_FINGERPRINT],
  ['VIEW_SCREENS', POP.MAPPNINGSREVISION.VIEW_SCREENS, F.VIEW_SCREENS],
  ['FRAME_SCREENS', POP.MAPPNINGSREVISION.FRAME_SCREENS, F.FRAME_SCREENS],
  ['FLOW_REPRESENTATION', JSON.stringify(POP.FLOW_REPRESENTATION), JSON.stringify(F.FLOW_REPRESENTATION)]
];
for (const [namn, har, vantat] of kontroll)
  if (har !== vantat)
    throw new Error('FAIL CLOSED: Block 282 ' + namn + ' ar ' + har + ', fryst vardet ar ' + vantat);

/* ── B · KONTROLLTILLSTAND ─────────────────────────────────────────────── */
const STATUSAR = new Set(['REQUIRED', 'NOT_REQUIRED', 'UNSPECIFIED', 'UNVERIFIABLE']);
const CSR282 = kor('csr');
const kallRader = new Map();
for (const r of K.kontrolltillstand) {
  if (kallRader.has(r.ROW_ID)) throw new Error('FAIL CLOSED: dubblerad rad ' + r.ROW_ID);
  if (!STATUSAR.has(r.NEW_STATUS)) throw new Error('FAIL CLOSED: ogiltig status ' + r.NEW_STATUS + ' i ' + r.ROW_ID);
  if (r.NEW_STATUS !== 'UNSPECIFIED' && (!r.SOURCE || !r.SOURCE.length))
    throw new Error('FAIL CLOSED: ' + r.ROW_ID + ' har status ' + r.NEW_STATUS + ' utan kalla');
  for (const s of r.SOURCE || [])
    if (!K.kallregister[s]) throw new Error('FAIL CLOSED: okand kalla "' + s + '" i ' + r.ROW_ID);
  kallRader.set(r.ROW_ID, r);
}
const saknas = CSR282.filter(x => !kallRader.has(x.id)).map(x => x.id);
const overtaliga = [...kallRader.keys()].filter(id => !CSR282.some(x => x.id === id));
if (saknas.length) throw new Error('FAIL CLOSED: ' + saknas.length + ' rader saknar beslut:\n  ' + saknas.join('\n  '));
if (overtaliga.length) throw new Error('FAIL CLOSED: kallan beslutar rader som inte finns:\n  ' + overtaliga.join('\n  '));
const CSR = CSR282.map(x => ({ ...kallRader.get(x.id), REPRESENTATION_OCCURRENCES: x.forekomster }));

/* ── C · OVERGANGAR ────────────────────────────────────────────────────── */
const TR282 = kor('tr');
const kallTr = new Map();
for (const t of K.overgangar) {
  if (kallTr.has(t.TRANSITION_ID)) throw new Error('FAIL CLOSED: dubblerad overgang ' + t.TRANSITION_ID);
  if (!STATUSAR.has(t.NEW_APPLICABILITY))
    throw new Error('FAIL CLOSED: ogiltig applicability i ' + t.TRANSITION_ID);
  kallTr.set(t.TRANSITION_ID, t);
}
const trSaknas = TR282.filter(x => !kallTr.has(x.id)).map(x => x.id);
const trOver = [...kallTr.keys()].filter(id => !TR282.some(x => x.id === id));
if (trSaknas.length) throw new Error('FAIL CLOSED: overgangar utan beslut:\n  ' + trSaknas.join('\n  '));
if (trOver.length) throw new Error('FAIL CLOSED: beslut om overgangar som inte finns:\n  ' + trOver.join('\n  '));
const TR = TR282.map(x => kallTr.get(x.id));

/* ── D · AGGREGAT OCH FINGERAVTRYCK ────────────────────────────────────── */
const rakna = (a, f) => a.reduce((m, x) => (m[f(x)] = (m[f(x)] || 0) + 1, m), {});
const h = o => createHash('sha256').update(JSON.stringify(o)).digest('hex').slice(0, 16);
const IDENT_FP = h([...CSR.map(x => x.ROW_ID), ...TR.map(x => x.TRANSITION_ID)].sort());
const STATUS_FP = h([...CSR.map(x => x.ROW_ID + '|' + x.NEW_STATUS),
  ...TR.map(x => x.TRANSITION_ID + '|' + x.NEW_APPLICABILITY + '|' + x.REPRESENTATION_STATUS)].sort());

const nyaRequired = CSR.filter(x => x.PREVIOUS_STATUS === 'UNKNOWN' && x.NEW_STATUS === 'REQUIRED');
const ut = {
  BLOCK_282_READONLY: { POPULATION_FINGERPRINT: POP.POPULATION_FINGERPRINT,
    IDENTITY_FINGERPRINT: POP.IDENTITY_FINGERPRINT,
    MAPPING_FINGERPRINT: POP.MAPPNINGSREVISION.MAPPING_FINGERPRINT,
    VIEW_SCREENS: POP.MAPPNINGSREVISION.VIEW_SCREENS,
    FRAME_SCREENS: POP.MAPPNINGSREVISION.FRAME_SCREENS,
    FLOW_REPRESENTATION: POP.FLOW_REPRESENTATION, grind: 'GRON' },
  PRODUKTBESLUT: {
    D10_GENERALIZATION: K.produktbeslut.D10_GENERALIZATION,
    ROLE_VOCABULARY_CONFLICT_OPEN: K.produktbeslut.ROLE_VOCABULARY_CONFLICT_OPEN,
    TRANSITION_REPRESENTATION_ABSENT_IS_NOT_AUTOMATIC_REMEDIATION:
      K.produktbeslut.TRANSITION_REPRESENTATION_ABSENT_IS_NOT_AUTOMATIC_REMEDIATION,
    berorda_roller: K.produktbeslut.berorda_roller,
    berorda_rader_antal: K.produktbeslut.berorda_rader.length },
  CONTROL_STATE: { ROWS: CSR.length, FORE: rakna(CSR, x => x.PREVIOUS_STATUS),
    EFTER: rakna(CSR, x => x.NEW_STATUS),
    NYA_REQUIRED: nyaRequired.map(x => x.ROW_ID).sort(),
    NYA_REQUIRED_UTAN_REPRESENTATION: nyaRequired.filter(x => x.REPRESENTATION_OCCURRENCES === 0).length },
  TRANSITION: { ROWS: TR.length, APPLICABILITY: rakna(TR, x => x.NEW_APPLICABILITY),
    REPRESENTATION: rakna(TR, x => x.REPRESENTATION_STATUS) },
  IDENTITY_SCHEME: 'ROW_ID = CSR::ROLE::<roll>::<state> · TRANSITION_ID ur Block 282. Status ingar aldrig.',
  IDENTITY_FINGERPRINT: IDENT_FP,
  STATUS_FINGERPRINT: STATUS_FP
};

/* Sjalvkontroll mot kallans egna forvantade varden. */
// En forvantan som kallan INTE deklarerar provas inte. Att jamfora mot en
// saknad nyckel skulle falla stangt av fel skal: kallan har da inte pastatt
// nagot, och en icke-utsaga kan inte motsagas. Deklarerade nycklar provas alltid.
const fv = K.forvantat, avvik = [];
let provade = 0;
const jfr = (k, har) => {
  if (!(k in fv)) return;
  provade++;
  if (JSON.stringify(har) !== JSON.stringify(fv[k]))
    avvik.push(k + ': ' + JSON.stringify(har) + ' != ' + JSON.stringify(fv[k]));
};
jfr('CONTROL_STATE_ROWS', CSR.length);
jfr('REQUIRED', ut.CONTROL_STATE.EFTER.REQUIRED || 0);
jfr('UNSPECIFIED', ut.CONTROL_STATE.EFTER.UNSPECIFIED || 0);
jfr('NOT_REQUIRED', ut.CONTROL_STATE.EFTER.NOT_REQUIRED || 0);
jfr('UNVERIFIABLE', ut.CONTROL_STATE.EFTER.UNVERIFIABLE || 0);
jfr('UNKNOWN', ut.CONTROL_STATE.EFTER.UNKNOWN || 0);
jfr('NYA_REQUIRED', ut.CONTROL_STATE.NYA_REQUIRED);
jfr('TRANSITION_ROWS', TR.length);
jfr('APPLICABILITY_REQUIRED', ut.TRANSITION.APPLICABILITY.REQUIRED || 0);
jfr('REPRESENTATION_PRESENT', ut.TRANSITION.REPRESENTATION.PRESENT || 0);
jfr('REPRESENTATION_ABSENT', ut.TRANSITION.REPRESENTATION.ABSENT || 0);
jfr('REPRESENTATION_UNVERIFIABLE', ut.TRANSITION.REPRESENTATION.UNVERIFIABLE || 0);
jfr('IDENTITY_FINGERPRINT', IDENT_FP);
jfr('STATUS_FINGERPRINT', STATUS_FP);
if (avvik.length) throw new Error('FAIL CLOSED: byggt resultat avviker fran kallans forvantade varden:\n  ' + avvik.join('\n  '));
ut.SJALVKONTROLL = { deklarerade_forvantningar: provade, avvikelser: 0 };

const d = arg('detalj');
if (d === 'csr') console.log(JSON.stringify(CSR, null, 1));
else if (d === 'tr') console.log(JSON.stringify(TR, null, 1));
else console.log(JSON.stringify(ut, null, 1));
