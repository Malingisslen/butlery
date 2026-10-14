// lib/widgets/common/buttons/butlery_text_button.dart
//
// The one text action in a row, a card or a sheet. A view picks the tone; it
// never sets a colour, a size or a padding on a TextButton of its own.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// What the words say about the action.
enum ButleryTextButtonTone {
  /// The theme's text button.
  standard,

  /// The link colour: the action leads away, as "Visa sparad plan".
  link,

  /// text.danger: the action removes something.
  danger,

  /// text.warning: the action withdraws something that is still pending,
  /// such as cancelling a sent request.
  warning,

  /// onErrorContainer: the action sits on an error banner and must read on it.
  onErrorBanner,
}

class ButleryTextButton extends StatelessWidget {
  const ButleryTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButleryTextButtonTone.standard,
    this.busy = false,
    this.busyLabel,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final IconData? icon;
  final ButleryTextButtonTone tone;

  /// Draws the plate line and keeps the name, as every busy button does.
  final bool busy;
  final String? busyLabel;

  /// What a screen reader says when the action needs more than the visible
  /// words ("Avbryt förfrågan" on a button that reads "Avbryt"). Name the
  /// action; the visible text is left out of the announcement.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colour = switch (tone) {
      ButleryTextButtonTone.standard => null,
      ButleryTextButtonTone.link => context.modeColors.textLink,
      ButleryTextButtonTone.danger => cs.error,
      ButleryTextButtonTone.warning => AppModeColors.textWarning(
        cs.brightness,
      ),
      ButleryTextButtonTone.onErrorBanner => cs.onErrorContainer,
    };
    final button = ActionButtons.textButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: busy,
      loadingText: busyLabel,
      style: colour == null
          ? null
          : TextButton.styleFrom(foregroundColor: colour),
    );
    final name = semanticLabel;
    if (name == null || busy) return button;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: name,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}
