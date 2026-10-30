'use strict';
// Keeps the hand-off to the app modular: every change is sorted by how far it reaches, so a
// one-off never turns into a hard-coded value inside a single view.

const MODULAR_RULE = 'Delade ändringar förs in som token eller i den delade komponenten, aldrig i en enskild vy. Enstaka ändringar (en enda del, en enda vy, flyttade eller fritt flyttade delar) hårdkodas inte i vyn: fråga Malin om de ska bli en ny variant av komponenten, ändra layouten i vyns egen struktur eller hoppas över.';

// Kit class -> the Flutter module that draws it. A class that is missing here has no known module.
const COMPONENT_MAP = {
  'b-btn': ['ButleryInkButton', 'lib/widgets/common/buttons/butlery_ink_button.dart'],
  'b-iconbtn': ['AppIconButton', 'lib/widgets/common/buttons/app_icon_button.dart'],
  'b-chip': ['ButleryFilterChip / ButleryActionChip', 'lib/widgets/common/chips/'],
  'b-row': ['ButleryListRow', 'lib/widgets/common/list/butlery_list.dart'],
  'b-section': ['ButleryListSection', 'lib/widgets/common/list/butlery_list.dart'],
  'b-card': ['StyledCard', 'lib/widgets/common/cards/styled_card.dart'],
  'b-empty': ['EmptyNoticeCard', 'lib/widgets/common/cards/empty_notice_card.dart'],
  'b-input': ['StyledInput', 'lib/widgets/common/input/styled_input.dart'],
  'b-field': ['ButleryRowField', 'lib/widgets/common/input/butlery_row_field.dart'],
  'b-field-error': ['FieldErrorLine', 'lib/widgets/common/input/field_error_line.dart'],
  'b-checkbox': ['ButleryCheckbox', 'lib/widgets/common/input/butlery_checkbox.dart'],
  'b-switch': ['ButlerySwitch', 'lib/widgets/common/input/butlery_switch.dart'],
  'b-stepper': ['PortionScaler', 'lib/widgets/common/input/portion_scaler.dart'],
  'b-dialog': ['ButleryDialog', 'lib/widgets/common/dialogs/butlery_dialog.dart'],
  'b-sheet': ['ButlerySheetHeader / ButleryAddSheet', 'lib/widgets/common/sheets/'],
  'b-topbar-root': ['ButleryTopBar', 'lib/widgets/common/butlery_top_bar.dart'],
  'b-topbar-sub': ['ButleryTopBar', 'lib/widgets/common/butlery_top_bar.dart'],
  'b-bottomnav': ['ButleryBottomNavigation', 'lib/widgets/common/navigation/butlery_bottom_navigation.dart'],
  'b-avatar': ['AvatarCircle', 'lib/widgets/common/avatar_circle.dart'],
  'b-pill': ['UnifiedBadge / ButleryBetygPill', 'lib/widgets/common/badges/unified_badge.dart'],
};
function moduleOf(sel) {
  const m = /\.(b-[a-z0-9-]+)/.exec(sel);
  if (!m) return null;
  return { cls: m[1], mod: COMPONENT_MAP[m[1]] || null };
}

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
  const moved = (st.moves?.length || 0) + freeGroups(Object.values(st.free || {})).length;
  const shared = g.delad.map(p => ({ p, m: moduleOf(p.sel) })).filter(x => x.m);
  const delade = shared.filter(x => x.m.mod).map(x => `${x.p.sel} -> ${x.m.mod[0]} (${x.m.mod[1]})`);
  const utanModul = shared.filter(x => !x.m.mod).map(x => x.p.sel);
  if (delade.length) (out.modularitet ||= {}).delade = delade;
  if (utanModul.length) (out.modularitet ||= {}).utanKandModul = utanModul;
  if (!g.envy.length && !g.enstaka.length && !moved) return;
  out.modularitet = {
    ...out.modularitet,
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
  const moved = (state.moves?.length || 0) + freeGroups(Object.values(state.free || {})).length;
  const rows = [];
  const add = (tone, text) => rows.push([tone, text]);
  if (g.delad.length) add('ok', `${g.delad.length} ändringar gäller alla likadana delar. De förs in i den delade komponenten eller som token.`);
  for (const p of g.delad) {
    const m = moduleOf(p.sel);
    if (m?.mod) add('ok', `${m.cls} hör till ${m.mod[0]}.`);
    else if (m) add('warn', `${m.cls} har ingen känd modul i appen. Det kan kräva en ny modul; Claude frågar dig först.`);
  }
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
  'Bilderna är sanningen. Begäran bär en bild av varje skärm som labbet visade när den skickades: dokumenten shots/<begärans id>-<skärm>-<ljust|mörkt> (fältet image är en JPEG som data-URL, fältet shots i begäran listar dem). Läs dem först, bifoga dem till Malin i tråden och bygg pixel för pixel mot dem, mätt med design/tools/lab-golden-compare.mjs. Siffrorna i begäran är kontroll, aldrig källa; texten ovan är Malins egna ord om vad som är medvetet.',
  'Reglerna för hur en labbexport byggs och lämnas tillbaka står i projektinstruktionerna under Labbexport.',
].join(' ');
