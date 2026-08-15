// F2 · STRUKTURELL KLUSTRING OCH GRANSKNINGSPRIORITERING.
//
// VAD MODULEN AR TILL FOR
// Efter att upptackten stangts ligger 2684 kandidater utan semantiskt svar. Att
// beta av dem en och en ar inte granskning, det ar utmattning. Modulen grupperar
// dem efter hur de FAKTISKT ar byggda, sa att en evidensinsamling kan avgora
// manga forekomster.
//
// TRE LAGER SOM ALDRIG FAR BLANDAS
//   A  STRUKTURSIGNATUR   hur objektet ar byggt
//   B  GRANSKNINGSKLUSTER vilka som kan granskas tillsammans
//   C  SEMANTISKT VERDIKT avgors senare, forekomst for forekomst
// A eller B far ALDRIG implicera C. Ingen majoritet, ingen spridning fran en
// comparator, ingen sammanslagning av identiteter.
//
// FORBJUDNA NYCKLAR
// Skarm-id, absolut DOM-index, rat x/y, literal etikettext, exakt farg,
// kontrastkvot, R-02-utfall, 48x48-status, befintligt verdikt, prioritetspoang,
// comparatorroll och tillgangligt namn far inte ingå i klusteridentiteten. De
// far anvandas diagnostiskt EFTERAT, aldrig for att skapa semantisk
// sjalvbekraftelse.
//
// GEOMETRI FAR INTE OVERFRAGMENTERA
// Samma komponentfamilj i 320 px och 364 px ar samma familj. Darfor anvands
// FORMKLASS och ANDELAR, aldrig absoluta matt, i signaturen.

/* ── NORMALISERANDE HJALPARE ─────────────────────────────────────────────── */

// Formklass ur proportion, inte ur matt. Trosklarna ar grova med flit: de ska
// skilja en kvadratisk ikonknapp fran en bred rad, inte 320 fran 364.
export function formklass(w, h) {
  if (!(w > 0 && h > 0)) return 'okand';
  const k = w / h;
  if (k >= 0.8 && k <= 1.25) return 'kvadratisk';
  if (k > 1.25 && k <= 3) return 'bred';
  if (k > 3) return 'mycket-bred';
  if (k < 0.8 && k >= 0.33) return 'hog';
  return 'mycket-hog';
}

export function malningsklass(o) {
  const d = [];
  if (o.harFyllning) d.push('fyllning');
  if (o.helRam) d.push('ram');
  if (o.harOutline) d.push('outline');
  return d.length ? d.join('+') : 'omalad';
}

export function layoutklass(o) {
  // inline-flex och flex ar samma layoutmodell.
  const d = /^(inline-)?flex$/.test(o.display) ? 'flex' : o.display;
  if (d !== 'flex') return d;
  const riktning = /column/.test(o.flexRiktning || 'row') ? 'kolumn' : 'rad';
  const tvar = o.align === 'center' ? 'centrerad'
    : o.align === 'flex-start' ? 'topp' : o.align === 'flex-end' ? 'botten' : 'normal';
  return 'flex-' + riktning + '-' + tvar;
}

// Antal i grova hinkar. Exakta tal fragmenterar utan strukturellt skal.
const hink = n => n === 0 ? '0' : n === 1 ? '1' : n === 2 ? '2' : n <= 4 ? '3-4' : '5+';

export function texttopologi(o) {
  if (o.egenTextLangd === 0) return 'ingen-egen-text';
  if (o.textblock <= 1) return 'enbart-etikett';
  if (o.textblock === 2) return 'etikett+sekundar';
  return 'etikett+flera';
}

// Tillstandsbararens MORFOLOGI, ur authored komponentvokabular och form.
// Ikonnamnen ar komponentvokabular, inte etikettext.
const BOCK = /^(check|bock|tick)/i;
const RIKTNING = /(chevron|caret|arrow|expand|collapse)/i;
export function tillstandsbarare(o) {
  if (o.piller && o.harKnopp) return 'spar+knopp';
  if (o.segmentgrupp >= 3) return 'segmenterat-falt';
  const ik = o.ikoner || [];
  if (ik.some(x => BOCK.test(x))) return 'bock';
  if (o.komponent === 'checkbox' && !ik.length) return 'tom-ruta';
  if (ik.some(x => RIKTNING.test(x))) return 'riktningsmarkor';
  const rund = (o.maladeBarn || []).some(b => b.rund && b.andelBredd < 0.6);
  if (rund) return 'rund-markor';
  if (ik.length) return 'glyf-utan-tillstandsroll';
  return 'ingen-observerad';
}

/* ── NIVA 1 · STRUKTURSIGNATUR ───────────────────────────────────────────── */
export function struktursignatur(o) {
  return {
    malning: malningsklass(o),
    layout: layoutklass(o),
    form: formklass(o.w, o.h),
    egenText: o.egenTextLangd > 0,
    glyfer: hink((o.ikoner || []).length),
    nastladeFormer: hink(o.inreMalande),
    barn: hink(o.barnAntal),
    komponent: o.komponent || 'ingen',
    piller: !!(o.piller && o.harKnopp),
    segmenterat: o.segmentgrupp >= 3,
    mekanismer: (o.mekanismer || []).slice().sort().join('+'),
  };
}
export const signaturnyckel = s => Object.entries(s)
  .map(([k, v]) => k + '=' + v).join('|');

/* ── NIVA 2 · GRANSKNINGSPARTITION ───────────────────────────────────────── */
// Splittar ett strukturkluster BARA nar ytterligare pre-verdict-evidens visar
// materiellt olika granskningskontext.
export function partitionsnyckel(o, extra = {}) {
  return [
    'tillstand=' + tillstandsbarare(o),
    'text=' + texttopologi(o),
    'egenAtgard=' + (extra.harEgenKandidatIBarn ? 'ja' : 'nej'),
    'comparatorprofil=' + (extra.comparatorProfil || 'ingen'),
  ].join('|');
}

/* ── DETERMINISTISK HASH ─────────────────────────────────────────────────── */
export function hash(s) {
  let h1 = 0x811c9dc5, h2 = 0x01000193;
  for (let i = 0; i < s.length; i++) {
    h1 ^= s.charCodeAt(i); h1 = Math.imul(h1, 16777619) >>> 0;
    h2 = Math.imul(h2 ^ s.charCodeAt(i), 2246822519) >>> 0;
  }
  return (h1.toString(16).padStart(8, '0') + h2.toString(16).padStart(8, '0'));
}

/* ── PRIORITERING ────────────────────────────────────────────────────────── */
// GRANSKNINGSHAVSTANG, inte sannolikhet att nagot ar en kontroll. Poangen far
// aldrig avgora medlemskap i vare sig upptackt eller kluster.
export function havstang(k) {
  const storlek = k.olosta;
  const upprepning = k.olosta > 1 ? Math.log2(k.olosta) : 0;
  const comparator = k.comparatorer > 0 ? 2 : 0;
  const enRoll = k.comparatorRoller === 1 ? 1 : 0;
  const enTillstandsform = k.tillstandsformer === 1 ? 1 : 0;
  const enTexttopologi = k.texttopologier === 1 ? 1 : 0;
  const heterogen = k.semantisktHeterogen ? -3 : 0;
  return { poang: +(storlek * 0.02 + upprepning + comparator + enRoll +
      enTillstandsform + enTexttopologi + heterogen).toFixed(3),
    delar: { storlek, upprepning: +upprepning.toFixed(2), comparator, enRoll,
      enTillstandsform, enTexttopologi, heterogen },
    $regel: 'Havstang ar hur mycket EN evidensinsamling kan avgora. Den ar inte semantisk ' +
      'tilltro och far aldrig andra medlemskap.' };
}

export const FORBJUDNA_NYCKLAR = Object.freeze(['skarm-id', 'absolut DOM-index', 'ra x/y',
  'literal etikettext', 'exakt farg', 'kontrastkvot', 'R-02-utfall', '48x48-status',
  'befintligt verdikt', 'prioritetspoang', 'comparatorroll', 'tillgangligt namn']);
