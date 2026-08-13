// F2-R04 · TVATILLSTANDS-PREVIEW FOR ANIMERADE BESLUTSOBJEKT.
//
// GODKAND METOD 2026-08-13. Far anvandas nar
//   1 ett animerat visuellt objekt innehaller flera beslutsrelevanta delar
//   2 ingen faktisk bildruta visar samtliga delar samtidigt
//   3 tva eller fler FAKTISKA deterministiska tillstand tillsammans kan
//     representera hela objektet
//   4 inget syntetiskt tillstand som aldrig intraffar behover konstrueras
//
// Metoden ger 0 R-04 coverage credit och 0 conformance credit i sig. Den ger
// enbart manskligt designunderlag.
//
// JAMFORELSEENHETEN AR PARET. En ensam bild ar aldrig en illustrationspreview.
// paketera() vagrar returnera ett paket dar ett tillstand saknas.

import { FRYS, ATERSTALL_ANIMATION } from './animation-freeze.mjs';

export const TILLSTAND = Object.freeze({ TACKT: 'STATE_COVERED', AVTACKT: 'STATE_REVEALED' });

/**
 * Ett tillstand ar giltigt bara om frysningen holl OCH exakt de vantade
 * delarna ar representerade. Delar som animationens semantik doljer ska vara
 * frihanvarande — men de maste vara utpekade i forvag, aldrig upptackta i
 * efterhand.
 */
export function granskaTillstand(fryssvar, vantadeSynliga, vantadeDolda, troskel = 0.01) {
  if (!fryssvar || !fryssvar.ok) return { ok: false,
    skal: fryssvar ? fryssvar.skal : 'inget svar fran frysningen' };
  const av = new Map(fryssvar.delar.map(d => [d.ordinal, d.opacitet]));
  const saknade = vantadeSynliga.filter(o => !(av.get(o) > troskel));
  const ovantade = vantadeDolda.filter(o => av.get(o) > troskel);
  const ej = [...vantadeSynliga, ...vantadeDolda].filter(o => !av.has(o));
  const ok = !saknade.length && !ovantade.length && !ej.length;
  return { ok, saknade, ovantadeSynliga: ovantade, ejUppmatta: ej,
    frystTid: fryssvar.begardTid, faktiskTid: fryssvar.faktiskTid,
    skal: ok ? null : saknade.length + ' vantade delar saknas, ' + ovantade.length +
      ' delar syns som skulle vara dolda, ' + ej.length + ' ej uppmatta' };
}

/**
 * Paketerar ett bundlealternativ. Fail closed: bada tillstanden kravs, och
 * bada maste vara granskade och godkanda.
 */
export function paketera(bunt, tillstand) {
  const namn = Object.values(TILLSTAND);
  const saknade = namn.filter(n => !tillstand[n]);
  if (saknade.length) return { ok: false, bunt: bunt.id,
    skal: 'ofullstandigt par — saknar ' + saknade.join(', ') +
      '. En ensam bild far aldrig beskrivas som illustrationspreview.' };
  const fel = namn.filter(n => !tillstand[n].granskning.ok);
  if (fel.length) return { ok: false, bunt: bunt.id,
    skal: fel.map(n => n + ': ' + tillstand[n].granskning.skal).join(' · ') };
  return { ok: true, bunt: bunt.id, namn: bunt.namn,
    par: namn.map(n => ({ tillstand: n, frystTid: tillstand[n].granskning.frystTid,
      bild: tillstand[n].bild })),
    $regel: 'Det ordnade paret ar ETT designalternativ. Bilderna far inte bedomas var for sig.' };
}

/** Tva renderingar av samma tillstand ska vara matningsidentiska. */
export function determinismgrind(a, b) {
  const lika = JSON.stringify(a) === JSON.stringify(b);
  return { ok: lika, skal: lika ? null : 'tva renderingar av samma tillstand skiljer sig' };
}

export { FRYS, ATERSTALL_ANIMATION };
