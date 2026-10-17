// The lab's example screens are written by hand after the app's views. Each <figure data-views="..."> in
// designlabb.html names the app files it copies; lab-views.json holds a hash of those files from the day the
// screen was last brought in line. A hash that no longer matches is reported as a CI warning, never a failure,
// because most view edits do not change what the lab should show.
//   node tools/lab-views-check.mjs           report
//   node tools/lab-views-check.mjs --stamp   record the current hashes (after the lab screen is updated)
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const html = readFileSync(join(root, 'design/mockup-kit/designlabb.html'), 'utf8');
const stampFile = join(root, 'design/mockup-kit/lab-views.json');

const paths = new Set();
const owners = new Map();
for (const m of html.matchAll(/<figure data-views="([^"]+)"/g)) for (const p of m[1].split(/\s+/)) paths.add(p);

const filesUnder = p => {
  const full = join(root, p);
  if (!statSync(full).isDirectory()) return [p];
  return readdirSync(full, { recursive: true }).filter(f => f.endsWith('.dart')).sort().map(f => join(p, f));
};
const hashOf = p => {
  const h = createHash('sha1');
  for (const f of filesUnder(p)) h.update(f).update(readFileSync(join(root, f)));
  return h.digest('hex').slice(0, 12);
};

const current = Object.fromEntries([...paths].sort().map(p => [p, hashOf(p)]));
if (process.argv.includes('--stamp')) {
  writeFileSync(stampFile, JSON.stringify(current, null, 2) + '\n');
  console.log(`LAB-VIEWS stamped ${Object.keys(current).length} paths`);
  process.exit(0);
}
let stamped = {};
try { stamped = JSON.parse(readFileSync(stampFile, 'utf8')); } catch { /* first run */ }
const moved = Object.keys(current).filter(p => stamped[p] !== current[p]);
for (const p of moved) console.log(`::warning file=${p}::The lab's example screen for ${p} was last matched to an older version of it. Check design/mockup-kit/designlabb.html, update the screen if the view changed, then run: cd design && node tools/lab-views-check.mjs --stamp`);
console.log(moved.length ? `LAB-VIEWS ${moved.length} of ${Object.keys(current).length} paths changed since the lab was matched` : `LAB-VIEWS ok (${Object.keys(current).length} paths)`);
