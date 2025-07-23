// lib/widgets/common/search_filter/search_input_widget.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';

/// Search input field with clear functionality
class SearchInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool autofocus;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry? padding;

  const SearchInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Sök...',
    this.autofocus = false,
    this.onClear,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
        prefixIcon: Icon(
          Icons.search,
          size: AppDimensions.iconSizeAction,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: onClear,
              )
            : null,
      ),
    );

    // Wrap with padding if provided
    if (padding != null) {
      return Padding(
        padding: padding!,
        child: searchField,
      );
    }

    return searchField;
  }
}