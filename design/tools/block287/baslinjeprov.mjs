// Kor: node tools/block287/baslinjeprov.mjs --medlemmar=<medlemmar.json> --root=<kallrot>
// BV-01..BV-06 · baslinjegrinden far inte kunna passera nar en medlem byts mot en annan.
// Ett antal som star stilla ar inget bevis: mangden maste jamforas, inte summan.
import { readFileSync } from 'node:fs';
import { lcMedlemskap, medlemsHash, storlekAv } from './lc-medlemmar.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const M = JSON.parse(readFileSync(arg('medlemmar'), 'utf8'));
const INV = JSON.parse(readFileSync((arg('root') || '.') + '/fas2/matning/bas-inventering.json', 'utf8'));
const FV = INV.forvantat.MEDLEMSMANGDER;
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });
const kopia = o => JSON.parse(JSON.stringify(o));

/** Grinden: samma jamforelse som bas-build gor mot forvantat. */
const passerar = (namn, lista, antalNyckel, hashNyckel) =>
  lista.length === FV[antalNyckel] && medlemsHash(lista) === FV[hashNyckel];

const LC = M.LC_MEDLEMMAR, T08 = M.T08_MEDLEMMAR, REC = M.AVSTAMNING_MEDLEMMAR;

prov('BV-00', 'orord mangd passerar grinden',
  passerar('LC', LC, 'LC_MEMBER_COUNT', 'LC_MEMBER_SET_HASH')
  && passerar('T08', T08, 'T08_MEMBER_COUNT', 'T08_MEMBER_SET_HASH')
  && passerar('REC', REC, 'RECONCILIATION_MEMBER_COUNT', 'RECONCILIATION_MEMBER_SET_HASH'),
  LC.length + '/' + T08.length + '/' + REC.length);

{ // BV-01 · en LC-medlem byts mot en orelaterad, antalet star stilla
  const m = kopia(LC); m[0] = { ...m[0], ID: 'LC::pahittadram::radie 3 - tillatna: 0 / 2 / 8 / 12 / 999' };
  prov('BV-01', 'LC-medlem ersatt med orelaterad, samma antal => FAIL',
    m.length === LC.length && !passerar('LC', m, 'LC_MEMBER_COUNT', 'LC_MEMBER_SET_HASH'), m.length);
}
{ // BV-02 · en T-08-medlems identitet muteras
  const m = kopia(T08); m[5] = String(m[5]).replace(/\|/, '|MUTERAD ');
  prov('BV-02', 'T-08-medlems identitet muterad, samma antal => FAIL',
    m.length === T08.length && !passerar('T08', m, 'T08_MEMBER_COUNT', 'T08_MEMBER_SET_HASH'), m.length);
}
{ // BV-03 · en avstamningsmedlem muteras
  const m = kopia(REC); m[m.length - 1] = String(m[m.length - 1]) + ' MUTERAD';
  prov('BV-03', 'avstamningsmedlem muterad, samma antal => FAIL',
    m.length === REC.length && !passerar('REC', m, 'RECONCILIATION_MEMBER_COUNT', 'RECONCILIATION_MEMBER_SET_HASH'), m.length);
}
{ // BV-04 · en avatar som bara finns via var() tappas bort
  const utan = LC.filter(x => !(x.REPRESENTATION === 'VAR_REFERENS' && /::avatar::/.test(x.ID) && /#1$/.test(x.ID)));
  prov('BV-04', 'en var()-buren avatar tappas => FAIL',
    utan.length < LC.length && !passerar('LC', utan, 'LC_MEMBER_COUNT', 'LC_MEMBER_SET_HASH'),
    LC.length + ' -> ' + utan.length);
}
{ // BV-05 · literal farg <-> var()-referens ger samma medlemskap
  const avatar = LC.find(x => x.REPRESENTATION === 'VAR_REFERENS');
  if (!avatar) prov('BV-05', 'literal <-> var() ger samma medlemskap', false, 'ingen var()-buren avatar i mangden');
  else {
    const storlek = /::avatar::([\d.]+)/.exec(avatar.ID)[1];
    // utgangslage: avataren syns bara i matfilen
    const lintRader = LC.filter(x => !/::avatar::/.test(x.ID)).map(x => ({ fil: x.fil, ram: x.ram, text: x.text }));
    const lintAvatarer = LC.filter(x => /::avatar::/.test(x.ID) && x.REPRESENTATION === 'LITERAL')
      .map(x => ({ fil: x.fil, ram: x.ram, text: x.text }));
    const matAvatarer = LC.filter(x => /::avatar::/.test(x.ID) && x.REPRESENTATION === 'VAR_REFERENS')
      .map(x => ({ fil: x.fil, ram: x.ram, storlek: /::avatar::([\d.]+)/.exec(x.ID)[1], text: x.text }));
    const fore = lcMedlemskap([...lintRader, ...lintAvatarer], matAvatarer);
    // mutation: just denna avatar skrivs om till literal farg, sa linten ser den sjalv
    const flyttad = matAvatarer.filter(a => !(a.ram === avatar.ram && a.storlek === storlek));
    const nyLint = matAvatarer.filter(a => a.ram === avatar.ram && a.storlek === storlek)
      .map(a => ({ fil: a.fil, ram: a.ram, text: 'avatar ' + storlek + ' px — skalan är 26 / 32 / 40 / 54 / 72' }));
    const efter = lcMedlemskap([...lintRader, ...lintAvatarer, ...nyLint], flyttad);
    prov('BV-05', 'literal farg <-> var()-referens ger oforandrat medlemskap',
      efter.length === fore.length && medlemsHash(efter) === medlemsHash(fore),
      fore.length + '/' + medlemsHash(fore) + ' vs ' + efter.length + '/' + medlemsHash(efter));
  }
}
{ // BV-06 · omvand filordning ger identiska mangder och hashar
  const lintRader = LC.filter(x => !/::avatar::/.test(x.ID)).map(x => ({ fil: x.fil, ram: x.ram, text: x.text }));
  const matAvatarer = LC.filter(x => /::avatar::/.test(x.ID) && x.REPRESENTATION === 'VAR_REFERENS')
    .map(x => ({ fil: x.fil, ram: x.ram, storlek: /::avatar::([\d.]+)/.exec(x.ID)[1], text: x.text }));
  const lintAvatarer = LC.filter(x => /::avatar::/.test(x.ID) && x.REPRESENTATION === 'LITERAL')
    .map(x => ({ fil: x.fil, ram: x.ram, text: x.text }));
  const a = lcMedlemskap([...lintRader, ...lintAvatarer], matAvatarer);
  const b = lcMedlemskap([...lintRader, ...lintAvatarer].reverse(), matAvatarer.slice().reverse());
  prov('BV-06', 'omvand filordning ger samma mangd och samma hash',
    a.length === b.length && medlemsHash(a) === medlemsHash(b)
      && medlemsHash(T08) === medlemsHash(kopia(T08).reverse())
      && medlemsHash(REC) === medlemsHash(kopia(REC).reverse()),
    medlemsHash(a) + ' vs ' + medlemsHash(b));
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
