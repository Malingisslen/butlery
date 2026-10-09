// Kor: node tools/block287-censusomprovning.mjs <scratchrot> <reporot>
// Kraver att tools/bl01-elementindex.mjs har skrivit <scratchrot>/bl01/idx-full.json.
// H/I · Omprovning av census-medlemskapet for HD4-delgrupperna BODY_OR_CONTENT_TEXT och CONTAINER.
// Manniskobeslutet star fast: akta presentationsmedlemmar forblir icke-kontroll/dekor.
// Har provas MEDLEMSKAPET mot BL-01-kallan med positiv kallevidens.
import { readFileSync, writeFileSync } from 'node:fs';
const [, , SC, REPO] = process.argv;
const IDX = JSON.parse(readFileSync(SC + '/bl01/idx-full.json', 'utf8'));
const A = JSON.parse(readFileSync(REPO + '/fas2/block287-avgoranden.json', 'utf8'));
const T = JSON.parse(readFileSync(REPO + '/tokens.json', 'utf8'));
const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const occId = e => 'OCC::' + slug(e.fil) + '::' + e.art + '::' + e.ordProd;
const byOcc = new Map(IDX.map(e => [occId(e), e]));
const norm = t => String(t || '').replace(/[ \t\n\r]+/g, ' ').trim().toLowerCase();
const rgb = s => { const m = /rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?/.exec(s || ''); return m ? [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]] : null; };
const eq = (a, b) => a && b && a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
const ACTION = [206, 124, 30], ONACTION = [23, 37, 29], B = T.controls.button;
const RADII = new Set(Object.values(T.space.radius));
const FIELDY = /^(textbox|searchbox|combobox|tab|button|switch|checkbox|radio|menuitem|link|spinbutton)$/;
const declared = IDX.filter(e => e.role);
const painted = e => { const b = rgb(e.bgC); return (b && b[3] > 0) || (parseFloat(e.bw) || 0) > 0; };
// stilnyckel utan positionsegenskaper: designkontraktet, inte placeringen
const POSITIONAL = /^(margin|flex|order|position|top|left|right|bottom|z-index|grid-)/;
const styleKey = st => String(st || '').split(';').map(x => x.trim()).filter(Boolean)
  .map(x => { const i = x.indexOf(':'); return [x.slice(0, i).trim().toLowerCase(), x.slice(i + 1).trim().replace(/\s+/g, ' ').toLowerCase()]; })
  .filter(p => p[0] && !POSITIONAL.test(p[0])).sort().map(p => p[0] + ':' + p[1]).join(';');
const gsig = e => [e.bgC, e.fgC, e.bw, e.bc, e.mh, e.hh, e.fsz, e.fwt, e.brad, e.pad].join('|');
const add = (m, k, x) => { if (!k) return; (m.get(k) || m.set(k, []).get(k)).push(x); };
const gix = new Map(), tix = new Map();
for (const e of declared) { add(gix, gsig(e), e); add(tix, norm(e.own), e); add(tix, norm(e.name), e); }
const ctlByOcc = new Map();
for (const p of Object.entries(A.forekomst)) if (p[1].klass === 'KNOWN_CONTROL') ctlByOcc.set(p[0], p[1]);
const frameCtl = new Map();
for (const e of IDX) {
  const isCtl = !!e.role || ctlByOcc.has(occId(e));
  if (!isCtl) continue;
  const roll = e.role || (ctlByOcc.get(occId(e)) || {}).roll || null;
  add(frameCtl, e.art + '|' + styleKey(e.style), { e: e, roll: roll });
}
const REOPEN = /HD4-(BODY_OR_CONTENT_TEXT|CONTAINER_WITH_KNOWN_CONTROLS_AND_OWN_TEXT)/;
const reopened = Object.entries(A.forekomst).filter(p => REOPEN.test(p[1].sg));
const kontroller = [], kvar = [];
const promoted = new Map();   // OCCURRENCE_ID -> roll, fran tidigare varv
let VARV=0;
function passera() {
  kontroller.length=0; kvar.length=0;
  for (const pair of reopened) {
  const id = pair[0], v = pair[1];
  const e = byOcc.get(id); if (!e) continue;
  const bg = rgb(e.bgC), fg = rgb(e.fgC), fsz = parseFloat(e.fsz), fwt = parseInt(e.fwt, 10);
  const brad = parseFloat(e.brad) || 0;
  const R = [];
  if (eq(bg, ACTION) && eq(fg, ONACTION) && norm(e.own) && fsz === B.fontSize && fwt === B.weight)
    R.push({ rule: 'R1_ACTION_PRIMARY', role: 'button', bevis: 'beraknad yta = designtokenet semantic.action.primary #CE7C1E med parad text.onActionPrimary #17251D och controls.button ' + B.fontSize + '/' + B.weight });
  const sib = (frameCtl.get(e.art + '|' + styleKey(e.style)) || []).filter(x => x.e.ordProd !== e.ordProd && x.roll);
  const sibRoles = [...new Set(sib.map(x => x.roll).filter(r => FIELDY.test(r)))];
  if (sib.length && sibRoles.length === 1)
    R.push({ rule: 'R5_IDENTICAL_SIBLING_IN_FRAME', role: sibRoles[0], bevis: 'identisk kallforfattad stil som ' + sib.length + ' redan klassad ' + sibRoles[0] + ' i samma ram: ' + sib.slice(0, 3).map(x => '#' + x.e.ordProd + ' "' + (x.e.own || x.e.text).slice(0, 18) + '"').join(', ') });
  const gAll = (gix.get(gsig(e)) || []).filter(x => x.art !== e.art);
  const gRoles = [...new Set(gAll.map(x => x.role))];
  if (gAll.length && gRoles.length === 1 && FIELDY.test(gRoles[0]) && painted(e))
    R.push({ rule: 'R2_DECLARED_SHAPE_TWIN', role: gRoles[0], bevis: 'identisk kontrollkontraktsignatur som kalldeklarerad ' + gRoles[0] + ' i ' + [...new Set(gAll.map(x => x.art))].slice(0, 3).join(', ') + '; signaturen traffar bara den rollen' });
  const tAll = (tix.get(norm(e.own)) || []).concat(tix.get(norm(e.text)) || []).filter(x => x.art !== e.art && FIELDY.test(x.role));
  const tRoles = [...new Set(tAll.map(x => x.role))];
  const boxad = painted(e) && RADII.has(brad);
  const typoLik = tAll.some(x => x.tag === e.tag && Math.abs((parseFloat(x.fsz) || 0) - fsz) < 0.6 && (parseInt(x.fwt, 10) || 0) === fwt);
  if (tAll.length && !e.inDecl && tRoles.length === 1 && (boxad || typoLik))
    R.push({ rule: 'R3_DECLARED_TEXT_TWIN', role: tRoles[0], bevis: 'samma synliga text som kalldeklarerad ' + tRoles[0] + ' i ' + [...new Set(tAll.map(x => x.art))].slice(0, 3).join(', ') + (boxad ? '; elementet bar en kontrollformad ruta (kant eller yta plus radie ur skalan)' : '; samma tagg och typografi') });
  if (e.comp && /^(chip|toggle|checkbox)$/.test(e.comp))
    R.push({ rule: 'R4_COMPONENT_TOKEN', role: e.comp === 'chip' ? 'button' : e.comp, bevis: 'data-component="' + e.comp + '" ur komponentarket' });
  const rad = { OCCURRENCE_ID: id, SUBGROUP: v.sg, RAM: e.art, ordProd: e.ordProd, TAGG: e.tag, TEXT: (e.own || e.text).slice(0, 70) };
  if (R.length) kontroller.push(Object.assign({}, rad, { TIDIGARE: v.klass, NY_KLASS: 'KNOWN_CONTROL', ROLL: R[0].role, REGLER: R }));
  else kvar.push(Object.assign({}, rad, { KLASS: v.klass, SKAL: 'ingen positiv kallevidens: ingen designtoken, inget identiskt kontrollsyskon i ramen, ingen diskriminerande tvilling mot kalldeklarerad kontroll' }));
  }
}
// R5 till fixpunkt: en nyklassad kontroll smittar sina identiska syskon i samma ram
for(;;){ passera(); VARV++;
  let nytt=0;
  for(const k of kontroller){ if(!promoted.has(k.OCCURRENCE_ID)){ promoted.set(k.OCCURRENCE_ID,k.ROLL); nytt++;
      const e=byOcc.get(k.OCCURRENCE_ID); if(e) add(frameCtl, e.art+"|"+styleKey(e.style), {e:e, roll:k.ROLL}); } }
  if(!nytt||VARV>12) break; }
console.log("R5-fixpunkt efter",VARV,"varv");
const ut = {
  $om: 'Block 287 · omprovat census-medlemskap for HD4-delgrupperna BODY_OR_CONTENT_TEXT och CONTAINER, mot BL-01',
  BASLINJE: 'BL-01',
  MANSKLIGT_BESLUT: 'HD-UNMARKED-PRESENTATION star fast: akta presentationsmedlemmar forblir KNOWN_NON_CONTROL / DECORATIVE_OR_STRUCTURAL. Endast medlemskapet ar omprovat.',
  ATERUPPTAGNA: reopened.length,
  OMKLASSADE_TILL_KONTROLL: kontroller.length,
  KVAR_SOM_PRESENTATION: kvar.length,
  REGLER: {
    R1_ACTION_PRIMARY: 'ytan ar designtokenet semantic.action.primary med parad textfarg och knappens typografi',
    R2_DECLARED_SHAPE_TWIN: 'identisk kontrollkontraktsignatur som en kalldeklarerad kontroll i annan ram, och signaturen traffar bara en roll',
    R3_DECLARED_TEXT_TWIN: 'samma synliga text som en kalldeklarerad kontroll, plus kontrollform eller samma typografi',
    R4_COMPONENT_TOKEN: 'data-component ur komponentarket',
    R5_IDENTICAL_SIBLING_IN_FRAME: 'identisk kallforfattad stil som ett element i SAMMA ram som redan ar klassat kontroll'
  },
  KONTROLLER: kontroller,
  KVAR: kvar
};
writeFileSync(SC + '/bl01/census-reopen.json', JSON.stringify(ut, null, 1) + '\n');
const t = {};
for (const k of kontroller) { const s = k.REGLER.map(r => r.rule).join('+'); t[s] = (t[s] || 0) + 1; }
console.log('aterupptagna:', reopened.length, '| omklassade till KONTROLL:', kontroller.length, '| kvar som presentation:', kvar.length);
for (const p of Object.entries(t).sort((a, b) => b[1] - a[1])) console.log('  ' + p[1] + '  ' + p[0]);
const perRoll = {}; for (const k of kontroller) perRoll[k.ROLL] = (perRoll[k.ROLL] || 0) + 1;
console.log('roller:', JSON.stringify(perRoll));
