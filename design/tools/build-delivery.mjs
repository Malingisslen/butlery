#!/usr/bin/env node
// Butlery · bygger den KOMPLETTA leveransen ur versionshanterade filer.
// Kör: node tools/build-delivery.mjs --out=<katalog> [--force]
//
// F1-U01: paketeringen låg tidigare i ett skalskript utanför Git
// (butlery-bevis/sync-delivery.sh) och läste ZIP-rotlagret ur en katalog på
// utvecklarmaskinen. En färsk klon kunde därför inte bygga leveransen, och
// GitHub Actions kunde bli grönt utan att någonsin ha sett leveransytan.
//
// Modellen är spegling och inget annat:
//     leverans/<sökväg>   →   <out>/<sökväg>            (ZIP-roten)
//     .                   →   <out>/uploads/…/v12/      (reporoten)
//
// Reporoten kopieras HEL, inklusive `leverans/`. Den levererade ZIP:en bär
// alltså sina egna byggindata — samma yta i repot och i paketet, en enda
// definition, inga undantagsregler att glida på.
import { readdirSync, lstatSync, mkdirSync, copyFileSync, rmSync, existsSync } from 'node:fs';
import { join, dirname, resolve, sep } from 'node:path';
import { RUNTIME_EXEMPT, REJECT_DIRS, VCS_DIR } from './manifest-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const FORCE = process.argv.includes('--force');
if (!OUT) { console.error('✖ ange --out=<katalog>'); process.exit(2); }

export const ZIP_LAYER = 'leverans';
// Reporotens plats inne i leveransen. Manifestkontrollen kräver exakt tre
// nivåer mellan leveransroten och reporoten — den här sökvägen ÄR det kravet.
export const PACKAGE_PATH = 'uploads/Butlery Skarmar etapp 3 onboarding/Butlery design uppdatering v12';

if (!existsSync(ZIP_LAYER)) {
  console.error('✖ ' + ZIP_LAYER + '/ saknas — kör från reporoten');
  process.exit(1);
}
if (!existsSync(join(ZIP_LAYER, 'fas0/DELIVERY'))) {
  console.error('✖ ' + ZIP_LAYER + '/fas0/DELIVERY saknas — utan leveransmarkören finns inget delivery-läge');
  process.exit(1);
}

const outAbs = resolve(OUT);
const repoAbs = resolve('.');
// F1-U09 · --out får varken vara reporoten, en förälder till den, ELLER ligga
// inne i den. Ett bygge inuti källan hade kopierat sig självt rekursivt och
// smugit in byggprodukten i nästa manifest.
if (outAbs === repoAbs || repoAbs.startsWith(outAbs + sep)) {
  console.error('✖ --out pekar på reporoten eller en förälder till den');
  process.exit(2);
}
if (outAbs.startsWith(repoAbs + sep)) {
  console.error('✖ --out ligger inne i reporoten (' + outAbs + ') — bygg utanför källan');
  process.exit(2);
}
// F1-U09 · --force får bara skriva över en TIDIGARE BYGGPRODUKT, aldrig en
// godtycklig katalog. Ett bygge känns igen på leveransmarkören. En tom katalog
// är också säker. Allt annat kräver att du städar för hand.
if (existsSync(outAbs)) {
  if (!FORCE) { console.error('✖ ' + OUT + ' finns redan — ange --force för att bygga om'); process.exit(2); }
  const looksBuilt = existsSync(join(outAbs, 'fas0/DELIVERY'));
  const empty = (() => { try { return readdirSync(outAbs).length === 0; } catch { return false; } })();
  if (!looksBuilt && !empty) {
    console.error('✖ ' + OUT + ' är varken tom eller en tidigare leverans (ingen fas0/DELIVERY) — --force vägrar radera den');
    process.exit(2);
  }
  rmSync(outAbs, { recursive: true, force: true });
}

const EXEMPT = new Set(RUNTIME_EXEMPT);
let files = 0, skippedRuntime = 0;

// Kopierar en katalog rekursivt. Symlänkar och bygg-/VCS-kataloger avvisas med
// samma regler som enumeratorn — en leverans får inte bära dem, och en länk
// som följdes tyst hade kunnat dra in filer utifrån.
function copyTree(from, to, rel = '') {
  for (const name of readdirSync(from)) {
    const src = join(from, name);
    const r = rel ? rel + '/' + name : name;
    const st = lstatSync(src);
    if (st.isSymbolicLink()) { console.error('✖ symlänk i källan: ' + r); process.exit(1); }
    if (st.isDirectory()) {
      // F1-U09 · FÖRBJUDNA KATALOGER AVVISAS, DE SANERAS INTE BORT.
      //
      // Byggaren hoppade tidigare tyst över REJECT_DIRS. Med `dist/undeclared.bin`
      // i källan gav bygget exit 0 och utelämnade filen — byggaren städade alltså
      // undan precis det som manifestkontrollen finns för att upptäcka, och CI
      // fick aldrig se det. Enda undantaget är reporotens EGEN .git, som är en
      // checkout-artefakt och aldrig hör hemma i en leverans.
      if (name === VCS_DIR) {
        if (rel === '') continue;                       // reporotens egen .git
        console.error('✖ VCS-katalogen ' + r + ' hör inte hemma i källan');
        process.exit(1);
      }
      if (REJECT_DIRS.includes(name)) {
        console.error('✖ bygg- eller dependencykatalogen ' + r + ' finns i källan — ' +
          'byggaren avvisar den i stället för att sanera bort den (F1-U09)');
        process.exit(1);
      }
      copyTree(src, join(to, name), r);
      continue;
    }
    if (!st.isFile()) { console.error('✖ varken fil eller katalog: ' + r); process.exit(1); }
    if (EXEMPT.has(r)) { skippedRuntime++; continue; }   // körartefakter följer inte med
    mkdirSync(dirname(join(to, name)), { recursive: true });
    copyFileSync(src, join(to, name));
    files++;
  }
}

// 1 · ZIP-roten ur det versionshanterade lagret.
copyTree(ZIP_LAYER, outAbs);
const zipFiles = files;

// 2 · Reporoten, hel.
copyTree('.', join(outAbs, PACKAGE_PATH));

// Leveransroten måste ligga exakt tre nivåer över reporoten, annars vägrar
// manifestkontrollen bedöma delivery-läget.
const depth = PACKAGE_PATH.split('/').filter(Boolean).length;
if (depth !== 3) { console.error('✖ PACKAGE_PATH är ' + depth + ' nivåer, manifestkontrollen kräver 3'); process.exit(1); }

console.log('DELIVERY-BUILD out=' + outAbs + ' zip_root=' + zipFiles +
  ' package=' + (files - zipFiles) + ' total=' + files + ' runtime_skipped=' + skippedRuntime);
