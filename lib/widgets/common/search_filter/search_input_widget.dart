// lib/widgets/common/search_filter/search_input_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';

/// Search input field with clear functionality.
/// Uses TextFormField for better Flutter Web compatibility with text input handling.
class SearchInputWidget extends StatefulWidget {
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
  State<SearchInputWidget> createState() => _SearchInputWidgetState();
}

class _SearchInputWidgetState extends State<SearchInputWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes to update suffix icon visibility
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Trigger rebuild to update suffix icon visibility
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use TextFormField for better web compatibility with text input
    final searchField = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: AppTextStyles.bodyLarge,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTextStyles.bodyMediumMuted,
        prefixIcon: Icon(
          Icons.search,
          size: AppDimensions.iconSizeAction,
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  size: AppDimensions.iconSizeAction,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: widget.onClear,
              )
            : null,
        // Explicit border configuration for Flutter Web compatibility
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: BorderSide(
            color: colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );

    // Wrap with padding if provided
    if (widget.padding != null) {
      return Padding(
        padding: widget.padding!,
        child: searchField,
      );
    }

    return searchField;
  }
}
