/// Custom search box widget with forest green/rust border treatment.
///
/// Provides a styled search input that matches the Butlery UI redesign:
/// - White background with subtle border
/// - Forest green focus border with rust accent on bottom
/// - Matching icons and typography

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/components/input_themes.dart';

/// Custom search box with Butlery styling.
///
/// Example:
/// ```dart
/// ButlerySearchBox(
///   hintText: 'sök recept...',
///   onChanged: (value) => viewModel.search(value),
/// )
/// ```
class ButlerySearchBox extends StatefulWidget {
  /// Creates a Butlery-styled search box.
  const ButlerySearchBox({
    this.controller,
    this.hintText = 'sök...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    super.key,
  });

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Hint text displayed when the field is empty.
  final String hintText;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Callback when the user submits.
  final ValueChanged<String>? onSubmitted;

  /// Callback when the clear button is pressed.
  final VoidCallback? onClear;

  /// Whether to autofocus the field.
  final bool autofocus;

  /// Whether the field is enabled.
  final bool enabled;

  /// Custom prefix icon (defaults to search icon).
  final Widget? prefixIcon;

  /// Custom suffix icon (defaults to clear button when text is present).
  final Widget? suffixIcon;

  /// Focus node for the text field.
  final FocusNode? focusNode;

  @override
  State<ButlerySearchBox> createState() => _ButlerySearchBoxState();
}

class _ButlerySearchBoxState extends State<ButlerySearchBox> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = _controller.text.isNotEmpty;

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);

    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDimensions.animationDurationFast,
      decoration: _isFocused
          ? InputThemes.searchBoxDecorationFocused
          : InputThemes.searchBoxDecoration,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textLight,
          ),
          prefixIcon: widget.prefixIcon ??
              Icon(
                Icons.search,
                color: _isFocused ? AppColors.forestGreen : AppColors.textLight,
                size: AppDimensions.iconSizeM,
              ),
          suffixIcon: widget.suffixIcon ??
              (_hasText
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textLight,
                        size: AppDimensions.iconSizeM,
                      ),
                      onPressed: _clearText,
                      tooltip: 'Rensa',
                    )
                  : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
          ),
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}

/// A search box variant that appears in the header.
///
/// Use this when you want the search box to be part of the header area.
class ButleryHeaderSearchBox extends StatelessWidget {
  /// Creates a header search box.
  const ButleryHeaderSearchBox({
    this.controller,
    this.hintText = 'sök...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onTap,
    this.readOnly = false,
    super.key,
  });

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Hint text displayed when the field is empty.
  final String hintText;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Callback when the user submits.
  final ValueChanged<String>? onSubmitted;

  /// Callback when the clear button is pressed.
  final VoidCallback? onClear;

  /// Callback when the field is tapped (useful for read-only mode).
  final VoidCallback? onTap;

  /// Whether the field is read-only (tapping triggers [onTap]).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: readOnly
          ? GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadius8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: AppColors.textLight,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        hintText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ButlerySearchBox(
              controller: controller,
              hintText: hintText,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onClear: onClear,
            ),
    );
  }
}
