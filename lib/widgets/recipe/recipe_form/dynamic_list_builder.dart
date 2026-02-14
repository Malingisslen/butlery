// lib/widgets/recipe/recipe_form/dynamic_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Builds a dynamic list of text fields with add/remove functionality.
/// Used for ingredients, instructions, and tags in recipe forms.
class DynamicListBuilder extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllers;
  final void Function(int index, String value) onUpdate;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const DynamicListBuilder({
    super.key,
    required this.label,
    required this.controllers,
    required this.onUpdate,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
        for (int index = 0; index < controllers.length; index++)
          _buildItemRow(context, index),
        if (controllers.isEmpty) _buildAddButton(context),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, int index) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers[index],
                decoration: InputDecoration(hintText: '$label ${index + 1}'),
                style: AppTextStyles.bodyMedium,
                textInputAction: TextInputAction.next,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: (value) => _handleChange(index, value),
              ),
            ),
            if (controllers.length > 1)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onRemove(index),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
      ],
    );
  }

  void _handleChange(int index, String value) {
    onUpdate(index, value);
    // Auto-add new field when typing in the last empty field
    if (index == controllers.length - 1 &&
        value.trim().isNotEmpty &&
        value.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onAdd());
    }
  }

  Widget _buildAddButton(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.add),
      label: Text(context.l10n.commonAddWithLabel(label)),
      onPressed: onAdd,
    );
  }
}
