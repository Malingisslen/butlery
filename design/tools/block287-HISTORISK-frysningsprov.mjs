// HISTORISKT PROV - galler den OGILTIGFORKLARADE frysningen fas2/block287-frysning.json.
//
//   Det har ar INTE det aktiva Block 287-provet. Den frysning det provar bygger pa
//   den gamla positionsidentiteten och ar ersatt. Ett gront resultat har sager
//   ingenting om den kanoniska frysningen.
//
//   Aktivt prov:      node tools/block287/frysningsprov.mjs --root=<rot> --bygge=<byggkatalog>
//   Kanonisk frysning: fas2/block287k-frysning.json
//
//   Provet finns kvar for att den historiska evidensen fortfarande citeras av
//   fyndstangningen (M5:s 33/4/39). Kor det bara nar du medvetet granskar historik.
//
// Kor: node tools/block287-HISTORISK-frysningsprov.mjs --historisk
// Laser bara de persisterade artefakterna i fas2/ och designkallan; raknar om alla hashar och invarianter.
//   F01 populationens, statusens och forekomsternas hashar = manifestet
//   F02 inga UNKNOWN_SEMANTICS, inga manskliga beslut kvar, inga olosta agare, inga identitetskollisioner
//   F03 varje ursprunglig UNKNOWN (1538) har exakt ett terminalt utfall i avgorandena
//   F04 de fyra manskliga besluten finns med beslut, omfang, forekomster och proveniens
//   F05 HD4 ar avgransat till census-forekomsterna (ingen global regel)
//   F06 alla ankare i ankarkartan finns exakt en gang i kallan
//   F07 skrivledgern: varje blockerad agare har minst ett uttryckligt hinder; summorna stammer
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
if (!process.argv.includes('--historisk')) {
  console.error('✖ Det har provet galler den OGILTIGFORKLARADE frysningen och kors inte av misstag.');
  console.error('  Aktivt prov: node tools/block287/frysningsprov.mjs --root=<rot> --bygge=<byggkatalog>');
  console.error('  Kor detta anda med --historisk om du medvetet granskar historiken.');
  process.exit(2);
}
const ROT = join(dirname(fileURLToPath(import.meta.url)), '..');
const las = f => JSON.parse(readFileSync(join(ROT, 'fas2', f), 'utf8'));
const sha = x => createHash('sha256').update(JSON.stringify(x)).digest('hex');
const M = las('block287-frysning.json'), P = las('block287-population.json'), A = las('block287-avgoranden.json'), B = las('block287-beslut.json'), L = las('block287-skrivledger.json'), K = las('block287-ankarkarta.json');
const res = []; const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag) });
const enh = [...P].sort((a, b) => (a.id < b.id ? -1 : 1));
const hashar = { BLOCK287_POPULATION_HASH: sha(enh.map(e => e.id)), BLOCK287_STATUS_HASH: sha(enh.map(e => [e.id, e.CATEGORY, e.CURRENT_STATUS, (e.BLOCKERS || []).join(',')])),
  BLOCK287_OCCURRENCE_HASH: sha(enh.map(e => [e.id, e.OCCURRENCES || 1])) };
prov('F01', 'hasharna och antalet stammer med manifestet', enh.length === M.BLOCK287_POPULATION_COUNT && Object.entries(hashar).every(([k, v]) => M[k] === v), JSON.stringify(hashar));
const ids = enh.map(e => e.id);
const unk = enh.find(e => e.id === 'RP::DISCOVERY::UNKNOWN_SEMANTICS');
prov('F02', 'UNKNOWN 0, manskliga beslut 0, olosta agare 0, kollisioner 0', (!unk || unk.OCCURRENCES === 0) && !enh.some(e => e.CATEGORY === 'HUMAN_DECISION_REQUIRED' || e.CATEGORY === 'OWNER_IDENTITY_UNRESOLVED') && ids.length === new Set(ids).size
  && !Object.values(A.forekomst).some(v => v.klass === 'UNKNOWN_SEMANTICS' || v.beslutskort), JSON.stringify({ unknown: unk && unk.OCCURRENCES, dubbletter: ids.length - new Set(ids).size }));
const ursprung = M.UNKNOWN_START_OCCURRENCES || [];
const TERMINAL = new Set(['KNOWN_CONTROL', 'KNOWN_NON_CONTROL', 'DECORATIVE_OR_STRUCTURAL', 'OUT_OF_SCOPE', 'DUPLICATE_OF_CANONICAL_OWNER', 'KNOWN_COMPONENT']);
prov('F03', 'varje ursprunglig UNKNOWN har exakt ett terminalt utfall', ursprung.length === 1538 && ursprung.every(id => A.forekomst[id] && TERMINAL.has(A.forekomst[id].klass)), ursprung.length);
const kraven = ['HD-BACK-NAME-POLICY', 'HD-MORE-ACTIONS-OBJECT', 'HD-UNDECLARED-AFFORDANCE', 'HD-UNMARKED-PRESENTATION'];
prov('F04', 'de fyra besluten ar persisterade med omfang och proveniens', kraven.every(k => { const b = B.beslut.find(x => x.DECISION_ID === k); return b && b.DECISION && b.SCOPE && Array.isArray(b.AFFECTED_OCCURRENCES) && b.AFFECTED_OCCURRENCES.length && b.RATIONALE_PROVENANCE; }), B.beslut.map(b => b.DECISION_ID + ':' + b.AFFECTED_OCCURRENCES.length).join(' '));
const hd4 = B.beslut.find(x => x.DECISION_ID === 'HD-UNMARKED-PRESENTATION');
prov('F05', 'HD4 galler exakt de 1295 census-forekomsterna, ingen global regel', hd4.AFFECTED_OCCURRENCES.length === 1295 && /ingen global/i.test(hd4.SCOPE) && Object.values(A.forekomst).filter(v => /^HD4-/.test(v.sg || '')).length === 1295, hd4.AFFECTED_OCCURRENCES.length);
const kalla = {}; for (const f of readdirSync(ROT).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f))) for (const m of readFileSync(join(ROT, f), 'utf8').matchAll(/data-occurrence="([^"]*)"/g)) kalla[m[1]] = (kalla[m[1]] || 0) + 1;
const ank = Object.values(K).map(k => k.PERSISTENT_DATA_OCCURRENCE);
prov('F06', 'ankarkartans varden finns exakt en gang i kallan', ank.length === M.FINAL_CANONICAL_ANCHORS && ank.every(v => kalla[v] === 1) && Object.values(kalla).every(n => n === 1), ank.filter(v => kalla[v] !== 1).length);
const blk = L.rader.filter(r => !r.WRITE_READY && !r.WRITE_READY_AFTER_SPEC_LINT_SYNC);
prov('F07', 'skrivledgern: blockerade har uttryckliga hinder och summorna stammer', blk.every(r => r.BLOCKING_REASONS.length) && L.WRITE_OWNER_COUNT === L.rader.length && L.WRITE_OWNER_COUNT === L.WRITE_READY_COUNT + L.WRITE_READY_AFTER_SPEC_LINT_SYNC + L.WRITE_BLOCKED_COUNT, JSON.stringify({ agare: L.WRITE_OWNER_COUNT, klara: L.WRITE_READY_COUNT, synk: L.WRITE_READY_AFTER_SPEC_LINT_SYNC, blockerade: L.WRITE_BLOCKED_COUNT }));
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
