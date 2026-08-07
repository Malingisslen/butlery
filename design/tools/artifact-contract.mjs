// Butlery · KONTRAKTET för artefaktklassificeringen (Fas 2).
//
// F2-A01 · OBSERVATION OCH BESLUT ÄR OLIKA SAKER.
//
// En enhetsram är stark evidens för att artefakten är en viewport. Den är inte
// ett auktoritetsbeslut. Fas 1 lärde oss vad som händer när en maskin får
// besluta åt en människa och ingen märker skillnaden: registret drev, och
// generatorn kallade sitt eget antagande &rdquo;aktuellt&rdquo;.
//
// Därför två skilda begrepp, i två skilda fält:
//
//   OBSERVERAT   mäts ur skärmfilerna vid varje körning och ägs av maskinen.
//                Får aldrig skrivas till artifacts.json som ett beslut.
//   BESLUTAT     står i artifacts.json, sätts av en människa, och skrivs
//                ALDRIG av en generator. Varje beslut bär sin grund.
//
// Kontrollen (CHK-T-21) jämför de två och redovisar tre skilda felklasser:
//   · registerfel      — saknad, extra eller dubblerad post
//   · datafel          — ogiltigt värde mot vokabulären
//   · obeslutat        — giltig post, men beslutet är inte fattat än
// Det sista är ett Fas 2-grindfel, inte ett datafel. Ett obeslutat register är
// ärligt; ett register som gissar är det inte.

/* ── BESLUTADE VOKABULÄRER ────────────────────────────────────────────────── */

// Styrdokumentets § 5.1. `unclassified` är ett giltigt ÖVERGÅNGSVÄRDE — det får
// stå i schemat, men fäller Fas 2-grinden.
export const ARTIFACT_KINDS = {
  viewport:     { normative: true,  countsAsScreen: true,  label: 'vy' },
  crop:         { normative: true,  countsAsScreen: false, label: 'beskärning' },
  component:    { normative: true,  countsAsScreen: false, label: 'komponentbord' },
  pattern:      { normative: true,  countsAsScreen: false, label: 'mönsterbord' },
  annotation:   { normative: false, countsAsScreen: false, label: 'annotering' },
  concept:      { normative: false, countsAsScreen: false, label: 'koncept' },
  superseded:   { normative: false, countsAsScreen: false, label: 'ersatt' },
  unclassified: { normative: false, countsAsScreen: false, label: 'OBESLUTAD', undecided: true }
};

// Vilken yta artefakten bevisar något om. En vy i telefonram och samma vy i
// bred layout är två LEGITIMA aktiva varianter — de utesluter inte varandra.
export const VIEWPORT_CLASSES = {
  phone:        { label: 'telefon' },
  wide:         { label: 'bred' },
  expanded:     { label: 'utbredd (layoutlaget expanded)' },
  tablet:       { label: 'surfplatta' },
  none:         { label: 'ingen yta (bord eller annotering)' },
  unclassified: { label: 'OBESLUTAD', undecided: true }
};

// F2-A03 · TRE DIMENSIONER, INTE TVÅ.
//
// `draft` hörde aldrig hemma i authorityState. Auktoritet och arbetsläge är
// skilda frågor: en artefakt kan vara färdigbeslutad men blockerad, och den ska
// då inte kunna få normativ auktoritet i förtid bara för att beslutet är taget.
//
//   authorityState        vilken auktoritet artefakten HAR
//   classificationState   hur långt BESLUTET har kommit
//
// Invarianten som binder dem: authorityState `active` kräver
// classificationState `decided`. Allt annat är ett datafel.
export const ARTIFACT_STATES = {
  active:     { current: true,  normative: true,  label: 'gällande' },
  planned:    { current: false, normative: false, label: 'planerad' },
  superseded: { current: false, normative: false, label: 'ersatt', requiresSupersededBy: true },
  historical: { current: false, normative: false, label: 'historisk' },
  concept:    { current: false, normative: false, label: 'koncept (icke-normativ)' }
};

export const CLASSIFICATION_STATES = {
  unclassified: { decided: false, label: 'OBESLUTAD' },
  // Beslutet är fattat men artefakten är blockerad. Kräver activationBlockers.
  draft:        { decided: false, label: 'beslutad, blockerad', requiresBlockers: true },
  decided:      { decided: true,  label: 'beslutad' }
};

// F2-A03 · URVALSDIMENSIONER MED DEKLARERAD KÄLLA OCH DETERMINISTISKT RUNTIMEVAL.
//
// En dimension får inte användas förrän det finns (a) en deklarerad källa som
// säger vilka värden som gäller, och (b) ett deterministiskt sätt att välja
// mellan dem vid körning. En kohortdimension utan experimentkontrakt är inte
// ett urval — det är en gissning med två utfall.
// F2-A04 · VOKABULÄREN LÄSES UR selection-contexts.json.
//
// Dimensionerna stod tidigare hårdkodade här, vilket gjorde koden till sin
// egen auktoritet — samma fel som det handskrivna källauktoritetsregistret i
// Fas 1. Nu är JSON-filen källan, registrerad i source-authority.json och
// schemavaliderad av T-01. plattformsmatris.md GENERERAS ur den.
//
// Regeln som gör `enabled` meningsfull: en dimension får vara aktiverad först
// när den har en dokumentationskälla OCH en deterministisk runtimeadapter med
// minst ett verkligt användningsställe i appkoden.
import { readFileSync, existsSync } from 'node:fs';

function loadDimensions() {
  const P = 'selection-contexts.json';
  if (!existsSync(P)) return {};
  let doc = null;
  try { doc = JSON.parse(readFileSync(P, 'utf8')); } catch { return {}; }
  const out = {};
  for (const d of doc.dimensions || []) {
    const ra = d.runtimeAdapter;
    const usable = !!(d.enabled && d.documentation && ra && ra.deterministic &&
      Array.isArray(ra.usageSites) && ra.usageSites.length);
    out[d.id] = {
      values: d.values, enabled: usable, declaredEnabled: !!d.enabled,
      source: d.documentation, runtimeSelection: ra ? ra.expression : null,
      usageSites: ra ? ra.usageSites : [], note: d.note
    };
  }
  return out;
}

export const SELECTOR_DIMENSIONS = loadDimensions();

export const ENABLED_DIMENSIONS = Object.entries(SELECTOR_DIMENSIONS)
  .filter(([, d]) => d.enabled).map(([k]) => k);

/**
 * F2-A03 · Alla tillåtna URVALSKONTEXTER — den kartesiska produkten av de
 * aktiverade dimensionernas värden.
 *
 * Att bara jämföra nycklar räckte inte: selektorer ÖVERLAPPAR. En variant utan
 * selektor gäller alla plattformar, och en med `platform: ios` gäller också
 * iOS — två skilda nycklar, men båda matchar samma verklighet. Vokabulären är
 * ändlig, så kontexterna kan räknas upp och prövas var för sig.
 */
export function selectionContexts() {
  let ctxs = [{}];
  for (const dim of ENABLED_DIMENSIONS) {
    const next = [];
    for (const c of ctxs) for (const v of SELECTOR_DIMENSIONS[dim].values) next.push({ ...c, [dim]: v });
    ctxs = next;
  }
  return ctxs;
}

export const contextLabel = c => {
  const keys = Object.keys(c).sort();
  return keys.length ? keys.map(k => k + '=' + c[k]).join(', ') : '(ingen dimension)';
};

/** Matchar en variant den här kontexten? Ospecificerad dimension = alla. */
export const matchesContext = (a, ctx) =>
  Object.entries(a.selectors || {}).every(([d, v]) => ctx[d] === v);

/** Basnyckeln — utan selektorer. Kontexterna prövas separat, per bas. */
export const baseSlot = a => [a.screenId, a.stateId, a.viewportClass].join(' · ');

// Hur beslutet fattades. Ett beslut utan grund är en gissning med
// självförtroende.
export const CLASSIFICATION_BASES = {
  'device-frame-evidence': 'artefakten bär exakt en enhetsram; beslutet följer evidensen',
  'explicit-dimensions':   'artefakten saknar enhetsram men bär explicita mått',
  'content-review':        'avgjord genom läsning av artefaktens innehåll',
  'author-decision':       'avgjord av designsystemägaren mot styrdokumentets § 5.1',
  'superseded-by-record':  'avgjord av att en efterträdare pekats ut',
  'split-migration':       'uppkommen genom delning av en tidigare artefakt; se lineage',
  'undecided':             'beslutet är inte fattat — fäller Fas 2-grinden'
};

/* ── OBSERVATION ──────────────────────────────────────────────────────────── */

// Identiteten är sammansatt. HTML-id är i dag unika över filgränsen (326 av
// 326), men det är en OBSERVATION om nuläget, inte en garanti — Fas 0 fällde
// två globala dubblett-id i just de här filerna. Nyckeln bär därför alltid
// filen.
export const artifactIdOf = (sourceFile, sourceElementId) =>
  fileSlug(sourceFile) + ':' + sourceElementId;

export function fileSlug(file) {
  return file
    .replace(/\.dc\.html$/, '')
    .replace(/^Butlery Skarmar v12 /, '')
    .replace(/^Butlery /, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

/**
 * Läser ut artefakterna och deras OBSERVERADE egenskaper ur en skärmfil.
 * Returnerar aldrig något beslutat fält — det är hela poängen.
 */
export function observeArtifacts(file, text) {
  const out = [];
  const parts = text.split(/(?=<[a-z]+[^>]*class="sc-item")/);
  for (const part of parts.slice(1)) {
    const tag = (part.match(/^<[a-z]+[^>]*>/) || [''])[0];
    const sourceElementId = (tag.match(/id="([^"]+)"/) || [])[1] || null;
    // Artefaktens kropp slutar vid nästa sc-item; split ovan ger redan det.
    const deviceFrames = (part.match(/class="sc-phone"/g) || []).length;
    // F2-A05 · ANTALET DEKLARATIONER är inte ett MÅTT. Kolumnen hette "Mått"
    // och innehöll antalet gånger en bredd deklarerades någonstans i
    // artefakten — ett tal som säger något om markupens form, inte om ytans
    // storlek. De två redovisas nu var för sig.
    const dimensionDeclarations =
      [...part.matchAll(/width:\s*\d+px[^"]*?height:\s*\d+px/g)].length +
      [...part.matchAll(/max-width:\s*\d+px/g)].length;
    // Rotmåttet: den FÖRSTA bredd/höjd-deklarationen i artefaktens yttersta
    // ram, om den finns. Saknas den är ytan omätbar, och det är hela poängen
    // med § 5.1:s krav på explicita mått.
    // FÖRSTA deklarationen är inte artefaktens yta. I praktiken är den ofta en
    // ikon på 24 px. Talet redovisas därför under sitt riktiga namn, och det
    // STÖRSTA deklarerade måttet redovisas bredvid — det är närmare ytan, men
    // fortfarande inte en mätning. En riktig ytmätning kräver rendering.
    const firstWH = part.match(/width:\s*(\d+)px[^"]{0,80}?height:\s*(\d+)px/);
    const widths = [...part.matchAll(/(?:max-)?width:\s*(\d+)px/g)].map(m => Number(m[1]));
    // Etiketten står i data-screen-label på sc-item; sc-label bär prosan.
    const label = (tag.match(/data-screen-label="([^"]*)"/) || [])[1] || null;
    const leadIn = (part.match(/class="sc-id"[^>]*>[^<]*<\/a>([\s\S]{0,240})/) || [])[1] || '';
    // F2-A03 · Härledningen från en delad artefakt står i KÄLLAN, så den
    // överlever att registret sås om. Utan den försvinner spåret till det
    // gamla id:t när någon läser ett ankare som inte längre finns.
    const lineageFrom = (tag.match(/data-lineage-from="([^"]*)"/) || [])[1] || null;
    out.push({
      sourceFile: file,
      sourceElementId,
      artifactId: sourceElementId ? artifactIdOf(file, sourceElementId) : null,
      lineageFrom,
      observed: {
        deviceFrames,
        hasDeviceFrame: deviceFrames > 0,
        dimensionDeclarations,
        hasExplicitDimensions: dimensionDeclarations > 0,
        firstDeclaredWidth: firstWH ? Number(firstWH[1]) : null,
        firstDeclaredHeight: firstWH ? Number(firstWH[2]) : null,
        maxDeclaredWidth: widths.length ? Math.max(...widths) : null,
        controls: (part.match(/data-a11y-role=/g) || []).length,
        label: label ? label.trim() : null,
        lead: leadIn.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 200) || null
      }
    });
  }
  return out;
}

/** Behålls som läsbart namn på varianten. Ingår ALDRIG i slotnyckeln. */
export const variantLabel = a => a.variantId || '(namnlös)';

export const isUndecided = a =>
  (CLASSIFICATION_STATES[a.classificationState] || {}).decided !== true ||
  (ARTIFACT_KINDS[a.artifactKind] || {}).undecided === true ||
  (VIEWPORT_CLASSES[a.viewportClass] || {}).undecided === true ||
  a.screenId === null || a.stateId === null;
