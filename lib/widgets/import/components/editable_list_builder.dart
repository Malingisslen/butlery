// lib/widgets/import/components/editable_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// A reusable editable list widget for managing string items.
/// Used for ingredients and instructions in recipe import.
class EditableListBuilder extends StatefulWidget {
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
  State<EditableListBuilder> createState() => _EditableListBuilderState();
}

class _EditableListBuilderState extends State<EditableListBuilder> {
  // A field keeps its own text, so a row needs an identity that survives its
  // neighbours being removed; the item text changes on every keystroke and the
  // index shifts, so neither can be the key.
  late List<int> _ids = [for (final _ in widget.items) _nextId++];
  int _nextId = 0;

  @override
  void didUpdateWidget(EditableListBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    while (_ids.length < widget.items.length) {
      _ids.add(_nextId++);
    }
    if (_ids.length > widget.items.length) {
      _ids = _ids.sublist(0, widget.items.length);
    }
  }

  void _remove(int index) {
    if (index < _ids.length) _ids.removeAt(index);
    widget.onRemove(index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Existing items
        ...widget.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return ButleryFieldRow(
            key: ValueKey('editable-list-row-${_ids[index]}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showNumbers) ButleryRowNumber(index + 1),
              Expanded(
                child: ButleryRowField(
                  initialValue: item,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => widget.onUpdate(index, value),
                  suffixIcon: AppIconButton(
                    icon: ButleryIcons.x,
                    iconSize: AppDimensions.iconSize18,
                    onPressed: () => _remove(index),
                    semanticLabel: context.l10n.commonDelete,
                  ),
                ),
              ),
            ],
          );
        }),

        // Add new item
        ButleryFieldRow(
          children: [
            if (widget.showNumbers)
              const SizedBox(width: ButleryRowNumber.width),
            Expanded(
              child: AddItemField(
                hintText: widget.hintText,
                onAdd: widget.onAdd,
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
