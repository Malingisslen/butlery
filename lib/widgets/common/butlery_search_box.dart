/// Custom search box widget with forest green/rust border treatment.
///
/// Provides a styled search input that matches the Butlery UI redesign:
/// - White background with subtle border
/// - Forest green focus border with rust accent on bottom
/// - Matching icons and typography

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
    this.hintText,
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
  final String? hintText;

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
    final cs = Theme.of(context).colorScheme;
    // Focus is the canonical ring outside the box; the box's own edge no
    // longer thickens at focus (Komponentark v1:657). The ring shows for
    // keyboard focus, like every other control (beslut-paket2 D3).
    return ButleryFocusRing(
      focused: _isFocused,
      child: AnimatedContainer(
        duration: AppDimensions.animationDurationFast.respectingMotion(context),
        decoration: InputThemes.searchBoxDecoration,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? context.l10n.searchHint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: cs.outline,
            ),
            prefixIcon:
                widget.prefixIcon ??
                ButleryIcon(
                  ButleryIcons.search,
                  color: _isFocused ? cs.onSurface : cs.outline,
                  size: AppDimensions.iconSizeM,
                ),
            suffixIcon:
                widget.suffixIcon ??
                (_hasText
                    ? IconButton(
                        icon: ButleryIcon(
                          ButleryIcons.x,
                          color: cs.outline,
                          size: AppDimensions.iconSizeM,
                        ),
                        onPressed: _clearText,
                        tooltip: context.l10n.commonClear,
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
      ),
    );
  }
}
