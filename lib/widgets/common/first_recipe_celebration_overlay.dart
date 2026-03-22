import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Full-screen celebration overlay shown after saving the first recipe.
/// Auto-dismisses after [autoDismissDuration] or when the user taps Continue.
class FirstRecipeCelebrationOverlay extends StatefulWidget {
  final String recipeTitle;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const FirstRecipeCelebrationOverlay({
    super.key,
    required this.recipeTitle,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 5),
  });

  /// Shows the celebration overlay as a full-screen dialog.
  static Future<void> show(
    BuildContext context, {
    required String recipeTitle,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FirstRecipeCelebrationOverlay(
          recipeTitle: recipeTitle,
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<FirstRecipeCelebrationOverlay> createState() =>
      _FirstRecipeCelebrationOverlayState();
}

class _FirstRecipeCelebrationOverlayState
    extends State<FirstRecipeCelebrationOverlay> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(widget.autoDismissDuration, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: AppColors.forestGreen,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.celebrationFirstRecipeTitle,
                  style: AppTextStyles.headlineBold.copyWith(
                    color: AppColors.cream,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  l10n.celebrationFirstRecipeMessage(widget.recipeTitle),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.cream,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.spacingXxl,
                  child: FilledButton(
                    onPressed: widget.onDismiss,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cream,
                      foregroundColor: AppColors.forestGreenDark,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      l10n.celebrationFirstRecipeContinue,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.forestGreenDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
