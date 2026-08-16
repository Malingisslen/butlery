// F2-NT · MATSKRIPTET FOR ICKE-TEXTUELL KONTRAST.
//
// TVA STEG, I DEN HAR ORDNINGEN:
//
//   1  ROLLEN avgors. Vilken grafik BEHOVS for att se att kontrollen finns
//      (componentIdentityCarrier) och for att uppfatta dess tillstand
//      (stateCarrier)? Vad forstarker bara nagot som redan ar identifierbart
//      (supplemental)? Vad betyder ingenting (decorative)?
//
//   2  KONTRASTEN mats — men bara for carriers, och alltid mot den yta
//      carriern faktiskt ligger MOT.
//
// Kontrastvardet far ALDRIG paverka steg 1. En yta pa 1,00 kan vara helt
// redundant ELLER den enda avsedda signalen, och skillnaden avgors av
// komponentens struktur, inte av hur svag fargen rakar vara.
//
// Fargmotorn ar R-01:s verifierade — luminans, alfakomposition och
// bakgrundsupplosning. Text-run-modellen anvands inte: ett grafiskt element
// malas av nagot annat an en textnod.

import { FARGMOTOR } from './colour-engine.mjs';

export const NONTEXT_MEASURE = `(() => {
  /* ── Fargmotorn, delad med grafik utanfor kontroller ─────────────────── */
  ${FARGMOTOR}

  /* ── Hjalpare for struktur, inte for farg ─────────────────────────────── */
  const synligText = el => {
    // Bara text som FAKTISKT renderas raknas som identifierande.
    let t = '';
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    let n; while ((n = w.nextNode())) {
      const s = (n.textContent || '').trim(); if (!s) continue;
      const m = n.parentElement; if (!m) continue;
      if (getComputedStyle(m).visibility !== 'visible') continue;
      const r = document.createRange(); r.selectNodeContents(n);
      if (![...r.getClientRects()].some(x => x.width > 0 && x.height > 0)) continue;
      t += s + ' '; }
    return t.trim(); };
  const CHEVRON = /chevron|caret|arrow|expand|collapse|pil/i;
  const BOCK = /check|bock|tick/i;
  // Aldrig in i en ANNAN semantisk kontrolls subtrad. Den kontrollen har sin
  // egen grafik och sin egen bedomning.
  const egenSubtrad = (el, rot) => { let n = el;
    while (n && n !== rot) { if (n.hasAttribute('data-a11y-role')) return false; n = n.parentElement; }
    return true; };
  const UNDANTAGEN = e => { const v = e.getAttribute('data-graphic-role');
    return v === 'redundant' || v === 'decorative'; };
  const glyfer = el => [...el.querySelectorAll('svg, [data-icon]')]
    .filter(e => (e.tagName.toLowerCase() === 'svg' || e.hasAttribute('data-icon')) &&
      egenSubtrad(e, el) && !UNDANTAGEN(e));
  const harRam = el => { const c = getComputedStyle(el);
    return ['borderTopWidth','borderBottomWidth','borderLeftWidth','borderRightWidth']
      .some(k => parseFloat(c[k]) > 0); };
  // En OMSLUTANDE kant ritar en form. En kant pa en enda sida ar en avdelare
  // mellan rader och ritar ingen kontroll. Skillnaden anvands nar en
  // valkontrolls visuella struktur ska letas upp i en storre behallare: en
  // listrad med border-bottom far aldrig raknas som sjalva reglaget.
  const harOmslutandeRam = el => { const c = getComputedStyle(el);
    return ['borderTopWidth','borderBottomWidth','borderLeftWidth','borderRightWidth']
      .every(k => parseFloat(c[k]) > 0); };
  const harFyllning = el => { const c = parse(getComputedStyle(el).backgroundColor);
    return !!c && c[3] > 0; };
  const rect = el => { const r = el.getBoundingClientRect();
    return { w: +r.width.toFixed(2), h: +r.height.toFixed(2), x: +r.left.toFixed(2), y: +r.top.toFixed(2) }; };

  const VALKONTROLL = new Set(['checkbox', 'radio', 'switch']);
  const TILLSTANDSROLL = new Set(['tab', 'button', 'menuitem', 'link']);

  /* ── CHILD-DESCENT · den synliga formen kan ligga under agaren ────────── */
  //
  // R-02-modellen gjorde traffytan till ett genomskinligt element och flyttade
  // den synliga formen till ett barn. Agare och visuell barare ar darfor inte
  // alltid samma nod. Descent ar tillaten — men bara nar den ger ett ENTYDIGT
  // svar.
  //
  // Regeln "forsta barnet med ram eller fyllning" anvands INTE. Den skulle
  // valja nagot aven nar ritningen inte pekar ut nagot, och det ar precis vad
  // fail closed ska hindra. Kontrast lases aldrig har.
  //
  // ROW-OWNED CONTROL: rollen kan sitta pa hela listraden. Raden innehaller
  // da bade en textkolumn och den verkliga visuella kontrollen. Formen letas
  // darfor bland element med en OMSLUTANDE avgransning — en fyllning eller en
  // ram runt om. En textkolumn har varken, och en avdelarlinje under raden ar
  // ingen form. Ingen geometri, ingen DOM-position, ingen kontrast anvands.
  function visuellForm(c) {
    // AUTHORED UNDANTAG. Ett element inuti en kontroll kan vara deklarerat som
    // redundant eller decorative. Da ar det inte kontrollens form, hur fylld
    // det an ar. Samma attribut och samma semantik som for grafik utanfor
    // kontroller — ingen ny mekanism, ingen artefaktspecifik regel.
    const undantagen = e => { const v = e.getAttribute('data-graphic-role');
      return v === 'redundant' || v === 'decorative'; };
    const omslutande = e => !undantagen(e) && (harOmslutandeRam(e) || harFyllning(e));
    const inomAlla = [...c.querySelectorAll('*')].filter(e => egenSubtrad(e, c) && !undantagen(e));
    const inreFormer = inomAlla.filter(omslutande);

    // AUTHORED EVIDENS FORST. Ritningen kan sjalv peka ut vilket element som
    // ar komponenten, med data-component. Det ar en deklaration i kallan av
    // samma slag som data-hit och data-state-group, inte en heuristik, och
    // den gar fore all harledning. En listrad kan ha egen fyllning och egen
    // avdelarlinje utan att vara kontrollen; deklarationen avgor.
    if (!c.hasAttribute('data-component')) {
      const deklarerade = inomAlla.filter(e => e.hasAttribute('data-component'));
      if (deklarerade.length === 1) {
        const form = deklarerade[0];
        const inuti = inreFormer.filter(e => e !== form && form.contains(e));
        return { identitet: form, tillstand: inuti.length === 1 ? inuti[0] : null,
          grund: 'exakt ett element i kontrollens subtrad ar deklarerat med data-component' };
      }
      if (deklarerade.length > 1)
        return { identitet: null, tillstand: null,
          grund: deklarerade.length + ' element i subtradet ar deklarerade med data-component — vilket som ar kontrollen gar inte att avgora' };
    }
    // Agaren ar sjalv formen bara om den ar omslutande avgransad OCH inte ar
    // en behallare med en egen avgransad kontroll i sig.
    if (omslutande(c) && inreFormer.length <= 1)
      return { identitet: c, tillstand: inreFormer[0] || null,
        grund: inreFormer.length ? 'agaren ar sjalv formen och har ett avgransat barn som bar tillstandet'
          : 'agaren har egen omslutande boundary' };
    if (inreFormer.length === 1 && !omslutande(c))
      return { identitet: inreFormer[0], tillstand: null,
        grund: 'exakt ett element i kontrollens egen subtrad ritar en omslutande form' };
    if (inreFormer.length === 2) {
      const [a, b] = inreFormer;
      if (a.contains(b)) return { identitet: a, tillstand: b,
        grund: 'track och knopp i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
      if (b.contains(a)) return { identitet: b, tillstand: a,
        grund: 'track och knopp i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
    }
    if (inreFormer.length >= 2) {
      // AUTHORED EVIDENS. Ritningen kan sjalv peka ut vilken form som ar
      // komponenten, med data-component. Det ar en deklaration i kallan, av
      // samma slag som data-hit och data-state-group, och inte en heuristik.
      // Den anvands bara nar strukturen ar tvetydig, och bara nar den ar
      // entydig i sig.
      const deklarerade = inreFormer.filter(e => e.hasAttribute('data-component'));
      if (deklarerade.length === 1) {
        const form = deklarerade[0];
        const inuti = inreFormer.filter(e => e !== form && form.contains(e));
        return { identitet: form, tillstand: inuti.length === 1 ? inuti[0] : null,
          grund: 'flera avgransade former i behallaren, men exakt en ar deklarerad med data-component' };
      }
      if (inreFormer.length === 2)
        return { identitet: null, tillstand: null,
          grund: 'tva avgransade former som syskon i behallaren — vilken som ar kontrollen gar inte att avgora' };
      return { identitet: null, tillstand: null,
        grund: inreFormer.length + ' avgransade former i behallaren — flera plausibla kontrollstrukturer' };
    }
    // Ingen omslutande form. Fall tillbaka pa den ursprungliga modellen, som
    // ocksa accepterar en ram pa en enda sida — for kontroller som INTE ar
    // rader utan sjalva ar den lilla rutan.
    if (harRam(c) || harFyllning(c)) return { identitet: c, tillstand: null, grund: 'agaren har egen boundary' };
    const inom = inomAlla;
    const avgransade = inom.filter(e => harRam(e) || harFyllning(e));
    const g = glyfer(c);
    const bockar = g.filter(e => BOCK.test(e.getAttribute('data-icon') || ''));
    const ovrigaGlyfer = g.filter(e => !bockar.includes(e));

    if (avgransade.length === 1)
      return { identitet: avgransade[0], tillstand: bockar[0] || null,
        grund: 'exakt ett element i kontrollens egen subtrad ritar en avgransad form' };

    if (avgransade.length === 2) {
      // Track och thumb: den yttre rymmer den inre. Tva syskon gor det inte.
      const [a, b] = avgransade;
      if (a.contains(b)) return { identitet: a, tillstand: b, grund: 'tva avgransade element i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
      if (b.contains(a)) return { identitet: b, tillstand: a, grund: 'tva avgransade element i nastlad kedja — den yttre ar formen, den inre bar tillstandet' };
      return { identitet: null, tillstand: null, grund: 'tva avgransade element som syskon — vilket som ar kontrollens form gar inte att avgora' };
    }
    if (avgransade.length > 2)
      return { identitet: null, tillstand: null, grund: avgransade.length + ' avgransade element i subtradet — formen gar inte att avgora entydigt' };

    // Ingen avgransad form. Ar kontrollen ritad SOM en glyf?
    if (ovrigaGlyfer.length === 1)
      return { identitet: ovrigaGlyfer[0], tillstand: bockar[0] || null,
        grund: 'kontrollen ar ritad som en glyf och exakt en glyf bar formen' };
    if (ovrigaGlyfer.length > 1)
      return { identitet: null, tillstand: null, grund: ovrigaGlyfer.length + ' glyfer med olika funktion — vilken som ar kontrollens form gar inte att avgora' };
    return { identitet: null, tillstand: bockar[0] || null, grund: 'varken avgransad form eller glyf i kontrollens subtrad' };
  }

  const ut = [];
  window.__NT_EL = [];
  for (const c of document.querySelectorAll('[data-a11y-role]')) {
    const it = c.closest('.sc-item'); if (!it) continue;
    const roll = c.getAttribute('data-a11y-role');
    const namn = c.getAttribute('data-a11y-name') || '';
    const state = c.getAttribute('data-a11y-state');
    const disabled = /(^|[,;\\s])(disabled|inaktiv|avst[aä]ngd)([,;\\s]|$)/i.test(state || '') ||
      c.hasAttribute('disabled') || c.getAttribute('aria-disabled') === 'true';
    const text = synligText(c);
    const harEgenText = text.length > 0;
    const g = glyfer(c);
    const delar = [];
    // De icke-fargbaserade signalerna ska lasas av den nod som FAKTISKT malar
    // kontrollen. Lases de av den genomskinliga agaren blir varje form- och
    // lagesskillnad osynlig, och allt ser ut som color-only.
    let bararEl = c;
    // Spar och knopp for reglagets LAGESSIGNAL. De satts BARA av den
    // strukturella agarskapsanalysen. bararEl duger inte: den faller tillbaka
    // pa agaren nar formen inte gar att avgora, och da vore "sparet" hela
    // listraden. Ett lage matt mot fel box ar inget lage.
    let sparEl = null, knoppEl = null;

    /* ── STEG 1 · ROLLEN. Ingen kontrast lases har. ────────────────────── */

    if (VALKONTROLL.has(roll)) {
      // Valkontroller identifieras av sin egen ruta, inte av etiketten:
      // etiketten sager VAD valet galler, inte att det ar ett val.
      const bock = g.find(e => BOCK.test(e.getAttribute('data-icon') || ''));
      const form = visuellForm(c);
      if (form.identitet) {
        const e = form.identitet;
        bararEl = e;
        if (roll === 'switch') sparEl = e;
        const typ = harRam(e) ? 'ram' : harFyllning(e) ? 'fyllning' : 'glyf';
        delar.push({ typ, roll_i_kontrollen: 'componentIdentityCarrier',
          motivering: 'valkontrollens egen ruta ar det som visar att en valkontroll finns; etiketten identifierar bara vad valet galler — ' + form.grund,
          el: e, motEl: e.parentElement || c, mot: 'yttre', descent: e !== c });
      } else delar.push({ typ: 'saknas', roll_i_kontrollen: 'unknown',
        motivering: 'valkontrollens form gar inte att avgora: ' + form.grund,
        el: c, mot: null });
      // Tillstandsgrafiken matas mot den yta den faktiskt ligger PA. Det ar
      // elementet som direkt innehaller den, inte kontrollens identitetsform:
      // i ett radiokort ligger bocken i en liten fylld prick inuti kortet, och
      // det ar prickens farg den ska sta emot.
      const inreYta = form.identitet || c;
      if (bock) delar.push({ typ: 'bock', roll_i_kontrollen: 'stateCarrier',
        motivering: 'bocken ar den grafik som visar att kontrollen ar ikryssad',
        el: bock, motEl: bock.parentElement || inreYta, mot: 'inre' });
      // Knoppen kommer BARA fran den strukturella analysen. Ingen fallback
      // till "forsta barnet": i en listrad ar forsta barnet textkolumnen, och
      // den malar ingenting.
      const thumb = roll === 'switch' && form.tillstand && form.tillstand !== bock
        ? form.tillstand : null;
      if (thumb) { knoppEl = thumb;
        delar.push({ typ: 'thumb', roll_i_kontrollen: 'stateCarrier',
          motivering: 'reglagets knopp och dess lage visar on eller off',
          el: thumb, motEl: thumb.parentElement || inreYta, mot: 'inre' }); }
      const anvand = new Set([form.identitet, bock, thumb].filter(Boolean));
      for (const e of g) if (!anvand.has(e)) delar.push({ typ: 'ikon',
        roll_i_kontrollen: 'supplemental',
        motivering: 'ytterligare glyf i en valkontroll som redan identifieras av sin ruta',
        el: e, motEl: inreYta, mot: 'inre' });
    } else if (!harEgenText) {
      // Ikonkontroll: glyfen ar det enda som visar att kontrollen finns.
      if (g.length) for (const e of g) delar.push({ typ: 'ikon',
        roll_i_kontrollen: 'componentIdentityCarrier',
        motivering: 'kontrollen har ingen synlig text — glyfen ar det enda som identifierar den',
        el: e, motEl: e.parentElement || c, mot: 'yttre' });
      else {
        const form = visuellForm(c);
        if (form.identitet) bararEl = form.identitet;
        if (form.identitet) delar.push({ typ: harRam(form.identitet) ? 'ram' : 'fyllning',
          roll_i_kontrollen: 'componentIdentityCarrier',
          motivering: 'kontrollen har varken text eller glyf — dess egen yta ar det som identifierar den — ' + form.grund,
          el: form.identitet, motEl: form.identitet.parentElement || c, mot: 'yttre',
          descent: form.identitet !== c });
        else delar.push({ typ: 'saknas', roll_i_kontrollen: 'unknown',
          motivering: 'kontrollen har varken text eller glyf och ' + form.grund,
          el: c, mot: null });
      }
    } else {
      // Textmarkt kontroll: texten identifierar komponenten. Men en glyf kan
      // anda bara TILLSTANDET, och det avgors av glyfens funktion — inte av
      // hur den ser ut fargmassigt.
      for (const e of g) {
        const ikon = e.getAttribute('data-icon') || '';
        const barState = state && TILLSTANDSROLL.has(roll) && CHEVRON.test(ikon);
        delar.push({ typ: 'ikon',
          roll_i_kontrollen: barState ? 'stateCarrier' : 'supplemental',
          motivering: barState
            ? 'kontrollen har ett tillstand och glyfen ar riktningsbarande — den visar oppet eller stangt'
            : 'kontrollen identifieras av sin synliga text; glyfen forstarker men behovs inte for identiteten',
          el: e, motEl: e.parentElement || c, mot: 'yttre' });
      }
      if (harFyllning(c)) delar.push({ typ: 'fyllning', roll_i_kontrollen: 'supplemental',
        motivering: 'kontrollen identifieras av sin synliga text; fyllningen forstarker',
        el: c, mot: 'yttre' });
      if (harRam(c)) delar.push({ typ: 'ram', roll_i_kontrollen: 'supplemental',
        motivering: 'kontrollen identifieras av sin synliga text; ramen forstarker',
        el: c, mot: 'yttre' });
    }

    /* ── STEG 1b · KONTROLLENS EGEN MALADE GRANS ───────────────────────
     *
     * En malad kontrollgrans ar en grans oavsett om kontrollen bar text,
     * glyf eller bada. Fram till hit rakenades gransen BARA i den
     * textmarkta grenen. Exakt samma fysiska kant blev darfor en grafisk
     * del pa en textknapp men foll bort pa en ikonknapp — inte for att
     * kanten skilde sig, utan for att en textnod fanns eller saknades.
     * Textnoder ar ingen egenskap hos en kant.
     *
     * Gransen enumereras darfor har, en gang, for det element som
     * FAKTISKT malar den. Dubbletter avvisas pa elementidentitet plus typ,
     * sa att samma fysiska kant aldrig ger tva delar. Bararrollen ar
     * OFORANDRAD: den avgors fortfarande av bararrollsmodellen ovan.
     * Detta steg andrar vad som RAKNAS och MATS, aldrig vad som kravs. */
    //
    // NAR den maladea bararen ar utpekad av den strukturella analysen racker
    // en malad kant, precis som i den textmarkta grenen. NAR steget i stallet
    // faller tillbaka pa kontrollelementet sjalvt kravs en OMSLUTANDE kant:
    // en enda sida ar en avdelare mellan rader och ritar ingen kontroll, och
    // ett fallback som raknade avdelare skulle uppfinna granser som inte finns.
    const gransEl = (bararEl && bararEl !== c && harRam(bararEl)) ? bararEl
      : (harRam(c) && (bararEl === c ? true : harOmslutandeRam(c)) ? c : null);
    if (gransEl && !delar.some(d => d.el === gransEl && d.typ === 'ram'))
      delar.push({ typ: 'ram', roll_i_kontrollen: 'supplemental',
        motivering: 'kontrollens egen malade grans; enumererad oberoende av text och glyf',
        el: gransEl, motEl: gransEl.parentElement || c, mot: 'yttre' });

    /* ── STEG 2 · KONTRASTEN, bara for carriers ───────────────────────── */
    const matta = delar.map(d => {
      const bas = { typ: d.typ, carrier: d.roll_i_kontrollen, motivering: d.motivering,
        ikon: d.el && d.el.getAttribute ? (d.el.getAttribute('data-icon') || null) : null,
        descent: !!d.descent };
      /* GRANSMATNING · en malad kontrollgrans mats ALLTID, oberoende av
       * bararrollen och oberoende av om kontrollen bar text. Detta ar en
       * REDOVISNING: carrier och status styrs fortfarande av
       * bararrollsmodellen och paverkas inte av matningen. Falten ligger i
       * ett eget objekt sa att ingen befintlig lasare byter betydelse. */
      if (d.typ === 'ram' && d.el && d.el.getAttribute) {
        const gcs = getComputedStyle(d.el);
        const gsidor = ['Top','Right','Bottom','Left'].filter(s =>
          (parseFloat(gcs['border' + s + 'Width']) || 0) > 0 &&
          gcs['border' + s + 'Style'] !== 'none');
        const gbg = bakgrundBakom(d.motEl || d.el.parentElement || c);
        const gf = gsidor.length ? parse(gcs['border' + gsidor[0] + 'Color']) : null;
        if (gsidor.length && gf && !gbg.oreducerbar) {
          const gfk = gf[3] < 1 ? over(gf, gbg.rgb) : gf.slice(0, 3);
          bas.grans = { sidor: gsidor.length, bredd: gcs['border' + gsidor[0] + 'Width'],
            stil: gcs['border' + gsidor[0] + 'Style'], farg: fargRgb(gfk),
            angransande: fargRgb(gbg.rgb), kvot: kvot(gfk, gbg.rgb) };
        } else bas.grans = { sidor: gsidor.length, bredd: null, stil: null, farg: null,
          angransande: null, kvot: null,
          varfor: !gsidor.length ? 'ingen malad kant' :
            (!gf ? 'kantfargen kunde inte tolkas' : 'oreducerbar angransande farg') };
      }
      if (d.roll_i_kontrollen === 'supplemental' || d.roll_i_kontrollen === 'decorative' ||
          d.roll_i_kontrollen === 'unknown' || !d.mot)
        return { ...bas, kvot: null, status: d.roll_i_kontrollen === 'unknown' ? 'unknown' : 'ejKravd' };
      // Vilken yta ska den kontrastera MOT? Den yta som FAKTISKT ar malad
      // direkt bakom bararen, enligt malnings- och innehallsstrukturen. En
      // ikon som ligger pa knappens egen fyllning jamfors med fyllningen,
      // aldrig med ytan utanfor knappen. Ingen "narmsta farg"-heuristik:
      // bakgrundBakom foljer foraldrakedjan tills nagot faktiskt ar malat.
      const motEl = d.motEl || (d.mot === 'inre' ? c : (c.parentElement || c));
      const bg = bakgrundBakom(motEl);
      if (bg.oreducerbar) return { ...bas, kvot: null, status: 'unknown',
        varfor: 'oreducerbar angransande farg: ' + bg.oreducerbar };
      let f = null;
      if (d.typ === 'ram') f = parse(getComputedStyle(d.el).borderTopColor);
      else if (d.typ === 'fyllning' || d.typ === 'thumb') f = parse(getComputedStyle(d.el).backgroundColor);
      else f = parse(glyfFarg(d.el));
      if (!f) return { ...bas, kvot: null, status: 'unknown', varfor: 'fargen kunde inte tolkas' };
      const fk = f[3] < 1 ? over(f, bg.rgb) : f.slice(0, 3);
      return { ...bas, kvot: kvot(fk, bg.rgb), status: 'matt',
        farg: fargRgb(fk), angransande: fargRgb(bg.rgb),
        motYta: d.mot === 'inre' ? 'kontrollens inre yta' : 'ytan utanfor kontrollen' };
    });

    ut.push({ art: it.id, roll, namn: namn || null, state, disabled,
      // Identiteten for color-only ar authored och lases ORORD har. Den
      // valideras i colour-only.mjs, aldrig i browsern.
      stateGroup: c.getAttribute('data-state-group'),
      harEgenText, text: text.slice(0, 30),
      glyfer: g.map(e => e.getAttribute('data-icon') || '(namnlos)'),
      // Icke-fargbaserade signaler, for color-only-sparet.
      signaler: { bock: g.some(e => BOCK.test(e.getAttribute('data-icon') || '')),
        chevron: g.some(e => CHEVRON.test(e.getAttribute('data-icon') || '')),
        text: harEgenText, glyfNamn: g.map(e => e.getAttribute('data-icon') || '').filter(Boolean).sort().join(','),
        // Ihalig ram mot massiv yta ar en skillnad i form, inte i farg. Den
        // syns aven for den som inte uppfattar kulor.
        avgransning: ((harRam(bararEl) ? 'ram' : '') + (harFyllning(bararEl) ? 'fyllning' : '')) || 'ingen',
        barnAntal: bararEl.children.length,
        // KNOPPENS LAGE MATS UR FAKTISK RENDERAD GEOMETRI, inte ur CSS.
        //
        // Den forra modellen laste justify-content pa bararen. Den ar
        // implementationsspecifik: den ser flexplacerade knoppar men ar blind
        // for absolut placerade, som star pa "normal" i BADA tillstanden. Ett
        // reglage vars knopp bevisligen flyttar sig 16 px klassades da som
        // color-only. Det var en lucka i matningen, inte ett fel i produkten.
        //
        // Har lamnas bara RA GEOMETRI. Klassificeringen sker i colour-only.mjs,
        // enligt samma ordning som gruppidentiteten: browsern mater, Node
        // bedomer. Spar och knopp kommer uteslutande fran den strukturella
        // agarskapsanalysen — saknas nagon av dem blir svaret null och
        // bedomningen fail closed. Aldrig radens eller sidans box.
        knoppGeometri: roll === 'switch'
          ? (sparEl && knoppEl ? { spar: rect(sparEl), knopp: rect(knoppEl) } : null)
          : null,
        knoppGeometriVarfor: roll !== 'switch' ? null
          : sparEl && knoppEl ? 'spar och knopp entydigt utpekade av strukturanalysen'
          : !sparEl ? 'sparets agarskap gar inte att avgora: ' + visuellForm(c).grund
          : 'knoppens agarskap gar inte att avgora: ' + visuellForm(c).grund,
        form: rect(bararEl).w + 'x' + rect(bararEl).h,
        bararArAgaren: bararEl === c },
      // DIAGNOSTIK. Aldrig normativ. Finns for att kunna se VILKEN teknik en
      // implementation anvander nar en avvikelse ska forklaras.
      diagnostik: roll === 'switch' && sparEl
        ? { justifyContent: getComputedStyle(sparEl).justifyContent,
            knoppPosition: knoppEl ? getComputedStyle(knoppEl).position : null } : null,
      delar: matta });
    // Elementreferenserna lamnas kvar i sidan sa att kallrotorsaksanalysen
    // kan lasa VILKET element varje del avser utan att gissa. Detta paverkar
    // inte returvardet och darmed inte baslinjen.
    (window.__NT_EL = window.__NT_EL || []).push(delar.map(d => d.el || null));
  }
  return ut;
})()`;
