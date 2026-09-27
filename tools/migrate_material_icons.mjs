// tools/migrate_material_icons.mjs
// P7-U08 one-shot codemod: Material Icons / AdaptiveIcons -> ButleryIcons.
//
// The mapping is by MEANING, never by shape: a Material name maps to a
// Butlery glyph only when icons.json gives that glyph the same meaning. A
// handful of names mean different things at different call sites; those are
// mapped per file in SITE (with the reason). Everything else stays Material
// and is listed in test/architecture/icon_census_test.dart for design to draw.
//
// Usage: node tools/migrate_material_icons.mjs [lib|test]
// Kept in the repo so the one meaning map is reviewable.

import fs from 'node:fs';
import path from 'node:path';

// Material name -> ButleryIcons member. Variants (_outlined, _rounded, ...)
// are listed explicitly so nothing maps by accident.
export const MAP = {
  // x — Stäng (drawn for close, remove and stop sharing: Skarmar data-hit
  // targets "ta-bort-…", "sluta-dela-med-…")
  close: 'x', clear: 'x', cancel: 'x',
  // check — Bockad / klar
  check: 'check',
  // circle-check — Bekräftad
  check_circle: 'circleCheck', check_circle_outline: 'circleCheck',
  // plus — Lägg till
  add: 'plus', add_outlined: 'plus', add_circle: 'plus',
  // minus — Minska
  remove: 'minus', remove_circle_outline: 'minus',
  // utensils — Meny / måltid
  restaurant_menu: 'utensils', restaurant_menu_outlined: 'utensils',
  restaurant: 'utensils', restaurant_outlined: 'utensils',
  dinner_dining: 'utensils', lunch_dining: 'utensils',
  breakfast_dining: 'utensils', set_meal: 'utensils',
  set_meal_outlined: 'utensils',
  // triangle-alert — Varning / fel
  error: 'triangleAlert', error_outline: 'triangleAlert',
  warning: 'triangleAlert', warning_amber: 'triangleAlert',
  warning_amber_rounded: 'triangleAlert', warning_amber_outlined: 'triangleAlert',
  warning_outlined: 'triangleAlert',
  // info — Information
  info: 'info', info_outline: 'info',
  // circle-help — Okänt / förstods inte
  help: 'circleHelp',
  // pencil — Redigera
  edit: 'pencil', edit_outlined: 'pencil', edit_note: 'pencil',
  // chevrons
  chevron_right: 'chevronRight', arrow_forward_ios: 'chevronRight',
  chevron_left: 'chevronLeft',
  expand_more: 'chevronDown', keyboard_arrow_down: 'chevronDown',
  arrow_drop_down: 'chevronDown',
  expand_less: 'chevronUp', keyboard_arrow_up: 'chevronUp',
  // arrows — Tillbaka / Nästa steg
  arrow_back: 'arrowLeft', arrow_forward: 'arrowRight',
  // trash-2 — Radera
  delete: 'trash2', delete_outline: 'trash2', delete_outlined: 'trash2',
  delete_forever: 'trash2', delete_sweep: 'trash2',
  delete_sweep_outlined: 'trash2',
  // search — Sök
  search: 'search', search_outlined: 'search',
  // refresh-cw — Försök igen / synka
  refresh: 'refreshCw', refresh_outlined: 'refreshCw', sync: 'refreshCw',
  // users — Flera personer / grupp
  people: 'users', people_outline: 'users', group: 'users',
  group_outlined: 'users', groups: 'users', groups_outlined: 'users',
  family_restroom: 'users',
  // user — En person
  person: 'user', person_outline: 'user', account_circle: 'user',
  // user-minus — Ta bort medlem
  person_remove: 'userMinus',
  // eye — Visa/dölj (one glyph for both states; the label carries the state)
  visibility: 'eye', visibility_outlined: 'eye', visibility_off: 'eye',
  visibility_off_outlined: 'eye',
  // share-2 — Dela
  share: 'share2', share_outlined: 'share2', ios_share: 'share2',
  // shopping-cart — Inköp
  shopping_cart: 'shoppingCart', shopping_cart_outlined: 'shoppingCart',
  shopping_basket: 'shoppingCart', shopping_basket_outlined: 'shoppingCart',
  // more-vertical — Fler åtgärder
  more_vert: 'moreVertical', more_horiz: 'moreVertical',
  // link — Kopiera länk
  link: 'link', link_outlined: 'link',
  // tag — Egen tagg
  label: 'tag', label_outline: 'tag', local_offer: 'tag',
  local_offer_outlined: 'tag',
  // lock — Låst / privat; unlock — Avblockera (the only lock_open use
  // unblocks users)
  lock: 'lock', lock_outline: 'lock', lock_open: 'unlock',
  // download — Spara offline; drawn for "Spara", "Spara till mitt kök",
  // "Import", "Hämta receptet"
  download: 'download', download_outlined: 'download',
  download_rounded: 'download', download_done: 'download',
  file_download: 'download', cloud_download: 'download',
  cloud_download_outlined: 'download', cloud_download_rounded: 'download',
  save_alt: 'download',
  // clock — Tid
  schedule: 'clock', access_time: 'clock', timer: 'clock',
  timer_outlined: 'clock',
  // image — Bild
  image: 'image', image_outlined: 'image', photo: 'image',
  photo_outlined: 'image', photo_library: 'image',
  photo_library_outlined: 'image', collections: 'image',
  collections_outlined: 'image',
  // camera — Kamera; "Lägg till foto" is drawn with camera (Skarmar v12
  // del 1:317)
  camera: 'camera', camera_alt: 'camera', camera_alt_outlined: 'camera',
  photo_camera: 'camera', photo_camera_outlined: 'camera',
  add_a_photo: 'camera', add_photo_alternate: 'camera',
  add_photo_alternate_outlined: 'camera',
  // calendar — Veckomeny / datum
  calendar_today: 'calendar', calendar_today_outlined: 'calendar',
  calendar_month: 'calendar', calendar_month_outlined: 'calendar',
  today_outlined: 'calendar', event_note_outlined: 'calendar',
  // server — Drift och system
  dns: 'server', dns_outlined: 'server', storage: 'server',
  // star — Betyg
  star: 'star', star_border: 'starOutline', star_outline: 'starOutline',
  // heart — Favorit
  favorite: 'heart', favorite_border: 'heartOutline',
  // send — Skicka
  send: 'send',
  // block — Blockerad
  block: 'block',
  // settings — Inställningar
  settings: 'settings', settings_outlined: 'settings',
  // filter — Filtrera (every tune use toggles or manages filters)
  tune: 'filter', tune_outlined: 'filter', filter_list: 'filter',
  // arrow-up-down — Sortera
  sort: 'arrowUpDown',
  // drag — Dra för att ordna
  drag_handle: 'drag', drag_indicator: 'drag',
  // pause / stop. play_arrow and play_circle_outline stay Material: the
  // play master (assets/icons/play.svg) fills the disc and the triangle in
  // one colour, so it draws a solid dot (also in Skarmar v12 del 1:646), and
  // no Material play use means "Starta matlagning" (icons.json).
  pause: 'pause', pause_circle: 'pause', pause_circle_outline: 'pause',
  stop: 'stop',
  // mic — Diktera
  mic: 'mic', mic_none: 'mic',
  // message-square — Meddelande
  message: 'messageSquare', message_outlined: 'messageSquare',
  chat_bubble_outline: 'messageSquare', chat_outlined: 'messageSquare',
  comment: 'messageSquare', comment_outlined: 'messageSquare',
  forum_outlined: 'messageSquare',
  // copy — Duplicera; drawn for "Kopiera texten", "Kopiera felsökningstext"
  // and "Duplicera"
  content_copy: 'copy', content_copy_outlined: 'copy', copy: 'copy',
  copy_rounded: 'copy', copy_all_outlined: 'copy',
  // swap-horizontal — Byt ut
  swap_horiz: 'swapHorizontal',
  // pin — Fäst
  push_pin: 'pin', push_pin_outlined: 'pin',
  // archive — Arkivera
  archive: 'archive', archive_outlined: 'archive',
  // wifi-off — Offline
  wifi_off: 'wifiOff', cloud_off: 'wifiOff', cloud_off_outlined: 'wifiOff',
  // vote — Rösta
  how_to_vote: 'vote', how_to_vote_outlined: 'vote',
  // shuffle — Slumpa
  shuffle: 'shuffle',
  // mail — E-post
  email: 'mail', email_outlined: 'mail', mail_outline: 'mail',
  email_rounded: 'mail',
  // folder — Samling
  folder: 'folder', folder_outlined: 'folder', folder_open: 'folder',
  // paperclip — Bifoga
  attach_file: 'paperclip',
  // reaction-add — Lägg till en reaktion
  add_reaction_outlined: 'reactionAdd',
  // list-check — Välj flera
  checklist: 'listCheck', checklist_outlined: 'listCheck',
  // check-square — Markera alla
  select_all: 'checkSquare',
  // list — Lista / välj själv ("Välj själv" is drawn with list)
  list: 'list',
  // shield-check — Verifierad
  verified: 'shieldCheck', verified_user: 'shieldCheck',
  verified_user_outlined: 'shieldCheck',
  // zap — Snabbt
  flash_on: 'zap',
  // volume — Tysta uppläsningen
  volume_up: 'volume', volume_off: 'volume',
};

// Per-file meaning where the same Material name means different things.
// path (relative to repo) -> { materialName: member | null } ; null = keep
// Material (residue).
export const SITE = {
  // Data export is export, not download (Grafisk manual v6:308: download and
  // export are two glyphs with separate semantics).
  'lib/views/account/data_export_view.dart': {
    download_rounded: 'export', cloud_download_rounded: 'export',
  },
  'lib/views/admin/metric_tab_view.dart': { download_outlined: 'export' },
  // "Kopiera länk" (tooltip commonCopyLink) is the link glyph's meaning.
  'lib/views/social/friends_list/requests_tab.dart': { copy: 'link' },
  // Diet and allergen status: unknown shows the info glyph (icons.json
  // diet_icons: circle-check, triangle-alert, info).
  'lib/widgets/tagging/allergen_status_badge.dart': { help_outline: 'info' },
  'lib/widgets/tagging/dietary_status_badge.dart': { help_outline: 'info' },
  // Unknown permission / uncertain parse: circle-help "Okänt / förstods inte".
  'lib/widgets/common/social_components/social_collaborative_components.dart':
    { help_outline: 'circleHelp' },
  'lib/widgets/menu/parsed_extraction_chips.dart': { help_outline: 'circleHelp' },
  // Kept Material: the glyph's icons.json meaning is not this use.
  // stop = "Stoppa inspelning i matlagningsläget", not stopping uploads.
  'lib/widgets/image/components/upload_progress_widgets.dart': { stop: null },
  // more-vertical = "Fler åtgärder (kebab)"; these dots mean "is typing".
  'lib/widgets/messaging/typing_indicator.dart': { more_horiz: null },
  // Presence at home: house "Hemma (närvaro)".
  'lib/views/family/who_is_eating_sheet.dart': { home_outlined: 'house' },
  'lib/widgets/menu/calendar/presence_overview.dart': { home_outlined: 'house' },
  // Place manually: hand "Gör själv / placera manuellt".
  'lib/widgets/menu/menu_placement_footer.dart': { touch_app_outlined: 'hand' },
  // The tab bar uses the nav family (Grafisk manual v6:322, 160 grid).
  'lib/widgets/common/navigation/adaptive_navigation.dart': {
    home_outlined: 'navHome', calendar_today_outlined: 'navWeek',
    shopping_cart_outlined: 'navShopping', menu: 'navMore',
  },
  'lib/widgets/common/navigation/butlery_bottom_navigation.dart': {
    add: 'navAdd',
  },
};

// Files package 7's closing track deletes; they are left as they are.
export const PROTECTED = new Set([
  'lib/widgets/common/utility_components.dart',
  'lib/widgets/common/feedback/snackbar_widgets.dart',
  'lib/widgets/common/indicators/loading_indicator.dart',
  'lib/widgets/common/adaptive_app_bar.dart',
  'lib/widgets/common/indicators/adaptive_activity_indicator.dart',
  'lib/widgets/common/indicators/sync_indicator.dart',
  'lib/theme/butlery_colors_extension.dart',
]);

const SKIP_DIRS = ['lib/widgets/common/icons/', 'lib/l10n/'];

function adaptiveTables() {
  const src = fs.readFileSync(
    'lib/widgets/common/icons/adaptive_icon.dart', 'utf8');
  const ctor = {};
  for (const m of src.matchAll(
    /const AdaptiveIcon\.(\w+)\(\{[^}]*\}\) : materialIcon = Icons\.(\w+)/g)) {
    ctor[m[1]] = m[2];
  }
  const getter = {};
  for (const m of src.matchAll(
    /static IconData get (\w+) =>\s*_isIOS \? CupertinoIcons\.\w+ : Icons\.(\w+);/g)) {
    getter[m[1]] = m[2];
  }
  for (const m of src.matchAll(/static IconData get (\w+) => (\w+);/g)) {
    getter[m[1]] = getter[m[2]];
  }
  return { ctor, getter };
}

// K-10 (migration-gap.md:46): the semantic aliases map to semantic members.
const ALIAS = {
  favouriteFilled: 'ButleryIcons.favourite',
  favouriteOutline: 'ButleryIcons.favouriteOutline',
  primaryFilled: 'ButleryIcons.primary',
  primaryOutline: 'ButleryIcons.primaryOutline',
  savedTemplate: 'PendingGlyphs.savedTemplate',
  savedTemplateOutline: 'PendingGlyphs.savedTemplateOutline',
  bookmark: 'PendingGlyphs.savedTemplate',
  bookmarkOutlined: 'PendingGlyphs.savedTemplateOutline',
};

function iconExpr(rel, name) {
  const site = SITE[rel] ?? {};
  const member = name in site ? site[name] : MAP[name];
  return member ? `ButleryIcons.${member}` : `Icons.${name}`;
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.posix.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (p.endsWith('.dart')) out.push(p);
  }
  return out;
}

const IMPORT_ICONS =
  "import 'package:butlery/widgets/common/icons/butlery_icons.dart';";
const IMPORT_GLYPH =
  "import 'package:butlery/widgets/common/icons/butlery_glyph.dart';";
const IMPORT_PENDING =
  "import 'package:butlery/widgets/common/icons/pending_glyphs.dart';";

function addImport(src, line) {
  if (src.includes(line)) return src;
  const eol = src.includes('\r\n') ? '\r\n' : '\n';
  const lines = src.split(eol);
  // Insert in sorted position among package:butlery imports, else after the
  // last import.
  let last = -1;
  let at = -1;
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (l.startsWith('import ')) {
      last = i;
      if (l.startsWith("import 'package:butlery/") && at === -1 && l > line) {
        at = i;
      }
    }
  }
  if (at === -1) {
    // after the last package:butlery import, or the last import
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].startsWith("import 'package:butlery/")) at = i + 1;
    }
    if (at === -1) at = last + 1;
  }
  lines.splice(at, 0, line);
  return lines.join(eol);
}

export function migrate(rel, src, tables, { rewriteIconCtor }) {
  let out = src;
  // AdaptiveIcon.<ctor>( ... ) -> ButleryIcon(<icon>, ...)
  out = out.replace(/\bAdaptiveIcon\.(\w+)\(\s*\)/g, (_, c) =>
    `ButleryIcon(${iconExpr(rel, tables.ctor[c])})`);
  out = out.replace(/\bAdaptiveIcon\.(\w+)\(/g, (_, c) =>
    `ButleryIcon(${iconExpr(rel, tables.ctor[c])}, `);
  // AdaptiveIcons.<getter>
  out = out.replace(/\bAdaptiveIcons\.(\w+)/g, (_, g) =>
    ALIAS[g] ?? iconExpr(rel, tables.getter[g]));
  // Icons.<name>
  out = out.replace(/(?<![\w.$])Icons\.(\w+)/g, (_, n) => iconExpr(rel, n));
  if (rewriteIconCtor) {
    out = out.replace(/(?<![\w.$])Icon\(/g, 'ButleryIcon(');
  }
  if (out === src) return src;
  out = out.replace(
    /^import '(package:butlery\/widgets\/common\/icons\/|[./]*)adaptive_icon\.dart';\r?\n/m, '');
  if (/\bButleryIcons\./.test(out)) out = addImport(out, IMPORT_ICONS);
  if (/\bButleryIcon\(/.test(out)) out = addImport(out, IMPORT_GLYPH);
  if (/\bPendingGlyphs\./.test(out)) out = addImport(out, IMPORT_PENDING);
  return out;
}

if (process.argv[1] && process.argv[1].endsWith('migrate_material_icons.mjs')) {
  const root = process.argv[2] ?? 'lib';
  const tables = adaptiveTables();
  let changed = 0;
  for (const rel of walk(root)) {
    if (PROTECTED.has(rel) || SKIP_DIRS.some((d) => rel.startsWith(d))) continue;
    if (rel.endsWith('.g.dart') || rel.endsWith('.mocks.dart')) continue;
    const src = fs.readFileSync(rel, 'utf8');
    const out = migrate(rel, src, tables, { rewriteIconCtor: root === 'lib' });
    if (out !== src) {
      fs.writeFileSync(rel, out);
      changed++;
    }
  }
  console.log(`changed ${changed} files under ${root}`);
}
