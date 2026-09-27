/// P8-U01: the states that break their design rule today.
///
/// Shrink-only (decision Q8-01 = A, Q8-03): an entry is a failure the app has
/// now, with the ticket that will fix it. The 53-state test fails when a
/// state breaks a rule that is not listed here, and also when a listed rule
/// holds again but the entry is still here. The list may not grow past
/// [knownStateFindingsCeiling] without that number changing in review.
///
/// Keys are `view::STATE::mode::CODE`. A ticket of the form `NY-P8-nn` is
/// proposed, not yet filed: its title and one line are in the package 8
/// report, and the entry takes the BUT number when it is filed.
library;

/// One known failure and the ticket that owns it.
class KnownFinding {
  const KnownFinding(this.ticket, this.what);

  /// BUT-nnnn, or NY-P8-nn while the ticket is only proposed.
  final String ticket;

  /// What is wrong, in one line.
  final String what;
}

/// Today's failures, from test_results/design-states-53.json.
const Map<String, KnownFinding> knownStateFindings = {
  'admin::DEFAULT::light::OVERFLOW': KnownFinding(
    'NY-P8-01',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::DEFAULT::dark::OVERFLOW': KnownFinding(
    'NY-P8-01',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::EMPTY::light::OVERFLOW': KnownFinding(
    'NY-P8-01',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::EMPTY::dark::OVERFLOW': KnownFinding(
    'NY-P8-01',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'auth-otp::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'auth-otp::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'chatt::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B3E6EAD9 ("Skickat")',
  ),
  'chatt::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #33CE7C1E',
  ),
  'chatt::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B32F4437 ("Skickat")',
  ),
  'chatt::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #33CE7C1E',
  ),
  'chatt::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #338FB89A',
  ),
  'chatt::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #338FB89A',
  ),
  'dialog-sheet::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::LOADING::light::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::LOADING::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'hem::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-19',
    '#FFE09D50 ("IKVÄLL · 45 MIN · 4 PORT…")',
  ),
  'hem::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-19',
    '#FFE09D50 ("IKVÄLL · 45 MIN · 4 PORT…")',
  ),
  'import-av-recept::LOADING::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-05',
    '#6124382C ("https://www.koket.se/kra…")',
  ),
  'import-av-recept::LOADING::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #80E6EAD9',
  ),
  'import-av-recept::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-05',
    '#61F5F4ED ("https://www.koket.se/kra…")',
  ),
  'import-av-recept::LOADING::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #802F4437',
  ),
  'import-av-recept::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'import-av-recept::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1AD8B784',
  ),
  'import-av-recept::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'import-av-recept::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1ADCA968',
  ),
  'inköpslista::CONFLICT::light::NO_UPDATED_BY_NOTICE': KnownFinding(
    'NY-P8-08',
    'no "Listan uppdaterades av namn" (produktregler.md:101)',
  ),
  'inköpslista::CONFLICT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1AD8B784',
  ),
  'inköpslista::CONFLICT::dark::NO_UPDATED_BY_NOTICE': KnownFinding(
    'NY-P8-08',
    'no "Listan uppdaterades av namn" (produktregler.md:101)',
  ),
  'inköpslista::CONFLICT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-09',
    '#FF37453A ("Veckans inköp")',
  ),
  'inköpslista::CONFLICT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1ADCA968',
  ),
  'inköpslista::DEFAULT::light::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::DEFAULT::dark::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#99FFFFFF ("Välj inköpslista")',
  ),
  'inköpslista::EMPTY::light::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::EMPTY::dark::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::LOADING::light::OVERFLOW': KnownFinding(
    'NY-P8-11',
    'A RenderFlex overflowed by 68 pixels on the right.',
  ),
  'inköpslista::LOADING::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#61000000 ("Redigera"), #DD000000 ("icon U+E3C6"), #FFBDBDBD ("icon U+E098")',
  ),
  'inköpslista::LOADING::light::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000, DecoratedBox #1A24382C',
  ),
  'inköpslista::LOADING::dark::OVERFLOW': KnownFinding(
    'NY-P8-11',
    'A RenderFlex overflowed by 68 pixels on the right.',
  ),
  'inköpslista::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#1AFFFFFF ("icon U+E098"), #62FFFFFF ("Redigera"), #FF8A5212 ("Ägare"), #FFFFFFFF ("icon U+E3C6")',
  ),
  'inköpslista::LOADING::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000, DecoratedBox #1AF5F4ED',
  ),
  'inköpslista::OFFLINE::light::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::OFFLINE::dark::EXCEPTION': KnownFinding(
    'NY-P8-07',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#99FFFFFF ("Välj inköpslista")',
  ),
  'profil-inställningar::OFFLINE::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#FF616161 ("icon U+E098")',
  ),
  'profil-inställningar::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::CONFLICT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1A3F6B4F, DecoratedBox #1AD8B784',
  ),
  'recepteditor::CONFLICT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1A8FB89A, DecoratedBox #1ADCA968',
  ),
  'recepteditor::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B324382C ("Tryck för att lägga till…"), #FF616161 ("icon U+E098")',
  ),
  'recepteditor::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1A24382C',
  ),
  'recepteditor::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B3F5F4ED ("Tryck för att lägga till…"), #B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1AF5F4ED',
  ),
  'recepteditor::OFFLINE::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B324382C ("Tryck för att lägga till…"), #FF616161 ("icon U+E098")',
  ),
  'recepteditor::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1A24382C',
  ),
  'recepteditor::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-04',
    '#B3F5F4ED ("Tryck för att lägga till…"), #B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1AF5F4ED',
  ),
  'receptlista-sök::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'receptlista-sök::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'skafferi::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#FF616161 ("icon U+E098")',
  ),
  'skafferi::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'skafferi::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-06',
    '#B3FFFFFF ("icon U+E098")',
  ),
  'skafferi::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-02',
    'ColoredBox #8A000000',
  ),
  'skafferi::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'skafferi::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'NY-P8-03',
    'no "Ingen anslutning" title',
  ),
  'veckogenerering::LOADING::light::COLOUR_TEXT': KnownFinding(
    'NY-P8-05',
    '#6124382C ("Vegetariskt i veckan, sn…")',
  ),
  'veckogenerering::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-05',
    '#61F5F4ED ("Vegetariskt i veckan, sn…")',
  ),
  'vänner-grupp::LOADING::light::NO_PLATE_LINE': KnownFinding(
    'NY-P8-10',
    'no PlateLine in the tree',
  ),
  'vänner-grupp::LOADING::dark::NO_PLATE_LINE': KnownFinding(
    'NY-P8-10',
    'no PlateLine in the tree',
  ),
  'vänner-grupp::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1AD8B784',
  ),
  'vänner-grupp::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'NY-P8-09',
    '#FF37453A ("Veckans inköp")',
  ),
  'vänner-grupp::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'NY-P8-04',
    'DecoratedBox #1ADCA968',
  ),
};

/// The most entries the list may hold. Lower it when an entry goes.
const int knownStateFindingsCeiling = 72;

/// The proposed tickets, by id: title in one line.
const Map<String, String> proposedTickets = {
  'NY-P8-01':
      'Admin: the top bar filter row overflows by 8 px (butlery_top_bar.dart undersida bottom, 56 px row)',
  'NY-P8-02': 'Dialogs and sheets dim with Flutter black54, not semantic.scrim',
  'NY-P8-03': 'No offline banner ("Ingen anslutning") on this view',
  'NY-P8-04': 'Opacity used as decoration or state, off the opacityLadder',
  'NY-P8-05':
      'Disabled fields and buttons use Material default opacity (0.38/0.5), not text.disabled/surface.disabled',
  'NY-P8-06':
      'Material default greys (DropdownButton arrow #616161/white70, black87, hint white60) instead of tokens',
  'NY-P8-07':
      'Shopping list header: "Sortera kategorier" OutlinedButton gets infinite width in a Row (theme minimumSize width infinity), layout fails on every open list',
  'NY-P8-08':
      'Shopping list conflict: no "Listan uppdaterades av namn" notice (produktregler.md:101)',
  'NY-P8-09': 'Shared list header draws light text.body (#37453A) in dark mode',
  'NY-P8-10':
      'Add members shows the empty state, not loading, while the friends service is still loading',
  'NY-P8-11': 'Member management dialog overflows by 68 px at 360 dp',
  'NY-P8-12':
      'Contrast pairs in tokens.json with no generated app member (text.accent, text.disabled, surface.tint.*, control.checked.background, dataScale.*)',
  'NY-P8-13':
      'Layout overflows at 320 dp or at 150/200 % text (auth, settings, recipe detail, week menu)',
  'NY-P8-14':
      'Button labels are cut with an ellipsis instead of wrapping (Skicka igen, Välj recept manuellt, Till inköpslista, list name)',
  'NY-P8-15':
      'Tap targets under 48 dp (cooking ingredient rows 32 dp, recipe detail text button 20 dp, shared list button 40 dp)',
  'NY-P8-16':
      'Tap targets without a label (smart import full-page tap area, add-members checkboxes)',
  'NY-P8-17':
      'Rendered text under its contrast floor (textContrastGuideline): meta lines, week subtitle, start wordmark in dark',
  'NY-P8-18':
      'Key-screen Linux goldens: land goldens-linux-update.yml on main, run it on the branch, commit the PNGs; until then the comparisons are skipped',
  'NY-P8-19':
      'Hem tonight card eyebrow draws palette.saffronLight #E09D50 in dark; Skarmar v12 del 1:47 (--r04slot-765) draws #DCA968 in dark',
};
