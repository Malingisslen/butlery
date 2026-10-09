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
  'fas0/kallauktoritetsregister.md',
  'fas0/artefaktforslag.md'
];

// F1-H06: den DELMÄNGD av skrivmålen som source-authority.json måste förteckna
// i `generatedArtifacts` — filer som renderas i sin HELHET ur en kanonisk källa
// och därför inte har någon egen auktoritet. T-20 kräver mängdlikhet i båda
// riktningarna mot den här listan. Tidigare fanns ingen definierad koppling
// alls: en rad kunde tas bort ur generatedArtifacts utan att något fälldes.
// F1-U03: listan bar bara FILNAMN, och T-20 jämförde bara mängden filnamn. En
// artefakt kunde därför behålla rätt filnamn men få namnet på en annan
// existerande generator — `assets/generated/tokens.css` kunde stå som skriven
// av `gen-flutter.mjs` — och ingenting fällde. Kopplingen är nu kanonisk:
// output → generator, och T-20 kräver exakt likhet i BÅDA fälten.
export const FULLY_GENERATED_BY = {
  'fas0/verify-report.schema.json': 'tools/gen-schema.mjs',
  'assets/generated/tokens.css': 'tools/gen-css.mjs',
  'lib/theme/butlery_tokens.dart': 'tools/gen-flutter.mjs',
  'lib/theme/app_colors.dart': 'tools/gen-app-theme.mjs',
  'lib/theme/app_text_styles.dart': 'tools/gen-app-theme.mjs',
  'fas0/kallauktoritetsregister.md': 'tools/gen-authority.mjs',
  'fas0/artefaktforslag.md': 'tools/gen-artifact-proposal.mjs'
};

export const FULLY_GENERATED = Object.keys(FULLY_GENERATED_BY);

// De övriga skrivmålen ANNOTERAS på plats — generatorn skriver in räknetal eller
// `usages` i en fil som i övrigt är handskriven och bär egen auktoritet. De ska
// därför INTE stå i generatedArtifacts.
export const ANNOTATED_IN_PLACE = [
  'icons.json',
  '00-spec-index.md',
  'testmatris.md',
  'evidensmatris.md',
  'Butlery tillganglighetshandoff.dc.html'
];

// Invarianten binder de två listorna till GENERATED_OUTPUTS: varje skrivmål är
// antingen helrenderat eller annoterat, aldrig ingetdera och aldrig båda.
{
  const split = [...FULLY_GENERATED, ...ANNOTATED_IN_PLACE];
  const dup = split.filter((v, i) => split.indexOf(v) !== i);
  const missing = GENERATED_OUTPUTS.filter(f => !split.includes(f));
  const extra = split.filter(f => !GENERATED_OUTPUTS.includes(f));
  if (dup.length || missing.length || extra.length)
    throw new Error('gen-targets: FULLY_GENERATED + ANNOTATED_IN_PLACE ≠ GENERATED_OUTPUTS' +
      (dup.length ? ' · dubbletter: ' + dup.join(', ') : '') +
      (missing.length ? ' · saknas: ' + missing.join(', ') : '') +
      (extra.length ? ' · okända: ' + extra.join(', ') : ''));
}

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
