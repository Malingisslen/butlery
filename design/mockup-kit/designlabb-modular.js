'use strict';
// Keeps the hand-off to the app modular: every change is sorted by how far it reaches, so a
// one-off never turns into a hard-coded value inside a single view.

const MODULAR_RULE = 'Delade ändringar förs in som token eller i den delade komponenten, aldrig i en enskild vy. Enstaka ändringar (en enda del, en enda vy, flyttade eller fritt flyttade delar) hårdkodas inte i vyn: fråga Malin om de ska bli en ny variant av komponenten, ändra layouten i vyns egen struktur eller hoppas över.';

function modularScope(p) {
  if (p.sel.startsWith('[data-lab-id')) return 'enstaka';
  if (p.view != null) return 'envy';
  return 'delad';
}
function modularParts(st) {
  const groups = { delad: [], envy: [], enstaka: [] };
  for (const p of Object.values(st.parts)) {
    if (Object.keys(p.props).length) groups[modularScope(p)].push(p);
  }
  return groups;
}
function modularitySummary(st, out) {
  const g = modularParts(st);
  const moved = (st.moves?.length || 0) + Object.keys(st.free || {}).length;
  if (!g.envy.length && !g.enstaka.length && !moved) return;
  out.modularitet = {
    regel: MODULAR_RULE,
    kraverBeslut: [
      ...g.enstaka.map(p => `enstaka del ${p.sel}`),
      ...g.envy.map(p => `bara i en vy: ${p.sel}`),
      ...(moved ? [`${moved} flyttade delar`] : []),
    ],
  };
}
function renderModular() {
  const box = document.getElementById('modular');
  if (!box) return;
  const g = modularParts(state);
  const moved = (state.moves?.length || 0) + Object.keys(state.free || {}).length;
  const rows = [];
  const add = (tone, text) => rows.push([tone, text]);
  if (g.delad.length) add('ok', `${g.delad.length} ändringar gäller alla likadana delar. De förs in i den delade komponenten eller som token.`);
  if (g.envy.length) add('warn', `${g.envy.length} gäller bara en vy. Claude frågar dig om de ska bli en variant av komponenten.`);
  if (g.enstaka.length) add('warn', `${g.enstaka.length} gäller bara en enda del. Claude frågar dig innan något hårdkodas.`);
  if (moved) add('warn', `${moved} flyttade delar ändrar layouten i en vy, inte komponenten.`);
  box.textContent = '';
  if (!rows.length) {
    const p = document.createElement('p');
    p.className = 'hint';
    p.textContent = 'Alla dina ändringar gäller hela appen eller en delad komponent. Inget enstaka som kan skapa avvikelser.';
    box.append(p);
    return;
  }
  for (const [tone, text] of rows) {
    const p = document.createElement('p');
    p.className = `hint mod-${tone}`;
    p.textContent = text;
    box.append(p);
  }
  const rule = document.createElement('p');
  rule.className = 'hint';
  rule.textContent = 'Ingenting enstaka hårdkodas i appen utan ditt ja. Det som gäller flera likadana delar går via den delade komponenten.';
  box.append(rule);
}

// Travels with every request to Claude, so the build rule does not depend on anyone remembering it.
const HANDOFF_RULE = [
  'Rendera labbets exakta bilder från "state" (öppna designlabb.html med state, ta före- och efterbilder av berörda vyer, ljust och mörkt) och bifoga dem till Malin i tråden.',
  'Bygg så nära dessa bilder som modulariteten tillåter: ändra token eller den delade komponenten, aldrig en enskild vy.',
  'Där bilden inte kan nås utan en ny modul eller en ny variant av en befintlig, bygg inte en lösning i vyn. Säg till Malin vilken modul som saknas och vad den skulle ge, och vänta på hennes svar.',
  'Redovisa efteråt vad som landade exakt, vad som landade nära och vad som väntar på hennes beslut.',
].join(' ');
