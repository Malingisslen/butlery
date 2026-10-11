/// The search field: paper with a 1 px border.control edge, radius 8, no
/// shadow, and the focus ring outside it (Komponentark v1 §07 Sökfält:
/// "Papper + border-control. Aldrig border-subtle, aldrig #FFF").

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/field_text_style.dart';

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
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    // The edge keeps its colour and width at focus; the ring outside the
    // box shows focus (Komponentark v1:657). Fill, disabled edge and hover
    // come from the app's input theme.
    final edge = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.outline,
        width: AppDimensions.borderWidthStandard,
      ),
    );
    return ButleryFocusRing(
      focused: _isFocused,
      borderRadius: radius,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        style: fieldTextStyle(
          context,
          enabled: widget.enabled,
          base: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurface,
          ),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? context.l10n.searchHint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
          prefixIcon:
              widget.prefixIcon ??
              ButleryIcon(
                ButleryIcons.search,
                color: _isFocused ? cs.onSurface : cs.onSurfaceVariant,
                size: AppDimensions.iconSizeM,
              ),
          suffixIcon:
              widget.suffixIcon ??
              (_hasText
                  ? IconButton(
                      icon: ButleryIcon(
                        ButleryIcons.x,
                        color: cs.onSurface,
                        size: AppDimensions.iconSizeM,
                      ),
                      onPressed: _clearText,
                      tooltip: context.l10n.commonClear,
                    )
                  : null),
          border: edge,
          enabledBorder: edge,
          focusedBorder: edge,
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.space12,
          ),
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
