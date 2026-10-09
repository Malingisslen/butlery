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
import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

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

/* ── DELADE BEREDSKAPSGRINDAR ────────────────────────────────────────
 *
 * Tva fel i tidigare korningar ska inte kunna upprepas:
 *
 *  A. Animationsberedskap. En grind som raknade animationsrutor gav upp efter
 *     cirka 1100 ms nar requestAnimationFrame stryptes i headless. Grinden ar
 *     nu POSITIVT TILLSTANDSBASERAD med vaggklockstak — den fragar om
 *     animationerna finns, inte om rutor levereras snabbt. Ingen diagnostikrad
 *     far vara nodvandig for att timingen ska ga ihop.
 *
 *  B. Layoutberedskap. Utsnittet berknades fore fardig layout och gav tomma
 *     bilder pa 168 byte. Geometrin maste vara positivt upplost, icke-noll och
 *     lasas OM efter beredskapen.
 *
 * Bada faller stangt. Anroparen skickar in en evaluator; grindarna ager
 * villkoren, inte vantetiden.
 */

export const ANIMATIONSTILLSTAND = art => `(() => {
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return JSON.stringify({ ok: false, skal: 'artefakten saknas' });
  const anim = it.getAnimations({ subtree: true });
  const identiteter = anim.map(a => ({
    langd: a.effect && a.effect.getComputedTiming ? a.effect.getComputedTiming().duration : null,
    playState: a.playState, harEffekt: !!a.effect }));
  const initierade = identiteter.length > 0 && identiteter.every(x => x.harEffekt && x.langd);
  return JSON.stringify({ ok: initierade, antal: anim.length, identiteter,
    skal: !anim.length ? 'inga animationer registrerade'
      : !initierade ? 'en animation saknar effekt eller langd' : null }); })()`;

/* Produktordinalbasen. Samma harledning som ovriga sonder — scopemotorn
   seriealiserad, aldrig en egen kopia av reglerna. */
const BAS_GEO = `
${SCOPE_KOD}
${KEDJA_KOD}
  function produktElement(it) {
    return [...it.querySelectorAll('*')]
      .filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product'); }`;

export const GEOMETRI = (art, ordinal, marginal = 8) => `(() => {
${BAS_GEO}
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return JSON.stringify({ ok: false, skal: 'artefakten saknas' });
  const prod = produktElement(it);
  const el = prod[${ordinal}];
  if (!el) return JSON.stringify({ ok: false, skal: 'ordinalen finns inte' });
  const r = el.getBoundingClientRect();
  const M = ${marginal};
  const ruta = { x: Math.round(r.x) - M, y: Math.round(r.y) - M,
    width: Math.round(r.width) + 2 * M, height: Math.round(r.height) + 2 * M };
  const inomVy = ruta.x + ruta.width > 0 && ruta.y + ruta.height > 0;
  return JSON.stringify({ ok: ruta.width > 2 * M && ruta.height > 2 * M && inomVy,
    ruta, radMatt: { w: r.width, h: r.height },
    skal: ruta.width <= 2 * M || ruta.height <= 2 * M ? 'geometrin ar noll eller degenererad'
      : !inomVy ? 'utsnittet ligger utanfor vyn' : null }); })()`;

/**
 * Vaggklocksbaserad pollning. Grinden ager villkoret; anroparen levererar bara
 * en evaluator och en sovfunktion. Ingen ruta raknas.
 */
export async function vantaPa(kor, uttryck, { maxMs = 8000, intervallMs = 120, nu = () => Date.now(),
  sov = ms => new Promise(r => setTimeout(r, ms)) } = {}) {
  const t0 = nu();
  let sista = null;
  while (nu() - t0 < maxMs) {
    const svar = await kor(uttryck);
    sista = typeof svar === 'string' ? JSON.parse(svar) : svar;
    if (sista && sista.ok) return { ...sista, vantadeMs: nu() - t0, forsokt: true };
    await sov(intervallMs); }
  return { ok: false, vantadeMs: maxMs, sista,
    skal: 'beredskapen intraffade aldrig inom ' + maxMs + ' ms' + (sista && sista.skal ? ': ' + sista.skal : '') };
}

/** Bildgrind: en tom eller nastan tom PNG far aldrig passera. */
export function bildgrind(base64, { minBytes = 2000 } = {}) {
  const bytes = Math.floor(String(base64).length * 3 / 4);
  return { ok: bytes >= minBytes, bytes, minBytes,
    skal: bytes >= minBytes ? null : 'bilden ar ' + bytes + ' byte — under gransen ' + minBytes +
      ', vilket ar den signatur en tom rendering har' };
}
