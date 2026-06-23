// lib/widgets/recipe/recipe_form/dynamic_list_builder.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Builds a dynamic list of text fields with add/remove/reorder functionality.
/// Used for ingredients, instructions, and tags in recipe forms.
class DynamicListBuilder extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllers;
  final void Function(int index, String value) onUpdate;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final int maxLength;

  const DynamicListBuilder({
    super.key,
    required this.label,
    required this.controllers,
    required this.onUpdate,
    required this.onAdd,
    required this.onRemove,
    this.onReorder,
    this.maxLength = 500,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
        if (controllers.isNotEmpty && onReorder != null)
          _buildReorderableList(context)
        else ...[
          for (int index = 0; index < controllers.length; index++)
            _buildItemRow(context, index),
        ],
        if (controllers.isEmpty) _buildAddButton(context),
      ],
    );
  }

  Widget _buildReorderableList(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: controllers.length,
      onReorder: onReorder!,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            if (!AnimationUtils.shouldAnimate(context)) {
              return Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusS,
                ),
                child: child,
              );
            }
            return Material(
              elevation: animation.value * 4,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return _buildReorderableRow(context, index);
      },
    );
  }

  Widget _buildReorderableRow(BuildContext context, int index) {
    return Padding(
      key: ValueKey('${label}_$index'),
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
              child: Icon(Icons.drag_handle, size: AppDimensions.iconSizeM),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controllers[index],
              decoration: InputDecoration(hintText: '$label ${index + 1}'),
              style: AppTextStyles.bodyMedium,
              textInputAction: TextInputAction.next,
              maxLines: null,
              maxLength: maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
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
                maxLength: maxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
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
