#!/usr/bin/env node
// Butlery · spec-lint T-01…T-10. Kör: node tools/spec-lint.mjs
// Fel (✖) fäller bygget. Varningar (◐) syns men fäller inte.
// Testerna ska mäta rätt sak, inte bara ge noll. Varje check säger vad den INTE kan se.
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { lint } from './lint-core.mjs';

const env = {
  read: p => readFileSync(p, 'utf8'),
  exists: p => existsSync(p),
  // Alla filer i reporoten — T-19 granskar varje aktiv md-fil, inte fem valda.
  // REKURSIVT. readdirSync('.') läste bara toppnivån och missade sju nästlade
  // md-filer, medan T-19 påstod att den granskar alla aktiva. Fas 0.11.
  list: () => {
    const SKIP = new Set(['node_modules', '.git', 'assets', 'exports', 'Butlery-lockup-family-L4-3']);
    const out = [];
    const walk = (dir, pre) => {
      for (const e of readdirSync(dir)) {
        if (SKIP.has(e)) continue;
        const p = dir === '.' ? e : dir + '/' + e;
        let st;
        try { st = statSync(p); } catch { continue; }
        if (st.isDirectory()) walk(p, pre);
        else out.push(p);
      }
    };
    walk('.', '');
    return out;
  }
};
const { errors, warnings, ran } = lint(env);
// Körbevis: verify.mjs sätter "not run" på varje kontroll som INTE står här.
console.log('KÖRDA: ' + (ran || []).join(' '));
for (const w of warnings) console.warn('◐ ' + w);
for (const e of errors) console.error('✖ ' + e);
console.log('\n' + errors.length + ' fel · ' + warnings.length + ' varningar');
process.exit(errors.length ? 1 : 0);
