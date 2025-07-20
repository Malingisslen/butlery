// lib/views/edit_recipe/edit_recipe_dynamic_list.dart

import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_dimensions.dart';

/// Dynamic list builder for ingredients, instructions, and tags
class EditRecipeDynamicList {
  
  /// Build a dynamic list widget with add/remove functionality
  static Widget build({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: AppDimensions.spacingS),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '$label ${index + 1}',
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) => onUpdate(index, value),
                  ),
                ),
                if (controllers.length > 1)
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => onRemove(index),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (controllers.isEmpty ||
            (controllers.isNotEmpty && controllers.last.text.isNotEmpty))
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}