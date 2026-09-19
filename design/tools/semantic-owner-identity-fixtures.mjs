#!/usr/bin/env node
// Prov for tools/semantic-owner-identity.mjs. Kor: node tools/semantic-owner-identity-fixtures.mjs
//   HN-01..14  handoffstyrda kontroller: agaren foljer monstret, aldrig namnet
//   A01..A12   objektankare: rad, betygsgrupp, chip, dubblettrevision
//   AO-01..05  handling i redan ankrat objekt: objektankare + stabil lokal handling
//   ST-01..07  lage/varde i namnet ar aldrig identitet (semantiska lagesfraser, inte skiljetecken)
//   C01..C14   innehallsobjekt: synligt innehall byts, agaren bestar
//   G01..G06   fail closed: legacy-skuld, veckomenyns byten, innehallsmallar, varde utan objekt
import { semantiskAgare, tilldela, narmasteAnkare, ankarRevision, LEGACY_IDENTITY_DEBT, POLICY, handoffMatris } from './semantic-owner-identity.mjs';
import { readFileSync, existsSync } from 'node:fs';

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag) });
// fakta: kedja = [kontrollens element, forfader ...]; led = { occ, innehall }
const f = (x = {}) => { const k = { art: 'prov', roll: 'button', namn: '', kedja: [], ...x }; return { ...k, objekt: narmasteAnkare(k.kedja) }; };
const self = occ => [{ occ, innehall: [] }];
const inne = (occ, innehall) => [{ occ: null, innehall: [] }, { occ, innehall }];
const n = k => { const r = semantiskAgare(k); return r.nyckel || 'OLOST'; };
const lika = (id, vad, a, b) => { const x = n(a), y = n(b); prov(id, vad, x !== 'OLOST' && x === y, x + ' / ' + y); };
const olika = (id, vad, a, b) => { const x = n(a), y = n(b); prov(id, vad, x !== 'OLOST' && y !== 'OLOST' && x !== y, x + ' / ' + y); };
const olost = (id, vad, a) => { const x = n(a); prov(id, vad, x === 'OLOST', x); };

// ── HN · handoffmonster
lika('HN-01', '"Stäng" → "Stäng Delning"', f({ art: 'tadelning', namn: 'Stäng', glyf: 'x' }), f({ art: 'tadelning', namn: 'Stäng Delning', glyf: 'x' }));
lika('HN-02', '"Visa lösenordet" → "Dölj lösenord"', f({ art: 'inloggning', namn: 'Visa lösenordet' }), f({ art: 'inloggning', namn: 'Dölj lösenord' }));
lika('HN-03', 'timerns tid byts', f({ art: 'laga', namn: 'Starta timer 15 minuter' }), f({ art: 'laga', namn: 'Starta timer 20 minuter' }));
lika('HN-04', '"Textstorlek" → "Öka textstorlek"', f({ art: 'lagamorkt', namn: 'Textstorlek', text: 'A+' }), f({ art: 'lagamorkt', namn: 'Öka textstorlek', text: 'A+' }));
lika('HN-05', 'OTP-namnet rattas', f({ art: 'authmfa', roll: 'textbox', namn: 'Sexsiffrig kod' }), f({ art: 'authmfa', roll: 'textbox', namn: 'Verifieringskod, sex siffror' }));
lika('HN-06', 'sorteringens aktuella ordning byts', f({ art: 'sortera', namn: 'Sortera listan, nu senast tillagda' }), f({ art: 'sortera', namn: 'Sortera listan, nu kortast tid' }));
lika('HN-07', 'favorit: lage/namn vaxlar', f({ art: 'recept', namn: 'Spara som favorit' }), f({ art: 'recept', namn: 'Ta bort från favoriter' }));
lika('HN-08', 'bakat: malformuleringen byts', f({ art: 'familj', namn: 'Tillbaka', glyf: 'arrow-left' }), f({ art: 'familj', namn: 'Tillbaka till Inställningar', glyf: 'arrow-left' }));
lika('HN-09', 'stang: vyslotten byts', f({ art: 'delaark', namn: 'Stäng Dela-arket', glyf: 'x' }), f({ art: 'delaark', namn: 'Stäng delningen', glyf: 'x' }));
lika('HN-10', 'radetiketten byts, radankaret bestar', f({ art: 'redigera', namn: 'Byt ut Tomat', kedja: inne('occ-radsju', ['Tomat']) }), f({ art: 'redigera', namn: 'Byt ut Körsbärstomat', kedja: inne('occ-radsju', ['Körsbärstomat']) }));
olika('HN-11', 'samma radhandling pa tva ankrade rader → skilda agare', f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag', kedja: inne('occ-rada', []) }), f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag', kedja: inne('occ-radb', []) }));
olost('HN-12', 'upprepad radhandling utan objektankare faller stangt', f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag' }));
lika('HN-13', 'filterchipets visningsnamn byts, optionsankaret bestar', f({ art: 'hemrecept', namn: 'Filtrera på Snabbt', kedja: self('occ-chipsnabb') }), f({ art: 'hemrecept', namn: 'Filtrera på Snabb mat', kedja: self('occ-chipsnabb') }));
olost('HN-14', 'filterchip med bara visningstext far ingen agare', f({ art: 'hemrecept', namn: 'Filtrera på Snabbt' }));

// ── A · objektankare for handoffmonster
const kryss = x => f({ art: 'delatlista', roll: 'checkbox', iLista: true, namn: 'Färskpotatis 2 kg', kedja: self('occ-radett'), ...x });
lika('A01', 'radens synliga text byts', kryss(), kryss({ namn: 'Nypotatis 2 kg' }));
lika('A02', 'personens namn byts — betygsagaren bestar', f({ art: 'familjebetyg', roll: 'radio', namn: '3 av 5 för Malin', kedja: inne('occ-betygsgrupp', []) }), f({ art: 'familjebetyg', roll: 'radio', namn: '3 av 5 för Malin G.', kedja: inne('occ-betygsgrupp', []) }));
lika('A03', 'filterchipets etikett byts', f({ art: 'hemrecept', namn: 'Filtrera på Snabbt', kedja: self('occ-chip') }), f({ art: 'hemrecept', namn: 'Filtrera på Snabb mat', kedja: self('occ-chip') }));
lika('A04', 'raden flyttas bland syskonen (ordinal/geometri laser inte)', kryss({ ordProd: 12, y: 100 }), kryss({ ordProd: 40, y: 900 }));
lika('A05', 'orelaterad rad infogas fore', kryss({ ordProd: 12 }), kryss({ ordProd: 13 }));
lika('A06', 'valt lage byts', kryss({ namn: 'Gul lök, vald' }), kryss({ namn: 'Gul lök' }));
lika('A07', 'mangd byts', kryss({ namn: 'Färskpotatis 2 kg' }), kryss({ namn: 'Färskpotatis 3 kg' }));
lika('A08', 'namnet rattas enligt handoffen', f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag', kedja: inne('occ-irad', []) }), f({ art: 'redigera', namn: 'Flytta Tomat', glyf: 'drag', kedja: inne('occ-irad', ['Tomat']) }));
lika('A09', 'rollen remedieras (odeklarerad → deklarerad)', kryss({ odeklarerad: true }), kryss({ deklarerad: true }));
olika('A10', 'samma handling pa tva olika ankrade objekt', f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag', kedja: inne('occ-irad', []) }), f({ art: 'redigera', namn: 'Flytta rad', glyf: 'drag', kedja: inne('occ-annan', []) }));
{ const html = '<div data-occurrence="occ-aaaaaaaaaaaa"></div><div data-occurrence="occ-bbbbbbbbbbbb"></div>';
  prov('A11', 'ren kalla har inga dubbletter; en tillagd dubblett upptacks', ankarRevision(html).length === 0 && ankarRevision(html + '<i data-occurrence="occ-aaaaaaaaaaaa"></i>').includes('occ-aaaaaaaaaaaa'), ankarRevision(html).length); }
{ const html = '<ul><li data-occurrence="occ-cccccccccccc">Tomat</li></ul>'; const kopia = html.replace('</ul>', '<li data-occurrence="occ-cccccccccccc">Tomat</li></ul>');
  prov('A12', 'kopierad rad utan nytt ankare ar en dubblett, inte tyst samma agare', ankarRevision(kopia).includes('occ-cccccccccccc'), ankarRevision(kopia).join(',')); }

// ── AO · handling i ett redan ankrat objekt (aldrig "ensam kontroll")
const regel = x => f({ art: 'taggdetalj', roll: 'switch', namn: 'Innehåller "rester"', kedja: inne('occ-regelrad', ['Nyckelord i titel eller beskrivning']), ...x });
{ const a = tilldela([regel()]); prov('AO-01', 'en kontroll i ankrat objekt → stabil agare', a[0].id === 'OWNER::taggdetalj::objekt::occ-regelrad::handling::rule-active', a[0].id); }
{ const ensam = tilldela([regel()])[0].id;
  const tva = tilldela([regel(), f({ art: 'taggdetalj', namn: 'Redigera regeln', kedja: inne('occ-regelrad', ['Nyckelord i titel eller beskrivning']) })]);
  prov('AO-02', 'ny orelaterad kontroll i samma objekt → forsta agaren oforandrad', tva[0].id === ensam && tva[1].id && tva[1].id !== ensam, ensam + ' / ' + tva.map(x => x.id).join(' , ')); }
{ const ett = tilldela([regel(), f({ art: 'taggdetalj', namn: 'Redigera regeln', kedja: inne('occ-regelrad', []) })]).map(x => x.id);
  const tva = tilldela([f({ art: 'taggdetalj', namn: 'Redigera regeln', kedja: inne('occ-regelrad', []) }), regel()]).map(x => x.id);
  prov('AO-03', 'omordnade kontroller → samma id', ett[0] === tva[1] && ett[1] === tva[0], ett.join(',') + ' / ' + tva.join(',')); }
{ const a = tilldela([regel(), regel({ namn: 'Ingrediens: kokt ris', kedja: inne('occ-regelrad2', ['Ingrediensregel']) })]);
  prov('AO-04', 'samma handling i tva ankrade objekt → skilda agare', a[0].id && a[1].id && a[0].id !== a[1].id, a.map(x => x.id).join(' / ')); }
{ const a = tilldela([regel(), regel({ namn: 'Innehåller "rester" (kopia)' })]);
  prov('AO-05', 'tva lika handlingar i samma objekt utan starkare skillnad → fail closed, ingen ordinal', a.every(x => x.id === null && x.status === 'OWNER_IDENTITY_UNRESOLVED'), a.map(x => x.status).join(',')); }
lika('AO-06', 'regelns titel byts → samma agare', regel(), regel({ namn: 'Innehåller "överblivet"' }));

// ── ST · lage och varde
lika('ST-01', 'Verifiera avstangd/aktiv', f({ art: 'authmfa', namn: 'Verifiera, avstängd till dess sex siffror är ifyllda' }), f({ art: 'authmfa', namn: 'Verifiera' }));
lika('ST-02', 'Nästa avstangd/aktiv', f({ art: 'onbaldermorkt', namn: 'Nästa, avstängd till dess ett år är valt' }), f({ art: 'onbaldermorkt', namn: 'Nästa' }));
lika('ST-03', 'Födelseår platshallare/valt ar', f({ art: 'onbaldermorkt', roll: 'combobox', namn: 'Födelseår, välj ett år' }), f({ art: 'onbaldermorkt', roll: 'combobox', namn: 'Födelseår 1988' }));
lika('ST-04', 'Importera från länk offline/online', f({ art: 'formularmorkt', roll: 'textbox', namn: 'Importera från länk, ej tillgänglig offline' }), f({ art: 'formularmorkt', roll: 'textbox', namn: 'Importera från länk' }));
lika('ST-05', 'Visa reservkoder saknas/finns', f({ art: 'mfaaktiv', namn: 'Visa reservkoder, finns inte ännu' }), f({ art: 'mfaaktiv', namn: 'Visa reservkoder' }));
lika('ST-06', 'AI-tolkning av/på', f({ art: 'samtyckeai', roll: 'switch', namn: 'AI-tolkning av recept, avstängd' }), f({ art: 'samtyckeai', roll: 'switch', namn: 'AI-tolkning av recept, på' }));
{ const v = ['Verifiera, avstängd till dess koden är ifylld', 'Verifiera – avstängd till dess koden är ifylld', 'Verifiera (avstängd till dess koden är ifylld)', 'Verifiera; avstängd till dess koden är ifylld'].map(x => n(f({ art: 'authmfa', namn: x })));
  prov('ST-07', 'skiljetecken byts utan semantisk andring → samma agare', v.every(x => x === v[0] && x !== 'OLOST'), v.join(' / ')); }
lika('ST-08', 'knapp som slutar pa "på" ar inget lage (bara reglage bar pa/av)', f({ art: 'x', namn: 'Slå på' }), f({ art: 'x', namn: 'Slå på' }));
{ const x = n(f({ art: 'x', namn: 'Slå på' })); prov('ST-09', '"Slå på" behaller hela sin semantik', x === 'OWNER::x::namn::sla-pa', x); }

// ── C · innehallsobjekt (kallankare, synligt innehall byts)
lika('C01', 'dagrad: Rester → annan ratt', f({ art: 'hemmorkt', namn: 'Lör · Rester', kedja: self('occ-dagrad') }), f({ art: 'hemmorkt', namn: 'Lör · Tacos', kedja: self('occ-dagrad') }));
lika('C02', 'ingrediensrad: text och mangd byts', f({ art: 'redigera', namn: 'Ta bort 3 dl arborioris', kedja: inne('occ-ingrad', ['3 dl arborioris']) }), f({ art: 'redigera', namn: 'Ta bort 4 dl carnaroliris', kedja: inne('occ-ingrad', ['4 dl carnaroliris']) }));
lika('C03', 'taggens visningsnamn byts', f({ art: 'taggar', namn: 'Vego 34 recept · 2 regler', kedja: self('occ-tagg') }), f({ art: 'taggar', namn: 'Vegetariskt 35 recept · 2 regler', kedja: self('occ-tagg') }));
lika('C04', 'familjemedlemmens namn byts', f({ art: 'familj', namn: 'E Ebba, 9 år Allergi: jordnötter', kedja: self('occ-medlem') }), f({ art: 'familj', namn: 'E Ebba S., 10 år Allergi: jordnötter', kedja: self('occ-medlem') }));
lika('C05', 'notisens text byts', f({ art: 'notiscentral', namn: 'Läst: veckans meny är klar', kedja: self('occ-notis') }), f({ art: 'notiscentral', namn: 'Läst: menyn för vecka 29 är klar', kedja: self('occ-notis') }));
lika('C06', 'gruppens namn byts', f({ art: 'socgruppinfo', namn: 'Samtalets namnMatlaget', kedja: self('occ-namnrad') }), f({ art: 'socgruppinfo', namn: 'Samtalets namnKöksgänget', kedja: self('occ-namnrad') }));
lika('C07', 'forvaringsplatsens etikett byts, semantiken samma', f({ art: 'skafferi', namn: 'Frysen 7', kedja: self('occ-frys') }), f({ art: 'skafferi', namn: 'Frys 8', kedja: self('occ-frys') }));
lika('C08', 'valt sprak byts', f({ art: 'installningar', namn: 'Svenska', kedja: inne('occ-sprakrad', ['Språk']) }), f({ art: 'installningar', namn: 'English', kedja: inne('occ-sprakrad', ['Språk']) }));
lika('C09', 'installningens lage På → Av', f({ art: 'kontosakerhet', namn: 'På', kedja: inne('occ-tvafaktor', ['Tvåfaktorsinloggning', 'SMS-kod vid inloggning']) }), f({ art: 'kontosakerhet', namn: 'Av', kedja: inne('occ-tvafaktor', ['Tvåfaktorsinloggning', 'SMS-kod vid inloggning']) }));
lika('C10', 'sprakraden: valt varde i radnamnet byts', f({ art: 'installningar', namn: 'SpråkSvenska', kedja: self('occ-sprakrad') }), f({ art: 'installningar', namn: 'SpråkEnglish', kedja: self('occ-sprakrad') }));
lika('C11', 'rostalternativ: ratt och rostetal byts', f({ art: 'veckorostning', roll: 'radio', namn: 'Rösta på Krämig svamppasta', kedja: self('occ-alt') }), f({ art: 'veckorostning', roll: 'radio', namn: 'Rösta på Svamprisotto', kedja: self('occ-alt') }));
lika('C12', 'varurad i delad lista: vara byts', f({ art: 'delatclaimkonflikt', roll: 'checkbox', namn: 'Bocka av champinjoner', kedja: inne('occ-vara', ['250 g', 'champinjoner']) }), f({ art: 'delatclaimkonflikt', roll: 'checkbox', namn: 'Bocka av kantareller', kedja: inne('occ-vara', ['200 g', 'kantareller']) }));
lika('C13', 'deltagarchip: personens namn byts', f({ art: 'nygruppchatt', namn: 'Ta bort Erik', kedja: inne('occ-deltagare', ['Erik']) }), f({ art: 'nygruppchatt', namn: 'Ta bort Erik S.', kedja: inne('occ-deltagare', ['Erik S.']) }));
lika('C14', 'kalenderns maltidsrad: innehall byts', f({ art: 'kalender', namn: 'Middag Krämig svamppasta', kedja: self('occ-maltid') }), f({ art: 'kalender', namn: 'Middag Tacos', kedja: self('occ-maltid') }));

// ── G · fail closed
olost('G01', 'legacy-skuld blir aldrig agargrund', f({ art: 'delatmindel', roll: 'checkbox', namn: 'Gul lök, Anna tar', kedja: self(LEGACY_IDENTITY_DEBT[6]) }));
olost('G02', 'veckomenyns "Byt ut {rätt}" utan ankare: inget id, aldrig rattens namn', f({ art: 'veckobyt', namn: 'Byt ut Tacos', ramEtikett: 'Veckomeny · byt' }));
lika('G03', 'veckomenyns byte med ankare: ratten byts, agaren bestar (inte H15)', f({ art: 'veckobyt', namn: 'Byt ut Tacos', ramEtikett: 'Veckomeny · byt', kedja: inne('occ-veckoplats', ['Tacos']) }), f({ art: 'veckobyt', namn: 'Byt ut Linsgryta', ramEtikett: 'Veckomeny · byt', kedja: inne('occ-veckoplats', ['Linsgryta']) }));
{ const x = semantiskAgare(f({ art: 'veckobyt', namn: 'Byt ut Tacos', ramEtikett: 'Veckomeny · byt', kedja: inne('occ-veckoplats', ['Tacos']) })); prov('G04', 'veckomenyns byte styrs inte av H15', !x.monster && /handling::replace-dish$/.test(x.nyckel), x.nyckel); }
olost('G05', 'rostning utan objektankare faller stangt', f({ art: 'veckorostning', roll: 'radio', namn: 'Rösta på Tacos' }));
olost('G06', 'valt varde utan ankrat installningsobjekt faller stangt', f({ art: 'installningar', namn: 'Svenska' }));

// ── P · policyn tacker handoffens 49 regler (om handoffen finns i roten)
const H = 'Butlery tillganglighetshandoff.dc.html';
if (existsSync(H)) { const m = handoffMatris(readFileSync(H, 'utf8')); const utan = m.filter(r => !POLICY[r.CONTROL_PATTERN]);
  prov('P01', 'alla handoffens regler har en agarpolicy', m.length === 49 && utan.length === 0, m.length + ' regler, utan policy: ' + utan.map(r => r.CONTROL_PATTERN).join(',')); }

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
