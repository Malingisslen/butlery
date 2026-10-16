// lib/widgets/common/feedback/ink_snack_bar_action.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/components/feedback_themes.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// The ink snackbar's action: 13/700 (text accent on ink; Komponentark
/// v1:747), with its own paper focus ring.
class InkSnackBarAction extends StatelessWidget {
  const InkSnackBarAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Ångra, Försök igen, Öppna inställningar or Stäng. Never "OK".
  final String label;

  /// What the action does. The caller closes the snackbar.
  final VoidCallback onPressed;

  /// The action. The key is for tests, not identity.
  static const Key actionKey = ValueKey<String>('inkSnackBar.action');

  /// Komponentark v1:747: `border-radius:4px`. Interpretation: 4 is the
  /// spacing scale's smallest step; the radius scale has no 4.
  static const double radius = AppDimensions.space4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).snackBarTheme;
    return FocusRingSurface(
      brightness: Brightness.dark,
      child: TextButton(
        key: actionKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: theme.actionTextColor,
          textStyle: FeedbackThemes.inkSnackBarActionStyle,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
