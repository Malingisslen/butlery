import 'package:flutter/widgets.dart';

/// The one place "Skapa konto" leads from: the guest band and the guest sheets.
class GuestUpgradeLauncher {
  const GuestUpgradeLauncher();

  /// Deliberately empty: part 2 (BUT-920) routes this to the upgrade screen,
  /// and wiring it here keeps that a one-line change.
  void launch(BuildContext context) {}
}
