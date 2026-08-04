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
