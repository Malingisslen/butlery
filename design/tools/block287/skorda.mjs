// Kor: node tools/block287/skorda.mjs --root=<kallrot> --ut=<skord.json> [--filordning=fallande]
//
// CLI runt tools/discovery-harvest.mjs. Skorden kordes tidigare som ett
// engangsskript utanfor repot; utan den har gar kedjan inte att koras om ur en
// ren utcheckning.
import { writeFileSync } from 'node:fs';
import { skorda } from '../discovery-harvest.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root') || process.cwd();
const UT = arg('ut');
if (!UT) { console.error('skorda.mjs kraver --ut=<fil>'); process.exit(2); }
const val = { filordning: arg('filordning') || 'stigande' };
if (arg('krom')) val.krom = arg('krom');

const s = await skorda(ROT, val);
writeFileSync(UT, JSON.stringify(s, null, 1) + '\n');
const antal = Array.isArray(s) ? s.length : (s.objekt || s.rader || []).length;
console.log(JSON.stringify({ SKORDADE_OBJEKT: antal, FILORDNING: val.filordning }, null, 1));
