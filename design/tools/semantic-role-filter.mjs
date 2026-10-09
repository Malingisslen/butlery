// F2-R04 · SEMANTISKT ROLLFILTER.
//
// GODKAND METOD 2026-08-13.
//
// NORMATIV REGEL
//   kandidatuniversum  !=  semantisk kandidatbehorighet
//
// Ett varde kan vara medlem i den globala morkpaletten darfor att det faktiskt
// anvands i forfattat morkt lage, och anda vara obehorigt for en viss
// beslutsenhet darfor att dess OBSERVERADE semantiska roll inte bar den
// anvandningen. Palettmedlemskap overfor aldrig behorighet mellan roller.
//
// DET FINNS INGEN REGEL OM LJUSHET HAR. En ljus farg far vara appbakgrund i
// morkt lage — men bara om nagot faktiskt stodjer det, eller om ett uttryckligt
// designforslag med positiv semantisk intention foreslar den. Filtret laser
// observerad roll, aldrig luminans.
//
// KEDJAN, i ordning, utan genvagar:
//   1  GLOBAL_DARK_PALETTE          alla varden i forfattat morkt lage
//   2  SEMANTIC_ROLE_FILTER         observerad rollfamilj maste bara anvandningen
//   3  TECHNICAL_CONSTRAINT_FILTER  kontrast och ovriga matbara krav
//   4  VISUAL_CANDIDATES            det som aterstar att valja mellan
// Varje steg redovisar behallna och bortfallna med skal, och summan maste ga
// ihop i varje steg. Inget varde far tyst forsvinna.

export const ROLLFAMILJ = Object.freeze({
  YTHIERARKI: 'YTHIERARKI',
  PLATSHALLARE: 'PLATSHALLARE',
  FORGRUND: 'FORGRUND',
  RAM: 'RAM',
  OKAND: 'OKAND' });

/** Rollens familj. Harledd ur rollnamnet i den incheckade rollkartan. */
export function familjAvRoll(roll) {
  switch (roll) {
    case 'yta-app': case 'yta-upphojd': case 'yta-kontroll': return ROLLFAMILJ.YTHIERARKI;
    case 'yta-platshallare': return ROLLFAMILJ.PLATSHALLARE;
    case 'text-innehall': case 'text-kontroll':
    case 'ikon-fristaende': case 'ikon-kontroll': return ROLLFAMILJ.FORGRUND;
    case 'ram-app': case 'ram-behallare': case 'ram-kontroll': return ROLLFAMILJ.RAM;
    default: return ROLLFAMILJ.OKAND; } }

/**
 * Observerat rollstod per varde.
 * poster: [{ varde, roll }] — en per observerad MORK deklaration i en artefakt
 * som faktiskt har forfattat morkt lage.
 */
export function rollstod(poster) {
  const m = new Map();
  for (const p of poster) {
    if (!m.has(p.varde)) m.set(p.varde, { varde: p.varde, roller: new Map(), familjer: new Map() });
    const e = m.get(p.varde);
    e.roller.set(p.roll, (e.roller.get(p.roll) || 0) + 1);
    const f = familjAvRoll(p.roll);
    e.familjer.set(f, (e.familjer.get(f) || 0) + 1); }
  return new Map([...m].map(([k, e]) => [k, { varde: e.varde,
    roller: Object.fromEntries(e.roller), familjer: Object.fromEntries(e.familjer) }])); }

/**
 * Semantisk behorighet for EN beslutsenhet.
 *
 * malroll   enhetens semantiska roll, t.ex. 'yta-app'
 * varde     palettvardet som provas
 * stod      rollstod().get(varde) — observerad anvandning, eller undefined
 * opt.positivIntention
 *           ett uttryckligt designforslag som nominerar vardet trots att den
 *           observerade rollen inte bar det. Ger ALDRIG ELIGIBLE — det ger en
 *           ny kandidat som maste avgoras som VISUAL_CHOICE_REQUIRED, utan
 *           evidens.
 */
export function semantiskBehorighet(malroll, varde, stod, opt = {}) {
  const malfamilj = familjAvRoll(malroll);
  if (malfamilj === ROLLFAMILJ.OKAND)
    return { varde, utfall: 'INELIGIBLE', klass: 'OKAND_MALROLL', evidens: 'NONE',
      skal: 'malrollen ' + malroll + ' har ingen kand rollfamilj — faller stangt' };
  if (!stod)
    return { varde, utfall: 'INELIGIBLE', klass: 'INGEN_OBSERVERAD_ANVANDNING', evidens: 'NONE',
      skal: 'vardet har ingen observerad anvandning i forfattat morkt lage' };
  const iMalfamiljen = stod.familjer[malfamilj] || 0;
  const iMalrollen = stod.roller[malroll] || 0;
  const andraFamiljer = Object.entries(stod.familjer).filter(([f]) => f !== malfamilj);
  if (iMalfamiljen > 0)
    return { varde, utfall: 'ELIGIBLE',
      klass: iMalrollen > 0 ? 'OBSERVERAD_I_SAMMA_ROLL' : 'OBSERVERAD_I_SAMMA_ROLLFAMILJ',
      evidens: iMalrollen > 0 ? 'SAME_ROLE_OBSERVED' : 'SAME_FAMILY_OBSERVED',
      observerat: { iMalrollen, iMalfamiljen },
      skal: null };
  if (opt.positivIntention)
    return { varde, utfall: 'NY_KANDIDAT_MED_POSITIV_INTENTION', klass: 'EXPLICIT_DESIGNFORSLAG',
      evidens: 'NONE',
      $regel: 'Maste avgoras som VISUAL_CHOICE_REQUIRED. Den observerade anvandningen ar inget stod och far inte redovisas som det.',
      skal: 'nominerat av ett uttryckligt designforslag: ' + opt.positivIntention };
  return { varde, utfall: 'INELIGIBLE', klass: 'ANNAN_SEMANTISK_ROLL', evidens: 'NONE',
    observerat: Object.fromEntries(andraFamiljer),
    skal: 'observerad anvandning ar ' + andraFamiljer.map(([f, n]) => f + ' x' + n).join(', ') +
      ' — inte ' + malfamilj + '. Palettmedlemskap overfor inte behorighet mellan roller.' }; }

/**
 * Hela kedjan for en beslutsenhet. Summan ska ga ihop i varje steg.
 *
 * palett     [{ varde, ... }]
 * malroll    enhetens roll
 * stod       Map fran rollstod()
 * tekniskt   varde => { ok, skal } eller null om inget matbart krav finns
 * intention  { [varde]: 'motivering' } — uttryckliga designforslag
 */
export function kandidatkedja(palett, malroll, stod, tekniskt = null, intention = {}) {
  const steg1 = palett.map(p => p.varde);
  const sem = steg1.map(v => semantiskBehorighet(malroll, v, stod.get(v),
    intention[v] ? { positivIntention: intention[v] } : {}));
  const behallna2 = sem.filter(r => r.utfall === 'ELIGIBLE').map(r => r.varde);
  const nyaKandidater = sem.filter(r => r.utfall === 'NY_KANDIDAT_MED_POSITIV_INTENTION');
  const bortfall2 = sem.filter(r => r.utfall === 'INELIGIBLE');

  const tek = behallna2.map(v => { const t = tekniskt ? tekniskt(v) : null;
    return { varde: v, provat: !!tekniskt, ok: t ? !!t.ok : true, skal: t ? t.skal : 'inget matbart krav for denna enhet' }; });
  const behallna3 = tek.filter(r => r.ok).map(r => r.varde);
  const bortfall3 = tek.filter(r => !r.ok);

  return {
    GLOBAL_DARK_PALETTE: { antal: steg1.length, varden: steg1 },
    SEMANTIC_ROLE_FILTER: { in: steg1.length, behallna: behallna2, bortfallna: bortfall2,
      nyaKandidaterMedPositivIntention: nyaKandidater,
      summerar: behallna2.length + bortfall2.length + nyaKandidater.length === steg1.length },
    TECHNICAL_CONSTRAINT_FILTER: { in: behallna2.length, behallna: behallna3, bortfallna: bortfall3,
      tillampat: !!tekniskt,
      summerar: behallna3.length + bortfall3.length === behallna2.length },
    VISUAL_CANDIDATES: { antal: behallna3.length, varden: behallna3 },
    $regel: 'Ett varde far aldrig hoppa over SEMANTIC_ROLE_FILTER bara for att det forekommer i forfattat morkt lage.' }; }
