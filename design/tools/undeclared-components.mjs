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
// RATTAD 2026-08-14: en tidigare version anvande komponenttypens
// deklarationsgrad i korpusen (>= 90 %) som beslutsregel. Det ar ingen giltig
// semantisk regel — frekvens beskriver hur ofta NAGON ANNAN forekomst blivit
// anmald och sager ingenting om DEN HAR forekomsten. Frekvens ar nu enbart
// stodjande evidens och prioriteringssignal, aldrig tillracklig och aldrig
// nodvandig for ett verdikt.
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

// De fem evidenskraven for INTERACTIVE_CONTROL. Samtliga galler DEN ENSKILDA
// forekomsten. Inget av dem ar en frekvensregel.
export const EVIDENSKRAV = Object.freeze({
  AUTHORED_KOMPONENTTYP: 'elementet bar en authored data-component som namnger en komponenttyp',
  SYNLIG_ETIKETT: 'raden innehaller synlig text vid sidan av komponenten, sa att ett ' +
    'tillgangligt namn kan tas ur befintlig text utan att uppfinnas',
  DEKLARERAT_EXEMPEL: 'det finns minst en DEKLARERAD kontroll i korpusen med samma ' +
    'komponenttyp, samma radsignatur, samma tillstandsstruktur OCH samma agarmodell ' +
    '(rollen sitter pa raden). Exemplet levererar kontrollrollen',
  KONTROLLRADSFORM: 'radens hela innehall ar etikett foljt av komponenten och inget mer',
  INSTALLNINGSKONTEXT: 'raden ligger under en sektionsrubrik'
});

export const ADJUDICERINGSREGEL = Object.freeze([
  'A INTERACTIVE_CONTROL kravs antingen en agande deklaration, eller att SAMTLIGA fem ' +
    'evidenskrav i EVIDENSKRAV ar uppfyllda for just den forekomsten.',
  'B NON_INTERACTIVE_STATE_GRAPHIC kravs positiv evidens for att objektet visar ' +
    'tillstand utan att vara manovrerbart. Saknad metadata ar inte sadan evidens.',
  'C DECORATIVE_GRAPHIC kravs positiv evidens, till exempel aria-hidden.',
  'D UNKNOWN ar utfallet nar ingen av de tre har positiv evidens. Unknown ar ett ' +
    'giltigt slutresultat och far aldrig tvingas till pass eller till kontroll.',
  'Utseende, geometri och skarmnamn ar aldrig tillrackligt for A, B eller C.',
  'Komponenttypens deklarationsgrad i korpusen ar STODJANDE evidens och ' +
    'prioriteringssignal. Den ar varken tillracklig eller nodvandig for A, och den far ' +
    'aldrig ensam gora en typ till UNKNOWN.',
  'Syskonparitet och lokal skarmkonvention hojer prioriteten i adjudiceringskon ' +
    'men avgor inte verdikt — grannens roll ar inte elementets roll.'
]);

// Deklarationsgrad per komponenttyp. ENBART stodjande statistik.
// post: { komponent, deklarerad }
export function typkonvention(poster) {
  const per = new Map();
  for (const p of poster) {
    const k = p.komponent || null;
    if (!k) continue;
    if (!per.has(k)) per.set(k, { komponent: k, totalt: 0, deklarerade: 0 });
    const e = per.get(k); e.totalt++; if (p.deklarerad) e.deklarerade++; }
  for (const e of per.values()) {
    e.grad = e.totalt ? e.deklarerade / e.totalt : 0;
    e.$roll = 'STODJANDE_EVIDENS_OCH_PRIORITERING — aldrig beslutsregel'; }
  return per;
}

// Index over DEKLARERADE exempel med agarmodell "rollen sitter pa raden".
export function exempelindex(poster) {
  const ix = new Map();
  for (const p of poster) {
    if (!p.deklarerad) continue;
    if (!p.agare || !p.agare.roll) continue;          // bara radagda exempel
    const k = exempelnyckel(p);
    if (!ix.has(k)) ix.set(k, { nyckel: k, antal: 0, roller: new Set(), exempel: [] });
    const e = ix.get(k); e.antal++; e.roller.add(p.agare.roll);
    if (e.exempel.length < 3) e.exempel.push(p.art + '|' + p.ordinal); }
  return ix;
}
export const exempelnyckel = p => (p.komponent || '-') + ' ‖ ' + (p.signatur || '-') +
  ' ‖ ' + ((p.tillstandsstruktur && p.tillstandsstruktur.typ) || '-');

// Kandidatgrind. Returnerar true bara for odeklarerade komponentstrukturer.
export function arKandidat(post) {
  if (post.egenA11yRoll) return false;
  if (post.agare) return false;
  return !!post.komponent || !!post.harKnopp;
}

const KONTROLLRADSFORMER = new Set(['div|flex|TEXT+KOMPONENT', 'span|flex|TEXT+KOMPONENT']);

// Evidensinsamling per forekomst. Ingen slutsats, bara fakta.
export function evidens(post, ix, konvention) {
  const ex = ix.get(exempelnyckel(post)) || null;
  const typ = post.komponent && konvention ? konvention.get(post.komponent) : null;
  return {
    AUTHORED_KOMPONENTTYP: !!post.komponent,
    authoradKomponenttyp: post.komponent || null,
    SYNLIG_ETIKETT: !!(post.etikett && String(post.etikett).trim()),
    synligEtikett: post.etikett || null,
    DEKLARERAT_EXEMPEL: !!ex,
    exempelroll: ex ? [...ex.roller].join(',') : null,
    exempelantal: ex ? ex.antal : 0,
    exempel: ex ? ex.exempel : [],
    KONTROLLRADSFORM: KONTROLLRADSFORMER.has(post.signatur),
    radsignatur: post.signatur || null,
    INSTALLNINGSKONTEXT: !!post.sektion,
    sektion: post.sektion || null,
    tillstandsstruktur: post.tillstandsstruktur || null,
    agandeDeklaration: post.agare ? post.agare.roll : null,
    ariaHidden: post.ariaHidden || null,
    interaktionsdeklaration: (post.handlare && post.handlare.length) ? post.handlare : null,
    accessibilityTrad: 'EJ INFORMATIV I DENNA KORPUS',
    $stodjande: { typkonventionTotalt: typ ? typ.totalt : null,
      typkonventionDeklarerade: typ ? typ.deklarerade : null,
      typkonventionGrad: typ ? Number(typ.grad.toFixed(4)) : null,
      syskonAiDeklareradeKontroller: post.syskonKontroller || 0,
      sammaTypDeklareradISkarmen: post.sammaTypDeklareradISkarmen || 0,
      $roll: 'STODJANDE — ingar aldrig i verdiktet' }
  };
}

const KRAVNYCKLAR = ['AUTHORED_KOMPONENTTYP', 'SYNLIG_ETIKETT', 'DEKLARERAT_EXEMPEL',
  'KONTROLLRADSFORM', 'INSTALLNINGSKONTEXT'];

// Adjudicering. Exakt ett verdikt, med den positiva evidensen som ledde dit.
export function adjudicera(post, ix, konvention) {
  const ev = evidens(post, ix, konvention);
  const skal = [];
  if (ev.ariaHidden === 'true') {
    skal.push('aria-hidden="true" ar positiv evidens for dekorativ');
    return { verdikt: VERDIKT.DECORATIVE_GRAPHIC, evidens: ev, skal }; }
  if (ev.agandeDeklaration) {
    skal.push('agande deklaration ' + ev.agandeDeklaration);
    return { verdikt: VERDIKT.INTERACTIVE_CONTROL, kontrolltyp: ev.agandeDeklaration,
      evidens: ev, skal, uppfylldaKrav: ['AGANDE_DEKLARATION'] }; }
  const uppfyllda = KRAVNYCKLAR.filter(k => ev[k]);
  const saknade = KRAVNYCKLAR.filter(k => !ev[k]);
  if (saknade.length === 0) {
    skal.push('authored data-component="' + ev.authoradKomponenttyp + '"');
    skal.push('synlig etikett i raden: "' + String(ev.synligEtikett).slice(0, 60) + '"');
    skal.push('samma agar- och radstruktur som ' + ev.exempelantal +
      ' deklarerade ' + ev.exempelroll + '-kontroller (till exempel ' + ev.exempel.join(', ') + ')');
    skal.push('radens innehall ar etikett foljd av komponenten och inget mer: ' + ev.radsignatur);
    skal.push('installningskontext under sektionsrubriken "' + ev.sektion + '"');
    if (ev.tillstandsstruktur) skal.push('tillstandet visualiseras av den etablerade strukturen ' +
      ev.tillstandsstruktur.typ + (ev.tillstandsstruktur.lage ? ' med knoppen till ' +
      ev.tillstandsstruktur.lage : ''));
    skal.push('$ingenFrekvensregel: komponenttypens deklarationsgrad ingar inte i verdiktet');
    return { verdikt: VERDIKT.INTERACTIVE_CONTROL, kontrolltyp: ev.exempelroll,
      evidens: ev, skal, uppfylldaKrav: uppfyllda }; }
  skal.push('saknad positiv evidens: ' + saknade.join(', '));
  skal.push('ingen positiv evidens for icke-interaktiv tillstandsgrafik eller dekoration');
  if (!ev.AUTHORED_KOMPONENTTYP)
    skal.push('ingen authored komponenttyp — bara en strukturell form, och formen ar inte evidens');
  if (ev.$stodjande.syskonAiDeklareradeKontroller)
    skal.push('OBS: ' + ev.$stodjande.syskonAiDeklareradeKontroller +
      ' syskonrader ar deklarerade kontroller — hojer prioritet, avgor inte verdikt');
  return { verdikt: VERDIKT.UNKNOWN, evidens: ev, skal,
    uppfylldaKrav: uppfyllda, saknadeKrav: saknade };
}

// Prioritet i adjudiceringskon. Rent en sorteringshjalp — aldrig ett verdikt.
export function prioritet(res) {
  if (res.verdikt !== VERDIKT.UNKNOWN) return 0;
  const s = res.evidens.$stodjande;
  return (res.uppfylldaKrav ? res.uppfylldaKrav.length : 0) +
    (s.syskonAiDeklareradeKontroller ? 2 : 0) + (s.sammaTypDeklareradISkarmen ? 1 : 0);
}

// Hela svepet. poster = korpusobservationen, redan insamlad ur renderingen.
export function svep(poster) {
  const konvention = typkonvention(poster);
  const ix = exempelindex(poster);
  const kandidater = poster.filter(arKandidat);
  const rader = kandidater.map(p => { const r = adjudicera(p, ix, konvention);
    return { art: p.art, ordinal: p.ordinal, komponent: p.komponent || null,
      identitet: p.art + '|' + p.ordinal, etikett: p.etikett || null,
      ...r, prioritet: prioritet(r) }; });
  const rakn = {};
  for (const v of Object.values(VERDIKT)) rakn[v] = rader.filter(r => r.verdikt === v).length;
  return { konvention: [...konvention.values()], exempelindex: [...ix.values()]
      .map(e => ({ nyckel: e.nyckel, antal: e.antal, roller: [...e.roller], exempel: e.exempel })),
    kandidater: rader, rakn,
    summerar: rader.length === Object.values(rakn).reduce((a, b) => a + b, 0) };
}
