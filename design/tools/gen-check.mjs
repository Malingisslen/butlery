// Butlery · GEMENSAM utskrift för generatorer, med ett rent --check-läge.
//
// Fas 1 (tredje vändan): preflight jämförde bara headerns tokenversion och
// källfingeravtryck. Båda kan vara HELT korrekta medan filens kropp kommer ur en
// äldre körning — fingeravtrycket binder headern till källan, inte kroppen till
// generatorn. Två levererade filer var stale på precis det sättet.
//
// Varje generator bygger nu en {sökväg: innehåll}-karta och lämnar den till
// emit(). Utan --check skrivs filerna. Med --check skrivs INGENTING: innehållet
// jämförs byte för byte mot filen på disk, och första avvikande rad rapporteras.
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

function firstDiff(got, want) {
  const a = got.split('\n'), b = want.split('\n');
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if (a[i] === b[i]) continue;
    return 'rad ' + (i + 1) + ': filen har ' + JSON.stringify(String(a[i] ?? '(slut)').slice(0, 70)) +
      ', generatorn ger ' + JSON.stringify(String(b[i] ?? '(slut)').slice(0, 70));
  }
  return 'olika längd (' + got.length + ' mot ' + want.length + ' tecken)';
}

// Returnerar antalet avvikande filer i check-läge, annars 0.
export function emit(outputs, { check = process.argv.includes('--check'), label = '' } = {}) {
  let bad = 0;
  for (const [file, content] of Object.entries(outputs)) {
    if (check) {
      const got = existsSync(file) ? readFileSync(file, 'utf8') : null;
      if (got === content) { console.log('GEN-CHECK ok ' + file); continue; }
      console.error('✖ GEN-CHECK drift ' + file + ' — ' +
        (got === null ? 'filen finns inte' : firstDiff(got, content)));
      bad++;
      continue;
    }
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, content);
  }
  if (check) {
    console.log('GEN-CHECK-SUMMARY' + (label ? ' generator=' + label : '') +
      ' checked=' + Object.keys(outputs).length + ' drift=' + bad);
    process.exit(bad ? 1 : 0);
  }
  return bad;
}
