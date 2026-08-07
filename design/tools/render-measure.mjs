// F2-R06 · MÄTSKRIPTET, utbrutet så att de negativa proven kör EXAKT samma
// kod som den skarpa körningen. Ett prov mot en kopia bevisar ingenting om
// koden som faktiskt mäter.

export const MEASURE = `(() => {
  // F2-R02 · ALLA mått är CSS-pixlar. getBoundingClientRect ger CSS-px oavsett
  // devicePixelRatio; DPR påverkar rasterisering, inte layout. Vi mäter alltså
  // samma tal en granskare ser i DevTools.
  const srgb = c => { c /= 255; return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); };
  const lum = ([r,g,b]) => 0.2126*srgb(r) + 0.7152*srgb(g) + 0.0722*srgb(b);
  // Bakstrecken är DUBBLA för att mätskriptet ligger i en template literal:
  // \\( blir \( i sidan. Enkla bakstreck åt regexen tyst och gav
  // "textfärgen kunde inte tolkas" på varenda kontroll.
  const parse = s => { const m = String(s).match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)/);
    return m ? [ +m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4] ] : null; };
  const over = (fg, bg) => { const a = fg[3]; return [0,1,2].map(i => Math.round(fg[i]*a + bg[i]*(1-a))); };

  // Bakgrunden kan vara OREDUCERBAR: en gradient, en bild eller en
  // bakgrundsegenskap vi inte kan platta till en färg. Då är kontrasten
  // UNKNOWN — inte godkänd, inte underkänd.
  function bgOf(el) {
    let n = el, stack = [], unreducible = null;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') {
        unreducible = cs.backgroundImage.slice(0, 60);
        break;
      }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) { stack.push(c); if (c[3] === 1) break; }
      n = n.parentElement;
    }
    if (unreducible) return { unreducible };
    let base = [255,255,255];
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return { rgb: base };
  }

  // Närmaste förfader som faktiskt klipper. Vi skiljer nu på KLIPPANDE
  // (hidden/clip) och SCROLLANDE (auto/scroll) förfader: att ligga utanför en
  // scrollbar behållare är normalt scrollinnehåll, inte klippning.
  function clipAncestor(el) {
    let n = el.parentElement;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      const s = cs.overflow + ' ' + cs.overflowX + ' ' + cs.overflowY;
      if (/hidden|clip|auto|scroll/.test(s))
        return { el: n, klipper: /hidden|clip/.test(s), scrollar: /auto|scroll/.test(s), s };
      n = n.parentElement;
    }
    return null;
  }

  // STABIL ELEMENTIDENTITET. Utan den kan samma underliggande problem inte
  // dedupliceras mellan R-03a, R-03b, R-03c och R-03d — de skulle räknas som
  // fyra fel. Sökvägen är barnindexkedjan från artefaktroten.
  function nodePath(el, root) {
    const parts = [];
    let n = el;
    while (n && n !== root) {
      const p = n.parentElement;
      if (!p) break;
      parts.push([...p.children].indexOf(n));
      n = p;
    }
    return parts.reverse().join('/');
  }
  // className är en SVGAnimatedString på SVG-element. Attributet är säkert.
  const clsOf = el => (el.getAttribute && el.getAttribute('class')) || '';

  // STABIL ELEMENTNYCKEL i prioriteringsordning. DOM-sökvägen är sist och bara
  // som dokumenterad reserv: ett inskjutet syskon flyttar varje index efter sig
  // och skulle byta identitet på ett fynd som inte ändrats.
  //   1  explicit id-attribut satt av ritningen
  //   2  semantisk roll + tillgängligt namn + lokalt löpnummer
  //   3  normaliserad selektor: tagg + klasslista + löpnummer bland likadana
  //   4  DOM-sökväg (reserv)
  function elementKey(el, root) {
    const a = n => (el.getAttribute && el.getAttribute(n)) || '';
    const explicit = a('data-element-id') || a('data-control-id') || el.id;
    if (explicit) return { key: 'id:' + explicit, basis: 'explicit-id' };

    const roll = a('data-a11y-role') || a('role');
    const namn = a('data-a11y-name') || a('aria-label') || '';
    if (roll && namn) {
      const lika = [...root.querySelectorAll('[data-a11y-role="' + roll + '"]')]
        .filter(x => ((x.getAttribute('data-a11y-name') || '') === namn));
      const n = lika.indexOf(el);
      return { key: 'roll:' + roll + '|' + namn + (lika.length > 1 ? '#' + (n < 0 ? '?' : n) : ''),
               basis: 'roll-och-namn' };
    }

    // Normaliserad selektor. Klasslistan sorteras så att ordningen i markup
    // inte kan byta identitet. Löpnumret räknas bland syskon med SAMMA
    // tagg och klass — ett orelaterat inskjutet syskon påverkar det inte.
    const tag = el.tagName.toLowerCase();
    const kl = clsOf(el).trim().split(/\s+/).filter(Boolean).sort().join('.');
    const p = el.parentElement;
    if (p) {
      const lika = [...p.children].filter(x =>
        x.tagName.toLowerCase() === tag &&
        clsOf(x).trim().split(/\s+/).filter(Boolean).sort().join('.') === kl);
      const n = lika.indexOf(el);
      const förälder = p === root ? 'rot' :
        (p.id ? 'id:' + p.id : p.tagName.toLowerCase() +
          (clsOf(p).trim() ? '.' + clsOf(p).trim().split(/\s+/).filter(Boolean).sort().join('.') : ''));
      return { key: 'sel:' + förälder + '>' + tag + (kl ? '.' + kl : '') + '[' + n + ']',
               basis: 'normaliserad-selektor' };
    }
    return { key: 'path:' + nodePath(el, root), basis: 'dom-path-reserv' };
  }

  // Element utan egen visuell box. Ett <br> är en radbrytning, inte en yta:
  // det har alltid bredd 0 och kan varken klippa eller klippas. Att klassa det
  // som verktygsfel gjorde en scoperegel till ett mätfel. Texten omkring det
  // mäts av det innehållande blocket och går alltså inte förlorad.
  const UTAN_BOX = new Set(['br', 'wbr']);

  const TAK = 500;
  const cap = arr => arr.slice(0, TAK);
  const klasser = arr => ({
    verifierad:  arr.filter(x => x.klass === 'verifierad').length,
    avsiktlig:   arr.filter(x => x.klass === 'avsiktlig').length,
    observation: arr.filter(x => x.klass === 'observation').length,
    verktygsfel: arr.filter(x => x.klass === 'verktygsfel').length });

  const items = [...document.querySelectorAll('.sc-item')];
  const out = { viewport: { w: innerWidth, h: innerHeight, dpr: devicePixelRatio, unit: 'css-px' },
    fontsReady: document.fonts ? document.fonts.status : 'saknas',
    colorScheme: matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
    bodyBg: getComputedStyle(document.body).backgroundColor,
    bodyColor: getComputedStyle(document.body).color, artifacts: [] };

  for (const it of items) {
    const r = it.getBoundingClientRect();
    const controls = [...it.querySelectorAll('[data-a11y-role]')].map(c => {
      const cr = c.getBoundingClientRect();
      const cs = getComputedStyle(c);
      const fg = parse(cs.color);
      const bg = bgOf(c);
      const weight = parseInt(cs.fontWeight, 10) || (cs.fontWeight === 'bold' ? 700 : 400);
      const size = parseFloat(cs.fontSize) || null;
      // WCAG: stor text = >=24 px, eller >=18.66 px vid vikt >=700.
      const large = size !== null && (size >= 24 || (size >= 18.66 && weight >= 700));
      let ratio = null, contrastStatus = 'ok', why = null;
      if (bg.unreducible) { contrastStatus = 'unknown'; why = 'oreducerbar bakgrund: ' + bg.unreducible; }
      else if (!fg) { contrastStatus = 'unknown'; why = 'textfärgen kunde inte tolkas: ' + cs.color; }
      else {
        const f = fg[3] < 1 ? over(fg, bg.rgb) : fg.slice(0,3);
        const L1 = lum(f), L2 = lum(bg.rgb);
        ratio = +(((Math.max(L1,L2)+0.05)/(Math.min(L1,L2)+0.05))).toFixed(2);
      }
      return { role: c.getAttribute('data-a11y-role'), name: c.getAttribute('data-a11y-name') || null,
        state: c.getAttribute('data-a11y-state') || null,
        w: +cr.width.toFixed(2), h: +cr.height.toFixed(2),
        fontSize: size, fontWeight: weight, large,
        opacity: parseFloat(cs.opacity),
        disabled: (c.getAttribute('data-a11y-state') || '').includes('disabled'),
        contrast: ratio, contrastStatus, contrastWhy: why };
    });

    // R-03a scroll-overflow · R-03b utanför klippande förfader ·
    // R-03c deklarerad hidden/clip · R-03d text-overflow och line-clamp
    const a3 = [], b3 = [], c3 = [], d3 = [], unknown = [];
    for (const el of [it, ...it.querySelectorAll('*')]) {
      const cs = getComputedStyle(el);
      const er = el.getBoundingClientRect();
      const ox = el.scrollWidth - el.clientWidth, oy = el.scrollHeight - el.clientHeight;
      const taggen = el.tagName.toLowerCase();
      // Radbrytare har ingen egen yta och ligger utanför geometrisk klippning.
      // Det är en dokumenterad scoperegel, inte ett mätfel.
      if (UTAN_BOX.has(taggen)) continue;
      const mätbar = er.width > 0 && er.height > 0 && cs.display !== 'none';
      const ek = elementKey(el, it);
      // F2-ID01 · BESKRIVANDE FÄLT FÖR IDENTITETSREVISIONEN.
      //
      // De ingår ALDRIG i findingId och ändrar därför inget kanoniskt resultat.
      // De finns för att en kollisionsinventering ska kunna avgöra OM två
      // detektioner med samma elementKey är samma fysiska nod eller två skilda,
      // och vilken stabil diskriminator som i så fall hade kunnat skilja dem.
      // Fältet path är den sanna nodidentiteten inom en enskild renderkörning.
      // (Inga bakstreck-citat här: de avslutar mallsträngen mätskriptet bor i.)
      const dataAttr = {};
      for (const a of el.attributes || [])
        if (a.name.startsWith('data-') && a.name !== 'data-dc-tpl') dataAttr[a.name] = a.value.slice(0, 60);
      const förälder = el.parentElement;
      const desc = { tag: taggen, cls: clsOf(el).slice(0, 40),
        path: nodePath(el, it), elementKey: ek.key, keyBasis: ek.basis,
        roll: el.getAttribute('data-a11y-role') || el.getAttribute('role') || null,
        namn: el.getAttribute('data-a11y-name') || el.getAttribute('aria-label') || null,
        dataAttr,
        domBeskrivning: (förälder && förälder !== it
          ? förälder.tagName.toLowerCase() + (clsOf(förälder) ? '.' + clsOf(förälder).trim().split(/\s+/)[0] : '')
          : 'rot') + ' > ' + taggen + (clsOf(el) ? '.' + clsOf(el).trim().split(/\s+/)[0] : '') +
          ' [' + (el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 24) + ']',
        intent: el.getAttribute('data-clip-intent') || null };

      // R-03a · Överskjutande innehåll är INTE automatiskt ett fel. En behållare
      // med overflow auto/scroll är per deklaration scrollbar; då är överskottet
      // avsett. Bara hidden/clip i den överskjutande axeln är verklig klippning.
      if ((ox > 1 || oy > 1) && !(cs.overflow === 'visible' && cs.overflowX === 'visible' && cs.overflowY === 'visible')) {
        const axlar = [];
        if (ox > 1) axlar.push({ ax: 'x', px: ox, of: cs.overflowX });
        if (oy > 1) axlar.push({ ax: 'y', px: oy, of: cs.overflowY });
        const klippande = axlar.filter(a => /hidden|clip/.test(a.of));
        const scrollande = axlar.filter(a => /auto|scroll/.test(a.of));
        let klass, why;
        if (!mätbar) { klass = 'verktygsfel'; why = 'nollstor eller dold box — överskott går inte att avgöra'; }
        else if (desc.intent) { klass = 'avsiktlig'; why = 'deklarerad orsak: ' + desc.intent; }
        else if (klippande.length) {
          klass = 'verifierad';
          why = 'överskott ' + klippande.map(a => a.px + ' px i ' + a.ax + ' med overflow-' + a.ax + ': ' + a.of).join(', ');
        } else if (scrollande.length) {
          klass = 'avsiktlig';
          why = 'behållaren är scrollbar per deklaration: ' + scrollande.map(a => 'overflow-' + a.ax + ': ' + a.of).join(', ');
        } else { klass = 'observation'; why = 'överskott i axel med overflow visible — innehållet syns, ingen klippning'; }
        a3.push({ ...desc, klass, why, subtype: 'klippning', detaljsubtyp: 'egen-box-överskott',
          axis: (ox > 1 && oy > 1) ? 'xy' : (ox > 1 ? 'x' : 'y'),
          overflowX: ox, overflowY: oy, overflow: cs.overflow });
      }

      // R-03b · Att ligga utanför en SCROLLANDE förfader är normalt
      // scrollinnehåll. Bara en klippande (hidden/clip) förfader ger avvikelse.
      const anc = clipAncestor(el);
      if (anc) {
        const ar = anc.el.getBoundingClientRect();
        const outX = Math.max(0, er.right - ar.right) + Math.max(0, ar.left - er.left);
        const outY = Math.max(0, er.bottom - ar.bottom) + Math.max(0, ar.top - er.top);
        if (outX > 1 || outY > 1) {
          let klass, why;
          if (!mätbar) { klass = 'verktygsfel'; why = 'nollstor eller dold box — läget går inte att avgöra'; }
          else if (desc.intent) { klass = 'avsiktlig'; why = 'deklarerad orsak: ' + desc.intent; }
          else if (anc.klipper) { klass = 'verifierad'; why = 'utanför klippande förfader (' + anc.s.trim() + ')'; }
          else { klass = 'avsiktlig'; why = 'utanför scrollande förfader (' + anc.s.trim() + ') — nås genom scroll'; }
          b3.push({ ...desc, klass, why, subtype: 'klippning', detaljsubtyp: 'utanför-klippande-förfader',
            axis: (outX > 1 && outY > 1) ? 'xy' : (outX > 1 ? 'x' : 'y'),
            outsideX: +outX.toFixed(1), outsideY: +outY.toFixed(1),
            ancestor: clsOf(anc.el).slice(0, 30) || anc.el.tagName.toLowerCase(),
            ancestorTag: anc.el.tagName.toLowerCase(),
            // ÖMSESIDIG REFERENS. Utan den går det inte att skilja "barnet är
            // just det som förfadern rapporterar" från två oberoende fel.
            ancestorPath: nodePath(anc.el, it),
            ancestorKey: elementKey(anc.el, it).key,
            // BEVIS. Utan de faktiska rektanglarna går ett fynd inte att granska,
            // och ett mätartefakt går inte att skilja från en verklig avvikelse.
            rects: { el: [+er.left.toFixed(1), +er.top.toFixed(1), +er.width.toFixed(1), +er.height.toFixed(1)],
                     anc: [+ar.left.toFixed(1), +ar.top.toFixed(1), +ar.width.toFixed(1), +ar.height.toFixed(1)] },
            svgKontext: !!(el.ownerSVGElement || el.tagName.toLowerCase() === 'svg') });
        }
      }
      // R-03c · En overflow-DEKLARATION är ingen klippning. Den är en
      // riskindikator. Ett fel kräver bevis: innehåll som faktiskt sticker ut
      // ur den klippande boxen. Varje traff klassas darfor, och bara klassen
      // klippt ar en avvikelse. (Inga bakstreck-citat har: de avslutar mallstrangen.)
      if (/hidden|clip/.test(cs.overflow + cs.overflowX + cs.overflowY)) {
        const ovX = el.scrollWidth - el.clientWidth, ovY = el.scrollHeight - el.clientHeight;
        // Sticker något barn ut ur den här boxens klientbox?
        // clientWidth/clientHeight är NOLL på <svg> och på alla SVG-barn i
        // Chrome — de är inte HTML-boxar. Att jämföra ett barn mot en nollstor
        // klientbox får varje ikon att se ut att spilla över. Mät därför mot
        // den faktiska rektangeln när elementet är SVG.
        const svgKontext = !!(el.ownerSVGElement || el.tagName.toLowerCase() === 'svg');
        const boxR = svgKontext ? er.right : er.left + el.clientLeft + el.clientWidth;
        const boxB = svgKontext ? er.bottom : er.top + el.clientTop + el.clientHeight;
        let childOut = 0, offender = null, offenderPath = null, offenderKey = null, offenderAxis = null;
        for (const kid of el.children) {
          if (UTAN_BOX.has(kid.tagName.toLowerCase())) continue;
          const kr = kid.getBoundingClientRect();
          const oX = Math.max(0, kr.right - boxR), oB = Math.max(0, kr.bottom - boxB);
          const o = oX + oB;
          if (o > 1 && o > childOut) {
            childOut = o;
            offender = kid.tagName.toLowerCase() + (clsOf(kid) ? '.' + clsOf(kid).slice(0, 20) : '');
            offenderPath = nodePath(kid, it);
            offenderKey = elementKey(kid, it).key;
            offenderAxis = (oX > 1 && oB > 1) ? 'xy' : (oX > 1 ? 'x' : 'y');
          }
        }
        let klass, why;
        if (!mätbar) { klass = 'verktygsfel'; why = 'nollstor eller dold box — klippning går inte att avgöra'; }
        else if (desc.intent) { klass = 'avsiktlig'; why = 'deklarerad orsak: ' + desc.intent; }
        else if (ovX > 1 || ovY > 1 || childOut > 1) {
          klass = 'verifierad';
          why = 'innehåll utanför boxen: scroll ' + Math.max(ovX, 0) + '×' + Math.max(ovY, 0) +
                (childOut > 1 ? ', barn ' + childOut.toFixed(1) + ' px (' + offender + ')' : '');
        } else { klass = 'observation'; why = 'overflow ' + cs.overflow + ' deklarerad, men inget innehåll sticker ut'; }
        c3.push({ ...desc, klass, why, subtype: 'klippning', detaljsubtyp: 'deklarerad-klippning',
          axis: (ovX > 1 && ovY > 1) ? 'xy' : (ovX > 1 ? 'x' : (ovY > 1 ? 'y' : offenderAxis)),
          overflow: cs.overflow,
          w: +er.width.toFixed(1), h: +er.height.toFixed(1),
          scrollOverX: Math.max(0, ovX), scrollOverY: Math.max(0, ovY), childOut: +childOut.toFixed(1),
          offenderPath, offenderKey, offenderAxis,
          svgKontext, clientW: el.clientWidth, clientH: el.clientHeight });
      }

      // R-03d · En DEKLARERAD ellips eller line-clamp är ingen trunkering.
      // Avvikelse kräver bevis: texten ryms faktiskt inte i sin box.
      const clamp = cs.webkitLineClamp && cs.webkitLineClamp !== 'none' ? cs.webkitLineClamp : null;
      if ((cs.textOverflow && cs.textOverflow !== 'clip') || clamp) {
        const övX = el.scrollWidth - el.clientWidth, övY = el.scrollHeight - el.clientHeight;
        const ellipsTrunkerad = cs.textOverflow === 'ellipsis' && övX > 1;
        const clampTrunkerad = !!clamp && övY > 1;
        let klass, why;
        if (!mätbar) { klass = 'verktygsfel'; why = 'nollstor eller dold box — trunkering går inte att avgöra'; }
        else if (desc.intent) { klass = 'avsiktlig'; why = 'deklarerad orsak: ' + desc.intent; }
        else if (ellipsTrunkerad) { klass = 'verifierad'; why = 'texten trunkeras: ' + övX + ' px bredare än boxen med text-overflow: ' + cs.textOverflow; }
        else if (clampTrunkerad) { klass = 'verifierad'; why = 'texten trunkeras: ' + övY + ' px högre än boxen med line-clamp ' + clamp; }
        else { klass = 'observation'; why = 'deklarerad ' + (clamp ? 'line-clamp ' + clamp : 'text-overflow: ' + cs.textOverflow) + ', men texten ryms'; }
        d3.push({ ...desc, klass, why,
          subtype: 'textrunkering', detaljsubtyp: clamp ? 'line-clamp' : 'text-overflow',
          axis: clampTrunkerad ? 'y' : (ellipsTrunkerad ? 'x' : (clamp ? 'y' : 'x')),
          textOverflow: cs.textOverflow, lineClamp: clamp,
          textOverX: Math.max(0, övX), textOverY: Math.max(0, övY) });
      }
      // Omätbart: nollstora element med innehåll, eller transformerade ytor.
      if (er.width === 0 && er.height === 0 && el.childNodes.length && cs.display !== 'none')
        unknown.push({ ...desc, why: 'nollstor rektangel med innehåll — går inte att mäta' });
      if (cs.transform && cs.transform !== 'none' && (ox > 1 || oy > 1))
        unknown.push({ ...desc, why: 'transformerad yta med overflow — mätningen är inte säker' });
    }
    // F2-R04 · UNDERLAG FÖR TEMAPARNING. Två maskinobservationer, inga beslut:
    //  · bakgrundens uppmätta luminans — om artefakten FAKTISKT ritas mörk.
    //  · en strukturell fingeravtryck av kontrollerna (roll, namn, tillstånd) och
    //    av taggskelettet. Filnamn och rubrik ingår inte: de är inte beslut.
    // .sc-item är oftast genomskinlig — den ärver sidans ljusa botten. Den yta
    // som faktiskt bär temat är den STÖRSTA ogenomskinliga bakgrunden inuti
    // artefakten (telefonramen). Utan detta mäts sidan, inte ritningen.
    let bgEl = it, bgArea = 0;
    for (const el of [it, ...it.querySelectorAll('*')]) {
      const c = parse(getComputedStyle(el).backgroundColor);
      if (!c || c[3] < 0.9) continue;
      const b = el.getBoundingClientRect(), area = b.width * b.height;
      if (area > bgArea) { bgArea = area; bgEl = el; }
    }
    const bgArt = bgArea > 0 ? { rgb: parse(getComputedStyle(bgEl).backgroundColor).slice(0, 3) } : bgOf(it);
    const L = bgArt.rgb ? +lum(bgArt.rgb).toFixed(4) : null;
    const rollrad = [...it.querySelectorAll('[data-a11y-role]')]
      .map(c => c.getAttribute('data-a11y-role') + ':' + (c.getAttribute('data-a11y-name') || '')).join('|');
    const skelett = [...it.querySelectorAll('*')].map(e => e.tagName.toLowerCase()).join('.');
    const h32 = s => { let h = 5381; for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0; return h.toString(16); };

    out.artifacts.push({ id: it.id || null,
      rect: { w: +r.width.toFixed(2), h: +r.height.toFixed(2) },
      bg: { rgb: bgArt.rgb || null, oreducerbar: bgArt.unreducible || null, luminans: L,
            uppmätt: L === null ? 'okänd' : (L < 0.18 ? 'mörk' : 'ljus') },
      fingeravtryck: { roller: h32(rollrad), rollantal: rollrad ? rollrad.split('|').length : 0,
                       skelett: h32(skelett), noder: skelett ? skelett.split('.').length : 0,
                       rollrad: rollrad.slice(0, 400) },
      scrollW: it.scrollWidth, scrollH: it.scrollHeight,
      clientW: it.clientWidth, clientH: it.clientHeight,
      overflowsViewport: r.width > innerWidth + 1,
      controls,
      // KAPPNING SKA SYNAS. En tyst slice(0,40) gör dedupliceringen ofullständig
      // utan att någon märker det. Vi tar med allt och redovisar om taket nås.
      r03a: cap(a3), r03aTotal: a3.length, r03aKlass: klasser(a3),
      r03b: cap(b3), r03bTotal: b3.length, r03bKlass: klasser(b3),
      r03c: cap(c3), r03cTotal: c3.length, r03cKlass: klasser(c3),
      r03d: cap(d3), r03dTotal: d3.length, r03dKlass: klasser(d3),
      kapad: [a3, b3, c3, d3].some(x => x.length > TAK),
      unknown: unknown.slice(0, 20), unknownTotal: unknown.length });
  }
  return out;
})()`;
