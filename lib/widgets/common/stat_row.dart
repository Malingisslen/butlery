// lib/widgets/common/stat_row.dart
//
// The key-figure row of the drawn detail pages (Skarmar v12 del 3 #18): up to
// three figures, each with a hairline over it, the number above its label.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class StatRowItem {
  const StatRowItem({required this.value, required this.label});

  final String value;
  final String label;
}

class StatRow extends StatelessWidget {
  const StatRow({required this.items, super.key});

  final List<StatRowItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimensions.space16),
          Expanded(
            child: Semantics(
              container: true,
              child: Container(
                padding: const EdgeInsets.only(top: AppDimensions.space8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: cs.outline,
                      width: AppDimensions.borderWidthStandard,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].value,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      items[i].label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
