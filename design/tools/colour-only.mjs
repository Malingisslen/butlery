// F2-NT · PARBILDNING FOR USE OF COLOR (WCAG 1.4.1).
//
// Rena funktioner. Ingen DOM, ingen browser, ingen kontrast.
//
// Fragan ar: skiljs tva TILLSTAND av samma komponent enbart av farg?
//
// Tre saker maste halla for att fragan ens ska kunna stallas:
//   1  bada kontrollerna deklarerar SAMMA komponentidentitet
//   2  de har OLIKA tillstandsvarden
//   3  det gar att lasa av vilka icke-fargbaserade signaler som finns
// Faller nagot av dem ar svaret pairingUnknown — aldrig "ingen skillnad".
//
// Kontrastvardet anvands aldrig har. Ett par ar color-only eller inte
// oberoende av hur stark fargskillnaden ar.

// Vilka signaler ar INTE farg? Delade i tva slag, for att rapporten ska kunna
// skiljas at: innehall (finns en bock, en annan glyf, annan text) och form
// (annan storlek, annat lage pa knoppen, annat antal synliga delar).
export const SIGNALER = [
  { nyckel: 'bock', slag: 'innehall', las: x => x.signaler.bock,
    text: 'bock tillkommer eller forsvinner' },
  { nyckel: 'chevron', slag: 'innehall', las: x => x.signaler.chevron,
    text: 'riktningsglyf tillkommer eller forsvinner' },
  { nyckel: 'glyfNamn', slag: 'innehall', las: x => x.signaler.glyfNamn,
    text: 'glyfuppsattningen skiljer' },
  { nyckel: 'text', slag: 'innehall', las: x => x.text,
    text: 'den synliga texten skiljer' },
  { nyckel: 'thumbLage', slag: 'form', las: x => x.signaler.thumbLage,
    text: 'knoppens lage skiljer' },
  { nyckel: 'barnAntal', slag: 'form', las: x => x.signaler.barnAntal,
    text: 'antal synliga delar skiljer' },
  { nyckel: 'form', slag: 'form', las: x => x.signaler.form,
    text: 'storleken eller formen skiljer' },
];

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

// Grupperar pa DEKLARERAD familjidentitet. Kontroller utan deklaration
// hamnar aldrig i nagon familj — de blir pairingUnknown var for sig.
export function parbilda(kontroller) {
  const medTillstand = kontroller.filter(x => x.state);
  const okanda = [], familjer = new Map();
  for (const x of medTillstand) {
    const f = x.familj || { status: 'pairingUnknown', varfor: 'familjidentitet saknas helt i matdatan' };
    if (f.status !== 'deklarerad' || !f.id) {
      okanda.push({ art: x.art, roll: x.roll, namn: x.namn, state: x.state, varfor: f.varfor });
      continue; }
    if (!familjer.has(f.id)) familjer.set(f.id, []);
    familjer.get(f.id).push(x);
  }
  const par = [], utanMotpart = [];
  for (const [id, v] of familjer) {
    const states = [...new Set(v.map(x => x.state))].sort();
    if (states.length < 2) {
      utanMotpart.push({ familj: id, state: states[0], instanser: v.length,
        varfor: 'familjen forekommer bara i ett tillstand i hela sviten — det finns ingen motpart att jamfora med' });
      continue; }
    for (let i = 0; i < states.length; i++) for (let j = i + 1; j < states.length; j++) {
      const a = v.find(x => x.state === states[i]), b = v.find(x => x.state === states[j]);
      const skillnader = jamfor(a, b);
      par.push({ familj: id, stateA: states[i], stateB: states[j],
        artA: a.art, artB: b.art, namnA: a.namn, namnB: b.namn,
        ickeFargSignaler: skillnader, colorOnly: skillnader.length === 0 });
    }
  }
  return {
    kontroller_med_tillstand_st: medTillstand.length,
    familjer_st: familjer.size,
    kontroller_i_familj_st: medTillstand.length - okanda.length,
    pairingUnknown_st: okanda.length,
    familjer_utan_motpart_st: utanMotpart.length,
    par_st: par.length,
    colorOnly_st: par.filter(p => p.colorOnly).length,
    par, colorOnly: par.filter(p => p.colorOnly), pairingUnknown: okanda, utanMotpart,
  };
}
