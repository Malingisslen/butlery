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

export const GRUPPNYCKEL = /^[a-z][a-z0-9]*(-[a-z0-9]+){1,}$/;
export const MAXLANGD = 64;

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
  { nyckel: 'thumbLage', slag: 'form', las: x => x.signaler.thumbLage,
    text: 'knoppens lage skiljer' },
  { nyckel: 'barnAntal', slag: 'form', las: x => x.signaler.barnAntal,
    text: 'antal synliga delar skiljer' },
  { nyckel: 'form', slag: 'form', las: x => x.signaler.form,
    text: 'storleken eller formen skiljer' },
];
// Den synliga texten skiljer sig mellan tva rader i samma lista utan att
// tillstandet skiljer sig. Text ar darfor ingen tillstandssignal och far inte
// rakna som icke-fargbaserad skillnad.

const signatur = x => SIGNALER.map(s => s.nyckel + '=' + String(s.las(x))).join('|');

export function jamfor(a, b) {
  const skillnader = [];
  for (const s of SIGNALER) {
    const va = s.las(a), vb = s.las(b);
    if (va === undefined || vb === undefined) continue;
    if (va !== vb) skillnader.push({ nyckel: s.nyckel, slag: s.slag, text: s.text,
      a: String(va), b: String(vb) });
  }
  return skillnader;
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
      par.push({ familj: id, stateA: states[i], stateB: states[j],
        artA: a.art, artB: b.art, namnA: a.namn, namnB: b.namn,
        ickeFargSignaler: skillnader, colorOnly: skillnader.length === 0 });
    }
  }

  const colorOnly = par.filter(p => p.colorOnly);
  return {
    kontroller_med_tillstand_st: medTillstand.length,
    kontroller_i_grupp_st: medTillstand.length - okanda.length,
    pairingUnknown_kontroller_st: okanda.length,
    grupper_st: grupper.size,
    grupper_singelState_st: singelState.length,
    grupper_tvetydiga_st: tvetydiga.length,
    par_st: par.length,
    par_med_ickefargSignal_st: par.length - colorOnly.length,
    colorOnly_st: colorOnly.length,
    par, colorOnly, pairingUnknown: okanda, singelState, tvetydiga,
    // Tacknings-invariant: varje kontroll med tillstand ar antingen i en
    // grupp eller pairingUnknown. Inget far falla mellan.
    invariant_ok: medTillstand.length ===
      ([...grupper.values()].reduce((n, v) => n + v.length, 0) + okanda.length),
  };
}
