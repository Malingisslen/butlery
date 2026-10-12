// lib/widgets/common/buttons/square_check_box.dart
//
// The square box at the end of a row you tick (Skarmar v12 'Dela med' and
// 'Importera från arkiv'): ink with a paper check when ticked, an outline edge
// when not. Paint only; the row around it owns the tap and the semantics.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class SquareCheckBox extends StatelessWidget {
  const SquareCheckBox({required this.checked, super.key});

  final bool checked;

  static const double _box = 24;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: _box,
      height: _box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl / 2),
        border: Border.all(
          color: checked ? cs.primary : cs.outline,
          width: AppDimensions.borderWidthOutlinedEdge,
        ),
      ),
      child: checked
          ? ButleryIcon(
              ButleryIcons.check,
              size: AppDimensions.iconSizeS,
              color: cs.onPrimary,
            )
          : null,
    );
  }
}
