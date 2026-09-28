// F2-R04 · SEMANTISK INSTANSSOND FOR BESLUTSENHETER.
//
// Beslutsenheten ar aldrig en rafarg. Den ar
//   semantisk roll x semantisk undergrupp x nuvarande ljusvarde x kontext.
// Sonden BESKRIVER varje instans langs de dimensioner som far bilda en
// undergrupp. Den grupperar inte och den domer inte — det sker utanfor.
//
// Undergruppsnyckeln beskriver vad saken AR, aldrig vilken farg den har.

import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const SEMANTISK_SOND = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  function parse(v) { const m = String(v || '').match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; }
  function over(f, b) { const a = f[3];
    return [Math.round(f[0]*a+b[0]*(1-a)), Math.round(f[1]*a+b[1]*(1-a)), Math.round(f[2]*a+b[2]*(1-a))]; }
  function lum(c) { const f = x => { x/=255; return x<=0.03928 ? x/12.92 : Math.pow((x+0.055)/1.055,2.4); };
    return 0.2126*f(c[0])+0.7152*f(c[1])+0.0722*f(c[2]); }
  function kvot(a, b) { const l1=lum(a), l2=lum(b), h=Math.max(l1,l2), l=Math.min(l1,l2);
    return Math.round(((h+0.05)/(l+0.05))*100)/100; }
  // Underliggande MALAD yta, med identitet — inte bara farg.
  function ytaUnder(el, stopp) { let n = el.parentElement;
    while (n && n !== stopp) { const c = parse(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0) return { el: n, farg: getComputedStyle(n).backgroundColor, alpha: c[3] };
      n = n.parentElement; } return null; }
  function plattBakgrund(el) { let n = el, st = [];
    while (n && n !== document.documentElement) { const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') return null;
      const c = parse(cs.backgroundColor); if (c && c[3] > 0) { st.push(c); if (c[3] === 1) break; }
      n = n.parentElement; }
    let b = [255,255,255]; for (let i = st.length-1; i >= 0; i--) b = over(st[i], b); return b; }

  const MAL = window.__MAL || [];      // [{roll, ljus}]
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const alla = [...it.querySelectorAll('*')];
    const iProdukt = el => el !== it && losScope(kedjaFor(el, it)).scope === 'product';
    // ORDINALBAS. Samma som fargsonden: index i PRODUKTELEMENTEN, inte i alla
    // element. Med tva olika baser gick posterna inte att sammanfoga.
    const produktElement = alla.filter(iProdukt);
    const ord = new Map(produktElement.map((e, i) => [e, i]));
    // Appytan = den storsta malade ytan i produktscope, som identitet.
    let appyta = null, appArea = 0;
    for (const el of produktElement) {
      const c = parse(getComputedStyle(el).backgroundColor); if (!c || c[3] === 0) continue;
      const r = el.getBoundingClientRect(); const a = r.width * r.height;
      if (a > appArea) { appArea = a; appyta = el; } }

    for (const el of produktElement) {
      const cs = getComputedStyle(el);
      const svg = el.tagName.toLowerCase() === 'svg';
      const egenText = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
      // Vilka egenskaper malar har?
      const kand = [];
      if (parse(cs.backgroundColor) && parse(cs.backgroundColor)[3] > 0) kand.push(['background-color', cs.backgroundColor]);
      if (egenText && parse(cs.color)) kand.push(['color', cs.color]);
      for (const sida of ['Top','Right','Bottom','Left'])
        if (parseFloat(cs['border' + sida + 'Width']) > 0 && parse(cs['border' + sida + 'Color']) &&
            parse(cs['border' + sida + 'Color'])[3] > 0)
          kand.push(['border-' + sida.toLowerCase() + '-color', cs['border' + sida + 'Color']]);
      if (svg) { for (const p of ['fill', 'stroke']) { const v = cs.getPropertyValue(p);
        if (v && v !== 'none' && parse(v) && parse(v)[3] > 0) kand.push([p, v]); } }
      if (!kand.length) continue;

      const ktrl = el.closest('[data-a11y-role]');
      const under = ytaUnder(el, it);
      const r = el.getBoundingClientRect();
      const bak = plattBakgrund(el);
      const barn = [...el.children];
      const grund = {
        art: it.id, elementOrdinal: ord.get(el), tagg: el.tagName.toLowerCase(),
        klass: el.getAttribute('class') || null,
        komponent: el.getAttribute('data-component') || null,
        kontrollroll: ktrl ? ktrl.getAttribute('data-a11y-role') : null,
        kontrollnamn: ktrl ? ktrl.getAttribute('data-a11y-name') : null,
        state: (ktrl && ktrl.getAttribute('data-a11y-state')) || el.getAttribute('data-a11y-state') || null,
        stateGrupp: ktrl ? ktrl.getAttribute('data-state-group') : null,
        arKontrollen: !!ktrl && ktrl === el,
        arSvg: svg, grafikroll: svg ? el.getAttribute('data-graphic-role') : null,
        ikon: svg ? el.getAttribute('data-icon') : null,
        barText: egenText, barIkon: !!el.querySelector('svg'),
        bredd: Math.round(r.width), hojd: Math.round(r.height),
        yta: Math.round(r.width * r.height),
        direktPaAppytan: !!(under && under.el === appyta),
        arAppytan: el === appyta,
        underliggandeYta: under ? { ordinal: ord.get(under.el), farg: under.farg,
          klass: under.el.getAttribute('class') || null, genomskinlig: under.alpha < 1 } : null,
        nastladeYtor: barn.filter(b => { const c = parse(getComputedStyle(b).backgroundColor); return c && c[3] > 0; }).length,
        barnForgrunder: barn.filter(b => (b.textContent || '').trim()).length,
        plattBakgrund: bak ? 'rgb(' + bak.join(', ') + ')' : null };
      for (const [egenskap, varde] of kand) {
        const c = parse(varde);
        const post = { ...grund, egenskap, varde, alpha: c ? c[3] : null,
          genomskinlig: !!(c && c[3] < 1) };
        if (egenskap === 'color' && bak) { const fg = c[3] < 1 ? over(c, bak) : [c[0], c[1], c[2]];
          const w = parseInt(cs.fontWeight, 10) || 400, sz = parseFloat(cs.fontSize) || null;
          const stor = sz !== null && (sz >= 24 || (sz >= 18.66 && w >= 700));
          post.text = { fontSize: sz, fontWeight: w, stor, krav: stor ? 3 : 4.5,
            bakgrund: 'rgb(' + bak.join(', ') + ')', kvot: kvot(fg, bak) }; }
        if (egenskap === 'background-color' && under) { const u = parse(under.farg);
          if (u && u[3] === 1 && c && c[3] === 1) post.motUnderliggande = kvot([c[0],c[1],c[2]], [u[0],u[1],u[2]]); }
        ut.push(post);
      }
    }
  }
  return ut;
})()`;

/**
 * SEMANTISK UNDERGRUPPSNYCKEL. Beskriver vad instansen AR. Innehaller aldrig
 * farg, aldrig kontrast, aldrig hur ofta den forekommer.
 */
export function undergruppsnyckel(p) {
  const d = [];
  d.push(p.kontrollroll ? 'kontroll:' + p.kontrollroll : 'utan-kontroll');
  if (p.komponent) d.push('komponent:' + p.komponent);
  d.push(p.state ? 'state:' + String(p.state).toLowerCase().split(/[,;]/)[0].trim() : 'utan-state');
  d.push(p.arAppytan ? 'appytan-sjalv' : p.direktPaAppytan ? 'direkt-pa-appytan' : 'nastlad-yta');
  d.push(p.barText ? 'bar-text' : 'utan-text');
  d.push(p.barIkon ? 'bar-ikon' : 'utan-ikon');
  d.push(p.genomskinlig ? 'genomskinlig' : 'tackande');
  if (p.egenskap === 'fill' || p.egenskap === 'stroke')
    d.push('grafik:' + (p.grafikroll || 'oklassad'));
  if (p.egenskap.startsWith('border-')) d.push('ram');
  return d.join(' · ');
}
