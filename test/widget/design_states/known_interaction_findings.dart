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

/// Keyed by `CSR::ROLE::<role>::<STATE> (light|dark)`.
const Map<String, KnownInteractionFinding> knownInteractionFindings = {
};
