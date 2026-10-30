// lib/widgets/import/clipboard_url_banner.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Offers to import a recipe URL found on the clipboard when the app resumes.
///
/// The banner and its auto-dismiss timer are both tied to this banner's own
/// controller: the root messenger shows one banner at a time, so hiding "the
/// current banner" would close whichever one is on top by then (e.g. the
/// allergen prompt shown after an import).
class ClipboardUrlBanner {
  const ClipboardUrlBanner._();

  static const autoDismissAfter = Duration(seconds: 8);

  static void show(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n, {
    required VoidCallback onUse,
  }) {
    late final ScaffoldFeatureController<
      MaterialBanner,
      MaterialBannerClosedReason
    >
    controller;
    controller = messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(l10n.importClipboardUrlDetected),
        leading: const ButleryIcon(ButleryIcons.link),
        actions: [
          ButleryTextButton(
            label: l10n.importClipboardUseUrl,
            onPressed: () {
              controller.close();
              onUse();
            },
          ),
          ButleryTextButton(
            label: l10n.commonClose,
            onPressed: () => controller.close(),
          ),
        ],
      ),
    );

    final timer = Timer(autoDismissAfter, controller.close);
    controller.closed.whenComplete(timer.cancel);
  }
}
