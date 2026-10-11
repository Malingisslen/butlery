// lib/widgets/recipe/recipe_form/dynamic_list_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';

/// Builds a dynamic list of text fields with add/remove/reorder functionality.
/// Used for ingredients, instructions, and tags in recipe forms.
class DynamicListBuilder extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllers;
  final void Function(int index, String value) onUpdate;
  final VoidCallback onAdd;

  /// Called after a frame once the last field has text; must add a field
  /// only when the last field is still non-empty.
  final VoidCallback onLastFilled;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final int maxLength;

  const DynamicListBuilder({
    super.key,
    required this.label,
    required this.controllers,
    required this.onUpdate,
    required this.onAdd,
    required this.onLastFilled,
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
        const SizedBox(height: AppDimensions.space8),
        if (controllers.isNotEmpty && onReorder != null)
          _buildReorderableList(context)
        else ...[
          for (int index = 0; index < controllers.length; index++)
            _buildItemRow(context, index),
        ],
        _buildAddButton(context),
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
                  AppDimensions.radiusControl,
                ),
                child: child,
              );
            }
            return Material(
              elevation: animation.value * 4,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
    return ButleryFieldRow(
      key: ValueKey('${label}_$index'),
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsetsDirectional.only(end: AppDimensions.space4),
            child: ButleryIcon(
              ButleryIcons.drag,
              size: AppDimensions.iconSizeM,
            ),
          ),
        ),
        Expanded(child: _buildField(index)),
        if (controllers.length > 1)
          IconButton(
            icon: const ButleryIcon(ButleryIcons.trash2),
            onPressed: () => onRemove(index),
          ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, int index) {
    return ButleryFieldRow(
      children: [
        Expanded(child: _buildField(index)),
        if (controllers.length > 1)
          IconButton(
            icon: const ButleryIcon(ButleryIcons.trash2),
            onPressed: () => onRemove(index),
          ),
      ],
    );
  }

  Widget _buildField(int index) {
    return ButleryRowField(
      controller: controllers[index],
      hintText: '$label ${index + 1}',
      maxLength: maxLength,
      onChanged: (value) => _handleChange(index, value),
    );
  }

  void _handleChange(int index, String value) {
    onUpdate(index, value);
    // Same trigger as the sectioned ingredient editor: a paste or dictation
    // arrives as one multi-character change.
    if (index == controllers.length - 1 && value.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLastFilled());
    }
  }

  Widget _buildAddButton(BuildContext context) {
    return TextButton.icon(
      icon: const ButleryIcon(ButleryIcons.plus),
      label: Text(context.l10n.commonAddWithLabel(label.toLowerCase())),
      onPressed: onAdd,
    );
  }
}
