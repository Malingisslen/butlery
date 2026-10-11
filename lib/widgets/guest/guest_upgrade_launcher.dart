import 'package:flutter/material.dart';

import 'package:butlery/views/auth/guest_upgrade_view.dart';

/// The one place "Skapa konto" leads from: the guest band and the guest sheets.
class GuestUpgradeLauncher {
  const GuestUpgradeLauncher();

  /// Opens the upgrade screen. The sheets call this after closing
  /// themselves, so [context] may belong to a screen that is gone by then.
  void launch(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GuestUpgradeView()),
    );
  }
}
