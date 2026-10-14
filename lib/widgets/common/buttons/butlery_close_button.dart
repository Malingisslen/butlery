// lib/widgets/common/buttons/butlery_close_button.dart
//
// The one × a sheet, a banner or a notice closes with. A view names what the
// button closes ([semanticLabel]); the glyph, the touch target and the
// default action (pop the route) are drawn here.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class ButleryCloseButton extends StatelessWidget {
  const ButleryCloseButton({
    required this.semanticLabel,
    this.onPressed,
    this.color,
    super.key,
  });

  /// What closes, from l10n: "Stäng näringsvärden", never a bare "×".
  final String semanticLabel;

  /// Pops the route when null. A banner passes its own dismiss.
  final VoidCallback? onPressed;

  /// The glyph's colour; the theme's icon colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: ButleryIcons.x,
      semanticLabel: semanticLabel,
      color: color,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
