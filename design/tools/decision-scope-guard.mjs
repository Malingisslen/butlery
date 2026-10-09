// F2 · SORTERINGSNYCKEL MOT FAKTISKT BESLUTSSCOPE.
//
// Belagd felklass: tva olika forekomster kan hamna pa samma sorteringsnyckel
// — roll + ljusvarde + eventuell undergrupp — utan att ha nagot med varandra
// att gora. Nyckeln ar en gruppering, inte en identitet. Om en nyckeltraff
// far rakna som beslutstraff sa lacker mork mappning, tokenidentitet och
// R-04-kredit over till forekomster som aldrig ingick i beslutet.
//
// Skyddet lag tidigare i analyskod och rekonstruerades for hand tre ganger
// (start -> snackbars -> lagatimers). Har ligger det en gang.
//
// Modulen skapar INGEN ny matchningssemantik. Identitetslagret ar och forblir
// malMatchning() i decision-target.mjs. Det som tillkommer ar ett scopelager
// ovanpa det: aven nar hela identiteten stammer maste beslutets FAKTISKA
// scope omfatta just den forekomst som analyseras.

import { malMatchning } from './decision-target.mjs';
import { arAktiv, beslutsIdAv } from './theme-decisions.mjs';

export const NYCKELKONTRAKT = Object.freeze([
  'En sorteringsnyckeltraff far aldrig ensam koppla ihop beslut.',
  'En sorteringsnyckeltraff far aldrig ensam ge mappningsevidens.',
  'En sorteringsnyckeltraff far aldrig ensam ge ett morkt varde.',
  'En sorteringsnyckeltraff far aldrig ensam ge R-04-kredit.',
  'En sorteringsnyckeltraff far aldrig ensam andra tokenidentitet.',
  'En sorteringsnyckeltraff far aldrig ensam utoka scope.',
  'En kandidat far bindas till ett registrerat beslut BARA nar beslutets ' +
    'faktiska scope och identitet omfattar just den forekomst som analyseras.'
]);

// Hur ett beslut avgransar sig. Mest specifik vinner.
export const OMFATTNINGSKLASS = Object.freeze({
  KALLIDENTITET: 'KALLIDENTITET',        // en enda kallrad
  ARTEFAKTLISTA: 'ARTEFAKTLISTA',        // de uppraknade artefakterna
  HISTORISK_KORPUS: 'HISTORISK_KORPUS',  // inget scope deklarerat nagonsin
  OKAND: 'OKAND'                         // scopefalt finns men gar inte att lasa
});

export const TACKNING = Object.freeze({
  TACKT: 'TACKT',
  EJ_TACKT_ANNAN_KALLA: 'EJ_TACKT_ANNAN_KALLA',
  EJ_TACKT_ANNAT_SCOPE: 'EJ_TACKT_ANNAT_SCOPE',
  EJ_TACKT_ANNAN_BESLUTSENHET: 'EJ_TACKT_ANNAN_BESLUTSENHET',
  TVETYDIG: 'TVETYDIG',
  SAKNAD_SCOPEINFORMATION: 'SAKNAD_SCOPEINFORMATION'
});

// Nollutfall. Ett icke-tackt fall far inte lamna nagot varde bakom sig.
const NOLL = Object.freeze({
  kredit: 0, mappningsevidens: false, morktVarde: null,
  tokenidentitet: null, scopeUtokat: false, kopplarBeslut: false
});

// Sorteringsnyckeln. Bara en gruppering — aldrig ett bevis.
export function sorteringsnyckel({ roll, ljusvarde, undergrupp }) {
  return roll + '|' + String(ljusvarde).toLowerCase() +
    (undergrupp ? ' ‖ ' + undergrupp : '');
}
export function nyckelAvBeslut(b) {
  return sorteringsnyckel({ roll: b.roll, ljusvarde: b.ljusvarde,
    undergrupp: b.omfattning === 'SUBGROUP' ? b.semantiskUndergrupp : null });
}

export function beslutsomfattning(beslut) {
  const harKalla = Object.prototype.hasOwnProperty.call(beslut, 'kallidentitet');
  const harLista = Object.prototype.hasOwnProperty.call(beslut, 'berordaArtefakter');
  if (harKalla && typeof beslut.kallidentitet === 'string' && beslut.kallidentitet)
    return { klass: OMFATTNINGSKLASS.KALLIDENTITET, varde: beslut.kallidentitet };
  if (harLista && Array.isArray(beslut.berordaArtefakter) && beslut.berordaArtefakter.length)
    return { klass: OMFATTNINGSKLASS.ARTEFAKTLISTA, varde: beslut.berordaArtefakter.slice() };
  // Falten finns men ar tomma eller fel typ: gar inte att lasa. Fail closed.
  if (harKalla || harLista)
    return { klass: OMFATTNINGSKLASS.OKAND, varde: null };
  // Ingetdera faltet finns. Det ar den dokumenterade historiska klassen:
  // beslut fattade innan scope bokfordes. De avgransas av identitetslagret.
  return { klass: OMFATTNINGSKLASS.HISTORISK_KORPUS, varde: null };
}

// Tacker DETTA beslut DENNA forekomst? Identiteten provas inte har.
// forekomst: { artefakt, kallidentitet }
export function tackerForekomst(beslut, forekomst) {
  const o = beslutsomfattning(beslut);
  if (o.klass === OMFATTNINGSKLASS.OKAND)
    return { tackt: false, tackning: TACKNING.SAKNAD_SCOPEINFORMATION, omfattning: o,
      skal: 'beslutets scopefalt finns men gar inte att lasa' };
  if (o.klass === OMFATTNINGSKLASS.KALLIDENTITET) {
    if (!forekomst.kallidentitet)
      return { tackt: false, tackning: TACKNING.SAKNAD_SCOPEINFORMATION, omfattning: o,
        skal: 'beslutet ar scopat till en enda kallrad men forekomsten saknar kallidentitet' };
    return o.varde === forekomst.kallidentitet
      ? { tackt: true, tackning: TACKNING.TACKT, omfattning: o,
          skal: 'forekomsten ar exakt den kallrad beslutet ar scopat till' }
      : { tackt: false, tackning: TACKNING.EJ_TACKT_ANNAN_KALLA, omfattning: o,
          skal: 'beslutet ar scopat till kallraden ' + o.varde +
            ' — forekomsten ' + forekomst.kallidentitet + ' ar en annan kallrad' };
  }
  if (o.klass === OMFATTNINGSKLASS.ARTEFAKTLISTA) {
    if (!forekomst.artefakt)
      return { tackt: false, tackning: TACKNING.SAKNAD_SCOPEINFORMATION, omfattning: o,
        skal: 'beslutet ar scopat till en artefaktlista men forekomsten saknar artefakt' };
    return o.varde.includes(forekomst.artefakt)
      ? { tackt: true, tackning: TACKNING.TACKT, omfattning: o,
          skal: 'forekomstens artefakt ingar i beslutets artefaktlista' }
      : { tackt: false, tackning: TACKNING.EJ_TACKT_ANNAT_SCOPE, omfattning: o,
          skal: 'beslutet omfattar ' + o.varde.join(', ') +
            ' — forekomsten ligger i ' + forekomst.artefakt };
  }
  return { tackt: true, tackning: TACKNING.TACKT, omfattning: o,
    skal: 'historiskt beslut utan deklarerat scope; avgransas av identitetslagret' };
}

// Huvudingang. Identitetslager (malMatchning) och darefter scopelager.
// forekomst: { kandidatId, roll, undergrupp, ljusvarde, artefakt, kallidentitet }
export function beslutstackning(register, forekomst) {
  const m = malMatchning(register, forekomst);
  if (!m.ok) return { ...NOLL, ok: false,
    tackning: /flera/.test(m.skal) ? TACKNING.TVETYDIG : TACKNING.EJ_TACKT_ANNAN_BESLUTSENHET,
    beslut: null, skal: m.skal };
  const t = tackerForekomst(m.beslut, forekomst);
  if (!t.tackt) return { ...NOLL, ok: false, tackning: t.tackning, beslut: null,
    beslutsIdSomAvvisades: beslutsIdAv(m.beslut), omfattning: t.omfattning, skal: t.skal };
  return { ok: true, tackning: TACKNING.TACKT, beslut: m.beslut,
    omfattning: t.omfattning, skal: t.skal,
    kredit: 1, mappningsevidens: true, morktVarde: m.beslut.morkvarde,
    tokenidentitet: m.beslut.tokenNamn || null, scopeUtokat: false, kopplarBeslut: true };
}

// Diagnostiken: vilka registerposter delar sorteringsnyckel med forekomsten,
// och vad blir utfallet nar scope- och identitetslagret provas?
export function nyckelkollision(register, forekomst) {
  const nyckel = sorteringsnyckel(forekomst);
  const traffar = register.beslut.filter(arAktiv).filter(b => nyckelAvBeslut(b) === nyckel);
  const t = beslutstackning(register, forekomst);
  return { nyckel, nyckeltraffar: traffar.map(b => ({
      beslutsId: beslutsIdAv(b), tokenNamn: b.tokenNamn || null,
      omfattning: beslutsomfattning(b),
      tackerForekomsten: tackerForekomst(b, forekomst).tackt })),
    antalNyckeltraffar: traffar.length,
    utfall: t.ok ? 'TACKT' : 'NYCKELTRAFF_UTAN_TACKNING',
    ...(t.ok ? {} : NOLL), tackning: t.tackning, skal: t.skal,
    $regel: NYCKELKONTRAKT[6] };
}
