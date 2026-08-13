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
 */
export function bortfallsprov(del, begripligUtan, motivering) {
  if (begripligUtan === null || begripligUtan === undefined)
    return { del: del.id, klass: DELKLASS.UNKNOWN, krav: null,
      skal: 'begriplighet utan delen ar inte bedomd — faller stangt' };
  if (begripligUtan === false)
    return { del: del.id, klass: DELKLASS.REQUIRED_FOR_UNDERSTANDING,
      krav: { minsta: KRAV_MOT_ANGRANSANDE, mot: 'faktiskt malad angransande farg', kalla: KRAVKALLA },
      skal: motivering };
  return { del: del.id, klass: DELKLASS.SUPPLEMENTAL, krav: null, skal: motivering };
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
