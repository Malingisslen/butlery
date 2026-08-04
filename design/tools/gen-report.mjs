// Butlery · renderar kontrollstatus.md ur verify-report.json.
// Samma controls[]-struktur som JSON:en — inget register tappas i Markdown.
// Varje värde som hamnar i en tabellcell MÅSTE escapas. Fas 1: en scope-text med
// '||' skrev två tabellrader på samma källrad, vilket T-19 fällde på andra
// körningen — rapporten fällde alltså en Fas 0-grindkontroll.
const cell = v => String(v ?? '')
  .replace(/\\/g, '\\\\')
  .replace(/\|/g, '\\|')
  .replace(/\r?\n/g, ' ');

export function renderMarkdown(r) {
  const l = [];
  const t = r.tally || {};
  l.push('# Kontrollstatus');
  l.push('');
  l.push('**Genererad av `tools/verify.mjs` ur `tools/controls.mjs` + körningen. Redigera inte för hand.**');
  l.push('');
  l.push('| | |');
  l.push('|---|---|');
  l.push('| Kommando | `' + cell(r.command) + '` |');
  l.push('| Körd | ' + cell(r.generated) + ' · Node ' + cell(r.node) + ' |');
  l.push('| Kedjan (steg) | **' + (r.pipelineResult || r.stepsResult || r.result) + '** |');
  l.push('| Kontrollerna | **' + (r.controlsResult || '—') + '**' + (r.controlsSummary ? ' · failed: ' + (r.controlsSummary.failed.join(', ') || '—') + ' · blocked: ' + (r.controlsSummary.blocked.join(', ') || '—') : '') + ' |');
  l.push('| Fas ' + cell(r.currentPhase ?? 0) + '-grinden | **' + cell(r.phaseGateResult || '—') + '**' + (r.gateBlockers && r.gateBlockers.length ? ' — ' + cell(r.gateBlockers.join(', ')) : '') + ' · eget kommando: `node tools/gate.mjs --phase=' + (r.currentPhase ?? 0) + '` |');
  if (r.schema) l.push('| Rapportschema | `' + cell(r.schema) + '` · runId `' + cell(r.runId) + '` · ' + cell(r.generatedAt) + ' |');
  if (r.packageIdentity) l.push('| Paket | manifest `' + String(r.packageIdentity.manifestSha256).slice(0, 16) + '…` · ' + cell(r.packageIdentity.manifestExpected) + ' poster · node ' + cell(r.packageIdentity.node) + (r.packageIdentity.commit ? ' · commit ' + String(r.packageIdentity.commit).slice(0, 8) : '') + ' |');
  if (r.namespaces) l.push('| Namnrymder | ' + (r.namespaces.ok ? '**disjunkta**' : '**' + cell(r.namespaces.problems.length) + ' fel**') + ' · ' + cell(r.namespaces.controls) + ' CHK-* · ' + cell(r.namespaces.requirements) + ' REQ-* |');
  if (r.selftestCoverage) l.push('| Självtestets täckning | ' + cell(Object.entries(r.selftestCoverage).map(([k, v]) => k + ' ' + v).join(' · ')) + ' |');
  l.push('| **Totalt** | **' + cell(r.overallResult || r.result) + '** (exit ' + cell(r.exitCode) + ')' + (r.overallBlockers && r.overallBlockers.length ? ' — ' + cell(r.overallBlockers.join(' · ')) : '') + ' |');
  l.push('| Spec-fel | **' + cell(r.measures.specErrors) + '** |');
  l.push('| Spec-varningar | **' + cell(r.measures.specWarnings) + '** |');
  l.push('| Geometriavvikelser | **' + cell(r.measures.geometryDeviations) + '** |');
  l.push('| Täckningsfel (LC) | **' + (r.measures.coverageErrors || 0) + '** |');
  if (r.manifest) l.push('| Manifest | **' + r.manifest.status + '** · parsed ' + (r.manifest.parsed ?? '—') + ' · verified ' + (r.manifest.verified ?? '—') +
    ' · bad ' + (r.manifest.bad ?? '—') + ' · missing ' + (r.manifest.missing ?? '—') + ' · duplicates ' + (r.manifest.duplicates ?? '—') +
    ' · unlisted ' + (r.manifest.unlisted ?? '—') + ' · outsideAbsent ' + (r.manifest.outsideAbsent ?? '—') + ' · exit ' + r.manifest.exitCode + ' |');
  if (r.finalExitCode !== undefined) l.push('| Kanoniskt kommando | `' + cell(r.canonicalCommand) + '` · **slutlig exit ' + cell(r.finalExitCode) + '** |');
  l.push('');
  l.push('De tre mätklasserna summeras aldrig till ett tal — de mäter olika saker.');
  l.push('');
  l.push('## Källor');
  l.push('');
  l.push('| Fil | Version | inputSha256 | outputSha256 |');
  l.push('|---|---|---|---|');
  for (const [f, s] of Object.entries(r.sources || {})) {
    if (f.startsWith('$')) continue;
    l.push('| `' + cell(f) + '` | ' + cell(s.version) + ' | `' + String(s.inputSha256).slice(0, 16) + '…` | `' + String(s.outputSha256).slice(0, 16) + '…` |');
  }
  l.push('');
  l.push((r.sources?.$note || '') || '');
  l.push('');
  l.push('## Steg');
  l.push('');
  l.push('| Steg | Skript | Status | Exit | Spec-fel | Spec-varn | Geometri |');
  l.push('|---|---|---|---|---|---|---|');
  for (const s of r.steps) l.push('| ' + cell(s.step) + ' | `' + cell(s.script) + '` | **' + cell(s.status) + '** | ' + cell(s.exitCode) + ' | ' + cell(s.specErrors) + ' | ' + cell(s.specWarnings) + ' | ' + cell(s.geometryDeviations) + ' |');
  l.push('');
  l.push('## Kontrollregister');
  l.push('');
  // Summeringen räknar ALLA statusvärden inklusive blocked och verifierar att
  // de summerar till registrets storlek — tidigare tappade Markdown den
  // blockerade raden och visade "31 av 32".
  const order = ['passed', 'failed', 'blocked', 'not run', 'not applicable'];
  const shown = order.map(k => (t[k] || 0) + ' ' + k);
  const sum = Object.values(t).reduce((a, b) => a + b, 0);
  l.push('**' + shown.join(' · ') + '** — summa ' + sum + ' av ' + r.controls.length + (sum === r.controls.length ? '' : ' ⚠ SUMMAN STÄMMER INTE'));
  const extra = Object.keys(t).filter(k => !order.includes(k));
  if (extra.length) l.push('');
  if (extra.length) l.push('⚠ okända statusvärden i tallyn: ' + extra.join(', '));
  l.push('');
  l.push('| Id | Kontroll | Status | Löses i fas | Blockerar grind | Fel | Varn | Avvik | Ägare | Motivering / avgränsning |');
  l.push('|---|---|---|---|---|---|---|---|---|---|');
  for (const c of r.controls) {
    const st = c.status === 'blocked' ? 'blocked (' + c.blockedBy + ')' : c.status;
    l.push('| ' + cell(c.id) + ' | ' + cell(c.name) + ' | **' + cell(st) + '** | ' + cell(c.resolutionPhase ?? '—') + ' | ' + (Array.isArray(c.requiredForGate) && c.requiredForGate.length ? c.requiredForGate.join(',') : '—') + ' | ' + cell(c.errors) + ' | ' + cell(c.warnings) + ' | ' + cell(c.deviations ?? '—') + ' | ' + cell(c.owner) + ' | ' + cell([c.why, c.scope].filter(Boolean).join(' · ')) + ' |');
  }
  l.push('');
  l.push('');
  if (r.requirements && r.requirements.total) {
    l.push('## Kravstatus — räknad ur evidensmatrisens rader, aldrig skriven för hand');
    l.push('');
    l.push('| Status | Antal |');
    l.push('|---|---|');
    for (const [k, n] of Object.entries(r.requirements.byStatus)) l.push('| ' + cell(k) + ' | **' + cell(n) + '** |');
    l.push('| **totalt** | **' + cell(r.requirements.total) + '** |');
    l.push('');
  }
  if (r.integrityWarnings && r.integrityWarnings.length) {
    l.push('## Integritetsvarningar');
    l.push('');
    for (const w of r.integrityWarnings) l.push('- ' + w);
    l.push('');
  }
  l.push('');
  if (Object.keys(r.metrics || {}).length) {
    l.push('## Mätvärden');
    l.push('');
    l.push('| Nyckel | Värde |');
    l.push('|---|---|');
    for (const [k, v] of Object.entries(r.metrics)) l.push('| ' + cell(k) + ' | ' + cell(v) + ' |');
    l.push('');
  }
  l.push('## Statusordbok');
  l.push('');
  l.push('**Statusordbok.** `passed` kördes och godkändes (varningar tillåtna, räknas separat) · `failed` kördes och fällde · `blocked` kördes, men mot en artefakt som en fallerad producent inte kunde skriva om — utfallet är en följd, inte ett självständigt fynd · `not run` kördes inte · `not applicable` kan inte gälla, med obligatorisk motivering och ägare. **Endast `passed` och `not applicable` uppfyller ett godkännandekriterium.**');
  l.push('');
  l.push('**Tre resultatnivåer.** `pipelineResult` = verktygsstegen · `controlsResult` = kontrollregistret · `phaseGateResult` = kontroller i den aktuella fasens scope. `overallResult` kräver att alla tre är gröna, plus manifestet och GEN-01.');
  l.push('');
  return l.join('\n');
}
