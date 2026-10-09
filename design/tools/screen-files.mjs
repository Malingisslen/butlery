// Butlery · KANONISK fillista. Enda källan till "vilka filer är skärmfiler".
// gen-counts, gen-icons, lint-core och lint-controls importerar härifrån.
// Två listor som räknade olika var orsaken till att T-11 aldrig kunde bli noll.
export const SCREEN_FILES = [
  'Butlery Skarmar v12 del 1 recept och veckomeny.dc.html',
  'Butlery Skarmar v12 del 2 familj och socialt.dc.html',
  'Butlery Skarmar v12 del 3 sok och skalbevis.dc.html',
  'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html',
  'Butlery Skarmar v12 etapp 10 bred layout.dc.html',
  'Butlery Skarmar v12 etapp 11 breda vyer.dc.html',
  'Butlery Skarmar v12 etapp 2 inkop och skafferi.dc.html',
  'Butlery Skarmar v12 etapp 2.dc.html',
  'Butlery Skarmar v12 etapp 3 onboarding.dc.html',
  'Butlery Skarmar v12 etapp 4 import.dc.html',
  'Butlery Skarmar v12 etapp 5-7.dc.html',
  'Butlery Skarmar v12 etapp 6 konto och integritet.dc.html',
  'Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html',
  'Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html'
];
// Innehållsfilen har noll ramar och räknas inte.
export const INDEX_FILE = 'Butlery Skarmar v12.dc.html';
// Dokument som BÄR ikoner men inte är skärmar.
export const COMPANION_DOCS = [
  'Butlery Komponentark v1.dc.html',
  'Butlery Grafisk manual v6.dc.html',
  'Butlery tillganglighetshandoff.dc.html'
];

// TVÅ namngivna scope, aldrig underförstådda:
//   SCREEN_FILES      → ramar, a11y, skärmbevis, kontrollräkning
//   ICON_SOURCE_FILES → varje dokument vars data-icon ska räknas
// gen-icons hade en egen lista medan T-06 bara läste skärmfilerna, vilket gav
// 24 usage-fel direkt efter att gen-icons själv körts. Rättat 2026-08-01.
export const ICON_SOURCE_FILES = [...SCREEN_FILES, ...COMPANION_DOCS];
