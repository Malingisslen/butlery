#!/usr/bin/env node
// BUTLERY · BLOCK 284 · METODPROV.  RV284-01 … RV284-09
//
// Arbetar pa KOPIOR utanfor reporoten. Produkten ror vi aldrig.
// Kor: node tools/role-vocabulary-reconciliation-prov.mjs --root=. --out=<katalog utanfor repot>

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, cpSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const REPO = resolve(arg('root') || '.');
const BYGG = join(REPO, 'tools/role-vocabulary-reconciliation.mjs');
const KALLA = join(REPO, 'fas2/role-vocabulary-reconciliation.json');
const UT = resolve(arg('out') || '');
if (!arg('out')) { console.error('\u2716 ange --out=<katalog utanfor reporoten>'); process.exit(2); }
if (UT.startsWith(REPO + '\\') || UT.startsWith(REPO + '/')) {
  console.error('\u2716 --out maste ligga utanfor reporoten'); process.exit(2); }
if (existsSync(UT)) rmSync(UT, { recursive: true, force: true });
mkdirSync(UT, { recursive: true });

const resultat = [];
const prov = (id, vad, ok, detalj) => {
  resultat.push({ id, vad, godkand: !!ok });
  console.log((ok ? '✔' : '✖') + ' ' + id + '  ' + vad + (detalj ? '\n     ' + detalj : ''));
};
const kor = (root, kalla, detalj) => JSON.parse(execFileSync(process.execPath,
  [BYGG, '--root=' + root, '--kalla=' + kalla, ...(detalj ? ['--detalj=' + detalj] : [])],
  { encoding: 'utf8', maxBuffer: 1 << 26 }));
const korRatt = (root, kalla) => {
  try { execFileSync(process.execPath, [BYGG, '--root=' + root, '--kalla=' + kalla],
    { encoding: 'utf8', stdio: 'pipe', maxBuffer: 1 << 26 }); return null; }
  catch (e) { return String(e.stderr || e.message); }
};
const kallkopia = (namn, mut) => {
  const p = join(UT, namn + '.json');
  const k = JSON.parse(readFileSync(KALLA, 'utf8'));
  mut(k);
  delete k.forvantat;                    // en medveten mutation far inte falla pa sjalvkontrollen
  writeFileSync(p, JSON.stringify(k, null, 1));
  return p;
};
const SKARMFILER = readFileSync(join(REPO, 'tools/screen-files.mjs'), 'utf8')
  .split('export const SCREEN_FILES')[1].split('];')[0]
  .split('\n').map(l => (/'([^']+\.dc\.html)'/.exec(l) || [])[1]).filter(Boolean);
const BEROENDE = [...SKARMFILER, 'tools/screen-files.mjs', 'tools/lint-core.mjs', 'testmatris.md',
  'flows-roles-budget.md', 'fas2/nt-baslinje.json', 'fas2/stateflow-mappning.json',
  'fas2/stateflow-applicability.json', 'tools/stateflow-population.mjs', 'tools/stateflow-applicability.mjs'];
const korpuskopia = namn => {
  const d = join(UT, 'repo-' + namn);
  if (existsSync(d)) rmSync(d, { recursive: true, force: true });
  for (const f of BEROENDE) { const m = join(d, f); mkdirSync(join(m, '..'), { recursive: true }); cpSync(join(REPO, f), m); }
  return d;
};

const BAS = kor(REPO, KALLA);
const BAS_OCC = kor(REPO, KALLA, 'occ');

/* RV284-01 · omkastad filordning -> samma occurrence identities */
{
  const d = korpuskopia('r01');
  const p = join(d, 'tools/screen-files.mjs');
  let t = readFileSync(p, 'utf8');
  const block = t.split('export const SCREEN_FILES')[1].split('];')[0];
  const rader = block.split('\n').filter(l => /\.dc\.html'/.test(l));
  const omkast = rader.slice().reverse().map((l, i, a) =>
    i === a.length - 1 ? l.replace(/,\s*$/, '') : (l.trim().endsWith(',') ? l : l + ','));
  writeFileSync(p, t.replace(block, '\n' + omkast.join('\n') + '\n'));
  const r = kor(d, KALLA);
  prov('RV284-01', 'omkastad filordning ger samma occurrence identities',
    r.OCCURRENCE_IDENTITY_FINGERPRINT === BAS.OCCURRENCE_IDENTITY_FINGERPRINT,
    'identitet ' + r.OCCURRENCE_IDENTITY_FINGERPRINT);
}

/* RV284-02 · omkastad syskonordning -> samma occurrence identities */
{
  const d = korpuskopia('r02');
  const f = join(d, SKARMFILER.find(x => readFileSync(join(REPO, x), 'utf8').includes('data-a11y-role="link"')));
  let t = readFileSync(f, 'utf8');
  const idx = [...t.matchAll(/<div class="sc-item" id="([^"]+)"/g)];
  const a0 = idx[0].index, a1 = idx[1].index, a2 = idx[2].index;
  writeFileSync(f, t.slice(0, a0) + t.slice(a1, a2) + t.slice(a0, a1) + t.slice(a2));
  const r = kor(d, KALLA);
  prov('RV284-02', 'omkastad syskonordning ger samma occurrence identities',
    r.OCCURRENCE_IDENTITY_FINGERPRINT === BAS.OCCURRENCE_IDENTITY_FINGERPRINT,
    'identitet ' + r.OCCURRENCE_IDENTITY_FINGERPRINT);
}

/* RV284-03 · en ny konfliktforekomst -> exakt +1 */
{
  const d = korpuskopia('r03');
  const fil = SKARMFILER[0];
  const p = join(d, fil);
  let t = readFileSync(p, 'utf8');
  const m = /<div class="sc-item" id="([^"]+)"[^>]*>/.exec(t);
  t = t.slice(0, m.index + m[0].length) +
    '<span data-a11y-role="link" data-a11y-name="Provlank for RV284" data-hit="self">Prov</span>' +
    t.slice(m.index + m[0].length);
  writeFileSync(p, t);
  const kp = kallkopia('r03', k => k.forekomster.push({
    OCCURRENCE_ID: 'RV284::' + m[1] + '::provlank-for-rv284', CONTROL_FUNCTION: 'prov',
    OUTCOME: 'SEMANTIC_ROLE_UNRESOLVED', SUPPORTED_ROLE: null, SOURCE: [], EVIDENCE: 'prov',
    DECISION_BASIS: 'prov', CONFIDENCE: 'LAG', KRAVER_BESLUT: null }));
  const r = kor(d, kp);
  prov('RV284-03', 'ny konfliktforekomst ger exakt +1',
    r.TOTAL_ROLE_CONFLICT_OCCURRENCES === BAS.TOTAL_ROLE_CONFLICT_OCCURRENCES + 1,
    BAS.TOTAL_ROLE_CONFLICT_OCCURRENCES + ' -> ' + r.TOTAL_ROLE_CONFLICT_OCCURRENCES);
}

/* RV284-04 · en konfliktforekomst borttagen -> exakt -1
 *
 * Malet ar en av FLERA forekomster av samma roll. Att ta bort den ENDA
 * forekomsten av en roll tar bort rollen ur Block 282:s kontrollpopulation
 * och andrar dess populationsfingeravtryck — da faller read-only-grinden,
 * helt riktigt, och provet skulle mata fel sak. Fjorton lankar finns; en
 * borttagen lamnar tretton, och Block 282 star stilla. */
{
  const d = korpuskopia('r04');
  let borttagen = null;
  for (const fil of SKARMFILER) {
    const p = join(d, fil);
    const t = readFileSync(p, 'utf8');
    const i = t.indexOf('id="authlogga"');
    if (i < 0) continue;
    // Attributordningen varierar i korpusen — namnet star ibland fore rollen.
    // Matcha darfor taggen och prova attributen var for sig.
    const svans = t.slice(i);
    const tagg = [...svans.matchAll(/<a([^>]*)>/g)].find(m =>
      /data-a11y-role="link"/.test(m[1]) && /data-a11y-name="Användarvillkor"/.test(m[1]));
    if (!tagg) continue;
    borttagen = 'authlogga · Användarvillkor';
    writeFileSync(p, t.slice(0, i) + svans.replace(tagg[0], '<a>'));
    break;
  }
  if (!borttagen) throw new Error('RV284-04: hittade ingen lank att ta bort');
  const kp = kallkopia('r04', k => {
    k.forekomster = k.forekomster.filter(x => x.OCCURRENCE_ID !== 'RV284::authlogga::användarvillkor'); });
  const r = kor(d, kp);
  prov('RV284-04', 'borttagen konfliktforekomst ger exakt -1',
    r.TOTAL_ROLE_CONFLICT_OCCURRENCES === BAS.TOTAL_ROLE_CONFLICT_OCCURRENCES - 1,
    '"' + borttagen + '" bort · ' + BAS.TOTAL_ROLE_CONFLICT_OCCURRENCES + ' -> ' + r.TOTAL_ROLE_CONFLICT_OCCURRENCES);
}

/* RV284-05 · andrad current role -> samma identitet, andrad klassificering */
{
  const d = korpuskopia('r05');
  for (const fil of SKARMFILER) {
    const p = join(d, fil);
    const t = readFileSync(p, 'utf8');
    if (!t.includes('data-a11y-name="Driftstatus"')) continue;
    writeFileSync(p, t.replace(/(data-a11y-name="Driftstatus"[^>]*?)data-a11y-role="link"/,
      '$1data-a11y-role="menuitem"').replace(/(data-a11y-role="link"[^>]*?)data-a11y-name="Driftstatus"/,
      'data-a11y-role="menuitem"$1'.replace('data-a11y-role="link"', '') + 'data-a11y-name="Driftstatus"'));
    break;
  }
  // Ett medvetet rollbyte andrar rollcensusen. Kallans deklarerade forvantningar
  // galler den oforandrade korpusen och maste darfor lyftas, annars faller bygget
  // pa sjalvkontrollen i stallet for pa det provet mater.
  // Korpusen sager nu menuitem for den har raden. En rad som BEHALLER sin roll
  // maste ha FINAL_ROLE lika med den roll korpusen bar, sa kallkopian foljer med.
  // Annars provar vi en motsagelse i stallet for identitetens stabilitet.
  const kp = kallkopia('r05', k => {
    const x = k.forekomster.find(y => y.OCCURRENCE_ID === 'RV284::globunderhall::driftstatus');
    if (!x) throw new Error('RV284-05: hittade inte driftstatus i kallan');
    x.FINAL_ROLE = 'menuitem';
  });
  const r = kor(d, kp), occ = kor(d, kp, 'occ');
  const rad = occ.find(x => x.OCCURRENCE_ID === 'RV284::globunderhall::driftstatus');
  prov('RV284-05', 'andrad current role: identitet bestar, klassificering foljer med',
    !!rad && r.OCCURRENCE_IDENTITY_FINGERPRINT === BAS.OCCURRENCE_IDENTITY_FINGERPRINT &&
    r.TOTAL_ROLE_CONFLICT_OCCURRENCES === BAS.TOTAL_ROLE_CONFLICT_OCCURRENCES,
    rad ? 'CURRENT_ROLE ' + rad.CURRENT_ROLE + ' · identitet oforandrad · ingen delete+add' : 'raden forsvann');
}

/* RV284-06 · andrat forslag till supported role -> identitet stabil */
{
  const kp = kallkopia('r06', k => {
    const x = k.forekomster.find(y => y.OCCURRENCE_ID === 'RV284::mfalagg::landskod-sverige-plus-46');
    // En omdirigerad rad maste ha FINAL_ROLE lika med den foreslagna rollen.
    // Provet byter darfor bada — annars provas en motsagelse, inte identiteten.
    x.SUPPORTED_ROLE = 'textbox'; x.FINAL_ROLE = 'textbox'; });
  const r = kor(REPO, kp);
  prov('RV284-06', 'andrat forslag till supported role lamnar identiteten stabil',
    r.OCCURRENCE_IDENTITY_FINGERPRINT === BAS.OCCURRENCE_IDENTITY_FINGERPRINT &&
    r.OCCURRENCE_STATUS_FINGERPRINT !== BAS.OCCURRENCE_STATUS_FINGERPRINT,
    'identitet oforandrad · statusavtryck andrat');
}

/* RV284-07 · status/bedomning ingar inte i persistent identity */
{
  // Hela bedomningen tas bort, inte halva: ett manskligt beslut utan utfall ar
  // en kombination kallmodellen forbjuder, och byggaren avvisar den med ratta.
  const kp = kallkopia('r07', k => k.forekomster.forEach(x => {
    x.OUTCOME = 'SEMANTIC_ROLE_UNRESOLVED'; x.SUPPORTED_ROLE = null; x.SOURCE = [];
    x.CONFIDENCE = 'LAG'; delete x.DECISION; delete x.NEW_ROLE;
    delete x.FINAL_ROLE; }));            // en olost rad far inte bara nagon slutroll
  const r = kor(REPO, kp);
  prov('RV284-07', 'status och bedomning ingar inte i persistent identity',
    r.OCCURRENCE_IDENTITY_FINGERPRINT === BAS.OCCURRENCE_IDENTITY_FINGERPRINT &&
    r.OCCURRENCE_STATUS_FINGERPRINT !== BAS.OCCURRENCE_STATUS_FINGERPRINT,
    'identitet ' + r.OCCURRENCE_IDENTITY_FINGERPRINT + ' (oforandrad)');
}

/* RV284-08 · Block 282 mapping fingerprint oforandrat */
{
  const kp = kallkopia('r08', k => { const x = k.forekomster[0];
    x.OUTCOME = 'SEMANTIC_ROLE_UNRESOLVED'; x.SOURCE = [];
    delete x.DECISION; delete x.NEW_ROLE; delete x.FINAL_ROLE; });
  const b = kor(REPO, kp).BLOCK_282_283_READONLY;
  prov('RV284-08', 'Block 282 mapping fingerprint oforandrat',
    b['282_MAPPING'] === '639a14d6afb84664' && b['282_POPULATION'] === '5ede5a7c9ab3dfef',
    'mapping ' + b['282_MAPPING']);
}

/* RV284-09 · Block 283 applicability identity fingerprint oforandrat */
{
  const b = kor(REPO, KALLA).BLOCK_282_283_READONLY;
  prov('RV284-09', 'Block 283 applicability identity fingerprint oforandrat',
    b['283_IDENTITY'] === '2e7816936df8d602' && b['283_STATUS'] === '48182cf827ccfb6b',
    '283 identitet ' + b['283_IDENTITY'] + ' · status ' + b['283_STATUS']);
}

/* RV284-10 · en kallankrad rad utan slutroll far inte slinka igenom
 *
 * Det var precis det som gick fel: sex rader med utfallet "behaller sin roll"
 * saknade explicit slutroll, och ingenting fallde bygget. */
{
  let mal = null;
  const kp = kallkopia('r10', k => {
    const x = k.forekomster.find(y => y.OUTCOME === 'CURRENT_ROLE_SUPPORTED' &&
      y.DECISION !== 'HUMAN_APPROVED' && y.FINAL_ROLE);
    if (!x) throw new Error('RV284-10: hittade ingen kallankrad rad med slutroll');
    mal = x.OCCURRENCE_ID;
    delete x.FINAL_ROLE;
  });
  const fel = korRatt(REPO, kp);
  prov('RV284-10', 'kallankrad rad utan FINAL_ROLE faller bygget',
    !!fel && /saknar FINAL_ROLE/.test(fel),
    fel ? (fel.split('\n').find(l => /FAIL CLOSED/.test(l)) || '').slice(0, 100)
        : 'byggde utan att klaga pa ' + mal);
}

const g = resultat.filter(r => r.godkand).length;
writeFileSync(join(UT, 'rv284-prov.json'), JSON.stringify(
  { $schema: 'butlery-rv284-prov/1', godkanda: g, av: resultat.length, resultat }, null, 1) + '\n');
console.log('\nRV284-PROV status=' + (g === resultat.length ? 'godkand' : 'UNDERKAND') +
  ' godkanda=' + g + ' av ' + resultat.length);
process.exit(g === resultat.length ? 0 : 1);
