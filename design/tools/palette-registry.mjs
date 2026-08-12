// F2-R04 · MORK PALETT + KANDIDATKONTRAKT.
//
// TRE BEGREPP SOM ALDRIG FAR BLANDAS:
//   A OBSERVED MAPPING EVIDENCE      vad som faktiskt observerats i tackta familjer
//   B PALETTE SEMANTIC ELIGIBILITY   vilka befintliga varden som ens ar legitima
//                                    kandidater for en viss beslutstyp
//   C DESIGN RECOMMENDATION          vad principen pekar ut bland de kvarvarande
//
// B ar INTE evidens. Att #de9078 ar en semantisk accent gor den olamplig som
// neutral brodtext — det sager ingenting om vilken neutral farg som ska valjas.
//
// FREKVENS ar deskriptiv. Den far registreras och visas, men far aldrig
// motivera ett val. Den regeln ar orsaken till att kandidatgrinden ligger har
// och inte i analysen.

export const PRINCIPER = ['P-SURFACE-APP', 'P-SURFACE-ELEVATED', 'P-SURFACE-CONTROL',
  'P-TEXT-CONTENT', 'P-TEXT-SEMANTIC', 'P-GRAPHIC'];

/** Semantiska accenter i Butlerys morksystem. Belagt ur ljuspalettens roller. */
export const ACCENTER = new Set(['#ce7c1e', '#dca968', '#de9078', '#9c3b23', '#8a5212', '#a15a0a']);

export const rgbAv = h => { const m = /^#([0-9a-f]{6})$/i.exec(h);
  if (m) return [0, 2, 4].map(i => parseInt(m[1].slice(i, i + 2), 16)).concat(1);
  const p = /rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/.exec(h);
  return p ? [+p[1], +p[2], +p[3], p[4] === undefined ? 1 : +p[4]] : null; };
export const overLagg = (f, b) => [0, 1, 2].map(i => Math.round(f[i] * f[3] + b[i] * (1 - f[3])));
const lum = c => { const f = x => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); };
  return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); };
export const kvot = (a, b) => { const A = Array.isArray(a) ? a : rgbAv(a), Bc = Array.isArray(b) ? b : rgbAv(b);
  if (!A || !Bc) return null;
  const l1 = lum(A), l2 = lum(Bc), h = Math.max(l1, l2), l = Math.min(l1, l2);
  return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100; };

/**
 * Bygg registret ur den verifierade morka populationen.
 * poster: [{ varde, egenskap, roll }] — en per observerad mork deklaration.
 */
export function byggRegister(poster) {
  const m = new Map();
  for (const p of poster) {
    if (!m.has(p.varde)) m.set(p.varde, { varde: p.varde, rgba: rgbAv(p.varde),
      genomskinlig: (rgbAv(p.varde) || [0, 0, 0, 1])[3] < 1,
      egenskaper: new Set(), roller: new Set(), forekomster: 0 });
    const e = m.get(p.varde);
    e.egenskaper.add(p.egenskap); e.roller.add(p.roll); e.forekomster++; }
  return [...m.values()].map(e => {
    const eg = [...e.egenskaper], ro = [...e.roller];
    const somForgrund = eg.includes('color') || eg.includes('fill') || eg.includes('stroke');
    const somYta = eg.includes('background-color');
    const somRam = eg.some(x => x.startsWith('border-'));
    return { varde: e.varde, rgba: e.rgba, genomskinlig: e.genomskinlig,
      egenskaper: eg, roller: ro, forekomster: e.forekomster,
      // KAPABILITETER ur faktisk anvandning, aldrig ur frekvens.
      forgrundskapabel: somForgrund, ytkapabel: somYta, ramkapabel: somRam,
      appytekapabel: somYta && ro.some(r => r === 'yta-app'),
      semantiskAccent: ACCENTER.has(e.varde),
      neutral: !ACCENTER.has(e.varde) }; });
}

/**
 * KANDIDATKONTRAKT. Varje palettvarde hamnar exakt en gang i ELIGIBLE eller
 * INELIGIBLE, med skal. Ingen kandidat far tyst forsvinna.
 */
export function behorighet(princip, post) {
  const skal = [];
  switch (princip) {
    case 'P-TEXT-CONTENT':
      if (!post.forgrundskapabel) skal.push('anvands aldrig som forgrund i den verifierade morka populationen');
      if (post.semantiskAccent) skal.push('semantisk accent — far inte losa kontrast for neutral innehallstext');
      break;
    case 'P-TEXT-SEMANTIC':
      if (!post.forgrundskapabel) skal.push('anvands aldrig som forgrund');
      break;
    case 'P-SURFACE-APP':
      if (!post.ytkapabel) skal.push('anvands aldrig som malad yta');
      if (post.semantiskAccent) skal.push('semantisk accent kan inte bara appytans canvasfunktion');
      if (post.genomskinlig) skal.push('genomskinligt varde kan inte vara temabasens lagsta yta');
      break;
    case 'P-SURFACE-ELEVATED':
    case 'P-SURFACE-CONTROL':
      if (!post.ytkapabel) skal.push('anvands aldrig som malad yta');
      break;
    case 'P-GRAPHIC':
      if (!post.forgrundskapabel && !post.ramkapabel)
        skal.push('anvands varken som grafisk forgrund eller ram');
      break;
    default: skal.push('okand princip');
  }
  return { varde: post.varde, behorig: skal.length === 0,
    klass: skal.length === 0 ? 'ELIGIBLE_AND_TESTED' : 'INELIGIBLE_WITH_REASON',
    skal: skal.length ? skal.join(' · ') : null };
}

/** Hela universumet, redovisat. Summan maste alltid ga ihop. */
export function kandidatuniversum(princip, register) {
  const rader = register.map(p => behorighet(princip, p));
  const behoriga = rader.filter(r => r.behorig);
  return { princip, totalt: register.length, behoriga: behoriga.length,
    obehoriga: rader.length - behoriga.length,
    summerar: behoriga.length + (rader.length - behoriga.length) === register.length,
    rader };
}
