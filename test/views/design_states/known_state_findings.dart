/// P8-U01: the states that break their design rule today.
///
/// Shrink-only (decision Q8-01 = A, Q8-03): an entry is a failure the app has
/// now, with the ticket that will fix it. The 53-state test fails when a
/// state breaks a rule that is not listed here, and also when a listed rule
/// holds again but the entry is still here. The list may not grow past
/// [knownStateFindingsCeiling] without that number changing in review.
///
/// Keys are `view::STATE::mode::CODE`. Every ticket is a registered Linear
/// issue (BUT-nnnn); the package 8 tickets have their title in
/// [registeredTickets].
library;

/// One known failure and the ticket that owns it.
class KnownFinding {
  const KnownFinding(this.ticket, this.what);

  /// The Linear issue, BUT-nnnn.
  final String ticket;

  /// What is wrong, in one line.
  final String what;
}

/// Today's failures, from test_results/design-states-53.json.
const Map<String, KnownFinding> knownStateFindings = {
  'admin::DEFAULT::light::OVERFLOW': KnownFinding(
    'BUT-2180',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::DEFAULT::dark::OVERFLOW': KnownFinding(
    'BUT-2180',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::EMPTY::light::OVERFLOW': KnownFinding(
    'BUT-2180',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'admin::EMPTY::dark::OVERFLOW': KnownFinding(
    'BUT-2180',
    'A RenderFlex overflowed by 8.0 pixels on the bottom.',
  ),
  'auth-otp::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'auth-otp::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'chatt::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B3E6EAD9 ("Skickat")',
  ),
  'chatt::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #33CE7C1E',
  ),
  'chatt::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B32F4437 ("Skickat")',
  ),
  'chatt::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #33CE7C1E',
  ),
  'chatt::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #338FB89A',
  ),
  'chatt::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #338FB89A',
  ),
  'dialog-sheet::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::LOADING::light::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'dialog-sheet::LOADING::dark::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'hem::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2197',
    '#FFE09D50 ("IKVÄLL · 45 MIN · 4 PORT…")',
  ),
  'hem::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2197',
    '#FFE09D50 ("IKVÄLL · 45 MIN · 4 PORT…")',
  ),
  'import-av-recept::LOADING::light::COLOUR_TEXT': KnownFinding(
    'BUT-2184',
    '#6124382C ("https://www.koket.se/kra…")',
  ),
  'import-av-recept::LOADING::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #80E6EAD9',
  ),
  'import-av-recept::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2184',
    '#61F5F4ED ("https://www.koket.se/kra…")',
  ),
  'import-av-recept::LOADING::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #802F4437',
  ),
  'import-av-recept::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'import-av-recept::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1AD8B784',
  ),
  'import-av-recept::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'import-av-recept::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1ADCA968',
  ),
  'inköpslista::CONFLICT::light::NO_UPDATED_BY_NOTICE': KnownFinding(
    'BUT-2187',
    'no "Listan uppdaterades av namn" (produktregler.md:101)',
  ),
  'inköpslista::CONFLICT::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1AD8B784',
  ),
  'inköpslista::CONFLICT::dark::NO_UPDATED_BY_NOTICE': KnownFinding(
    'BUT-2187',
    'no "Listan uppdaterades av namn" (produktregler.md:101)',
  ),
  'inköpslista::CONFLICT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2199',
    '#FF37453A ("Veckans inköp")',
  ),
  'inköpslista::CONFLICT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1ADCA968',
  ),
  'inköpslista::DEFAULT::light::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::DEFAULT::dark::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#99FFFFFF ("Välj inköpslista")',
  ),
  'inköpslista::EMPTY::light::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::EMPTY::dark::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::LOADING::light::OVERFLOW': KnownFinding(
    'BUT-2190',
    'A RenderFlex overflowed by 68 pixels on the right.',
  ),
  'inköpslista::LOADING::light::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#61000000 ("Redigera"), #DD000000 ("icon U+E3C6"), #FFBDBDBD ("icon U+E098")',
  ),
  'inköpslista::LOADING::light::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000, DecoratedBox #1A24382C',
  ),
  'inköpslista::LOADING::dark::OVERFLOW': KnownFinding(
    'BUT-2190',
    'A RenderFlex overflowed by 68 pixels on the right.',
  ),
  'inköpslista::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#1AFFFFFF ("icon U+E098"), #62FFFFFF ("Redigera"), #FF8A5212 ("Ägare"), #FFFFFFFF ("icon U+E3C6")',
  ),
  'inköpslista::LOADING::dark::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000, DecoratedBox #1AF5F4ED',
  ),
  'inköpslista::OFFLINE::light::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::OFFLINE::dark::EXCEPTION': KnownFinding(
    'BUT-2186',
    'BoxConstraints forces an infinite width.',
  ),
  'inköpslista::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#99FFFFFF ("Välj inköpslista")',
  ),
  'profil-inställningar::OFFLINE::light::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#FF616161 ("icon U+E098")',
  ),
  'profil-inställningar::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::CONFLICT::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1A3F6B4F, DecoratedBox #1AD8B784',
  ),
  'recepteditor::CONFLICT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1A8FB89A, DecoratedBox #1ADCA968',
  ),
  'recepteditor::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B324382C ("Tryck för att lägga till…"), #FF616161 ("icon U+E098")',
  ),
  'recepteditor::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1A24382C',
  ),
  'recepteditor::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B3F5F4ED ("Tryck för att lägga till…"), #B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1AF5F4ED',
  ),
  'recepteditor::OFFLINE::light::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B324382C ("Tryck för att lägga till…"), #FF616161 ("icon U+E098")',
  ),
  'recepteditor::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1A24382C',
  ),
  'recepteditor::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2183',
    '#B3F5F4ED ("Tryck för att lägga till…"), #B3FFFFFF ("icon U+E098")',
  ),
  'recepteditor::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1AF5F4ED',
  ),
  'receptlista-sök::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'receptlista-sök::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'skafferi::DEFAULT::light::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#FF616161 ("icon U+E098")',
  ),
  'skafferi::DEFAULT::light::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'skafferi::DEFAULT::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2185',
    '#B3FFFFFF ("icon U+E098")',
  ),
  'skafferi::DEFAULT::dark::COLOUR_FILL': KnownFinding(
    'BUT-2181',
    'ColoredBox #8A000000',
  ),
  'skafferi::OFFLINE::light::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'skafferi::OFFLINE::dark::NO_OFFLINE_BANNER': KnownFinding(
    'BUT-2182',
    'no "Ingen anslutning" title',
  ),
  'veckogenerering::LOADING::light::COLOUR_TEXT': KnownFinding(
    'BUT-2184',
    '#6124382C ("Vegetariskt i veckan, sn…")',
  ),
  'veckogenerering::LOADING::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2184',
    '#61F5F4ED ("Vegetariskt i veckan, sn…")',
  ),
  'vänner-grupp::LOADING::light::NO_PLATE_LINE': KnownFinding(
    'BUT-2189',
    'no PlateLine in the tree',
  ),
  'vänner-grupp::LOADING::dark::NO_PLATE_LINE': KnownFinding(
    'BUT-2189',
    'no PlateLine in the tree',
  ),
  'vänner-grupp::OFFLINE::light::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1AD8B784',
  ),
  'vänner-grupp::OFFLINE::dark::COLOUR_TEXT': KnownFinding(
    'BUT-2199',
    '#FF37453A ("Veckans inköp")',
  ),
  'vänner-grupp::OFFLINE::dark::COLOUR_FILL': KnownFinding(
    'BUT-2183',
    'DecoratedBox #1ADCA968',
  ),
};

/// The most entries the list may hold. Lower it when an entry goes.
const int knownStateFindingsCeiling = 72;

/// The package 8 tickets, registered in Linear, by id: title in one line.
const Map<String, String> registeredTickets = {
  'BUT-2180':
      'Admin: the top bar filter row overflows by 8 px (butlery_top_bar.dart undersida bottom, 56 px row)',
  'BUT-2181': 'Dialogs and sheets dim with Flutter black54, not semantic.scrim',
  'BUT-2182': 'No offline banner ("Ingen anslutning") on this view',
  'BUT-2183': 'Opacity used as decoration or state, off the opacityLadder',
  'BUT-2184':
      'Disabled fields and buttons use Material default opacity (0.38/0.5), not text.disabled/surface.disabled',
  'BUT-2185':
      'Material default greys (DropdownButton arrow #616161/white70, black87, hint white60) instead of tokens',
  'BUT-2186':
      'Shopping list header: "Sortera kategorier" OutlinedButton gets infinite width in a Row (theme minimumSize width infinity), layout fails on every open list',
  'BUT-2187':
      'Shopping list conflict: no "Listan uppdaterades av namn" notice (produktregler.md:101)',
  'BUT-2199': 'Shared list header draws light text.body (#37453A) in dark mode',
  'BUT-2189':
      'Add members shows the empty state, not loading, while the friends service is still loading',
  'BUT-2190': 'Member management dialog overflows by 68 px at 360 dp',
  'BUT-2191':
      'Contrast pairs in tokens.json with no generated app member (text.accent, text.disabled, surface.tint.*, control.checked.background, dataScale.*)',
  'BUT-2192':
      'Layout overflows at 320 dp or at 150/200 % text (auth, settings, recipe detail, week menu)',
  'BUT-2193':
      'Button labels are cut with an ellipsis instead of wrapping (Skicka igen, Välj recept manuellt, Till inköpslista, list name)',
  'BUT-2194':
      'Tap targets under 48 dp (cooking ingredient rows 32 dp, recipe detail text button 20 dp, shared list button 40 dp)',
  'BUT-2195':
      'Tap targets without a label (smart import full-page tap area, add-members checkboxes)',
  'BUT-2196':
      'Rendered text under its contrast floor (textContrastGuideline): meta lines, week subtitle, start wordmark in dark',
  'BUT-2197':
      'Hem tonight card eyebrow draws palette.saffronLight #E09D50 in dark; Skarmar v12 del 1:47 (--r04slot-765) draws #DCA968 in dark',
};
