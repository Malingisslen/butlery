/// P8-U06: the checks of interaction_roles_test.dart that fail today.
///
/// Shrink-only (Q8-03): each entry names the row and mode, the checks that
/// fail, and a Linear ticket. The test fails when a row fails a check that
/// is not listed here, and also when a listed check passes, so a fix must
/// remove its entry. Never add an entry to make a test green without a
/// ticket.
library;

class KnownInteractionFinding {
  const KnownInteractionFinding({
    required this.checks,
    required this.ticket,
    required this.reason,
  });

  /// The checks that fail: reached, semantics, hitbox, visible, ring,
  /// contrast.
  final Set<String> checks;

  /// The BUT-#### Linear ticket.
  final String ticket;

  final String reason;
}

const _linkDefault = KnownInteractionFinding(
  checks: {'hitbox'},
  ticket: 'BUT-2177',
  reason:
      "The app's links (LinkifiedText, the recipe source link, the terms "
      'links in auth_view) are a GestureDetector around one line of text, '
      'shorter than 48 dp.',
);

const _linkFocused = KnownInteractionFinding(
  checks: {'reached', 'semantics', 'hitbox', 'visible'},
  ticket: 'BUT-2177',
  reason:
      'A link cannot take keyboard focus: the GestureDetector has no Focus, '
      'so Tab passes it by and no ring is drawn (HA285-A requires visible '
      'keyboard focus on links).',
);

const _radioFocused = KnownInteractionFinding(
  checks: {'ring'},
  ticket: 'BUT-2148',
  reason:
      'RadioListTile shows focus as the saffron focusColor fill '
      '(app_theme.dart focusColor) and draws no ring. The Radio inside '
      'ButleryControlFocus has the ring (butlery_control_focus_test.dart).',
);

const _switchFocused = KnownInteractionFinding(
  checks: {'ring'},
  ticket: 'BUT-2148',
  reason:
      'SwitchListTile shows focus as the saffron focusColor fill and draws no '
      'ring. The Switch inside ButleryControlFocus has the ring '
      '(butlery_control_focus_test.dart).',
);

/// Keyed by `CSR::ROLE::<role>::<STATE> (light|dark)`.
const Map<String, KnownInteractionFinding> knownInteractionFindings = {
  'CSR::ROLE::link::DEFAULT (light)': _linkDefault,
  'CSR::ROLE::link::DEFAULT (dark)': _linkDefault,
  'CSR::ROLE::link::FOCUSED (light)': _linkFocused,
  'CSR::ROLE::link::FOCUSED (dark)': _linkFocused,
  'CSR::ROLE::radio::FOCUSED (light)': _radioFocused,
  'CSR::ROLE::radio::FOCUSED (dark)': _radioFocused,
  'CSR::ROLE::switch::FOCUSED (light)': _switchFocused,
  'CSR::ROLE::switch::FOCUSED (dark)': _switchFocused,
};
