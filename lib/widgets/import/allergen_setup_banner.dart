// lib/widgets/import/allergen_setup_banner.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// BUT-1198: non-blocking import-flow prompt shown when a freshly-imported
/// recipe contains an allergen the user hasn't configured to track.
///
/// Rendered as an app-level [MaterialBanner] via the root [ScaffoldMessenger]
/// so it survives the `pushReplacement` into the recipe editor — it never gates
/// the import success flow, and is dismissible. The CTA deep-links to the same
/// combined allergen-preferences screen the recipe-list filter panel uses
/// (`Routes.settingsAllergens`), so part 1 and part 2 of BUT-987 share a target.
class AllergenSetupBanner {
  const AllergenSetupBanner._();

  static void show(BuildContext context) {
    // Capture stable references now: the calling view is about to be replaced,
    // so the banner's action closures must not depend on its BuildContext.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final l10n = context.l10n;
    final colors = context.butleryColors;
    final scheme = Theme.of(context).colorScheme;

    // Collapse any still-visible prompt from a prior back-to-back import to the
    // latest one rather than queueing duplicates.
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: scheme.surface,
        leading: Icon(
          Icons.health_and_safety_outlined,
          color: colors.warning,
        ),
        content: Text(l10n.importAllergenSetupBanner),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: Text(l10n.commonDismiss),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              navigator.pushNamed(Routes.settingsAllergens);
            },
            child: Text(l10n.importAllergenSetupCta),
          ),
        ],
      ),
    );
  }
}
