// lib/views/edit_recipe/edit_recipe_dynamic_list.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Dynamic list builder for ingredients, instructions, and tags
class EditRecipeDynamicList {
  
  /// Build a dynamic list widget with add/remove functionality
  static Widget build({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
        for (int index = 0; index < controllers.length; index++)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        hintText: '$label ${index + 1}',
                      ),
                      style: AppTextStyles.bodyMedium,
                      textInputAction: TextInputAction.next,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) {
                        onUpdate(index, value);
                        // Add new field when typing in the last field and it becomes non-empty
                        if (index == controllers.length - 1 && 
                            value.trim().isNotEmpty && 
                            value.length == 1) { // Only on first character to prevent duplicates
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onAdd();
                          });
                        }
                      },
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
          ),
        if (controllers.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}