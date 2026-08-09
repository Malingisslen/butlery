// F2-R04 · MATSKRIPT FOR TEMADIMENSIONEN.
//
// Laser DEKLARATIONER och samlar diagnostik. Avgor ingenting sjalv.
//
// Luminansen pa artefaktens storsta ogenomskinliga yta las ocksa av, men
// enbart som DIAGNOSTIK. Den far aldrig avgora vilket tema en artefakt har:
// en mork dialog i ljust lage och matlagningslagets morka tema mater bada
// morkt utan att vara dark mode.
//
// CONFORMANCE mats inte har. R-04 orkestrerar de frysta motorerna — R-01:s
// textkontrast, non-text-carriermodellen och R-03:s klippning — over en
// verifierad temaparning. Deras grundmodeller rors inte.

import { FARGMOTOR } from './colour-engine.mjs';

export const THEME_MEASURE = `(() => {
  ${FARGMOTOR}

  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    // Diagnostik: den storsta ogenomskinliga ytan inuti telefonramen.
    let storst = null, storstArea = 0;
    for (const el of it.querySelectorAll('*')) {
      const c = parse(getComputedStyle(el).backgroundColor);
      if (!c || c[3] < 1) continue;
      const r = el.getBoundingClientRect();
      const a = r.width * r.height;
      if (a > storstArea) { storstArea = a; storst = c; }
    }
    const L = storst ? lum(storst.slice(0, 3)) : null;

    ut.push({
      art: it.id,
      skarmetikett: it.getAttribute('data-screen-label') || null,
      // DEKLARATIONER — den enda tillatna identiteten.
      tema: it.getAttribute('data-theme'),
      familj: it.getAttribute('data-theme-family'),
      // DIAGNOSTIK — aldrig identitet.
      diagnostik: {
        storstaYtaLuminans: L === null ? null : +L.toFixed(3),
        storstaYtaFarg: storst ? fargRgb(storst.slice(0, 3)) : null,
        kontroller_st: it.querySelectorAll('[data-a11y-role]').length,
        namnsignal_morkt: /morkt|dark/i.test(it.id),
        // Ramens bredd ar UNDERLAG for att forfatta familjens formfaktor.
        // Den avgor aldrig nagot vid korning.
        ramBredder: [...it.querySelectorAll('.sc-phone')]
          .map(e => Math.round(e.getBoundingClientRect().width))
          .filter((v, i, a) => a.indexOf(v) === i),
      },
    });
  }
  return ut;
})()`;
