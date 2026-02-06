// lib/widgets/common/search_filter/search_input_widget.dart
//
// UI Redesign: Green border (2px) + thicker rust bottom border (4px) + white background

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Search input field with clear functionality.
/// Uses TextFormField for better Flutter Web compatibility with text input handling.
///
/// UI Redesign styling:
/// - Green border (#4A7C59) on all sides (2px)
/// - Thicker rust bottom border (#8B5A3C) (4px)
/// - White background
class SearchInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool autofocus;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry? padding;

  /// Optional trailing widget inside the search field (e.g., filter button).
  final Widget? trailing;

  /// Use classic style without the rust bottom border accent.
  final bool useClassicStyle;

  const SearchInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Sök...',
    this.autofocus = false,
    this.onClear,
    this.padding,
    this.trailing,
    this.useClassicStyle = false,
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

  Widget? _buildSuffixIcon() {
    final hasClear = widget.controller.text.isNotEmpty;
    final hasTrailing = widget.trailing != null;

    if (!hasClear && !hasTrailing) return null;

    if (hasClear && hasTrailing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.clear,
              size: AppDimensions.iconSizeAction,
            ),
            onPressed: widget.onClear,
          ),
          widget.trailing!,
        ],
      );
    }

    if (hasClear) {
      return IconButton(
        icon: const Icon(
          Icons.clear,
          size: AppDimensions.iconSizeAction,
        ),
        onPressed: widget.onClear,
      );
    }

    return widget.trailing;
  }

  @override
  Widget build(BuildContext context) {
    // UI Redesign: Green border + rust bottom accent
    final searchField = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: AppTextStyles.bodyLarge,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTextStyles.bodyMediumMuted,
        prefixIcon: const Icon(
          Icons.search,
          size: AppDimensions.iconSizeAction,
          color: AppColors.forestGreen,
        ),
        suffixIcon: _buildSuffixIcon(),
        // Border configuration: green on all sides
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: const BorderSide(
            color: AppColors.forestGreen,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: const BorderSide(
            color: AppColors.forestGreen,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: const BorderSide(
            color: AppColors.forestGreen,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingMd,
        ),
      ),
    );

    // Classic style without rust accent
    if (widget.useClassicStyle) {
      if (widget.padding != null) {
        return Padding(
          padding: widget.padding!,
          child: searchField,
        );
      }
      return searchField;
    }

    // UI Redesign style: Add rust bottom border accent
    final styledSearchField = DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.rust,
            width: 4,
          ),
        ),
      ),
      child: searchField,
    );

    // Wrap with padding if provided
    if (widget.padding != null) {
      return Padding(
        padding: widget.padding!,
        child: styledSearchField,
      );
    }

    return styledSearchField;
  }
}
