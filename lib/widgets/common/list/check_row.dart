// lib/widgets/common/list/check_row.dart
//
// One thing in a list you tick (Skarmar v12 'Importera från arkiv'): the square
// box first, then the name in bold with an optional muted line under it, and
// a hairline under the row.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/square_check_box.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class CheckRow extends StatelessWidget {
  const CheckRow({
    required this.title,
    required this.checked,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Semantics(
        label: subtitle == null ? title : '$title, $subtitle',
        checked: checked,
        excludeSemantics: true,
        onTap: () => onChanged(!checked),
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: () => onChanged(!checked),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space12,
                ),
                child: Row(
                  children: [
                    SquareCheckBox(checked: checked),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
