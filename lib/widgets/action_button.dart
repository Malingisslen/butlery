// lib/widgets/action_button.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD ÅTERANVÄNDBAR KNAPPKOMPONENT
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final String? loadingText;
  final ActionButtonStyle style;
  final bool isExpanded;

  const ActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingText,
    this.style = ActionButtonStyle.primary,
    this.isExpanded = false,
  });

  const ActionButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingText,
    this.isExpanded = false,
  }) : style = ActionButtonStyle.primary;

  const ActionButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingText,
    this.isExpanded = false,
  }) : style = ActionButtonStyle.secondary;

  const ActionButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingText,
    this.isExpanded = false,
  }) : style = ActionButtonStyle.outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveLabel = isLoading ? (loadingText ?? 'Laddar...') : label;

    // Bygg knappens innehåll med bättre flex-hantering
    Widget buttonChild = Padding(
      padding: EdgeInsets.symmetric(
        horizontal:
            AppTheme.spacingXs, // Liten padding för att undvika overflow
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ikon eller loading indicator
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: AppTheme.smallLoadingIndicator(),
            )
          else if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: AppTheme.actionIcon(context, icon!),
            ),

          // Text med Flexible för att hantera overflow
          Flexible(
            fit: isExpanded ? FlexFit.tight : FlexFit.loose,
            child: Text(
              effectiveLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    Widget button;
    switch (style) {
      case ActionButtonStyle.primary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.primaryButtonStyle, // ✅ SEMANTISK BUTTON STYLE
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.secondary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.primaryButtonStyle.copyWith(
            // Baserad på primary men med egen styling om behövs
            backgroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.secondary,
            ),
          ),
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.secondaryButtonStyle, // ✅ SEMANTISK BUTTON STYLE
          child: buttonChild,
        );
        break;
    }

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

enum ActionButtonStyle { primary, secondary, outlined }
