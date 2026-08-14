// F2-NT · PARBILDNING FOR ANVANDNING AV FARG (WCAG 1.4.1).
//
// Rena funktioner. Ingen DOM, ingen browser, ingen kontrast.
//
// Fragan ar: skiljs tva TILLSTAND av samma konceptuella kontroll enbart av
// farg?
//
// IDENTITETEN AR AUTHORED. Nyckeln ar data-state-group pa kontrollen sjalv.
//
// data-component anvands INTE och far aldrig anvandas som reservidentitet.
// Den beskriver komponenttyp, inte kontroll: den kopplade i en tidigare
// version ihop ett 34x20-reglage i skafferibas med en 372x48-rad i
// behnotiser eftersom bada var markta "toggle". En komponenttyp ar inte en
// identitet.
//
// Otillatna identiteter, alla for att de parar ihop saker som RAKAR likna
// varandra: accessible name, nth-child, geometri, DOM-position, textmatchning
// och komponenttyp.
//
// Tre saker maste halla for att fragan ska kunna stallas:
//   1  bada kontrollerna deklarerar SAMMA data-state-group
//   2  gruppen forekommer i minst TVA olika data-a11y-state
//   3  varje tillstand har en ENTYDIG representant
// Faller nagot av dem ar svaret pairingUnknown eller single-state — aldrig
// "ingen skillnad".
//
// Kontrastvardet anvands aldrig har.

import { ANDEL_TOLERANS } from './box-graphics.mjs';

export const GRUPPNYCKEL = /^[a-z][a-z0-9]*(-[a-z0-9]+){1,}$/;
export const MAXLANGD = 64;

/* ── KNOPPENS LAGE · IMPLEMENTATIONSOBEROENDE ──────────────────────────────
 *
 * Fragan ar VAR knoppen faktiskt star i sparet, inte HUR nagon rakade skriva
 * det i CSS. justify-content, left/right och transform ar tre satt att uttrycka
 * samma sak; den forra modellen laste bara det forsta och var darfor blind for
 * de andra tva. Ett reglage vars knopp bevisligen flyttar sig klassades som
 * color-only. Har lases i stallet de renderade boxarna.
 *
 * Lagesmattet ar andelen av knoppens TILLGANGLIGA RESA, per axel:
 *
 *   n = (knoppens mitt − sparets mitt) / ((sparets matt − knoppens matt) / 2)
 *
 * n = −1 lang vanster, 0 mitten, +1 lang hoger. Kvoten ar dimensionslos och
 * darmed oberoende av sparets storlek, knoppens storlek och layoutmekanism.
 *
 * Toleransen ar ANDEL_TOLERANS ur box-graphics — samma andelstolerans som
 * redan anvands nar uppmatt geometri jamfors i verktygskedjan. Inget nytt
 * designtroskelvarde infors.
 *
 * BADA axlarna klassificeras. Da behover ingen axel valjas, och ett lodratt
 * reglage fungerar utan sarfall.
 *
 * FAIL CLOSED. Kan lagets inte bestammas blir svaret OKAND, och OKAND far
 * aldrig rakna som en skillnad — se jamfor().
 */
export const LAGE_OKANT = 'okant';

export function knoppLage(g) {
  if (!g) return { klass: LAGE_OKANT, varfor: 'ingen renderad geometri for spar och knopp' };
  const s = g.spar, k = g.knopp;
  if (!s || !k) return { klass: LAGE_OKANT, varfor: 'spar eller knopp saknas i matningen' };
  for (const [n, v] of [['sparets bredd', s.w], ['sparets hojd', s.h],
    ['knoppens bredd', k.w], ['knoppens hojd', k.h]])
    if (!(typeof v === 'number' && isFinite(v) && v > 0))
      return { klass: LAGE_OKANT, varfor: n + ' ar inte ett stabilt matt' };
  const resaX = (s.w - k.w) / 2, resaY = (s.h - k.h) / 2;
  // Ryms knoppen inte i sparet ar det inte ett spar med en knopp i.
  if (resaX < -ANDEL_TOLERANS || resaY < -ANDEL_TOLERANS)
    return { klass: LAGE_OKANT, varfor: 'knoppen ryms inte i sparet — agarskapet haller inte' };
  // Ingen resa pa en axel: knoppen KAN inte flytta sig dar. Det ar ett avgjort
  // svar, inte ett okant. Bada axlarna utan resa ger ett reglage som inte kan
  // bara nagon lagessignal alls — ocksa avgjort, och det ska da falla igenom
  // till color-only i stallet for att gomma sig som okant.
  const nX = resaX > 0 ? ((k.x + k.w / 2) - (s.x + s.w / 2)) / resaX : 0;
  const nY = resaY > 0 ? ((k.y + k.h / 2) - (s.y + s.h / 2)) / resaY : 0;
  if (Math.abs(nX) > 1 + ANDEL_TOLERANS || Math.abs(nY) > 1 + ANDEL_TOLERANS)
    return { klass: LAGE_OKANT, varfor: 'knoppens mitt hamnar utanfor sparets resa' };
  const b = (n, neg, mid, pos) => n < -ANDEL_TOLERANS ? neg : n > ANDEL_TOLERANS ? pos : mid;
  return { klass: b(nX, 'vanster', 'mitten', 'hoger') + '|' + b(nY, 'over', 'mitten', 'under'),
    nX: +nX.toFixed(3), nY: +nY.toFixed(3),
    varfor: 'uppmatt andel av knoppens tillgangliga resa i sparet' };
}

export function parseGrupp(varde) {
  if (varde === null || varde === undefined) return { form: 'saknas', id: null,
    varfor: 'ingen data-state-group pa kontrollen' };
  const s = String(varde);
  if (!s.trim()) return { form: 'ogiltig', id: null, varfor: 'data-state-group ar tom' };
  if (s.length > MAXLANGD) return { form: 'ogiltig', id: null,
    varfor: 'data-state-group ar langre an ' + MAXLANGD + ' tecken' };
  if (!GRUPPNYCKEL.test(s)) return { form: 'ogiltig', id: null,
    varfor: 'data-state-group "' + s + '" foljer inte formen gemener och bindestreck med minst tva led' };
  return { form: 'giltig', id: s, varfor: 'authored data-state-group' };
}

// Vilka signaler ar INTE farg? Delade i tva slag sa att rapporten kan skilja
// pa dem: innehall (bock, glyf, text) och form (storlek, lage, antal delar).
export const SIGNALER = [
  { nyckel: 'bock', slag: 'innehall', las: x => x.signaler.bock,
    text: 'bock tillkommer eller forsvinner' },
  { nyckel: 'chevron', slag: 'innehall', las: x => x.signaler.chevron,
    text: 'riktningsglyf tillkommer eller forsvinner' },
  { nyckel: 'glyfNamn', slag: 'innehall', las: x => x.signaler.glyfNamn,
    text: 'glyfuppsattningen skiljer' },
  { nyckel: 'avgransning', slag: 'form', las: x => x.signaler.avgransning,
    text: 'ihalig ram mot massiv yta' },
  { nyckel: 'thumbLage', slag: 'form',
    las: x => x.roll === 'switch' ? knoppLage(x.signaler.knoppGeometri).klass : undefined,
    text: 'knoppens lage skiljer' },
  { nyckel: 'barnAntal', slag: 'form', las: x => x.signaler.barnAntal,
    text: 'antal synliga delar skiljer' },
  { nyckel: 'form', slag: 'form', las: x => x.signaler.form,
    text: 'storleken eller formen skiljer' },
];
// Den synliga texten skiljer sig mellan tva rader i samma lista utan att
// tillstandet skiljer sig. Text ar darfor ingen tillstandssignal och far inte
// rakna som icke-fargbaserad skillnad.

// Signaturen svarar pa EN fraga: avbildar de har instanserna samma tillstand?
// Den raa pixelstorleken gor inte det. Tva obockade rader i samma lista ar
// olika breda for att etiketterna ar olika langa, och det sager ingenting om
// tillstandet. Storleken ar kvar som PARSIGNAL — den skiljer tillstand fran
// tillstand — men ingar inte i representantens signatur.
export const SIGNATURSIGNALER = SIGNALER.filter(s => s.nyckel !== 'form');
const signatur = x => SIGNATURSIGNALER.map(s => s.nyckel + '=' + String(s.las(x))).join('|');

// OKAND FAR ALDRIG BLI PASS. Star en signal pa okant for nagot av tillstanden
// gar det inte att saga att den skiljer dem at — och da far den inte heller
// rakna som den icke-fargbaserade skillnad som friar paret. Den bokfors i
// stallet separat, och paret hamnar i klassen OKAND i stallet for i vare sig
// godkand eller color-only.
export function jamfor(a, b) {
  const skillnader = [], okanda = [];
  for (const s of SIGNALER) {
    const va = s.las(a), vb = s.las(b);
    if (va === undefined || vb === undefined) continue;
    if (va === LAGE_OKANT || vb === LAGE_OKANT) {
      okanda.push({ nyckel: s.nyckel, slag: s.slag, text: s.text,
        a: String(va), b: String(vb),
        varfor: [a, b].map(x => knoppLage(x.signaler.knoppGeometri).varfor).join(' / ') });
      continue; }
    if (va !== vb) skillnader.push({ nyckel: s.nyckel, slag: s.slag, text: s.text,
      a: String(va), b: String(vb) });
  }
  skillnader.okanda = okanda;
  return skillnader;
}

export const PARKLASS = Object.freeze({
  ICKEFARG: 'NON_COLOR_STATE_DIFFERENCE',
  FARGENBART: 'COLOR_ONLY',
  OKAND: 'UNKNOWN' });

export function parklass(skillnader) {
  if (skillnader.length) return PARKLASS.ICKEFARG;
  if (skillnader.okanda && skillnader.okanda.length) return PARKLASS.OKAND;
  return PARKLASS.FARGENBART;
}

export function parbilda(kontroller) {
  const medTillstand = kontroller.filter(x => x.state);
  const okanda = [], grupper = new Map();
  for (const x of medTillstand) {
    const g = parseGrupp(x.stateGroup === undefined ? null : x.stateGroup);
    if (g.form !== 'giltig') {
      okanda.push({ art: x.art, roll: x.roll, namn: x.namn, state: x.state,
        stateGroup: x.stateGroup || null, varfor: g.varfor });
      continue; }
    if (!grupper.has(g.id)) grupper.set(g.id, []);
    grupper.get(g.id).push(x);
  }

  const par = [], singelState = [], tvetydiga = [];
  for (const [id, v] of grupper) {
    // En representant per tillstand. Flera instanser i samma tillstand ar
    // normalt — en lista har flera obockade rader — men de maste se LIKADANA
    // ut. Skiljer de sig gar det inte att saga vad tillstandet ser ut som.
    const perState = new Map();
    for (const x of v) { if (!perState.has(x.state)) perState.set(x.state, []); perState.get(x.state).push(x); }
    const representanter = new Map(); let brutet = false;
    for (const [st, lista] of perState) {
      const sig = new Set(lista.map(signatur));
      if (sig.size > 1) {
        tvetydiga.push({ familj: id, state: st, instanser: lista.length,
          artefakter: [...new Set(lista.map(x => x.art))],
          varfor: 'gruppen har ' + lista.length + ' instanser i tillstandet "' + st +
            '" som ser olika ut — vilken som representerar tillstandet gar inte att avgora' });
        brutet = true; continue; }
      representanter.set(st, lista[0]);
    }
    if (brutet) continue;
    const states = [...representanter.keys()].sort();
    if (states.length < 2) {
      singelState.push({ familj: id, state: states[0], instanser: v.length,
        artefakter: [...new Set(v.map(x => x.art))],
        varfor: 'gruppen forekommer bara i tillstandet "' + states[0] +
          '" i hela sviten — det finns ingen motpart att jamfora med' });
      continue; }
    for (let i = 0; i < states.length; i++) for (let j = i + 1; j < states.length; j++) {
      const a = representanter.get(states[i]), b = representanter.get(states[j]);
      const skillnader = jamfor(a, b);
      const klass = parklass(skillnader);
      par.push({ familj: id, stateA: states[i], stateB: states[j],
        artA: a.art, artB: b.art, namnA: a.namn, namnB: b.namn,
        ickeFargSignaler: [...skillnader], okandaSignaler: skillnader.okanda || [],
        klassificering: klass,
        // colorOnly ar RESERVERAT for den avgjorda faran. Ett par vars
        // lagessignal ar okant ar inte bevisat fargenbart och far darfor inte
        // bokforas som fynd — men det far heller aldrig bokforas som godkant.
        colorOnly: klass === PARKLASS.FARGENBART,
        lage: { a: knoppLage(a.signaler.knoppGeometri), b: knoppLage(b.signaler.knoppGeometri) } });
    }
  }

  const colorOnly = par.filter(p => p.colorOnly);
  const okandaPar = par.filter(p => p.klassificering === PARKLASS.OKAND);
  return {
    kontroller_med_tillstand_st: medTillstand.length,
    kontroller_i_grupp_st: medTillstand.length - okanda.length,
    pairingUnknown_kontroller_st: okanda.length,
    grupper_st: grupper.size,
    grupper_singelState_st: singelState.length,
    grupper_tvetydiga_st: tvetydiga.length,
    par_st: par.length,
    par_med_ickefargSignal_st: par.filter(p => p.klassificering === PARKLASS.ICKEFARG).length,
    par_okantLage_st: okandaPar.length,
    colorOnly_st: colorOnly.length,
    par, colorOnly, okandaPar, pairingUnknown: okanda, singelState, tvetydiga,
    // Parinvariant: varje par ar exakt en av de tre klasserna.
    parinvariant_ok: par.length === par.filter(p => p.klassificering === PARKLASS.ICKEFARG).length +
      okandaPar.length + colorOnly.length,
    // Tacknings-invariant: varje kontroll med tillstand ar antingen i en
    // grupp eller pairingUnknown. Inget far falla mellan.
    invariant_ok: medTillstand.length ===
      ([...grupper.values()].reduce((n, v) => n + v.length, 0) + okanda.length),
  };
}
