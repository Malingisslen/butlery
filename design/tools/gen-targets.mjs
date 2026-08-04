// Butlery · KANONISKT register över kedjans generatorer och deras skrivmål.
//
// Fas 1 (andra vändan): listan över generatorer låg i tools/verify.mjs (stegen),
// listan över skrivmål i verify.mjs (GENERATED_OUTPUTS) och en TREDJE lista i
// metatest M-18. gen-app-theme.mjs saknades i M-18, så en generator kunde skriva
// en fil som GEN-01 inte vaktade. Nu finns EN källa; M-18 läser den här filen och
// jämför den mot generatorernas faktiska skrivmål.
export const GENERATORS = [
  'tools/gen-schema.mjs',
  'tools/gen-icons.mjs',
  'tools/gen-counts.mjs',
  'tools/gen-css.mjs',
  'tools/gen-flutter.mjs',
  'tools/gen-app-theme.mjs',
  'tools/gen-authority.mjs'
];

// Allt kedjans generatorer skriver. GEN-01 hashar varje post före och efter
// körningen: ändras någon var den incheckade versionen stale.
export const GENERATED_OUTPUTS = [
  'fas0/verify-report.schema.json',
  'assets/generated/tokens.css',
  'lib/theme/butlery_tokens.dart',
  'lib/theme/app_colors.dart',
  'lib/theme/app_text_styles.dart',
  'icons.json',
  '00-spec-index.md',
  'testmatris.md',
  'evidensmatris.md',
  'Butlery tillganglighetshandoff.dc.html',
  'fas0/kallauktoritetsregister.md'
];

// output → förväntad generator → indata. Delas av preflight (GEN-02), som
//   1 kräver att headern namnger RÄTT generator för filen,
//   2 räknar om källfingeravtrycket ur indata + generatorns källa,
//   3 ber generatorn själv byte-jämföra filen med sitt aktuella resultat (--check).
//
// Fas 1 (tredje vändan): registret bar bara indata, och GEN-02 jämförde bara
// header och fingeravtryck. Båda kan vara HELT korrekta medan kroppen kommer ur
// en äldre körning — två levererade filer var stale på precis det sättet, och
// GEN-02 stod grön. Fingeravtrycket binder headern till källan; --check binder
// kroppen till generatorn.
export const GENERATED_REGISTER = {
  'assets/generated/tokens.css': { generator: 'tools/gen-css.mjs', inputs: ['tokens.json'] },
  'lib/theme/butlery_tokens.dart': { generator: 'tools/gen-flutter.mjs', inputs: ['tokens.json'] },
  'lib/theme/app_colors.dart': { generator: 'tools/gen-app-theme.mjs', inputs: ['tokens.json', 'tools/app-theme-map.json', 'assets/brand-colors.json'] },
  'lib/theme/app_text_styles.dart': { generator: 'tools/gen-app-theme.mjs', inputs: ['tokens.json', 'tools/app-theme-map.json', 'assets/brand-colors.json'] }
};

// Bakåtkompatibel vy: output → indata.
export const GENERATED_INPUTS = Object.fromEntries(
  Object.entries(GENERATED_REGISTER).map(([f, v]) => [f, v.inputs]));
