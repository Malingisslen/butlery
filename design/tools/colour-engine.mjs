// F2-NT · FARGMOTORN, EN ENDA GANG.
//
// Ordagrant R-01:s verifierade motor: luminans, alfakomposition och
// bakgrundsupplosning. Den ligger har for att kontrollgrafik och grafik
// utanfor kontroller ska rakna med EXAKT samma matematik. Tva kopior som
// glider isar ar en tyst metodlucka.
//
// Texten interpoleras in i browserskript. Den innehaller darfor dubbla
// bakstreck i de reguljara uttrycken.

export const FARGMOTOR = `
  const srgb = c => { c /= 255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); };
  const lum = ([r,g,b]) => 0.2126*srgb(r) + 0.7152*srgb(g) + 0.0722*srgb(b);
  const parse = s => { if (!s) return null;
    const m = String(s).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    if (m) return [ +m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4] ];
    const h = String(s).trim().match(/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/);
    if (!h) return null;
    const v = h[1].length === 3 ? h[1].split('').map(c => c + c).join('') : h[1];
    return [parseInt(v.slice(0,2),16), parseInt(v.slice(2,4),16), parseInt(v.slice(4,6),16), 1]; };
  const over = (fg, bg) => { const a = fg[3]; return [0,1,2].map(i => Math.round(fg[i]*a + bg[i]*(1-a))); };
  function bakgrundBakom(el) { let n = el, stack = [], oreducerbar = null;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') { oreducerbar = cs.backgroundImage.slice(0,60); break; }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement; }
    if (oreducerbar) return { oreducerbar };
    let base = [255,255,255];
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return { rgb: base }; }
  const kvot = (f, b) => { const L1 = lum(f), L2 = lum(b);
    return +(((Math.max(L1,L2)+0.05)/(Math.min(L1,L2)+0.05))).toFixed(2); };
  const fargRgb = c => 'rgb(' + c.join(', ') + ')';
  const glyfFarg = svg => { const st = svg.getAttribute('stroke'), fi = svg.getAttribute('fill');
    if (st && st !== 'none') return st;
    if (fi && fi !== 'none') return fi;
    const cs = getComputedStyle(svg);
    if (cs.stroke && cs.stroke !== 'none') return cs.stroke;
    if (cs.fill && cs.fill !== 'none') return cs.fill;
    return null; };
`;
