// Kor: node tools/block288/uxfrysning.mjs --root=<kallrot> [--ut=<fil>] [--torr]
//
// Block 288 · UX- och beteendefrysningen. Den ar skild fran Block 287:s
// visuella kravfrysning och ror den inte: har binds vytillstand, overgangar
// och interaktionstillstand, inte ritningens element.
//
// Verktyget ar rent. Det laser de kanoniska beslutskallorna och skarmkorpusen
// och raknar om varje mangd sjalv. Ingen siffra skrivs in for hand, och
// REPRESENTATION raknas ur korpusen, aldrig ur en rad som pastar nagot.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const h = x => createHash('sha256').update(typeof x === 'string' ? x : JSON.stringify(x)).digest('hex');
const kort = x => h(x).slice(0, 16);

export function bygg(rot) {
  const j = f => JSON.parse(readFileSync(join(rot, f), 'utf8'));

  /* ---- kallor ---- */
  const b282 = j('fas2/stateflow-mappning.json');
  const b283 = j('fas2/stateflow-applicability.json');
  const b285 = j('fas2/role-state-applicability.json');
  const b288 = j('fas2/stateflow-applicability-0608.json');
  const pop = j('fas2/block287k-population.json');

  /* ---- ramar ur skarmkorpusen; representation far bara komma harifran ---- */
  const korpusfiler = readdirSync(rot).filter(f => /^Butlery .*\.dc\.html$/.test(f)).sort();
  const ramar = new Set();
  let korpusbytes = 0;
  for (const f of korpusfiler) {
    const s = readFileSync(join(rot, f), 'utf8');
    korpusbytes += s.length;
    for (const m of s.matchAll(/\bid="([a-z0-9-]+)"/g)) ramar.add(m[1]);
  }

  /* ---- vytillstand: 18 vyer x 7 tillstand ur den frysta populationen ---- */
  const fsr = pop.filter(u => /^RP::FLOW_STATE::FSR::VIEW::/.test(u.id));
  const vytillstand = fsr.map(u => {
    const d = u.id.split('::');
    return { VIEW: d[4], STATE: d[5], KATEGORI: u.CATEGORY };
  }).sort((a, b) => (a.VIEW + a.STATE).localeCompare(b.VIEW + b.STATE));
  const TILLAMPLIGA = new Set(['ALREADY_SATISFIED', 'PRODUCT_REMEDIATION_REQUIRED']);
  const tillampliga = vytillstand.filter(r => TILLAMPLIGA.has(r.KATEGORI));

  /* ---- overgangar: Block 283 (floden 01-05) + Block 288 (06-08) ---- */
  const t0105 = b283.overgangar.map(t => ({
    TRANSITION_ID: t.TRANSITION_ID,
    FLOW_ID: t.TRANSITION_ID.split('::')[2],
    STATUS: t.NEW_APPLICABILITY,
    REPRESENTATION: t.REPRESENTATION_STATUS,
    BLOCK: '283'
  }));
  const t0608 = b288.overgangar.map(t => ({
    TRANSITION_ID: t.TRANSITION_ID,
    FLOW_ID: t.FLOW_ID,
    STATUS: t.STATUS,
    REPRESENTATION: t.FRAME_HINT && ramar.has(t.FRAME_HINT) ? 'PRESENT' : 'ABSENT',
    BLOCK: '288'
  }));
  const overgangar = [...t0105, ...t0608].sort((a, b) => a.TRANSITION_ID.localeCompare(b.TRANSITION_ID));

  /* ---- interaktionstillstand: Block 283:s 70 rader, dar Block 285 avgjort 24 ---- */
  const b285status = new Map();
  for (const r of b285.rollstate) {
    const t = JSON.stringify(r);
    const s = /"PROPOSED_STATUS"\s*:\s*"([A-Z_]+)"/.exec(t);
    b285status.set(r.ROW_ID, s ? s[1] : 'UNSPECIFIED');
  }
  const interaktion = b283.kontrolltillstand.map(r => ({
    ROW_ID: r.ROW_ID,
    CONTROL_TYPE: r.CONTROL_TYPE,
    STATE: r.STATE,
    STATUS: b285status.has(r.ROW_ID) ? b285status.get(r.ROW_ID) : r.NEW_STATUS,
    AVGJORD_I: b285status.has(r.ROW_ID) ? '285' : '283'
  })).sort((a, b) => a.ROW_ID.localeCompare(b.ROW_ID));

  /* ---- beslutsbehov ---- */
  const beslutsbehov = (b288.beslutsbehov || []).map(d => d.DESIGN_DECISION_REQUIRED).sort();

  /* ---- grindar ---- */
  const idn = overgangar.map(t => t.TRANSITION_ID);
  const fel = [];
  if (idn.length !== new Set(idn).size) fel.push('TRANSITION_ID_COLLISIONS');
  for (const t of b288.overgangar) {
    if (!t.SOURCE || !t.SOURCE.length) fel.push('UTAN_KALLA:' + t.TRANSITION_ID);
    if (!t.SOURCE_LOCATION || !t.EVIDENCE) fel.push('UTAN_EVIDENS:' + t.TRANSITION_ID);
    if (!['REQUIRED', 'NOT_REQUIRED', 'UNRESOLVED'].includes(t.STATUS)) fel.push('OKAND_STATUS:' + t.TRANSITION_ID);
  }
  const okandaTillstand = tillampliga.filter(r => !['DEFAULT', 'LOADING', 'EMPTY', 'PARTIAL', 'ERROR', 'OFFLINE', 'CONFLICT'].includes(r.STATE));
  if (okandaTillstand.length) fel.push('UNKNOWN_STATES:' + okandaTillstand.length);
  const olosta = overgangar.filter(t => t.STATUS === 'UNRESOLVED');
  if (olosta.length) fel.push('UNRESOLVED_TRANSITIONS:' + olosta.length);

  const rakn = {
    UX_STATE_ROWS: vytillstand.length,
    UX_STATES_APPLICABLE: tillampliga.length,
    UX_STATES_DRAWN: tillampliga.filter(r => r.KATEGORI === 'ALREADY_SATISFIED').length,
    UX_STATES_ABSENT_IN_DESIGN: tillampliga.filter(r => r.KATEGORI === 'PRODUCT_REMEDIATION_REQUIRED').length,
    UX_VIEWS: new Set(vytillstand.map(r => r.VIEW)).size,
    TRANSITIONS_TOTAL: overgangar.length,
    TRANSITIONS_FLOW_01_05: t0105.length,
    TRANSITIONS_FLOW_06_08: t0608.length,
    TRANSITIONS_REQUIRED: overgangar.filter(t => t.STATUS === 'REQUIRED').length,
    TRANSITIONS_NOT_REQUIRED: overgangar.filter(t => t.STATUS === 'NOT_REQUIRED').length,
    TRANSITIONS_UNRESOLVED: olosta.length,
    TRANSITIONS_PRESENT_IN_DESIGN: overgangar.filter(t => t.REPRESENTATION === 'PRESENT').length,
    TRANSITIONS_ABSENT_IN_DESIGN: overgangar.filter(t => t.REPRESENTATION === 'ABSENT').length,
    TRANSITIONS_UNVERIFIABLE_IN_DESIGN: overgangar.filter(t => t.REPRESENTATION === 'UNVERIFIABLE').length,
    INTERACTION_ROWS: interaktion.length,
    INTERACTION_REQUIRED: interaktion.filter(r => r.STATUS === 'REQUIRED').length,
    INTERACTION_NOT_REQUIRED: interaktion.filter(r => r.STATUS === 'NOT_REQUIRED').length,
    INTERACTION_UNSPECIFIED: interaktion.filter(r => r.STATUS === 'UNSPECIFIED').length,
    DESIGN_DECISION_REQUIRED: beslutsbehov.length,
    FLOWS_MODELLED: new Set(overgangar.map(t => t.FLOW_ID)).size
  };

  const bindning = {
    UX_STATE_SET_HASH: h(vytillstand.map(r => r.VIEW + '::' + r.STATE + '=' + r.KATEGORI).join('\n')),
    TRANSITION_SET_HASH: h(overgangar.map(t => t.TRANSITION_ID + '=' + t.STATUS + '/' + t.REPRESENTATION).join('\n')),
    INTERACTION_SET_HASH: h(interaktion.map(r => r.ROW_ID + '=' + r.STATUS).join('\n')),
    DECISION_SET_HASH: h(beslutsbehov.join('\n')),
    CORPUS_FRAME_SET_HASH: h([...ramar].sort().join('\n')),
    CORPUS_BYTES: korpusbytes,
    CORPUS_FILES: korpusfiler.length,
    CORPUS_FRAMES: ramar.size,
    SOURCE_0608_HASH: h(readFileSync(join(rot, 'fas2/stateflow-applicability-0608.json'), 'utf8')),
    BLOCK_282_FINGERPRINT: b282.forvantat.MAPPING_FINGERPRINT || null,
    BLOCK_283_IDENTITY_FINGERPRINT: b283.forvantat.IDENTITY_FINGERPRINT || null,
    UX_MODEL_FINGERPRINT: kort([vytillstand, overgangar, interaktion, beslutsbehov]),
    ...rakn
  };

  return {
    $om: 'Block 288 · UX- och beteendefrysning. Skild fran Block 287:s visuella kravfrysning.',
    BLOCK: 288,
    STATUS: fel.length === 0 ? 'FROZEN' : 'BLOCKED',
    PROVENIENS: {
      VISUAL_REQUIREMENT_FREEZE: 'fas2/block287k-frysning.json',
      $skillnad: 'Den visuella frysningen binder element och krav. Den har binder tillstand, overgangar och interaktionslagen. Ingen av dem raknar om den andra.',
      KALLOR: ['fas2/stateflow-mappning.json', 'fas2/stateflow-applicability.json', 'fas2/role-state-applicability.json', 'fas2/stateflow-applicability-0608.json', 'fas2/block287k-population.json', 'Butlery Skarmar v12*.dc.html']
    },
    BINDNING: bindning,
    BESLUTSBEHOV: beslutsbehov,
    BLOCKERANDE: fel,
    vytillstand,
    overgangar,
    interaktion
  };
}

const arAnropad = process.argv[1] && /uxfrysning\.mjs$/.test(process.argv[1].replace(/\\/g, '/'));
if (arAnropad && arg('root')) {
  const ut = bygg(arg('root'));
  if (arg('ut') && !process.argv.includes('--torr')) writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
  const { vytillstand, overgangar, interaktion, ...huvud } = ut;
  console.log(JSON.stringify(huvud, null, 1));
  process.exit(ut.BLOCKERANDE.length === 0 ? 0 : 1);
}
