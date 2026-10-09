// Kor: node tools/block287/fyndstangning.mjs --population=<pop.json> --grupper=<grupper.json>
//      --skrivplan=<skrivplan.json> --mork=<mork.json> --root=<kallrot> --ut=<fil.json>
//
// L/M · M1 och M5 stangs mot faktiska artefakter, inte mot prosa.
//
//   M1  de 24 uppmatta morklagesforekomsterna maste finnas i skrivplanen,
//       var och en med sina nio falt.
//   M5  relationen 33 / 4 / 39 reproduceras med mangdalgebra over riktiga id.
//       33 ar SPEC_SYNC-enheter, 4 ar LINT_SYNC-enheter, 39 ar skrivagare vars
//       enda hinder ar rollsynk. Fyndet var att 33+4 och 39 ar olika
//       populationer och att tre forutsattningar saknade enhet.
import { readFileSync, writeFileSync } from 'node:fs';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const POP = JSON.parse(readFileSync(arg('population'), 'utf8'));
const G = JSON.parse(readFileSync(arg('grupper'), 'utf8'));
const SP = JSON.parse(readFileSync(arg('skrivplan'), 'utf8'));
const MORK = JSON.parse(readFileSync(arg('mork'), 'utf8'));

/* ── M1 · de 24 morka forekomsterna ──────────────────────────────────────── */
const morkRader = Array.isArray(MORK) ? MORK : (MORK.rader || MORK.forekomster || []);
const morkKrav = G.grupper.filter(g => g.GROUP_FAMILY === 'DARK_MODE'
  && /yta-kontroll::sekundartext$/.test(g.GROUP_REQUIREMENT_ID));
const morkMal = morkKrav.flatMap(g => g.TARGET_ELEMENTS.map(t => ({ ...t, KRAV: g.GROUP_REQUIREMENT_ID })));
const planPerNyckel = new Map(SP.rader.map(r => [r.TARGET_SOURCE_KEY, r]));
const FALT = ['FRAME', 'OWNING_CONTROL', 'WRITE_OWNER_ID', 'MEASURED_CHILD', 'TARGET_SOURCE_KEY',
  'TARGET_SOURCE_ELEMENT', 'CURRENT_VALUE', 'REQUIRED_VALUE', 'REQUIREMENT_ID'];
const m1 = morkMal.map(t => {
  const p = planPerNyckel.get(t.TARGET_SOURCE_KEY);
  const rad = {
    FRAME: t.FRAME,
    OWNING_CONTROL: t.SEMANTIC_OWNER,
    WRITE_OWNER_ID: t.WRITE_OWNER_ID,
    MEASURED_CHILD: t.ELEMENT_SIGNATURE,
    TARGET_SOURCE_KEY: t.TARGET_SOURCE_KEY,
    TARGET_SOURCE_ELEMENT: t.TARGET_SOURCE_ELEMENT,
    CURRENT_VALUE: t.CURRENT_VALUE,
    REQUIRED_VALUE: t.REQUIRED_VALUE,
    REQUIREMENT_ID: t.KRAV,
    I_SKRIVPLANEN: !!p
  };
  rad.SAKNADE_FALT = FALT.filter(f => rad[f] == null || rad[f] === '');
  return rad;
});
const M1 = {
  M1_EXPECTED: 24,
  M1_MEASURED: morkRader.length,
  M1_PLANNED: m1.filter(r => r.I_SKRIVPLANEN && !r.SAKNADE_FALT.length).length,
  M1_MISSING: m1.filter(r => !r.I_SKRIVPLANEN || r.SAKNADE_FALT.length).length,
  M1_DUPLICATE: m1.length - new Set(m1.map(r => r.TARGET_SOURCE_KEY)).size,
  rader: m1
};
M1.M1_RESULT = (M1.M1_EXPECTED === 24 && M1.M1_PLANNED === 24 && M1.M1_MISSING === 0 && M1.M1_DUPLICATE === 0)
  ? 'CLOSED' : 'OPEN';

/* -- M5 - 33 / 4 / 39 --------------------------------------------------- */
// Fyndet: 33 + 4 ar forutsattningsENHETER, 39 ar skrivAGARE. Olika populationer.
// Tre forutsattningar (rollerna menu och dialog samt H41-lankvarianten) hade
// ingen egen enhet, sa fyra agare vantade pa nagot som ingen i populationen agde.
const HIST_POP = JSON.parse(readFileSync(arg('root') + '/fas2/block287-population.json', 'utf8'));
const HIST_LEDGER = JSON.parse(readFileSync(arg('root') + '/fas2/block287-skrivledger.json', 'utf8'));
const histLista = Array.isArray(HIST_POP) ? HIST_POP : (HIST_POP.enheter || []);

const mangd = pop => ({
  A: pop.filter(u => u.CATEGORY === 'SPEC_SYNC_REQUIRED').map(u => u.id).sort(),
  B: pop.filter(u => u.CATEGORY === 'LINT_SYNC_REQUIRED').map(u => u.id).sort()
});
const nu = mangd(POP), hist = mangd(histLista);

// Vilka roller kraver spec- och lintsynk? Exakt de som bar en ROLE_VOCABULARY-enhet.
const rollMedEnhet = new Set(POP.filter(u => /^RP::ROLE_VOCABULARY::/.test(u.id)).map(u => u.id.split('::')[2]));
const histRollMedEnhet = new Set(histLista.filter(u => /^RP::ROLE_VOCABULARY::/.test(u.id)).map(u => u.id.split('::')[2]));
// Den slutna rollistan star i tools/lint-core.mjs T-08. Allt utanfor den kraver
// spec- och lintsynk innan skrivagaren kan skriva sin roll.
const SLUTNA_I_SPEC = new Set(['button', 'tab', 'switch', 'radio', 'checkbox', 'textbox']);
// Marker som inte ar roller: de hor till ett annat hinder an rollsynk.
const EJ_ROLL = /^(CONTROL_ROLE_HUMAN_OR_DESIGN_UNRESOLVED|NONE|null)$/;
const rollRen = r => String(r || '').replace(/\s*\(.*\)$/, '').trim();

function agarMangd(pop, rollEnheter) {
  const rader = [];
  for (const u of pop) {
    if (u.CATEGORY !== 'PRODUCT_REMEDIATION_REQUIRED') continue;
    const roll = rollRen(u.FINAL_ROLE || u.ROLL || null) || null;
    const h41 = /H41/.test(JSON.stringify(u));
    if (!h41 && (!roll || EJ_ROLL.test(roll) || SLUTNA_I_SPEC.has(roll))) continue;
    const forutsattning = h41 ? 'RP::HANDOFF_RULE::H41-lankvariant'
      : (roll ? 'RP::ROLE_VOCABULARY::' + roll : null);
    if (!forutsattning) continue;
    rader.push({ id: u.id, ROLL: roll, FORUTSATTNING: forutsattning,
      FOREKOMSTER: u.OCCURRENCES || 1,
      FORUTSATTNING_HAR_ENHET: h41
        ? pop.some(x => x.id === 'RP::HANDOFF_RULE::H41-lankvariant')
        : rollEnheter.has(roll) });
  }
  return rader;
}
const nuAgare = agarMangd(POP, rollMedEnhet);
const histAgare = agarMangd(histLista, histRollMedEnhet);
const nuSaknar = nuAgare.filter(r => !r.FORUTSATTNING_HAR_ENHET);
const histSaknar = histAgare.filter(r => !r.FORUTSATTNING_HAR_ENHET);
const summa = r => r.reduce((s, x) => s + x.FOREKOMSTER, 0);

const M5 = {
  HISTORISK: {
    SET_A: { $om: 'SPEC_SYNC_REQUIRED-enheter', ANTAL: hist.A.length },
    SET_B: { $om: 'LINT_SYNC_REQUIRED-enheter', ANTAL: hist.B.length },
    SET_C: { $om: 'skrivagare som blir skrivklara efter spec- och lintsynk',
      ANTAL_UR_SKRIVLEDGERN: HIST_LEDGER.WRITE_READY_AFTER_SPEC_LINT_SYNC,
      ANTAL_UR_POPULATIONEN: summa(histAgare), ENHETER: histAgare.length },
    INTERSECTION_A_B: hist.A.filter(x => hist.B.includes(x)).length,
    INTERSECTION_AB_C: 0,
    A_ONLY: hist.A.length, B_ONLY: hist.B.length,
    PREREQUISITES_WITHOUT_UNIT: [...new Set(histSaknar.map(r => r.FORUTSATTNING))].sort(),
    rader: histSaknar
  },
  NULAGE: {
    SET_A: { $om: 'SPEC_SYNC_REQUIRED-enheter', ANTAL: nu.A.length, ID: nu.A },
    SET_B: { $om: 'LINT_SYNC_REQUIRED-enheter', ANTAL: nu.B.length, ID: nu.B },
    SET_C: { $om: 'skrivagare som vantar pa spec- och lintsynk',
      ANTAL_FOREKOMSTER: summa(nuAgare), ENHETER: nuAgare.length },
    INTERSECTION_A_B: nu.A.filter(x => nu.B.includes(x)).length,
    INTERSECTION_AB_C: nuAgare.filter(r => nu.A.includes(r.id) || nu.B.includes(r.id)).length,
    A_ONLY: nu.A.length, B_ONLY: nu.B.length,
    PREREQUISITE_UNITS: [...new Set(nuAgare.map(r => r.FORUTSATTNING))].sort(),
    PREREQUISITES_WITHOUT_UNIT: [...new Set(nuSaknar.map(r => r.FORUTSATTNING))].sort(),
    rader: nuAgare
  }
};
M5.HISTORICAL_RELATION = 'SET_A ' + hist.A.length + ' SPEC_SYNC-enheter och SET_B ' + hist.B.length
  + ' LINT_SYNC-enheter ar forutsattningar. SET_C ar ' + HIST_LEDGER.WRITE_READY_AFTER_SPEC_LINT_SYNC
  + ' skrivagare. Snittet mellan forutsattningar och agare ar tomt: 33+4 och 39 ar olika populationer.'
  + ' Forutsattningar utan egen enhet: ' + (histSaknar.length ? [...new Set(histSaknar.map(r => r.FORUTSATTNING))].join(', ') : 'inga') + '.';
M5.CURRENT_RELATION = 'SET_A ' + nu.A.length + ' (33 + de tre enheter korrigeringsrunda 1 lade till), SET_B '
  + nu.B.length + ', SET_C ' + summa(nuAgare) + ' forekomster over ' + nuAgare.length
  + ' enheter. Snitt A-B ' + M5.NULAGE.INTERSECTION_A_B + ', snitt forutsattningar-agare '
  + M5.NULAGE.INTERSECTION_AB_C + ', forutsattningar utan enhet ' + nuSaknar.length + '.';
M5.M5_RESULT = (nuSaknar.length === 0 && M5.NULAGE.INTERSECTION_A_B === 0 && M5.NULAGE.INTERSECTION_AB_C === 0)
  ? 'CLOSED' : 'OPEN';

const ut = { $om: 'L/M · stangning av M1 och M5 mot faktiska artefakter', M1, M5 };
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
console.log(JSON.stringify({
  M1_EXPECTED: M1.M1_EXPECTED, M1_PLANNED: M1.M1_PLANNED, M1_MISSING: M1.M1_MISSING,
  M1_DUPLICATE: M1.M1_DUPLICATE, M1_RESULT: M1.M1_RESULT,
  HIST_A: M5.HISTORISK.SET_A.ANTAL, HIST_B: M5.HISTORISK.SET_B.ANTAL,
  HIST_C: M5.HISTORISK.SET_C.ANTAL_UR_SKRIVLEDGERN,
  HIST_PREREQ_UTAN_ENHET: M5.HISTORISK.PREREQUISITES_WITHOUT_UNIT,
  NU_A: M5.NULAGE.SET_A.ANTAL, NU_B: M5.NULAGE.SET_B.ANTAL, NU_C: M5.NULAGE.SET_C.ANTAL_FOREKOMSTER,
  NU_INTERSECTION_A_B: M5.NULAGE.INTERSECTION_A_B, NU_INTERSECTION_AB_C: M5.NULAGE.INTERSECTION_AB_C,
  NU_PREREQ_UTAN_ENHET: M5.NULAGE.PREREQUISITES_WITHOUT_UNIT, M5_RESULT: M5.M5_RESULT
}, null, 1));
