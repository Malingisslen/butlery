// lib/widgets/import/components/editable_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';
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

          return Padding(
            padding: AppDimensions.paddingOnlyBottom8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showNumbers) ...[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: AppTextStyles.contentLabel,
                    ),
                  ),
                ],
                Expanded(
                  child: TextFormField(
                    initialValue: item,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingMs,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: AppDimensions.iconSize18,
                        ),
                        onPressed: () => onRemove(index),
                        tooltip: context.l10n.commonDelete,
                      ),
                    ),
                    onChanged: (value) => onUpdate(index, value),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
          );
        }),

        // Add new item
        Padding(
          padding: AppDimensions.paddingOnlyTop4,
          child: Row(
            children: [
              if (showNumbers) const SizedBox(width: 28),
              Expanded(
                child: AddItemField(
                  hintText: hintText,
                  onAdd: onAdd,
                ),
              ),
            ],
          ),
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
        Icon(
          icon,
          size: AppDimensions.iconSizeM,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Container(
          padding: AppDimensions.paddingSymmetric8x2,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
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
