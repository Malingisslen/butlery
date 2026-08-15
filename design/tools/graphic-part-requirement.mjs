// F2-NT · VILKA DELAR AV ETT SAMMANSATT GRAFISKT OBJEKT AR KRAVDA?
//
// GODKAND METOD 2026-08-13.
//
// FELET REGELN STANGER
// Det ar frestande att skriva "varje del maste na 3:1". Det ar for brett: en
// del kan vara ren utsmyckning i ett objekt som anda ar fullt begripligt utan
// den. Det ar lika frestande att skriva "det racker att objektet syns" — och
// det ar for smalt, eftersom en form kan sluta vara igenkannbar nar delar
// faller bort.
//
// NORMATIV REGEL
//   For ett sammansatt grafiskt objekt: avgor vilka delar som kravs for att
//   anvandaren ska forsta vad grafiken formedlar.
//
//   PROVET: behandla varje lagkontrastdel som osynlig. Ar objektet fortfarande
//   begripligt utan den delen?
//     NEJ  -> delen ar REQUIRED_FOR_UNDERSTANDING och maste na 3.0 mot sin
//             FAKTISKT MALADE angransande farg
//     JA   -> delen ar SUPPLEMENTAL och bar inget eget krav
//
// TVA SAKER REGELN INTE SAGER
//   · Den kraver ALDRIG kontrast mellan delarna inbordes. Varje del mats mot
//     sin angransande bakgrund, aldrig mot en annan del.
//   · Den harleder aldrig kravet ur en ordning eller en luminansserie. En
//     fallande betoning kan vara ett godkant designdrag utan att vara den
//     informationsbarande egenskapen.
//
// Bedomningen av begriplighet ar en MANSKLIG eller evidensbaserad bedomning
// och levereras till modulen. Modulen raknar aldrig ut den ur farg.

export const DELKLASS = Object.freeze({
  REQUIRED_FOR_UNDERSTANDING: 'REQUIRED_FOR_UNDERSTANDING',
  SUPPLEMENTAL: 'SUPPLEMENTAL',
  UNKNOWN: 'UNKNOWN' });

/* ── TEXTAGARSKAP AR INTE CARRIER-EVIDENS ───────────────────────────
 *
 * FELET DENNA GRIND STANGER
 * En malad yta som rakar vara den narmaste malade agaren till ett barns text
 * blir DARMED textens matbakgrund. Det ar en MATNINGSRELATION och besvarar
 * bara fragan "mot vilken faktiskt malad farg ska barnets textkontrast
 * matas?". Den sager ingenting om huruvida ytans EGEN malning bar information
 * eller struktur.
 *
 * Att en foralder ager eller innehaller informationsbarande text far darfor
 * ALDRIG ensamt etablera:
 *   · INFORMATION_BEARING
 *   · REQUIRED_GRAPHICAL_CARRIER
 *   · standalone non-text-tillhorighet
 *   · kravd ram eller fyllning
 *   · kravd grupperingsbarare
 *
 * Textrelationen forblir i textsparet. Grafisk carrier-status kraver egen
 * positiv grafisk eller strukturell evidens. Saknas den: UNKNOWN.
 */
export const EVIDENSGRUND = Object.freeze({
  TEXT_BACKGROUND_OWNER: 'TEXT_BACKGROUND_OWNER',
  OWNS_VISIBLE_TEXT: 'OWNS_VISIBLE_TEXT',
  CHILD_TEXT_VARIES: 'CHILD_TEXT_VARIES',
  GRAPHICAL_DELIMITATION: 'GRAPHICAL_DELIMITATION',
  STRUCTURAL_FUNCTION: 'STRUCTURAL_FUNCTION',
  STATE_ENCODING: 'STATE_ENCODING',
  SHAPE_RECOGNISABILITY: 'SHAPE_RECOGNISABILITY',
  CURRENT_VISUAL_COLLAPSE: 'CURRENT_VISUAL_COLLAPSE' });

/* Grunder som aldrig ensamma kan bara ett grafiskt krav. Samtliga ar
 * utsagor om TEXT, inte om malningen. */
export const ICKE_GRUNDANDE_ENSAMT = Object.freeze([
  EVIDENSGRUND.TEXT_BACKGROUND_OWNER,
  EVIDENSGRUND.OWNS_VISIBLE_TEXT,
  EVIDENSGRUND.CHILD_TEXT_VARIES ]);

/* ── EXAKT VISUELL LIKHET AR INGET ONODIGHETSBEVIS ──────────────────
 *
 * FELET DENNA GRIND STANGER
 * Nar en barare har exakt samma farg som ytan den ligger mot ar kvoten 1:1.
 * Det ar frestande att lasa det som "baren gor ingenting, alltsa behovs den
 * inte". Kvoten bevisar bara CURRENT_VISUAL_COLLAPSE — att baren i sitt
 * NUVARANDE utseende inte syns. Den sager ingenting om huruvida funktionen
 * behovs.
 *
 * Ar separationen eller grupperingen i sjalva verket kravd, ar samma 1:1 i
 * stallet ett KONFORMANSFYND: en kravd barare som inte nar 3.0 mot sin
 * angransande farg.
 *
 * Exakt likhet ar alltsa en SIGNAL, aldrig ett requiredness-bevis — at
 * nagot hall.
 */
export const ICKE_GRUNDANDE_FOR_ONODIG = Object.freeze([
  EVIDENSGRUND.CURRENT_VISUAL_COLLAPSE ]);

/** Kan de anforda grunderna bara slutsatsen att baren INTE behovs? */
export function grundarOnodig(grunder) {
  const g = Array.isArray(grunder) ? grunder : [];
  const barande = g.filter(x => !ICKE_GRUNDANDE_FOR_ONODIG.includes(x));
  return { grundar: barande.length > 0, barande,
    ickeGrundande: g.filter(x => ICKE_GRUNDANDE_FOR_ONODIG.includes(x)),
    skal: barande.length > 0
      ? 'minst en grund sager nagot om funktionen, inte bara om nuvarande utseende'
      : 'enda grunden ar att baren redan kollapsar visuellt — det bevisar inte att ' +
        'funktionen saknas' };
}

/** Kan de anforda grunderna over huvud taget bara ett grafiskt krav? */
export function grundarKrav(grunder) {
  const g = Array.isArray(grunder) ? grunder : [];
  const barande = g.filter(x => !ICKE_GRUNDANDE_ENSAMT.includes(x));
  return { grundar: barande.length > 0, barande,
    ickeGrundande: g.filter(x => ICKE_GRUNDANDE_ENSAMT.includes(x)),
    skal: barande.length > 0
      ? 'minst en grund ar en utsaga om malningen sjalv'
      : 'samtliga anforda grunder ar utsagor om text, inte om malningen' };
}

export const KRAV_MOT_ANGRANSANDE = 3.0;
export const KRAVKALLA = 'WCAG 1.4.11 · grafiska objekt som kravs for att forsta innehallet';

/**
 * Bortfallsprovet for EN del.
 *
 * del            { id, beskrivning }
 * begripligUtan  boolean — ar objektet fortfarande begripligt om delen ar
 *                osynlig? Levereras av den anropande som en bedomning med
 *                motivering. null = obedomd.
 * motivering     varfor
 * grunder        valfri lista ur EVIDENSGRUND. Anges den, provas den mot
 *                ICKE_GRUNDANDE_ENSAMT: ett krav som bara vilar pa
 *                textagarskap faller stangt till UNKNOWN i stallet for att
 *                bli REQUIRED_FOR_UNDERSTANDING.
 */
export function bortfallsprov(del, begripligUtan, motivering, grunder) {
  if (begripligUtan === null || begripligUtan === undefined)
    return { del: del.id, klass: DELKLASS.UNKNOWN, krav: null,
      skal: 'begriplighet utan delen ar inte bedomd — faller stangt' };
  if (begripligUtan === false) {
    if (grunder !== undefined && grunder !== null) {
      const g = grundarKrav(grunder);
      if (!g.grundar)
        return { del: del.id, klass: DELKLASS.UNKNOWN, krav: null, grunder: g,
          skal: 'kravet vilar enbart pa ' + g.ickeGrundande.join(', ') +
            ' — textagarskap kan inte ensamt etablera ett grafiskt krav; faller stangt' };
    }
    return { del: del.id, klass: DELKLASS.REQUIRED_FOR_UNDERSTANDING,
      krav: { minsta: KRAV_MOT_ANGRANSANDE, mot: 'faktiskt malad angransande farg', kalla: KRAVKALLA },
      grunder: grunder === undefined || grunder === null ? null : grundarKrav(grunder),
      skal: motivering }; }
  /* begripligUtan === true: baren pastas onodig. Samma stranghet at det hallet. */
  if (grunder !== undefined && grunder !== null) {
    const o = grundarOnodig(grunder);
    if (!o.grundar)
      return { del: del.id, klass: DELKLASS.UNKNOWN, krav: null, grunder: o,
        skal: 'slutsatsen vilar enbart pa ' + o.ickeGrundande.join(', ') +
          ' — exakt visuell likhet bevisar inte att funktionen saknas; faller stangt' }; }
  return { del: del.id, klass: DELKLASS.SUPPLEMENTAL, krav: null,
    grunder: grunder === undefined || grunder === null ? null : grundarOnodig(grunder),
    skal: motivering };
}

/* ── CARRIER-STABILITET ─────────────────────────────────────────────
 *
 * FELET DENNA REGEL STANGER
 * Om barnets text byts ut, flyttas eller byter agare andras textsparets
 * matning. Den grafiska barens ansvar andras INTE av det. Sa lange den
 * grafiska och strukturella evidensen ar oforandrad ska carrier-verdiktet
 * vara oforandrat. Annars kan ett verdikt vaggas fram genom att skriva om
 * texten omkring det.
 *
 * fore / efter   { grunder: [...], begripligUtan: bool|null }
 */
export function carrierstabilitet(fore, efter) {
  const gr = t => (Array.isArray(t.grunder) ? t.grunder : [])
    .filter(x => !ICKE_GRUNDANDE_ENSAMT.includes(x)).slice().sort().join(',');
  const grafiskLika = gr(fore) === gr(efter);
  const a = bortfallsprov({ id: 'bar' }, fore.begripligUtan, 'fore', fore.grunder);
  const b = bortfallsprov({ id: 'bar' }, efter.begripligUtan, 'efter', efter.grunder);
  return { grafiskEvidensLika: grafiskLika, fore: a.klass, efter: b.klass,
    stabil: !grafiskLika || a.klass === b.klass,
    skal: grafiskLika
      ? 'den grafiska evidensen ar oforandrad — carrier-verdiktet maste vara oforandrat'
      : 'den grafiska evidensen skiljer sig — verdiktet far skilja sig' };
}

/**
 * Hela objektet. Returnerar per del samt en avstamning: varje del hamnar
 * exakt en gang, och UNKNOWN faller stangt for objektet som helhet.
 */
export function objektprov(objekt, bedomningar) {
  const rader = objekt.delar.map(d => { const b = bedomningar[d.id] || {};
    return bortfallsprov(d, b.begripligUtan, b.motivering); });
  const okanda = rader.filter(r => r.klass === DELKLASS.UNKNOWN);
  const kravda = rader.filter(r => r.klass === DELKLASS.REQUIRED_FOR_UNDERSTANDING);
  return { objekt: objekt.id, delar: rader,
    kravda: kravda.map(r => r.del), supplementala: rader
      .filter(r => r.klass === DELKLASS.SUPPLEMENTAL).map(r => r.del),
    okanda: okanda.map(r => r.del),
    summerar: rader.length === objekt.delar.length,
    godkand: okanda.length === 0,
    $regel: 'Inget krav pa kontrast mellan delarna. Varje kravd del mats mot sin angransande malade farg.' };
}

/**
 * Provar en bunt varden mot objektets krav.
 * varden     { delId: farg }
 * angransande { delId: farg }   den FAKTISKT MALADE grannfargen
 * kvotFn     (a, b) => kvot     levereras av anroparen
 */
export function buntprov(prov, varden, angransande, kvotFn) {
  const rader = prov.delar.map(d => {
    const varde = varden[d.del], gran = angransande[d.del];
    if (d.klass !== DELKLASS.REQUIRED_FOR_UNDERSTANDING)
      return { del: d.del, kravd: false, varde, kvot: varde && gran ? kvotFn(varde, gran) : null, ok: true };
    const k = kvotFn(varde, gran);
    return { del: d.del, kravd: true, varde, angransande: gran, kvot: k,
      ok: k >= KRAV_MOT_ANGRANSANDE }; });
  return { rader, ok: rader.every(r => r.ok),
    fallande: rader.filter(r => r.kvot !== null).map(r => r.kvot),
    $not: 'Ordningen mellan delarna redovisas men avgor inte godkant. Den ar ett designdrag.' };
}
