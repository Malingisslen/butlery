#!/usr/bin/env node
// Butlery · artefaktmanifestet ur den GEMENSAMMA enumeratorn.
// Kör: node tools/gen-manifest.mjs   ·   ALLRA SIST i kedjan.
//
// F1-H08/H09: manifestet var handskrivet. En fil som lades till utan att någon
// kom ihåg att lista den fångades bara om den råkade ligga i en katalog
// walkern besökte och bära en filändelse i TEXT-allowlisten — `assets/`,
// `exports/` och lockup-katalogen räknades aldrig alls. Manifestet genereras nu
// ur exakt samma enumerator som kontrollen använder, så att listan och
// mätningen inte kan mena olika saker.
//
// Manifestet är INTE en GEN-01-artefakt: det hashar de andra generatorernas
// utdata och måste därför byggas efter dem, inte vaktas jämte dem.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, join, relative, sep } from 'node:path';
import { emit } from './gen-check.mjs';
import { enumerateSurface, RUNTIME_EXEMPT, MANIFEST_PATH, REJECT_DIRS } from './manifest-contract.mjs';

const sha = p => createHash('sha256').update(readFileSync(p)).digest('hex');
const ZIP_ROOT = resolve('../../..');
const relToRoot = relative(ZIP_ROOT, process.cwd()).split(sep).join('/');
const isDelivery = relToRoot.split('/').filter(Boolean).length === 3 && existsSync(join(ZIP_ROOT, 'fas0/DELIVERY'));

const repo = enumerateSurface('.', { mode: 'repo' });
if (repo.problems.length) {
  for (const p of repo.problems) console.error('✖ reporotsytan: ' + p);
  process.exit(1);
}

let outside = { files: [], problems: [] };
if (isDelivery) {
  outside = enumerateSurface(ZIP_ROOT, { mode: 'delivery', stopAt: [process.cwd()] });
  if (outside.problems.length) {
    for (const p of outside.problems) console.error('✖ leveransytan: ' + p);
    process.exit(1);
  }
}

const rows = repo.files.map(f => [f, sha(f)]);
// I repo-läge kan zip:/-posterna inte hashas — filerna finns inte. De bärs då
// vidare OFÖRÄNDRADE ur det befintliga manifestet, så att `--check` går att
// köra i båda lägena. Att de stämmer bevisas bara i delivery-läge; i repo-läge
// bevisas bara att ingen har handredigerat resten av listan.
let zip;
if (isDelivery) {
  zip = outside.files.map(f => ['zip:/' + f, sha(join(ZIP_ROOT, f))]);
} else {
  const prev = existsSync(MANIFEST_PATH) ? readFileSync(MANIFEST_PATH, 'utf8') : '';
  zip = [...prev.matchAll(/^\|\s*`(zip:\/[^`]+)`\s*\|\s*`([0-9a-f]{64})`\s*\|$/gm)].map(m => [m[1], m[2]]);
}
const total = rows.length + zip.length;

const L = [];
L.push('# Artefaktmanifest');
L.push('');
L.push('**GENERERAD FIL — kör `node tools/gen-manifest.mjs`, redigera inte för hand.** Byggs ALLRA SIST i kedjan, efter varje generator, och kontrolleras av `fas0/check-manifest.mjs` (CHK-MF-01) med samma enumerator som skrev den: `tools/manifest-contract.mjs`.');
L.push('');
L.push('## Två lägen');
L.push('');
L.push('| Läge | Yta | Krav | Set-likhet mot |');
L.push('|---|---|---|---|');
L.push('| `repo` | fristående checkout | `zip:/`-posterna får saknas | reporotsytan |');
L.push('| `delivery` | uppackad ZIP | **varje `zip:/`-post krävs · set-likhet över HELA ytan** | reporotsytan **plus** alla `zip:/`-poster |');
L.push('| `auto` | markören `zip:/fas0/DELIVERY` avgör | delivery när markören finns | följer valt läge |');
L.push('');
L.push('**VALIDERAD LEVERANSROT.** Delivery-läget kräver att roten ligger exakt tre nivåer över reporoten, inte är filsystemets rot, och bär `zip:/fas0/DELIVERY` — annars exit 2. Traverseringen är djupbegränsad.');
L.push('');
L.push('## Hela ytan, ingen allowlist (F1-H09)');
L.push('');
L.push('Varje **vanlig fil** räknas, oavsett filändelse och katalog. Det finns ingen filtypslista och inga katalogundantag — `assets/`, `exports/` och lockup-katalogen räknades tidigare inte alls. Bara följande **exakta** sökvägar undantas, och de är körartefakter som skrivs av kedjan:');
L.push('');
for (const f of RUNTIME_EXEMPT) L.push('- `' + f + '`');
L.push('');
L.push('Därtill `' + MANIFEST_PATH + '`, som inte kan bära sin egen hash.');
L.push('');
L.push('**Avvisas, göms inte:** symlänkar (prövade med `lstatSync()` FÖRE varje annan kontroll), poster utanför rotens `realpath`, samt bygg-, dependency- och VCS-kataloger (' +
  REJECT_DIRS.map(d => '`' + d + '`').join(', ') + ' och `.git` i en leverans). Var och en fäller kontrollen med egen diagnostik.');
L.push('');
L.push('<!--manifest:files=' + total + '-->');
L.push('');
L.push('## Reporoten');
L.push('');
L.push('| Fil | SHA-256 |');
L.push('|---|---|');
for (const [f, h] of rows) L.push('| `' + f + '` | `' + h + '` |');
L.push('');
if (zip.length) {
  L.push('## Leveransytan utanför reporoten');
  L.push('');
  L.push('| Fil | SHA-256 |');
  L.push('|---|---|');
  for (const [f, h] of zip) L.push('| `' + f + '` | `' + h + '` |');
  L.push('');
}
emit({ [MANIFEST_PATH]: L.join('\n') }, { label: 'gen-manifest' });
console.log('MANIFEST-GEN files=' + total + ' repo=' + rows.length + ' zip=' + zip.length +
  ' mode=' + (isDelivery ? 'delivery' : 'repo'));
