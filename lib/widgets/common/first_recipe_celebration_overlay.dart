import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_motion.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

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
      transitionDuration: AnimationUtils.getDuration(
        context,
        AppMotion.standard,
      ),
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
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.primary,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.celebrationFirstRecipeTitle,
                  style: AppTextStyles.headlineBold.copyWith(
                    color: cs.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space16),
                Text(
                  l10n.celebrationFirstRecipeMessage(widget.recipeTitle),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: cs.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space32),
                ActionButtons.actionButton(
                  context,
                  label: l10n.celebrationFirstRecipeContinue,
                  onPressed: widget.onDismiss,
                  style: ActionButtonStyle.onInk,
                  isExpanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
