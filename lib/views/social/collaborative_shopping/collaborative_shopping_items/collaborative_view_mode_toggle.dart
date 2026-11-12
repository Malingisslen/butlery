import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:flutter/material.dart';

class CollaborativeViewModeToggle extends StatelessWidget {
  final ShoppingViewMode mode;
  final ValueChanged<ShoppingViewMode> onChanged;

  const CollaborativeViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMargin,
      ),
      child: UnderlineTabs<ShoppingViewMode>(
        values: ShoppingViewMode.values,
        labelOf: (m) => switch (m) {
          ShoppingViewMode.all => context.l10n.alla,
          ShoppingViewMode.myPart => context.l10n.minDel,
          ShoppingViewMode.byZone => context.l10n.efterZon,
        },
        selected: mode,
        onChanged: onChanged,
      ),
    );
  }
}
