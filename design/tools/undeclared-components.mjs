// F2 · RIKTAD KONTROLL FOR ODEKLARERADE KOMPONENTER.
//
// Kontrollcensusen definieras av en authored deklaration: ett element ar en
// kontroll nar det, eller nagon forfader inom artefakten, bar data-a11y-role.
// Regeln ar riktig, men den har en tyst konsekvens: en komponent som aldrig
// blivit anmald ar per konstruktion osynlig for censusen. BG-020 upptacktes
// bara som en sidoeffekt i grafikspåret.
//
// Modulen listar de komponentstrukturer som SER UT att vara av en registrerad
// komponenttyp men saknar anmalan. Den doper dem INTE till kontroller.
// Utfallet ar KANDIDAT tills en semantisk adjudicering finns.
//
// VIKTIGT OM ACCESSIBILITY-TRADET: i den har korpusen ar .dc.html-filerna
// designspecifikationer. data-a11y-role ar en authored annotering som
// konsumeras nedstroms, inte ett levande ARIA-attribut. Ett prov pa 76
// korrekt deklarerade kontroller gav 0 exponerade roller i Chromes
// accessibility-trad. Tradet kan darfor varken bekrafta eller motbevisa
// exponering har, och far inte anvandas som evidens i nagon riktning.

export const KANDIDATGRIND = Object.freeze([
  'elementet bar ett authored data-component, ELLER',
  'elementet ar ett pillerformat spar med ett absolut placerat runt barn',
  'och varken elementet sjalvt eller nagon forfader inom artefakten bar data-a11y-role'
]);

export const VERDIKT = Object.freeze({
  INTERACTIVE_CONTROL: 'INTERACTIVE_CONTROL',
  NON_INTERACTIVE_STATE_GRAPHIC: 'NON_INTERACTIVE_STATE_GRAPHIC',
  DECORATIVE_GRAPHIC: 'DECORATIVE_GRAPHIC',
  UNKNOWN: 'UNKNOWN'
});

// En komponenttyp raknas som konventionellt entydig nar sa gott som varje
// forekomst i korpusen redan ar anmald som kontroll. Troskeln ar satt hogt
// med flit: den ska fanga "typen ar alltid en kontroll", inte "typen ar ofta
// en kontroll". Vid 0.9 kvalificerar toggle (32 av 34) medan checkbox (53 av
// 131) och chip (13 av 41) inte gor det.
export const TROSKEL_TYPKONVENTION = 0.9;

export const ADJUDICERINGSREGEL = Object.freeze([
  'A INTERACTIVE_CONTROL kravs positiv evidens: antingen en agande deklaration, ' +
    'eller en komponenttyp vars deklarationsgrad i korpusen nar TROSKEL_TYPKONVENTION.',
  'B NON_INTERACTIVE_STATE_GRAPHIC kravs positiv evidens for att objektet visar ' +
    'tillstand utan att vara manovrerbart. Saknad metadata ar inte sadan evidens.',
  'C DECORATIVE_GRAPHIC kravs positiv evidens, till exempel aria-hidden eller en ' +
    'deklarerad dekorativ roll.',
  'D UNKNOWN ar utfallet nar ingen av de tre har positiv evidens. Unknown ar ett ' +
    'giltigt slutresultat och far aldrig tvingas till pass eller till kontroll.',
  'Utseende, geometri och skarmnamn ar aldrig tillrackligt for A, B eller C.',
  'Syskonparitet och lokal skarmkonvention hojer prioriteten i adjudiceringskon ' +
    'men avgor inte verdikt — grannens roll ar inte elementets roll.'
]);

// Deklarationsgrad per komponenttyp, raknad ur hela korpusobservationen.
// post: { komponent, deklarerad }  (deklarerad = egen roll eller roll pa forfader)
export function typkonvention(poster) {
  const per = new Map();
  for (const p of poster) {
    const k = p.komponent || null;
    if (!k) continue;
    if (!per.has(k)) per.set(k, { komponent: k, totalt: 0, deklarerade: 0 });
    const e = per.get(k); e.totalt++; if (p.deklarerad) e.deklarerade++; }
  for (const e of per.values()) {
    e.grad = e.totalt ? e.deklarerade / e.totalt : 0;
    e.entydig = e.grad >= TROSKEL_TYPKONVENTION; }
  return per;
}

// Kandidatgrind. Returnerar true bara for odeklarerade komponentstrukturer.
export function arKandidat(post) {
  if (post.egenA11yRoll) return false;
  if (post.agare) return false;
  return !!post.komponent || !!post.harKnopp;
}

// Evidensinsamling. Ingen slutsats, bara fakta.
export function evidens(post, konvention) {
  const typ = post.komponent ? konvention.get(post.komponent) : null;
  return {
    authoradKomponenttyp: post.komponent || null,
    typkonventionTotalt: typ ? typ.totalt : null,
    typkonventionDeklarerade: typ ? typ.deklarerade : null,
    typkonventionGrad: typ ? Number(typ.grad.toFixed(4)) : null,
    typkonventionEntydig: typ ? typ.entydig : false,
    agandeDeklaration: post.agare ? post.agare.roll : null,
    synligEtikett: post.etikett || null,
    syskonAiDeklareradeKontroller: post.syskonKontroller || 0,
    syskonRoller: post.syskonRoller || [],
    sammaTypDeklareradISkarmen: post.sammaTypDeklareradISkarmen || 0,
    ariaHidden: post.ariaHidden || null,
    interaktionsdeklaration: (post.handlare && post.handlare.length) ? post.handlare : null,
    tabindex: post.tabindex ?? null,
    accessibilityTrad: 'EJ INFORMATIV I DENNA KORPUS',
    strukturellFormEnbart: !post.komponent && !!post.harKnopp
  };
}

// Adjudicering. Exakt ett verdikt, med skalen som ledde dit.
export function adjudicera(post, konvention) {
  const ev = evidens(post, konvention);
  const skal = [];
  if (ev.ariaHidden === 'true') {
    skal.push('aria-hidden="true" ar positiv evidens for dekorativ');
    return { verdikt: VERDIKT.DECORATIVE_GRAPHIC, evidens: ev, skal }; }
  if (ev.agandeDeklaration) {
    skal.push('agande deklaration ' + ev.agandeDeklaration);
    return { verdikt: VERDIKT.INTERACTIVE_CONTROL, kontrolltyp: ev.agandeDeklaration,
      evidens: ev, skal }; }
  if (ev.typkonventionEntydig) {
    skal.push('authored komponenttyp "' + ev.authoradKomponenttyp + '" ar deklarerad som kontroll i ' +
      ev.typkonventionDeklarerade + ' av ' + ev.typkonventionTotalt + ' fall i korpusen (' +
      (ev.typkonventionGrad * 100).toFixed(1) + ' %), over troskeln ' +
      (TROSKEL_TYPKONVENTION * 100) + ' %');
    if (ev.synligEtikett) skal.push('synlig etikett finns: "' + ev.synligEtikett.slice(0, 60) + '"');
    return { verdikt: VERDIKT.INTERACTIVE_CONTROL, kontrolltyp: 'switch', evidens: ev, skal }; }
  if (ev.strukturellFormEnbart)
    skal.push('ingen authored komponenttyp — bara en strukturell form, och formen ar inte evidens');
  else skal.push('komponenttypen "' + ev.authoradKomponenttyp + '" ar deklarerad som kontroll i bara ' +
    ev.typkonventionDeklarerade + ' av ' + ev.typkonventionTotalt + ' fall (' +
    (ev.typkonventionGrad * 100).toFixed(1) + ' %) — under troskeln');
  skal.push('ingen positiv evidens for icke-interaktiv tillstandsgrafik eller dekoration');
  if (ev.syskonAiDeklareradeKontroller)
    skal.push('OBS: ' + ev.syskonAiDeklareradeKontroller +
      ' syskonrader ar deklarerade kontroller — hojer prioritet, avgor inte verdikt');
  return { verdikt: VERDIKT.UNKNOWN, evidens: ev, skal };
}

// Prioritet i adjudiceringskon. Rent en sorteringshjalp — aldrig ett verdikt.
export function prioritet(res) {
  if (res.verdikt !== VERDIKT.UNKNOWN) return 0;
  const e = res.evidens;
  return (e.syskonAiDeklareradeKontroller ? 2 : 0) +
    (e.sammaTypDeklareradISkarmen ? 1 : 0);
}

// Hela svepet. poster = korpusobservationen, redan insamlad ur renderingen.
export function svep(poster) {
  const konvention = typkonvention(poster);
  const kandidater = poster.filter(arKandidat);
  const rader = kandidater.map(p => { const r = adjudicera(p, konvention);
    return { art: p.art, ordinal: p.ordinal, komponent: p.komponent || null,
      identitet: p.art + '|' + p.ordinal, etikett: p.etikett || null,
      ...r, prioritet: prioritet(r) }; });
  const rakn = {};
  for (const v of Object.values(VERDIKT)) rakn[v] = rader.filter(r => r.verdikt === v).length;
  return { konvention: [...konvention.values()], kandidater: rader, rakn,
    summerar: rader.length === Object.values(rakn).reduce((a, b) => a + b, 0) };
}
