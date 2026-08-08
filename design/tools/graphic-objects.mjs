// F2-NT · GRAFISKA OBJEKT UTANFOR KONTROLLER.
//
// WCAG 1.4.11 har tva halvor. UI-komponenternas grafik hanteras av
// nontext-measure.mjs. Den har filen tar den andra halvan: grafik som INTE
// ligger i en kontroll och som kravs for att FORSTA innehallet.
//
// Det ar en helt annan fraga, och den far darfor en helt egen modell och en
// egen rapport. De tva populationerna slas aldrig ihop.
//
// PROBLEMET: for en kontroll gar rollen att lasa ur strukturen — en kryssruta
// ar en kryssruta. For en fristaende bild finns ingen sadan struktur. Om en
// varningstriangel BEHOVS for att forsta texten, eller bara upprepar den, kan
// inte avgoras ur DOM:en.
//
// DARFOR: rollen kravs som DEKLARATION, precis som data-hit i R-02.
// Deklarationen ar data-graphic-role pa objektet sjalv.
//
//   required     grafiken behovs visuellt for att forsta information, status
//                eller betydelse
//                => omfattas av kontrastmatningen, trosskel 3:1
//
//   redundant    grafiken formedlar betydelse, men samma information finns
//                fullstandigt i en annan synlig signal — oftast texten intill
//                => rapporteras, men ar inte required carrier for 1.4.11
//
//   decorative   grafiken formedlar ingen information
//                => utanfor conformance-matningen
//
//   saknad eller ogiltig markning => unknown, fail closed
//
// data-icon raknas INTE som deklaration. Det namnger formen, inte funktionen:
// en "check" kan vara den enda bararen av "klart" eller ren utsmyckning
// bredvid ordet "Klart". Skillnaden finns inte i attributet.
//
// Kontrastvardet anvands aldrig for att avgora rollen. Markningen far aldrig
// sattas for att kvoten ar lag, for att kvoten ar hog eller for att minska
// fyndantalet. Fragan ar designens avsedda betydelse.

import { FARGMOTOR } from './colour-engine.mjs';

export const GRAPHIC_OBJECTS = `(() => {
  ${FARGMOTOR}

  const GILTIGA = new Set(['required', 'redundant', 'decorative']);

  function deklaration(g) {
    if (!g.hasAttribute('data-graphic-role'))
      return { roll: 'unknown',
        grund: 'ingen data-graphic-role' +
          (g.getAttribute('data-icon') ? ' (data-icon namnger formen, inte funktionen)' : '') };
    const v = (g.getAttribute('data-graphic-role') || '').trim();
    if (!GILTIGA.has(v))
      return { roll: 'unknown',
        grund: 'data-graphic-role "' + v + '" ar inte required, redundant eller decorative' };
    return { roll: v, grund: 'data-graphic-role="' + v + '"' };
  }

  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    for (const g of it.querySelectorAll('svg, [data-icon], [data-illustration]')) {
      if (g.closest('[data-a11y-role]')) continue;          // hor till kontrollpopulationen
      if (g.parentElement && g.parentElement.closest('svg')) continue;  // del av en svg
      const r = g.getBoundingClientRect();
      if (!(r.width > 0 && r.height > 0)) continue;
      const d = deklaration(g);
      const bas = { art: it.id, tag: g.tagName.toLowerCase(),
        ikon: g.getAttribute('data-icon') || g.getAttribute('data-illustration') || null,
        carrier: d.roll, motivering: d.grund,
        w: +r.width.toFixed(1), h: +r.height.toFixed(1) };
      if (d.roll !== 'required') {
        ut.push({ ...bas, kvot: null,
          status: d.roll === 'unknown' ? 'unknown' : 'ejKravd' });
        continue; }
      const bg = bakgrundBakom(g.parentElement || g);
      if (bg.oreducerbar) { ut.push({ ...bas, kvot: null, status: 'unknown',
        varfor: 'oreducerbar angransande farg: ' + bg.oreducerbar }); continue; }
      const f = parse(g.tagName.toLowerCase() === 'svg'
        ? glyfFarg(g) : getComputedStyle(g).backgroundColor);
      if (!f) { ut.push({ ...bas, kvot: null, status: 'unknown',
        varfor: 'fargen kunde inte tolkas' }); continue; }
      const fk = f[3] < 1 ? over(f, bg.rgb) : f.slice(0, 3);
      ut.push({ ...bas, kvot: kvot(fk, bg.rgb), status: 'matt',
        farg: fargRgb(fk), angransande: fargRgb(bg.rgb) });
    }
  }
  return ut;
})()`;
