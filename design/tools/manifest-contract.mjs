// Butlery · GEMENSAMT kontrakt och GEMENSAM enumerator för artefaktytan.
//
// F1-H08: repo- och leveransytan räknades av två skilda walkers med olika
// regler. Repo-walkern använde statSync() (som FÖLJER symlänkar), en
// filtypsallowlist och tre katalogundantag; leverans-walkern använde
// lstatSync(), räknade varje vanlig fil och undantog exakta sökvägar. Två
// implementationer med olika säkerhetsegenskaper — och repo-walkern jämförde
// dessutom sina undantag mot en Windows-sökväg med omvänt snedstreck, så att
// INGET fas0/-undantag matchade på Windows. Nu finns EN enumerator.
//
// F1-H09: breda filtypsallowlistor och generella katalogundantag gjorde
// innehåll osynligt — `assets/`, `exports/` och lockup-katalogen räknades
// aldrig, och allt som inte matchade TEXT-regexen var osynligt oavsett var det
// låg. Nu räknas VARJE vanlig fil. Bara de exakt namngivna körartefakterna
// nedan undantas, och bygg-, dependency- och VCS-kataloger AVVISAS i en
// leverans i stället för att hoppas över.
import { readdirSync, lstatSync, realpathSync } from 'node:fs';
import { join, sep } from 'node:path';

// De enda filer som får saknas i manifestet. Exakta sökvägar, inga mönster.
// Samma lista används av repo- och leveransytan, av generatorn och av
// kontrollen — den kan inte glida isär mellan lägena.
export const RUNTIME_EXEMPT = [
  'fas0/verify.log',
  'fas0/manifest.log',
  'fas0/verify-report.json',
  'fas0/kontrollstatus.md',
  'fas0/ci-evidence.json',
  'fas0/verify-exit',
  'fas0/verify-chain-exit'
];

// Manifestet kan inte bära sin egen hash. Det är inte en körartefakt utan en
// strukturell omöjlighet, och står därför för sig.
export const MANIFEST_PATH = 'fas0/andrade-filer.md';

// F1-U01 · Leveransens yttre lager, versionshanterat i repot. Speglingen ÄR
// modellen: `leverans/<sökväg>` blir `zip:/<sökväg>` i den byggda leveransen.
// Ingen mappningsfil, inga undantag. Katalogen ligger i reporotsytan som vilken
// annan spårad fil som helst och följer därför med in i paketet.
export const ZIP_LAYER = 'leverans';

// Kataloger som inte hör hemma i en leverans. De AVVISAS — de göms inte.
export const REJECT_DIRS = ['node_modules', 'dist', 'build', '.svn', '.hg', '__pycache__', '.venv', '.cache'];

// .git avvisas i en leverans men är väntad i en repocheckout, där den hoppas
// över tyst. Det är den enda skillnaden mellan de två ytorna.
export const VCS_DIR = '.git';

export const MAX_DEPTH = 12;

const posix = p => p.split(sep).join('/').split('\\').join('/');

export const isExempt = rel => RUNTIME_EXEMPT.includes(rel) || rel === MANIFEST_PATH;

/**
 * EN enumerator för hela artefaktytan.
 *
 *  · varje vanlig fil räknas, oavsett filändelse
 *  · varje fil räknas exakt en gång (Set)
 *  · lstatSync() ÖVERALLT — symlänkar avvisas innan de filtreras eller följs
 *  · varje post måste ligga innanför rotens realpath
 *  · sökvägar normaliseras till snedstreck INNAN undantagen prövas
 *
 * @param root      katalogen som räknas
 * @param opts.mode 'repo' (hoppar över .git) eller 'delivery' (avvisar den)
 * @param opts.stopAt absoluta realpaths som inte ska traverseras (den
 *                    inbäddade reporoten mäts av sin egen yta)
 */
export function enumerateSurface(root, { mode = 'repo', stopAt = [] } = {}) {
  const files = new Set();
  const problems = [];
  const rejectedDirs = [];
  let skippedVcs = 0, truncated = 0;

  let realRoot;
  try { realRoot = realpathSync(root); }
  catch { return { files: [], problems: ['roten ' + root + ' går inte att läsa'], rejectedDirs, skippedVcs, truncated }; }

  const stops = new Set(stopAt.map(p => { try { return realpathSync(p); } catch { return p; } }));

  const inside = p => {
    let rp = null;
    try { rp = realpathSync(p); } catch { return null; }
    return (rp === realRoot || rp.startsWith(realRoot + sep)) ? rp : false;
  };

  const walk = (dir, rel = '', depth = 0) => {
    // F1-U08 · DJUPGRÄNSEN ÄR FÄLLANDE, I ALLA LÄGEN.
    //
    // Traverseringen räknade tidigare bara upp `truncated` och gick vidare.
    // Repo-ytans anropare läste aldrig det talet, och leveransytan rapporterade
    // det utan att det ändrade utfallet: en odeklarerad fil fjorton nivåer ned
    // gav exit 0 och oförändrad set-likhet. En gräns som inte fäller är ingen
    // gräns — den är ett hål med en räknare bredvid.
    if (depth > MAX_DEPTH) {
      truncated++;
      problems.push('katalogen ' + (rel || '.') + ' ligger djupare än ' + MAX_DEPTH +
        ' nivåer — traverseringen avbröts och ytan kan därför inte mätas fullständigt');
      return;
    }
    let names = [];
    try { names = readdirSync(dir); } catch { problems.push('katalogen ' + (rel || '.') + ' går inte att läsa'); return; }
    for (const name of names) {
      const p = join(dir, name);
      const r = posix(rel ? rel + '/' + name : name);
      let st;
      try { st = lstatSync(p); } catch { problems.push('posten ' + r + ' går inte att statas'); continue; }

      // SYMLÄNKAR först — före varje annan prövning. En länk kan peka ut ur
      // ytan, och att filtrera på namn innan man vet att det är en länk är
      // precis den ordning som gjorde kontrollen fail-open.
      if (st.isSymbolicLink()) { problems.push('symlänk i artefaktytan: ' + r); continue; }

      const rp = inside(p);
      if (rp === false) { problems.push('posten ' + r + ' ligger utanför rotens realpath'); continue; }
      if (rp !== null && stops.has(rp)) continue;

      // VCS-posten prövas FÖRE fil/katalog-grenen. I en länkad git-worktree är
      // .git en FIL som innehåller "gitdir: <absolut sökväg>" — inte en katalog.
      // Med prövningen inne i katalogrenen hamnade den filen i manifestet, och
      // manifestet blev därmed omöjligt att regenerera identiskt från en ren
      // checkout: dess hash beror på var på disken worktreen råkar ligga.
      if (name === VCS_DIR) {
        if (mode === 'delivery') {
          problems.push('VCS-posten ' + r + ' hör inte hemma i en leverans');
          rejectedDirs.push(r);
        } else skippedVcs++;
        continue;
      }

      if (st.isDirectory()) {
        if (REJECT_DIRS.includes(name)) {
          problems.push('bygg- eller dependencykatalogen ' + r + ' hör inte hemma i artefaktytan');
          rejectedDirs.push(r);
          continue;
        }
        walk(p, r, depth + 1);
        continue;
      }
      if (!st.isFile()) { problems.push('posten ' + r + ' är varken fil eller katalog'); continue; }
      if (isExempt(r)) continue;
      files.add(r);
    }
  };
  walk(root);
  return { files: [...files].sort(), problems, rejectedDirs, skippedVcs, truncated };
}
