// Källskanner: numrerar elementens starttaggar i dokumentordning, samma ordning som support.js compileTemplate.
// Exporterar starttaggarnas positioner per fil. Ingen skrivning.
import { readFileSync } from 'node:fs';
export function startTags(src) {
  // x-dc-innehållet är allt mellan <x-dc> och </x-dc>
  const a = src.indexOf('<x-dc>'); const b = src.lastIndexOf('</x-dc>');
  const from = a >= 0 ? a + '<x-dc>'.length : 0;
  const to = b >= 0 ? b : src.length;
  const region = src.slice(from, to);
  const out = []; let i = 0;
  while (i < region.length) {
    const lt = region.indexOf('<', i);
    if (lt < 0) break;
    if (region.startsWith('<!--', lt)) { const e = region.indexOf('-->', lt); i = e < 0 ? region.length : e + 3; continue; }
    if (region.startsWith('<!', lt)) { const e = region.indexOf('>', lt); i = e < 0 ? region.length : e + 1; continue; }
    if (region.startsWith('</', lt)) { const e = region.indexOf('>', lt); i = e < 0 ? region.length : e + 1; continue; }
    const m = /^<([a-zA-Z][a-zA-Z0-9-]*)/.exec(region.slice(lt, lt + 40));
    if (!m) { i = lt + 1; continue; }
    // hitta slutet på starttaggen, hoppa över citerade attributvärden
    let j = lt + 1 + m[1].length, q = null;
    while (j < region.length) {
      const c = region[j];
      if (q) { if (c === q) q = null; }
      else if (c === '"' || c === "'") q = c;
      else if (c === '>') break;
      j++;
    }
    const tag = m[1].toLowerCase();
    out.push({ tag, start: from + lt, tagEnd: from + j, nameEnd: from + lt + 1 + m[1].length });
    const RAW = tag === 'script' || tag === 'style';
    if (RAW) { const close = region.toLowerCase().indexOf('</' + tag, j); i = close < 0 ? region.length : close; }
    else i = j + 1;
  }
  return out;
}
if (process.argv[1] && process.argv[1].endsWith('scan.mjs')) {
  const src = readFileSync(process.argv[2], 'utf8');
  const t = startTags(src);
  console.log(JSON.stringify({ count: t.length, first: t.slice(0, 5).map(x => x.tag), tagDist: t.reduce((o, x) => (o[x.tag] = (o[x.tag] || 0) + 1, o), {}) }, null, 1).slice(0, 900));
}
