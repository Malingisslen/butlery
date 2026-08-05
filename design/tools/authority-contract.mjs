// Butlery · KANONISKT kontrakt för källauktoriteten.
//
// F1-H04: T-20 kontrollerade tidigare bara de domäner som RÅKADE finnas i
// source-authority.json. En hel domän kunde alltså strykas ur registret utan
// att någon kontroll märkte det — registret validerade sig självt mot sig
// självt. Den obligatoriska mängden får därför inte bo i samma muterbara fil
// som valideras. Den bor här, i kod, och T-20 kräver EXAKT mängdlikhet.
//
// F1-H02: maskinvärden är engelska. Svenska etiketter genereras enbart i
// presentationslagret (tools/gen-authority.mjs) — aldrig i maskinfältet.

// Varje domän som MÅSTE ha en aktuell auktoritetspost (active eller planned).
// Ett stabilt id överlever att domänens svenska namn skrivs om.
export const REQUIRED_DOMAIN_IDS = [
  'product-invariants',
  'design-values',
  'token-structure',
  'legacy-dart-api-map',
  'brand-colors',
  'legacy-api-surface',
  'component-contract',
  'layout-composition',
  'content-text',
  'a11y-handoff',
  'icon-names',
  'asset-status',
  'principles',
  'requirement-status',
  'test-matrix',
  'platform-differences',
  'flows-budget-analytics',
  'decisions',
  'report-schema',
  'control-register',
  'source-authority',
  'governance',
  'document-runtime'
];

// TVÅDIMENSIONELL STATUS (F1-H02).
//
// Dimension 1 — authorityState: vilken roll posten spelar för sin domän.
// Dimension 2 — changePolicy: om källan får ändras.
//
// De två är oberoende: en källa kan vara `active` och samtidigt `frozen`
// (legacy-api-contract.json är precis det). Den gamla endimensionella
// statusordboken ("gällande" / "fryst" / "historisk" / "ska skapas") blandade
// ihop dem, vilket gjorde "fryst" tvetydigt — normativ eller inte?
export const AUTHORITY_STATES = {
  active:     { normative: true,  current: true,  requiresFile: true,  label: 'gällande' },
  planned:    { normative: false, current: true,  requiresFile: false, label: 'planerad' },
  superseded: { normative: false, current: false, requiresFile: true,  label: 'ersatt' },
  historical: { normative: false, current: false, requiresFile: true,  label: 'historisk' },
  concept:    { normative: false, current: false, requiresFile: true,  label: 'koncept' }
};

export const CHANGE_POLICIES = {
  maintained: { label: 'underhålls' },
  frozen:     { label: 'fryst' }
};

// `planned` är det ENDA tillstånd som får sakna fil.
export const STATES_WITHOUT_FILE = Object.entries(AUTHORITY_STATES)
  .filter(([, v]) => !v.requiresFile).map(([k]) => k);

// `active` och `planned` är de två aktuella tillstånden. Exakt ett av dem per
// obligatorisk domän — aldrig båda.
export const CURRENT_STATES = Object.entries(AUTHORITY_STATES)
  .filter(([, v]) => v.current).map(([k]) => k);

// Endast `superseded` kräver ett mål.
export const STATES_REQUIRING_SUPERSEDED_BY = ['superseded'];

export const stateLabel = s => (AUTHORITY_STATES[s] || {}).label || s;
export const policyLabel = p => (CHANGE_POLICIES[p] || {}).label || p;

// ── F1-U02 · INDEXETS AUKTORITETSRADER ────────────────────────────────────────
//
// Generatorn skrev tidigare bara cellerna `version` och `status`. Filkolumnen,
// radens identitet och det faktum att raden ÖVER HUVUD TAGET fanns var
// fortfarande manuella: en rad kunde strykas ur `00-spec-index.md` utan att
// någonting fällde, och generatorn kallade resultatet aktuellt eftersom den
// bara rörde de rader den råkade hitta.
//
// Mängden nedan är kanonisk och ligger i kod. Markörerna i indexet måste vara
// EXAKT den här mängden — varken fler, färre, okända eller dubblerade.
export const INDEX_AUTHORITY_ROWS = [
  'design-values',
  'token-structure',
  'product-invariants',
  'icon-names',
  'asset-status',
  'content-text',
  'flows-budget-analytics',
  'a11y-handoff',
  'test-matrix',
  'requirement-status',
  'platform-differences',
  'source-authority',
  'report-schema',
  'legacy-dart-api-map',
  'brand-colors',
  'legacy-api-surface',
  'decisions',
  'component-contract',
  'layout-composition',
  'principles'
];

// De tre domäner som medvetet INTE står i indexets versionstabell, med skälet.
// Utan den här listan hade "exakt mängdlikhet" bara betytt "de rader som råkar
// finnas", vilket var precis felet.
export const INDEX_ROWS_EXEMPT = {
  'control-register': 'tools/controls.mjs bär ingen version — versionstabellen kräver ett läsbart versionsvärde per rad',
  'governance': 'ligger i leveransroten (zip:/), inte i reporotens dokumentmängd',
  'document-runtime': 'support.js bär ingen version och är runtime, inte ett specdokument'
};

// ── Cellrenderare · EN definition, delad av generatorn och linten ────────────
// Ligger här för att `tools/gen-authority.mjs` och `tools/lint-core.mjs` ska
// mäta exakt samma sträng. Två renderare hade kunnat glida isär, och då hade
// linten godkänt en cell generatorn aldrig skulle ha skrivit.

// Numeriska versioner fetas; textbärande ("mot manual V6") skrivs som de står.
// null betyder "generatorn äger inte cellen" — versionslösa källor.
export function indexVersionCell(a) {
  if (a.version === null || a.version === undefined) return null;
  return /^[Vv]?\d/.test(String(a.version)) ? '**' + a.version + '**' : String(a.version);
}

// Filkolumnen kan bära mer än filnamnet (Skärmar räknar upp fjorton delfiler),
// därför äger generatorn bara det FÖRSTA `kodcitatet` i cellen — filen som
// källauktoriteten pekar ut. Resten av cellen är prosa och rörs inte.
export function indexFileRef(a) {
  return a.file ? '`' + a.file + '`' : '*saknas*';
}

export function indexStatusCell(a) {
  const bits = [stateLabel(a.authorityState)];
  if (a.changePolicy === 'frozen') bits.push(policyLabel('frozen'));
  bits.push('ägare ' + a.owner);
  return bits.join(' · ');
}

// Markörerna i indexet. Kolumnnamnen är slutna så att huvudblockets
// <!--auth:header:start--> aldrig kan tolkas som en radmarkör.
export const INDEX_MARKER_RE = /<!--auth:([a-z0-9-]+):((?:version|file|status)(?:,(?:version|file|status))*)-->/;
export const INDEX_MARKER_RE_G = new RegExp(INDEX_MARKER_RE.source, 'g');

// Vilka kolumner varje rad äger. Skärmraden äger inte `status`, eftersom dess
// statuscell bär gen-counts räkneankare — två generatorer får aldrig skriva i
// samma cell. Komponentarksraden äger inte `version`, eftersom domänen är
// `planned` och versionen i cellen är filens egen, inte registrets.
// Komponentarksraden äger varken `version` eller `file`: domänen är `planned`
// och har ingen normativ källa, medan raden pekar på det handritade
// komponentarket som underlag. Skrev generatorn filkolumnen där blev den
// `*saknas*`, och T-15 tappade sin enda mätbara filreferens på raden.
export const INDEX_ROW_COLUMNS = {
  'layout-composition': ['version', 'file'],
  'component-contract': ['status']
};
export const columnsFor = domainId => INDEX_ROW_COLUMNS[domainId] || ['version', 'file', 'status'];
