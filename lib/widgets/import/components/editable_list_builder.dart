// lib/widgets/import/components/editable_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// A reusable editable list widget for managing string items.
/// Used for ingredients and instructions in recipe import.
class EditableListBuilder extends StatelessWidget {
  final List<String> items;
  final void Function(int, String) onUpdate;
  final void Function(int) onRemove;
  final void Function(String) onAdd;
  final String hintText;
  final bool showNumbers;

  const EditableListBuilder({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onRemove,
    required this.onAdd,
    required this.hintText,
    this.showNumbers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Existing items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return ButleryFieldRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showNumbers) ButleryRowNumber(index + 1),
              Expanded(
                child: ButleryRowField(
                  initialValue: item,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => onUpdate(index, value),
                  suffixIcon: IconButton(
                    icon: const ButleryIcon(
                      ButleryIcons.x,
                      size: AppDimensions.iconSize18,
                    ),
                    onPressed: () => onRemove(index),
                    tooltip: context.l10n.commonDelete,
                  ),
                ),
              ),
            ],
          );
        }),

        // Add new item
        ButleryFieldRow(
          children: [
            if (showNumbers) const SizedBox(width: ButleryRowNumber.width),
            Expanded(
              child: AddItemField(
                hintText: hintText,
                onAdd: onAdd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section header for editable lists.
class EditableListHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const EditableListHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        ButleryIcon(
          icon,
          size: AppDimensions.iconSizeM,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: AppDimensions.space8),
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(width: AppDimensions.space8),
        Container(
          padding: AppDimensions.badgePadding,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
