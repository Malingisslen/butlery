/// BUT-670: full-screen "Underhållsläge" blocker.
///
/// Shown when Remote Config `app_maintenance_mode == true`. Replaces the
/// entire app UI (no nav, no FAB) so users can't perform actions against a
/// degraded backend. Copy comes from `app_maintenance_message_sv` via
/// Remote Config; the title and retry button are hardcoded Swedish so they
/// work even if AppLocalizations failed to initialize.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MaintenanceModeBlocker extends StatelessWidget {
  /// User-facing copy from Remote Config. Falls back to a localized generic
  /// message ([AppLocalizations.maintenanceModeDefaultMessage]) when empty.
  final String message;

  /// Triggered by the retry button. Should call
  /// `FeatureFlagService.refresh()` and re-evaluate the maintenance flag.
  final VoidCallback onRetry;

  const MaintenanceModeBlocker({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayMessage = message.trim().isEmpty
        ? context.l10n.maintenanceModeDefaultMessage
        : message;

    return MediaQuery(
      // Clamp text scaling so a user with extreme accessibility settings
      // still sees the action button on screen.
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.5,
        ),
      ),
      child: Scaffold(
        backgroundColor: cs.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: AppDimensions.iconSizeHero,
                    color: cs.onPrimary,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    context.l10n.maintenanceModeTitle,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: cs.onPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    displayMessage,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingXxl),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.onPrimary,
                      foregroundColor: cs.primary,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      minimumSize: const Size(160, 48),
                    ),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
