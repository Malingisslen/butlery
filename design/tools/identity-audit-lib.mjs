// F2-ID01 · Revisionens domslut som en ren funktion.
//
// identity-audit.mjs och identity-fixtures.mjs ANVÄNDER den. Ett prov mot en
// kopia av logiken bevisar ingenting om den logik som faktiskt kör.

import { bedomGrupp, identityContext, felClosedUtfall, identityKeyÄrSäker } from './identity-v2.mjs';

const METODER = ['r03a', 'r03b', 'r03c', 'r03d'];

export function revidera(D, RAW = '(minne)') {
  /* ── 1 · Samla varje detektion med sin sanna nodidentitet ────────────────── */

  const idProdukt = new Set(), idProbe = new Set();
  for (const r of D.results) for (const a of r.artifacts) (r.probe ? idProbe : idProdukt).add(a.id);
  const probeEndast = [...idProbe].filter(x => !idProdukt.has(x));

  const detektioner = [];
  for (const r of D.results) {
    const viewport = r.probe ? 'prob-' + r.probe.width : r.profile.id;
    for (const a of r.artifacts)
      for (const m of METODER)
        for (const t of (a[m] || []))
          detektioner.push({
            artefakt: a.id, viewport, theme: 'obeslutad', textScale: '1.0',
            metod: m, klass: t.klass, subtype: t.subtype, axis: t.axis,
            elementKey: t.elementKey, keyBasis: t.keyBasis,
            path: t.path === '' ? 'rot' : t.path,
            tag: t.tag, cls: t.cls, roll: t.roll ?? null, namn: t.namn ?? null,
            dataAttr: t.dataAttr || {}, domBeskrivning: t.domBeskrivning || null,
          rect: t.rect || null, stabilForfader: t.stabilForfader ?? null,
            population: probeEndast.includes(a.id) ? 'probe' : 'produkt'
          });
  }

  /* ── 2 · Gruppera per identitetskontext ──────────────────────────────────── */
  // Kontexten är exakt den som findingId använder, minus felklass och axel:
  // artefakt · viewport · theme · text-scale. Kollisionen ska mätas i samma rum
  // som identiteten lever i.
  const ktx = d => [d.artefakt, d.viewport, d.theme, d.textScale].join(' · ');
  const grupper = new Map();
  for (const d of detektioner) {
    const k = ktx(d) + ' ‖ ' + d.elementKey;
    if (!grupper.has(k)) grupper.set(k, []);
    grupper.get(k).push(d);
  }

  const ärFörfader = (a, b) => a !== b && a !== 'rot' && b.startsWith(a + '/');

  const kollisioner = [], flerMetoder = [], slaktskap = [];
  for (const [k, lista] of grupper) {
    const paths = [...new Set(lista.map(d => d.path))];
    if (paths.length === 1) {
      if (new Set(lista.map(d => d.metod)).size > 1)
        flerMetoder.push({ nyckel: k, path: paths[0], metoder: [...new Set(lista.map(d => d.metod))].sort() });
      continue;
    }
    // Flera path under samma nyckel. Är de i släktskap? Även då är det en
    // NYCKELKOLLISION — förfader och barn ska ha olika nycklar. Vi redovisar
    // släktskapet separat som förklaring, inte som ursäkt.
    const släkt = [];
    for (const a of paths) for (const b of paths) if (ärFörfader(a, b)) släkt.push(a + ' ⊃ ' + b);
    const [artefakt, viewport, theme, textScale] = k.split(' ‖ ')[0].split(' · ');
    const noder = paths.map(p => {
      const d = lista.find(x => x.path === p);
      return {
        path: p, tag: d.tag, cls: d.cls || null, roll: d.roll, namn: d.namn,
        dataAttr: d.dataAttr, domBeskrivning: d.domBeskrivning,
        metoder: [...new Set(lista.filter(x => x.path === p).map(x => x.metod))].sort(),
        klasser: [...new Set(lista.filter(x => x.path === p).map(x => x.klass))].sort()
      };
    });
    kollisioner.push({
      elementKey: k.split(' ‖ ')[1], artefakt, viewport, theme, textScale,
      population: lista[0].population,
      keyBasis: lista[0].keyBasis,
      domnoder_st: paths.length,
      detektioner_st: lista.length,
      klasser: [...new Set(lista.map(d => d.klass))].sort(),
      metoder: [...new Set(lista.map(d => d.metod))].sort(),
      slaktskap: släkt,
      // Finns en stabil diskriminator som HADE kunnat skilja noderna åt?
      diskriminator: (() => {
        const unik = f => new Set(noder.map(f)).size === noder.length;
        if (unik(n => JSON.stringify(n.dataAttr))) return 'data-attribut';
        if (unik(n => (n.roll || '') + '|' + (n.namn || '')) && noder.every(n => n.roll || n.namn)) return 'roll och namn';
        if (unik(n => n.cls || '')) return 'klasslista';
        if (unik(n => n.domBeskrivning || '')) return 'domänbeskrivning inklusive text';
        return null;
      })(),
      noder
    });
  }
  for (const [k, lista] of grupper) {
    const paths = [...new Set(lista.map(d => d.path))];
    if (paths.length < 2) continue;
    for (const a of paths) for (const b of paths) if (ärFörfader(a, b)) slaktskap.push(k + ': ' + a + ' ⊃ ' + b);
  }

  /* ── 3 · Nivåtal på två sätt ─────────────────────────────────────────────── */
  // A = dagens nyckelbaserade deduplicering. B = faktisk DOM-nodidentitet.
  function nivåer(klass, population) {
    const d = detektioner.filter(x => x.klass === klass && x.population === population);
    const A = new Set(d.map(x => ktx(x) + ' ‖ ' + x.elementKey + ' ‖ ' + x.subtype + ' ‖ ' + x.axis));
    const B = new Set(d.map(x => ktx(x) + ' ‖ ' + x.path + ' ‖ ' + x.subtype + ' ‖ ' + x.axis));
    return { raa_detektioner_st: d.length, A_elementfynd_st: A.size, B_domnodsfynd_st: B.size, differens_st: B.size - A.size };
  }

  const jamforelse = {};
  for (const kl of ['verifierad', 'observation', 'avsiktlig', 'verktygsfel'])
    jamforelse[kl] = nivåer(kl, 'produkt');

  /* ── 4 · Är något VERIFIERAT fynd påverkat? ──────────────────────────────── */
  const verifieradeKollisioner = kollisioner.filter(k => k.klasser.includes('verifierad'));
  const observationskollisioner = kollisioner.filter(k => k.klasser.includes('observation') && !k.klasser.includes('verifierad'));
  const avsiktligaKollisioner = kollisioner.filter(k => k.klasser.includes('avsiktlig'));

  /* ── 6 · Rapport ─────────────────────────────────────────────────────────── */
  const unikaNycklar = new Set(detektioner.map(d => ktx(d) + ' ‖ ' + d.elementKey));
  const berördaNoder = kollisioner.reduce((n, k) => n + k.domnoder_st, 0);

  const rapport = {
    $regel: 'REVISION, inte rättning. findingId, instansId, hopslagning och klassificeringsregler är oförändrade. Talen här beskriver identitetslagret; de ersätter inte R-03-rapporten.',
    $sanningsgrund: 'Fältet path (barnindexkedjan från artefaktroten) är den sanna nodidentiteten INOM en renderkörning. Det duger för att MÄTA kollisioner men inte som kanonisk identitet: ett inskjutet syskon flyttar varje index efter sig.',
    källa: RAW,
    populationer: {
      produktartefakter_st: idProdukt.size,
      probeartefakter_st: probeEndast.length,
      totalt_exekverade_artefakter_st: idProdukt.size + probeEndast.length
    },
    matning: {
      unika_elementKeys_st: unikaNycklar.size,
      kolliderande_elementKeys_st: kollisioner.length,
      berorda_domnoder_st: berördaNoder,
      verifierade_kollisioner_st: verifieradeKollisioner.length,
      observationskollisioner_st: observationskollisioner.length,
      avsiktliga_kollisioner_st: avsiktligaKollisioner.length,
      verktygsfelskollisioner_st: kollisioner.filter(k => k.klasser.includes('verktygsfel')).length,
      samma_nod_flera_metoder_st: flerMetoder.length,
      forfader_barn_par_st: slaktskap.length
    },
    $skillnad: 'samma_nod_flera_metoder och forfader_barn_par är INTE nyckelkollisioner. Det första är en nod sedd av flera metoder, det andra ett släktskap mellan skilda noder.',
    nivajamforelse: {
      $forklaring: 'A = dagens elementKey-baserade deduplicering. B = faktisk DOM-nodidentitet inom samma renderkörning. Differensen är antalet fynd som A slår samman men B håller isär.',
      ...jamforelse
    },
    paverkan_pa_kanoniskt_resultat: {
      verifierade_elementfynd_paverkade_st: verifieradeKollisioner.length,
      felinstanser_paverkade_st: verifieradeKollisioner.length,
      kallrotorsaker_paverkade_st: verifieradeKollisioner.length ? 'kan inte uteslutas' : 0,
      slutsats: verifieradeKollisioner.length === 0
        ? 'INGET verifierat elementfynd, ingen felinstans och ingen källrotorsak påverkas av en elementKey-kollision. Det kanoniska R-03-resultatet står oförändrat.'
        : 'STOPP: minst ett verifierat fynd delar elementKey med en annan DOM-nod. Inga produktfynd får rättas innan identitetslagret är rättat.'
    },
    rekommenderad_identitetsmodell: {
      $regel: 'Förslag, inte implementation. Ingen del av detta är infört i denna commit.',
      $forbud: 'nth-child, nth-of-type och rå DOM-position får inte ingå: ett orelaterat inskjutet syskon skulle då byta identitet på ett oförändrat fynd. Hash av outerHTML får inte heller användas: en likgiltig markupändring skulle skapa ett nytt semantiskt fynd.',
      prioritetsordning: [
        { steg: 1, grund: 'explicit stabil data-element-id eller data-control-id' },
        { steg: 2, grund: 'domänspecifikt stabilt attribut, i första hand data-icon' },
        { steg: 3, grund: 'roll och accessible name där kombinationen är unik i sin kontext' },
        { steg: 4, grund: 'unik normaliserad selektor' },
        { steg: 5, grund: 'stabilt semantiskt fingeravtryck inom en stabil förfader' },
        { steg: 6, grund: 'annars identityAmbiguous — fail closed' }
      ],
      failClosedRegel: 'Om två fysiska noder inte kan särskiljas stabilt får verktyget varken påstå att de är samma element eller hitta på ett skört index. Utfallet ska vara identitetsambiguitet.',
      beläggFranMatningen: null
    },
    kollisioner
  };

  /* ── IDENTITY-V2, parallellt lager ─────────────────────────────────────────
   *
   * Kör bredvid legacy-identiteten och ändrar ingenting i den. Varje DOM-nod
   * som någon R-03-metod observerat bedöms mot prioritetsordningen, och
   * identityKey sätts bara när identiteten är stabil enligt kontraktet. */
  const perNod = new Map();
  for (const d of detektioner) {
    const nyckel = ktx(d) + ' ‖ ' + d.elementKey + ' ‖ ' + d.path;
    if (!perNod.has(nyckel))
      perNod.set(nyckel, { ...d, klasser: new Set(), metoder: new Set() });
    perNod.get(nyckel).klasser.add(d.klass);
    perNod.get(nyckel).metoder.add(d.metod);
  }
  const perLegacyGrupp = new Map();
  for (const n of perNod.values()) {
    const g = ktx(n) + ' ‖ ' + n.elementKey;
    if (!perLegacyGrupp.has(g)) perLegacyGrupp.set(g, []);
    perLegacyGrupp.get(g).push(n);
  }

  const v2 = [];
  for (const [g, noder] of perLegacyGrupp) {
    const legacyKey = g.split(' ‖ ')[1];
    // Identitetskontexten är strängare än legacy-kontexten: den stabila
    // förfadern ingår. Noder som delar legacy-nyckel men ligger under skilda
    // stabila förfäder är därför olika identiteter från början.
    const perCtx = new Map();
    for (const n of noder) {
      const c = identityContext(n);
      if (!perCtx.has(c)) perCtx.set(c, []);
      perCtx.get(c).push(n);
    }
    for (const [c, lista] of perCtx) v2.push(...bedomGrupp(legacyKey, lista, c));
  }

  const räknaV2 = s => v2.filter(x => x.identityStatus === s).length;
  const ambiguösa = v2.filter(x => x.identityStatus === 'ambiguous');
  const kandidater = v2.filter(x => x.identityStatus === 'candidate');
  const ärVerifierad = x => [...(x.nod.klasser || [])].includes('verifierad');
  const verifieratAmbiguösa = ambiguösa.filter(ärVerifierad);
  const ambigNycklar = new Set(ambiguösa.map(x => x.legacyElementKey + ' ‖ ' + x.kontext));
  const ambigArtefakter = new Set(ambiguösa.map(x => x.nod.artefakt));
  const grupptorlekar = {};
  for (const x of ambiguösa) {
    const k = x.legacyElementKey + ' ‖ ' + x.kontext;
    grupptorlekar[k] = (grupptorlekar[k] || 0) + 1;
  }

  const utfall = felClosedUtfall({
    verified_ambiguous_st: verifieratAmbiguösa.length,
    error_st: räknaV2('error')
  });

  // identityKey får aldrig bära strängen null, undefined eller NaN.
  const osäkraNycklar = v2.filter(x => !identityKeyÄrSäker(x.identityKey));

  rapport.identityV2 = {
    $regel: 'PARALLELLT lager. Ersätter inte elementKey, findingId eller instansId. Ingen migrering av kanoniska id sker i denna commit.',
    $identityKeyRegel: 'identityKey sätts endast vid identityStatus stable. Vid candidate, ambiguous och error är den null och får aldrig strängifieras in i någon nyckel.',
    $textRegel: 'Text behandlas ALDRIG som stabil identitet automatiskt. Lokalisering, redaktionella ändringar, dynamiskt innehåll och formattering kan ändra den. Textbaserad särskiljning ger candidate med identityKey null.',
    $dataIconRegel: 'data-icon ger stable endast när värdet är unikt för samtliga noder inom identitetskontexten artefakt, viewport, tema, textskala och stabil förfader. Ett återanvänt värde gör noderna otydbara, inte identiska.',
    domnoder_st: perNod.size,
    stable_st: räknaV2('stable'),
    candidate_st: kandidater.length,
    ambiguous_st: ambiguösa.length,
    error_st: räknaV2('error'),
    perBasis: v2.reduce((a, x) => { a[x.identityBasis] = (a[x.identityBasis] || 0) + 1; return a; }, {}),
    ambiguitet: {
      ambiguous_elementKeys_st: ambigNycklar.size,
      ambiguous_domNodes_st: ambiguösa.length,
      artifacts_med_ambiguitet_st: ambigArtefakter.size,
      största_ambiguity_group_st: Math.max(0, ...Object.values(grupptorlekar))
    },
    kontrollresultat: {
      legacy_collisions_st: kollisioner.length,
      stable_resolved_by_v2_st: kollisioner.filter(k => {
        const g = v2.filter(x => x.legacyElementKey === k.elementKey && x.nod.artefakt === k.artefakt);
        return g.length > 1 && g.every(x => x.identityStatus === 'stable');
      }).length,
      candidate_only_st: kollisioner.filter(k => {
        const g = v2.filter(x => x.legacyElementKey === k.elementKey && x.nod.artefakt === k.artefakt);
        return g.length > 1 && g.some(x => x.identityStatus === 'candidate');
      }).length,
      ambiguous_st: ambigNycklar.size,
      verified_ambiguous_st: verifieratAmbiguösa.length,
      observation_ambiguous_st: ambiguösa.filter(x => [...(x.nod.klasser || [])].includes('observation')).length
    },
    failClosed: utfall,
    identityKey_osäkra_st: osäkraNycklar.length,
    produktmarkupspolicy: 'Explicit data-element-id införs INTE i förväg. Den införs endast när semantiken faktiskt kräver en stabil identitet, eller när en verifierad kontroll annars blockeras av identityAmbiguous.',
    ambiguösa_grupper: [...new Set(ambiguösa.map(x => x.legacyElementKey + ' ‖ ' + x.kontext))]
      .slice(0, 200).map(g => ({
        grupp: g, noder_st: grupptorlekar[g],
        exempel: ambiguösa.filter(x => x.legacyElementKey + ' ‖ ' + x.kontext === g).slice(0, 3)
          .map(x => x.identityDiagnostics)
      })),
    v2_per_nod: v2.map(x => ({
      legacyElementKey: x.legacyElementKey, artefakt: x.nod.artefakt, viewport: x.nod.viewport,
      identityStatus: x.identityStatus, identityBasis: x.identityBasis, identityKey: x.identityKey,
      klasser: [...(x.nod.klasser || [])].sort(),
      identityDiagnostics: x.identityDiagnostics
    }))
  };

  // Vilken diskriminator hade räckt? Räknas ur de faktiska kollisionerna.
  const perDisk = {};
  for (const k of kollisioner) perDisk[k.diskriminator || 'ingen stabil diskriminator'] =
    (perDisk[k.diskriminator || 'ingen stabil diskriminator'] || 0) + 1;
  rapport.rekommenderad_identitetsmodell.beläggFranMatningen = perDisk;

  return rapport;
}

/* ── Fixturer för de negativa proven ─────────────────────────────────────── */
export const FIXTUR_HTML = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;font:14px system-ui} .sc-item{background:#fff}
 .box{width:120px;height:40px;overflow:hidden}
</style>
<div class="sc-item" id="A-atta-syskon">
  <!-- A · atta syskon-svg med identisk normaliserad selector. Ska ge ATTA
       noder och EN nyckelkollision, aldrig ett element. -->
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
</div>
<div class="sc-item" id="B-samma-nod-flera-metoder">
  <!-- B · EN nod som bade R-03a och R-03c ser. Aldrig identitetskollision. -->
  <div style="width:120px;height:18px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">Ett mycket langt textinnehall som varken ryms i bredd eller hojd i denna lilla box</div>
</div>
<div class="sc-item" id="C-foralder-och-barn">
  <!-- C · Foraldern klipper, barnet sticker ut. Tva element fore hopslagning,
       men med OLIKA nycklar — alltsa ingen nyckelkollision. -->
  <div class="box" style="overflow:hidden"><span style="display:block;width:400px;height:30px">x</span></div>
</div>
<div class="sc-item" id="D-samma-tagg-olika-dataicon">
  <!-- D · Samma tagg och klass, olika data-icon. En stabil diskriminator FINNS. -->
  <div class="box"><div style="width:400px"><svg class="ik" width="8" height="8" viewBox="0 0 8 8" data-icon="hjarta"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg class="ik" width="8" height="8" viewBox="0 0 8 8" data-icon="stjarna"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
</div>
<div class="sc-item" id="E-oskiljbara-syskon">
  <!-- E · Tva semantiskt identiska syskon utan id, roll, namn eller data-attribut.
       Ingen stabil diskriminator finns. Ska markeras som identitetsambiguitet. -->
  <div class="box"><div style="width:400px">&nbsp;</div></div>
  <div class="box"><div style="width:400px">&nbsp;</div></div>
</div>
<div class="sc-item" id="F-inskjutet-syskon">
  <!-- F · Som E men med ett orelaterat syskon inskjutet FORE. Den tidigare
       identiteten ska fortfarande ga att kanna igen i underlaget. -->
  <p style="margin:0">orelaterat</p>
  <div class="box"><div style="width:400px">&nbsp;</div></div>
  <div class="box"><div style="width:400px">&nbsp;</div></div>
</div>
<div class="sc-item" id="G-samma-dataicon">
  <!-- G · Tva syskon med SAMMA data-icon. Attributet sarskiljer dem inte. -->
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8" data-icon="lika"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8" data-icon="lika"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
</div>
<div class="sc-item" id="H-olika-dataicon">
  <!-- H · Tva syskon med OLIKA unika data-icon. Stabil identitet. -->
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8" data-icon="ett"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
  <div class="box"><div style="width:400px"><svg width="8" height="8" viewBox="0 0 8 8" data-icon="tva"><rect x="0" y="0" width="8" height="8"/></svg></div></div>
</div>
<div class="sc-item" id="I-text-alfa">
  <!-- I · Samma element med explicit id, men olika text. Texten far inte skapa
       en ny kanonisk identitet. -->
  <div class="box" data-element-id="rutan"><div style="width:400px">Alfa</div></div>
</div>
<div class="sc-item" id="I-text-beta">
  <div class="box" data-element-id="rutan"><div style="width:400px">Beta</div></div>
</div>
<div class="sc-item" id="J-ambigu-observation">
  <!-- J · De OBSERVERADE noderna ar de inre divarna. Deras foraldrar har
       identisk signatur, sa nyckeln kolliderar — men innehallet ryms, sa
       traffen ar en OBSERVATION och inte ett fel. -->
  <div class="jbox"><div style="overflow:hidden;width:120px;height:40px"><span>x</span></div></div>
  <div class="jbox"><div style="overflow:hidden;width:120px;height:40px"><span>x</span></div></div>
</div>
<div class="sc-item" id="K-ambiguost-verifierat">
  <!-- K · Tva oskiljbara syskon som BADA klipper pa riktigt. Ett verifierat
       fynd landar da i en tvetydig grupp och maste blockera. -->
  <div style="width:60px;height:20px;overflow:hidden"><div style="width:300px;height:60px"></div></div>
  <div style="width:60px;height:20px;overflow:hidden"><div style="width:300px;height:60px"></div></div>
</div>
<div class="sc-item" id="L-stabil-utan-syskon">
  <!-- L · Stabil identitet via explicit id. -->
  <div class="box" data-element-id="stabil-1"><div style="width:400px">x</div></div>
</div>
<div class="sc-item" id="L-stabil-med-syskon">
  <!-- M · Samma element, men med ett orelaterat syskon inskjutet fore.
       Runtime-sokvagen flyttas; identityKey ska sta stilla. -->
  <p style="margin:0">orelaterat</p>
  <div class="box" data-element-id="stabil-1"><div style="width:400px">x</div></div>
</div>`;
