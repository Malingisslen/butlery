// Kor: node tools/block288/uxprov.mjs --root=<kallrot>
//
// UX-01..UX-17 · det aktiva provet for Block 288:s UX-frysning. Provet laser
// bara kallorna och den ombyggda modellen; det litar aldrig pa ett tal som
// nagon skrivit in.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { bygg } from './uxfrysning.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root') || '.';
const j = f => JSON.parse(readFileSync(join(ROT, f), 'utf8'));

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

const m = bygg(ROT);
const b = m.BINDNING;
const k0608 = j('fas2/stateflow-applicability-0608.json');
const b283 = j('fas2/stateflow-applicability.json');

/* UX-01 · alla atta floden ar modellerade */
prov('UX-01', 'alla atta floden har frysta overgangar',
  b.FLOWS_MODELLED === 8, 'FLOWS_MODELLED=' + b.FLOWS_MODELLED);

/* UX-02 · Block 283 ar orort */
{
  const kvar = m.overgangar.filter(t => t.BLOCK === '283');
  const identitet = kvar.length === b283.overgangar.length
    && kvar.every(t => b283.overgangar.some(o => o.TRANSITION_ID === t.TRANSITION_ID));
  const statusOrord = kvar.every(t => {
    const o = b283.overgangar.find(x => x.TRANSITION_ID === t.TRANSITION_ID);
    return t.STATUS === o.NEW_APPLICABILITY || (t.BESLUT && t.PREVIOUS_STATUS === o.NEW_APPLICABILITY);
  });
  prov('UX-02', 'Block 283:s 35 rader ar oforandrade utom dar ett produktbeslut overstyr dem',
    identitet && statusOrord, kvar.length + ' rader ur 283, ' + kvar.filter(t => t.BESLUT).length + ' overstyrda');
}

/* UX-03 · varje ny rad bar kalla och evidens */
{
  const utan = k0608.overgangar.filter(t => !t.SOURCE || !t.SOURCE.length || !t.SOURCE_LOCATION || !t.EVIDENCE);
  prov('UX-03', 'varje overgang i floden 06-08 bar kalla och evidens', utan.length === 0,
    utan.map(t => t.TRANSITION_ID).join(', '));
}

/* UX-04 · ingen olost overgang */
prov('UX-04', 'ingen overgang star olost', b.TRANSITIONS_UNRESOLVED === 0, 'UNRESOLVED=' + b.TRANSITIONS_UNRESOLVED);

/* UX-05 · varje endpoint-tillstand ar ett kanoniskt vytillstand */
{
  const kanoniska = new Set(['DEFAULT', 'LOADING', 'EMPTY', 'PARTIAL', 'ERROR', 'OFFLINE', 'CONFLICT']);
  const okanda = m.vytillstand.filter(r => !kanoniska.has(r.STATE));
  prov('UX-05', 'tillstandsmodellen anvander bara de sju kanoniska tillstanden',
    okanda.length === 0, okanda.length + ' okanda');
}

/* UX-06 · representation raknas ur korpusen, inte ur raden */
{
  const pastaende = k0608.overgangar.filter(t => 'REPRESENTATION_STATUS' in t);
  prov('UX-06', 'ingen rad i 06-08 pastar sin egen representation',
    pastaende.length === 0, pastaende.length + ' rader bar ett eget REPRESENTATION_STATUS');
}

/* UX-07 · beslutsbehov ar redovisade och kopplade till rader */
{
  const behov = k0608.beslutsbehov || [];
  const berorda = behov.flatMap(d => d.BEROR || []);
  const allaIdn = new Set(m.overgangar.map(t => t.TRANSITION_ID));
  const saknade = berorda.filter(id => !allaIdn.has(id));
  prov('UX-07', 'varje beslutsbehov pekar pa overgangar som finns',
    behov.length > 0 && saknade.length === 0, 'behov=' + behov.length + ' okanda rader=' + saknade.join(', '));
}

/* UX-08 · en NOT_REQUIRED-rad maste bara sitt skal */
{
  const utan = k0608.overgangar.filter(t => t.STATUS === 'NOT_REQUIRED' && !t.DECISION_BASIS);
  prov('UX-08', 'varje NOT_REQUIRED bar ett skal', utan.length === 0, utan.map(t => t.TRANSITION_ID).join(', '));
}

/* UX-09 · antalen i kallfilen stammer med de ombyggda */
{
  const f = k0608.forvantat;
  const ok = f.TRANSITION_ROWS === b.TRANSITIONS_FLOW_06_08
    && f.DESIGN_DECISION_REQUIRED === (k0608.beslutsbehov || []).length
    && f.REQUIRED === k0608.overgangar.filter(t => t.STATUS === 'REQUIRED').length
    && f.NOT_REQUIRED === k0608.overgangar.filter(t => t.STATUS === 'NOT_REQUIRED').length;
  prov('UX-09', 'kallfilens forvantade tal stammer med de ombyggda', ok,
    'rader=' + b.TRANSITIONS_FLOW_06_08 + ' nedtecknade behov=' + (k0608.beslutsbehov || []).length);
}

/* UX-10 · den visuella frysningen ar inte omraknad har */
{
  const visuell = j('fas2/block287k-frysning.json');
  const ok = visuell.STATUS === 'FROZEN' && m.PROVENIENS.VISUAL_REQUIREMENT_FREEZE === 'fas2/block287k-frysning.json'
    && !('BLOCK287_POPULATION_COUNT' in b);
  prov('UX-10', 'UX-frysningen rakner inte om den visuella frysningen', ok, 'visuell STATUS=' + visuell.STATUS);
}

/* UX-11 · modellen ar ordningsoberoende: varje radmangd ar sorterad pa sin identitet */
{
  const sorterad=(arr,nyckel)=>arr.every((x,i)=>i===0||nyckel(arr[i-1]).localeCompare(nyckel(x))<=0);
  const a=sorterad(m.overgangar,t=>t.TRANSITION_ID);
  const b2=sorterad(m.interaktion,r=>r.ROW_ID);
  const c=sorterad(m.vytillstand,r=>r.VIEW+r.STATE);
  prov("UX-11","alla radmangder ar sorterade pa identitet, sa indataordning inte kan andra utfallet",a&&b2&&c,"overgangar="+a+" interaktion="+b2+" vytillstand="+c);
}

/* UX-12 · tva ombyggnader ur samma kalla ger samma bindning */
{
  const igen=bygg(ROT);
  prov("UX-12","tva ombyggnader ger samma bindning",
    JSON.stringify(igen.BINDNING)===JSON.stringify(m.BINDNING),"avtryck="+igen.BINDNING.UX_MODEL_FINGERPRINT);
}

/* UX-13 · varje produktbeslut ar tillampat pa modellen */
{
  const bes=j("fas2/ux-beslut.json");
  const idn=new Set(m.overgangar.map(t=>t.TRANSITION_ID));
  const saknade=bes.beslut.flatMap(d=>(d.AFFECTED_TRANSITIONS||[]).map(t=>t.TRANSITION_ID)).filter(id=>!idn.has(id));
  const otillampade=bes.beslut.flatMap(d=>(d.AFFECTED_TRANSITIONS||[]).map(t=>({d:d.DECISION_ID,...t})))
    .filter(t=>{const r=m.overgangar.find(x=>x.TRANSITION_ID===t.TRANSITION_ID); return !r||r.BESLUT!==t.d;});
  prov("UX-13","varje beslut pekar pa rader som finns och ar tillampat",
    saknade.length===0&&otillampade.length===0,"saknade="+saknade.join(", ")+" otillampade="+otillampade.length);
}

/* UX-14 · ett overstyrt krav raderas inte, det bevaras som tidigare status */
{
  const over=m.overgangar.filter(t=>t.BESLUT&&t.STATUS==="NOT_REQUIRED");
  prov("UX-14","varje overstyrd rad bar kvar sin tidigare status och sitt beslut",
    over.length>0&&over.every(t=>t.PREVIOUS_STATUS==="REQUIRED"&&t.BESLUT),over.length+" overstyrda");
}

/* UX-15 · genereringens angravag och konflikthanteringen ar skilda mekanismer */
{
  const kvitto=m.overgangar.find(t=>t.TRANSITION_ID==="TR::FLOW::01::placering::kvitto-7-s-andra");
  const konflikt=m.overgangar.find(t=>t.TRANSITION_ID==="TR::FLOW::01::vecka-sparad-av-annan::konfliktsnackbar");
  const gamla=m.overgangar.filter(t=>/resultat::(ångra-snackbar-30-s|efter-30-s)/.test(t.TRANSITION_ID));
  prov("UX-15","placeringskvittot och konflikthanteringen ar tva skilda rader, och den gamla angravagen pa resultatet ar overstyrd",
    !!kvitto&&kvitto.STATUS==="REQUIRED"&&!!konflikt&&konflikt.STATUS==="REQUIRED"&&gamla.length===2&&gamla.every(t=>t.STATUS==="NOT_REQUIRED"),
    "kvitto="+(kvitto&&kvitto.STATUS)+" konflikt="+(konflikt&&konflikt.STATUS)+" gamla="+gamla.map(t=>t.STATUS).join("/"));
}

/* UX-16 · inget beslutsbehov star kvar */
prov("UX-16","inget oppet designbeslut aterstar",b.DESIGN_DECISION_REQUIRED===0,"DESIGN_DECISION_REQUIRED="+b.DESIGN_DECISION_REQUIRED);

/* UX-17 · lang vantan ar inte langre en vag ut ur genereringen */
{
  const kvar=m.overgangar.filter(t=>/lång-väntan|genererar::10-s$/.test(t.TRANSITION_ID)&&t.STATUS==="REQUIRED");
  const textrad=m.overgangar.find(t=>t.TRANSITION_ID==="TR::FLOW::01::genererar::6-10-s");
  prov("UX-17","lang vantan och bakgrundsvalet ar borta, men den tidsdrivna texten star kvar",
    kvar.length===0&&!!textrad&&textrad.STATUS==="REQUIRED","kvarvarande="+kvar.length+" textrad="+(textrad&&textrad.STATUS));
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id.padEnd(8) + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nUX ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
