// lib/widgets/action_button.dart

import 'package:flutter/material.dart';

/// Återanvändbar knappkomponent med konsistent styling
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

    Widget buttonChild;
    if (icon != null || isLoading) {
      buttonChild = Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon),
          if (icon != null || isLoading) const SizedBox(width: 8),
          Text(effectiveLabel),
        ],
      );
    } else {
      buttonChild = Text(effectiveLabel);
    }

    Widget button;
    switch (style) {
      case ActionButtonStyle.primary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.secondary:
        button = FilledButton.tonal(
          onPressed: effectiveOnPressed,
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
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
