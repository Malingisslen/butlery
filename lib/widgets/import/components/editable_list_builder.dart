// lib/widgets/import/components/editable_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';

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
    final theme = Theme.of(context);

    return Column(
      children: [
        // Existing items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showNumbers) ...[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: AppDimensions.iconSize18),
                        onPressed: () => onRemove(index),
                        tooltip: 'Ta bort',
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
          padding: const EdgeInsets.only(top: 4),
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
        Icon(icon, size: AppDimensions.iconSizeM, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
