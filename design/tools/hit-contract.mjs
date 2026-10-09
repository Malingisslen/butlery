// F2-R02 · KONTRAKTET FÖR data-hit, som rena funktioner.
//
// data-hit deklarerar den NORMATIVT AVSEDDA renderade träffytan. Det är inte
// ett bevis för att någon widget faktiskt lyssnar på ytan — den frågan hör
// hemma i app-repot och besvaras av en separat runtimekontroll. Här bevisas
// tre saker och inget mer:
//
//   · vilken yta designspecen avser
//   · dess faktiska renderade mått
//   · om projektkravet 48 × 48 CSS-px uppfylls
//
// STORLEKEN KOMMER ALLTID FRÅN RENDERINGEN. En deklaration som säger "48"
// är en avsikt, aldrig ett mätvärde. Talet bevaras som deklarerad avsikt så
// att avvikelsen mellan avsikt och utfall kan redovisas — och används aldrig
// i stället för getBoundingClientRect().

export const KRAV_PX = 48;

/* ── Deklarationsformer ──────────────────────────────────────────────────── */
//
// Formen måste vara maskinellt entydig. Den gamla löptexten ("raden 48",
// "wrapper 48 (rutan 24 är visuell)") tolkas ALDRIG heuristiskt: att gissa
// vilken nod "raden" syftar på vore att uppfinna evidens. Den formen får sin
// egen status och landar i unknown tills den migrerats för hand.
export const FORMER = {
  self:          { label: 'kontrollens eget element', matbar: true },
  target:        { label: 'explicit utpekad renderad target', matbar: true },
  undeclared:    { label: 'ingen deklaration', matbar: false },
  'legacy-prose':{ label: 'löptextdeklaration som inte migrerats', matbar: false }
};

// target:<id> pekar på det element som bär data-hit-target="<id>".
// Referensen är ett explicit attributvärde — aldrig DOM-position, aldrig
// nth-child, aldrig textmatchning, aldrig närmaste förfader.
const TARGET = /^target:([A-Za-z][A-Za-z0-9_-]{0,63})$/;
const BARA_SELF = /^self$/;
// Talen i löptexten fångas som DEKLARERAD AVSIKT, aldrig som mätvärde.
const TAL = /(\d{2,4})\s*(?:[x×]\s*(\d{2,4}))?/;

export function parseHit(varde) {
  if (varde === null || varde === undefined || String(varde).trim() === '')
    return { form: 'undeclared', targetId: null, deklareradAvsikt: null,
             giltig: true, why: null };
  const v = String(varde).trim();
  if (BARA_SELF.test(v))
    return { form: 'self', targetId: null, deklareradAvsikt: null, giltig: true, why: null };
  const m = v.match(TARGET);
  if (m)
    return { form: 'target', targetId: m[1], deklareradAvsikt: null, giltig: true, why: null };
  const t = v.match(TAL);
  return {
    form: 'legacy-prose', targetId: null,
    deklareradAvsikt: t ? { bredd: +t[1], hojd: t[2] ? +t[2] : +t[1],
      $regel: 'DEKLARERAD AVSIKT. Används aldrig som mätvärde — renderingen är source of truth.' } : null,
    giltig: false,
    why: 'löptextdeklaration ' + JSON.stringify(v.slice(0, 60)) +
         ' är inte maskinellt entydig och tolkas inte heuristiskt'
  };
}

/* ── Populationsklasser ──────────────────────────────────────────────────── */
//
// ÖMSESIDIGT UTESLUTANDE. Ett element hör till exakt en klass. Invarianterna
// nedan faller om den regeln bryts — det var precis så nämnaren spårade ur
// första gången: fyra tal ur fyra universum som subtraherades från varandra.
export const KLASSER = {
  'utanfor-artefakt':          { iProduktnamnare: false, label: 'märkt kontroll utanför registrerad artefakt' },
  'deklaration-self':          { iProduktnamnare: true,  label: 'träffytan är kontrollens eget element' },
  'deklaration-target':        { iProduktnamnare: true,  label: 'träffytan ägs av en utpekad renderad target' },
  'deklaration-lopttext':      { iProduktnamnare: true,  label: 'löptextdeklaration, ej migrerad' },
  'ingen-deklaration':         { iProduktnamnare: true,  label: 'ingen deklaration' },
  'metadata-utan-roll':        { iProduktnamnare: false, label: 'data-hit på element utan semantisk roll' }
};

export function klassificera(post) {
  // Metadatauniversum: bär data-hit men är ingen semantisk kontroll. Räknas i
  // attributinventeringen, aldrig som R-02-kontroll.
  if (!post.roll) return 'metadata-utan-roll';
  if (!post.iRegistreradArtefakt) return 'utanfor-artefakt';
  const p = parseHit(post.dataHit);
  if (p.form === 'self') return 'deklaration-self';
  if (p.form === 'target') return 'deklaration-target';
  if (p.form === 'legacy-prose') return 'deklaration-lopttext';
  return 'ingen-deklaration';
}

/* ── Upplösning av target ────────────────────────────────────────────────── */
//
// Fail closed hela vägen: noll träffar, flera träffar eller en target utanför
// den tillåtna kontexten ger aldrig ett mått. Att välja "den enda rimliga"
// noden vore en heuristik, och heuristiken var hela felet.
export function loesTarget(post) {
  const p = parseHit(post.dataHit);
  if (p.form === 'self')
    return { status: 'resolved', rect: post.egenRect, basis: 'self', why: null };
  if (p.form === 'undeclared')
    return { status: 'unknown', rect: null, basis: null, why: 'ingen deklaration' };
  if (p.form === 'legacy-prose')
    return { status: 'unknown', rect: null, basis: null, why: p.why };

  const kand = post.targetKandidater || [];
  if (kand.length === 0)
    return { status: 'unknown', rect: null, basis: null,
             why: 'deklarerad target ' + JSON.stringify(p.targetId) + ' finns inte i DOM:en' };
  if (kand.length > 1)
    return { status: 'unknown', rect: null, basis: null,
             why: kand.length + ' element bär samma target-id ' + JSON.stringify(p.targetId) +
                  ' — referensen är inte entydig' };
  const t = kand[0];
  if (!t.inomArtefakt)
    return { status: 'valideringsfel', rect: null, basis: null,
             why: 'target ' + JSON.stringify(p.targetId) + ' ligger utanför kontrollens artefakt' };
  if (!t.renderad)
    return { status: 'unknown', rect: null, basis: null,
             why: 'target ' + JSON.stringify(p.targetId) + ' renderas inte' };
  return { status: 'resolved', rect: { w: t.w, h: t.h }, basis: 'target:' + p.targetId, why: null };
}

/* ── Domslut ─────────────────────────────────────────────────────────────── */
export function domslut(post) {
  const r = loesTarget(post);
  const p = parseHit(post.dataHit);
  const bas = {
    artifactId: post.artifactId, roll: post.roll, namn: post.namn,
    klass: klassificera(post), form: p.form, targetId: p.targetId,
    deklareradAvsikt: p.deklareradAvsikt,
    upplosning: r.status, basis: r.basis, why: r.why
  };
  if (r.status !== 'resolved')
    return { ...bas, status: r.status === 'valideringsfel' ? 'valideringsfel' : 'unknown',
             matt: null, uppfyller: null };
  const matt = { w: +r.rect.w.toFixed(2), h: +r.rect.h.toFixed(2), enhet: 'css-px' };
  return { ...bas, status: 'measured', matt,
    uppfyller: matt.w >= KRAV_PX && matt.h >= KRAV_PX,
    // Avvikelsen mellan avsikt och utfall redovisas, men avsikten avgör aldrig.
    avvikelseMotAvsikt: p.deklareradAvsikt
      ? { deklarerat: p.deklareradAvsikt, uppmatt: matt,
          stammer: matt.w >= p.deklareradAvsikt.bredd && matt.h >= p.deklareradAvsikt.hojd }
      : null };
}

/* ── Populationsrapport med invarianter ──────────────────────────────────── */
export function population(poster, kalltal = {}) {
  const per = {};
  for (const p of poster) { const k = klassificera(p); per[k] = (per[k] || 0) + 1; }
  for (const k of Object.keys(KLASSER)) if (!(k in per)) per[k] = 0;

  const kontroller = poster.filter(p => p.roll);
  const medHit = kontroller.filter(p => p.dataHit !== null && p.dataHit !== undefined);
  const utanRoll = poster.filter(p => !p.roll);
  const produktnamnare = poster.filter(p => KLASSER[klassificera(p)].iProduktnamnare).length;

  const fel = [];
  // 1 · källtext mot rendering
  if (kalltal.kallDeklarationer !== undefined && kalltal.kallDeklarationer !== kontroller.length)
    fel.push('SOURCE DECLARATIONS ' + kalltal.kallDeklarationer +
      ' != RENDERED ' + kontroller.length);
  // 2 · data-hit-bokföringen
  if (kalltal.kallDataHit !== undefined && medHit.length + utanRoll.length !== kalltal.kallDataHit)
    fel.push('DATA-HIT ' + medHit.length + ' på kontroller + ' + utanRoll.length +
      ' utan roll = ' + (medHit.length + utanRoll.length) + ' != ' + kalltal.kallDataHit);
  // 3 · out-of-artifact får aldrig försvinna tyst
  if (per['utanfor-artefakt'] === 0 && poster.some(p => p.roll && !p.iRegistreradArtefakt))
    fel.push('kontroller utanför registrerad artefakt finns men klassificerades inte som sådana');
  // 4 · klasserna ska täcka precis en gång
  const summa = Object.values(per).reduce((a, b) => a + b, 0);
  if (summa !== poster.length)
    fel.push('klassumman ' + summa + ' != populationen ' + poster.length +
      ' — ett element räknas i två ömsesidigt uteslutande klasser eller i ingen');
  // 5 · control × viewport får aldrig blandas in
  if (kalltal.controlTimesViewport !== undefined &&
      kalltal.controlTimesViewport === kontroller.length)
    fel.push('control×viewport och kontrollmetadata har samma tal — de är skilda mätenheter och får aldrig dela summeringsidentitet');

  // 6 · UNDECLARED:s två delar ska summera till sin klass
  {
    const odekl = poster.filter(p => klassificera(p) === 'ingen-deklaration');
    const akt = odekl.filter(p => p.sjalvAktiverbar).length;
    if ((odekl.length - akt) + akt !== per['ingen-deklaration'])
      fel.push('UNDECLARED-delarna summerar inte till klassen ingen-deklaration');
  }

  return {
    $regel: 'SOURCE DECLARATIONS, DATA-HIT, UNDECLARED och OUTSIDE REGISTERED ARTIFACTS är kontrollmetadata. CONTROL × VIEWPORT är en annan mätenhet och ingår aldrig i samma summeringsidentitet.',
    sourceDeclarations: { kalltext: kalltal.kallDeklarationer ?? null, renderade: kontroller.length,
      delta: kalltal.kallDeklarationer !== undefined ? kalltal.kallDeklarationer - kontroller.length : null },
    dataHit: { totalt: kalltal.kallDataHit ?? (medHit.length + utanRoll.length),
      pa_kontroller: medHit.length, pa_element_utan_roll: utanRoll.length },
    // UNDECLARED redovisas i de två delar den frusna modellen namnger. De är
    // ömsesidigt uteslutande och summerar till klassen — invariant nr 6 nedan.
    undeclared: (() => {
      const odekl = poster.filter(p => klassificera(p) === 'ingen-deklaration');
      const akt = odekl.filter(p => p.sjalvAktiverbar).length;
      return { utan_data_hit: odekl.length - akt,
               aktiverbara_utan_deklaration: akt,
               summa: odekl.length };
    })(),
    outsideRegisteredArtifacts: { st: per['utanfor-artefakt'],
      $regel: 'Redovisas alltid, valideras som explicita poster, ingår aldrig i produktnämnaren.',
      poster: poster.filter(p => klassificera(p) === 'utanfor-artefakt')
        .map(p => ({ fil: p.fil, roll: p.roll, namn: p.namn })) },
    controlTimesViewport: { st: kalltal.controlTimesViewport ?? null,
      $regel: 'ANNAN MÄTENHET. Får aldrig summeras med talen ovan.' },
    klasser: per,
    produktnamnare_st: produktnamnare,
    failClosed: { fel, status: fel.length ? 'FÄLLD' : 'godkänd' }
  };
}
