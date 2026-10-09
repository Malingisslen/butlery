// F2-R04 · DETERMINISTISK ANIMATIONSFRYSNING FOR PREVIEW.
//
// FELKLASSEN
// Illustrationen i start kor en 5-sekunders loop. En stillbild fangar en
// godtycklig bildruta: forsta forsoket visade kupan men varken maten eller
// angan. En jamforelse av fargbuntar dar delar saknas ar inte evidens.
//
// VAD MODULEN GOR
// Fryser animationen vid en EXPLICIT angiven fas i previewharnesset. Den
// rakkraknar aldrig fram fasen ur keyframestext — den MATER faktisk berknad
// synlighet over cykeln och bygger intervall ur matningen.
//
// VAD DEN INTE GOR
// Den rors aldrig produktens normala animation. Den satter currentTime och
// pausar via Web Animations API pa de element previewn galler, och aterstaller
// efterat. Den andrar ingen CSS, ingen kalla och inget tema.
//
// FAIL CLOSED
// Finns ingen fas dar samtliga efterfragade delar ar representerade returneras
// inget frysvarde. Da far ingen bild renderas.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const REPRESENTERAD_TROSKEL = 0.01;   // opacity over noll, inget mer

/**
 * Mater berknad synlighet for angivna produktordinaler over hela cykeln.
 * steg = antal provpunkter. Returnerar en matris tid × del.
 */
export const SYNLIGHETSPROV = (art, ordinaler, steg) => `(async () => {
${SCOPE_KOD}
${KEDJA_KOD}
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return JSON.stringify({ fel: 'artefakten saknas' });
  const prod = [...it.querySelectorAll('*')].filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product');
  const MAL = ${JSON.stringify(ordinaler)};
  const element = MAL.map(o => prod[o]);
  if (element.some(e => !e)) return JSON.stringify({ fel: 'ordinal saknas' });

  // Alla animationer som paverkar malen eller deras forfader.
  const anim = it.getAnimations({ subtree: true });
  if (!anim.length) return JSON.stringify({ fel: 'inga animationer' });
  const langder = anim.map(a => { const t = a.effect && a.effect.getComputedTiming();
    return t && t.duration ? t.duration : null; }).filter(Boolean);
  const cykel = langder.length ? Math.max(...langder) : null;
  if (!cykel) return JSON.stringify({ fel: 'ingen cykellangd' });

  // Effektiv opacity = produkten av alla opacity-varden i kedjan upp till it.
  const effektiv = el => { let o = 1, n = el;
    while (n && n !== it) { const v = parseFloat(getComputedStyle(n).opacity);
      if (!isNaN(v)) o *= v; n = n.parentElement; }
    return o; };

  const STEG = ${steg};
  const rader = [];
  for (const a of anim) a.pause();
  for (let i = 0; i < STEG; i++) {
    const t = cykel * i / STEG;
    for (const a of anim) a.currentTime = t;
    await new Promise(r => requestAnimationFrame(() => r(1)));
    rader.push({ tid: Math.round(t * 100) / 100,
      opacitet: element.map(e => Math.round(effektiv(e) * 10000) / 10000) }); }
  for (const a of anim) { a.currentTime = 0; a.play(); }
  return JSON.stringify({ cykel, steg: STEG, ordinaler: MAL, rader,
    animationer: anim.length }); })()`;

/** Intervall dar en del ar representerad, ur MATNINGEN. */
export function synlighetsintervall(prov, troskel = REPRESENTERAD_TROSKEL) {
  const n = prov.ordinaler.length, ut = [];
  for (let d = 0; d < n; d++) {
    const intervall = []; let start = null;
    for (const r of prov.rader) { const synlig = r.opacitet[d] > troskel;
      if (synlig && start === null) start = r.tid;
      if (!synlig && start !== null) { intervall.push([start, r.tid]); start = null; } }
    if (start !== null) intervall.push([start, prov.cykel]);
    ut.push({ ordinal: prov.ordinaler[d], intervall,
      andelAvCykeln: Math.round(1000 * intervall.reduce((s, [a, b]) => s + (b - a), 0) / prov.cykel) / 10 }); }
  return ut;
}

/**
 * Fas dar SAMTLIGA delar ar representerade samtidigt.
 * Regel: mittpunkten i det BREDASTE sammanhangande intervallet. Lika breda:
 * det tidigaste. Ingen estetisk optimering.
 */
export function valjFrysTid(prov, troskel = REPRESENTERAD_TROSKEL) {
  const gemensam = []; let start = null;
  for (const r of prov.rader) { const alla = r.opacitet.every(o => o > troskel);
    if (alla && start === null) start = r.tid;
    if (!alla && start !== null) { gemensam.push([start, r.tid]); start = null; } }
  if (start !== null) gemensam.push([start, prov.cykel]);
  if (!gemensam.length) return { ok: false, frysTidMs: null, intervall: [],
    skal: 'ingen fas i cykeln dar samtliga delar ar representerade samtidigt' };
  const bredast = gemensam.reduce((b, i) => (i[1] - i[0]) > (b[1] - b[0]) ? i : b, gemensam[0]);
  return { ok: true, frysTidMs: Math.round((bredast[0] + bredast[1]) / 2 * 100) / 100,
    cykelMs: prov.cykel, valtIntervall: bredast, allaIntervall: gemensam,
    regel: 'mittpunkten i det bredaste sammanhangande intervallet dar samtliga delar ar representerade; lika breda bryts av det tidigaste' };
}

/**
 * VANTEGRIND. Animationerna registreras inte nodvandigtvis direkt efter load.
 * Fryser man for tidigt returnerar getAnimations en tom lista och frysningen
 * faller — men av fel skal. Grinden vantar tills minst en animation finns,
 * eller ger upp med ett explicit skal.
 */
export const VANTA_PA_ANIMATIONER = (art, forsok = 40) => `(async () => {
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return JSON.stringify({ ok: false, skal: 'artefakten saknas' });
  for (let i = 0; i < ${forsok}; i++) {
    const n = it.getAnimations({ subtree: true }).length;
    if (n > 0) return JSON.stringify({ ok: true, animationer: n, forsok: i + 1 });
    await new Promise(r => requestAnimationFrame(() => r(1))); }
  return JSON.stringify({ ok: false, animationer: 0, forsok: ${forsok},
    skal: 'inga animationer registrerade efter ${forsok} rutor' }); })()`;

/** Fryser vid exakt fas och laser tillbaka. Fail closed vid avvikelse. */
export const FRYS = (art, tidMs, ordinaler) => `(async () => {
${SCOPE_KOD}
${KEDJA_KOD}
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return JSON.stringify({ ok: false, skal: 'artefakten saknas' });
  const prod = [...it.querySelectorAll('*')].filter(el => el !== it && losScope(kedjaFor(el, it)).scope === 'product');
  const anim = it.getAnimations({ subtree: true });
  if (!anim.length) return JSON.stringify({ ok: false, skal: 'inga animationer att frysa' });
  const T = ${JSON.stringify(tidMs)};
  for (const a of anim) { a.pause(); a.currentTime = T; }
  await new Promise(r => requestAnimationFrame(() => r(1)));
  await new Promise(r => requestAnimationFrame(() => r(1)));   // en extra ruta: den far inte ga vidare
  const efter = anim.map(a => a.currentTime);
  const spelar = anim.map(a => a.playState);
  const effektiv = el => { let o = 1, n = el;
    while (n && n !== it) { const v = parseFloat(getComputedStyle(n).opacity);
      if (!isNaN(v)) o *= v; n = n.parentElement; }
    return o; };
  const delar = ${JSON.stringify(ordinaler)}.map(o => ({ ordinal: o,
    finns: !!prod[o], opacitet: prod[o] ? Math.round(effektiv(prod[o]) * 10000) / 10000 : null }));
  const stannade = efter.every(t => Math.abs(t - T) < 0.5);
  const pausade = spelar.every(s => s === 'paused');
  return JSON.stringify({ ok: stannade && pausade && delar.every(d => d.finns),
    begardTid: T, faktiskTid: efter, playState: spelar, delar,
    skal: !stannade ? 'animationen gick vidare' : !pausade ? 'animationen ar inte pausad'
      : !delar.every(d => d.finns) ? 'en efterfragad del saknas' : null }); })()`;

/** Aterstaller normal uppspelning. Produkten far aldrig lamnas fryst. */
export const ATERSTALL_ANIMATION = art => `(() => {
  const it = document.getElementById(${JSON.stringify(art)});
  if (!it) return 0;
  const anim = it.getAnimations({ subtree: true });
  for (const a of anim) { a.currentTime = 0; a.play(); }
  return anim.length; })()`;
