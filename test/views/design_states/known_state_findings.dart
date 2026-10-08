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
const Map<String, KnownFinding> knownStateFindings = {};

/// The most entries the list may hold. Lower it when an entry goes.
const int knownStateFindingsCeiling = 0;

/// The package 8 tickets, registered in Linear, by id: title in one line.
const Map<String, String> registeredTickets = {
  'BUT-2182': 'No offline banner ("Ingen anslutning") on this view',
  'BUT-2183': 'Opacity used as decoration or state, off the opacityLadder',
  'BUT-2184':
      'Disabled fields and buttons use Material default opacity (0.38/0.5), not text.disabled/surface.disabled',
  'BUT-2185':
      'Material default greys (DropdownButton arrow #616161/white70, black87, hint white60) instead of tokens',
  'BUT-2201':
      'Shopping list header: three buttons in one row do not fit at 320 dp or 150/200 % text, and the 104 dp Sortera kategorier fails text contrast at 360 dp; the design puts Rensa köpta in the Köpt heading',
  'BUT-2187':
      'Shopping list conflict: no "Listan uppdaterades av namn" notice (produktregler.md:101)',
  'BUT-2199': 'Shared list header draws light text.body (#37453A) in dark mode',
  'BUT-2190': 'Member management dialog overflows by 68 px at 360 dp',
  'BUT-2192':
      'Layout overflows at 320 dp or at 150/200 % text (auth, settings, recipe detail, week menu)',
  'BUT-2193':
      'Button labels are cut with an ellipsis instead of wrapping (Skicka igen, Välj recept manuellt, Till inköpslista, list name)',
  'BUT-2194':
      'Tap targets under 48 dp (cooking ingredient rows 32 dp, recipe detail text button 20 dp)',
  'BUT-2195': 'Tap targets without a label',
  'BUT-2196':
      'Rendered text under its contrast floor (textContrastGuideline): meta lines, week subtitle',
};
