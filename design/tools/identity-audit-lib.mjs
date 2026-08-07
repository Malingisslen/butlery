// F2-ID01 · Revisionens domslut som en ren funktion.
//
// identity-audit.mjs och identity-fixtures.mjs ANVÄNDER den. Ett prov mot en
// kopia av logiken bevisar ingenting om den logik som faktiskt kör.

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
</div>`;
