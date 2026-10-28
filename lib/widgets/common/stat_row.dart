// lib/widgets/common/stat_row.dart
//
// The key-figure row of the drawn detail pages: up to
// three figures, each with a hairline over it, the number above its label.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final share =
            (constraints.maxWidth -
                AppDimensions.space16 * (items.length - 1)) /
            items.length;
        final sideBySide =
            widestWord(
                  context,
                  items.map((item) => item.value),
                  AppTextStyles.titleLargeBold,
                ) <=
                share &&
            widestWord(
                  context,
                  items.map((item) => item.label),
                  AppTextStyles.captionText,
                ) <=
                share;
        // Large text: the figures stack, one to a line, rather than a word
        // breaking in the middle of its column.
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppDimensions.space16,
            children: [for (final item in items) _Figure(item: item)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppDimensions.space16,
          children: [
            for (final item in items) Expanded(child: _Figure(item: item)),
          ],
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.item});

  final StatRowItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.only(top: AppDimensions.space8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: cs.onSurface,
              width: AppDimensions.borderWidthThick,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              style: AppTextStyles.titleLargeBold.copyWith(color: cs.onSurface),
            ),
            Text(
              item.label,
              style: AppTextStyles.captionText.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
