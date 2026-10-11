/// The search field: paper with a 1 px border.control edge, radius 8, no
/// shadow, and the focus ring outside it (Komponentark v1 §07 Sökfält:
/// "Papper + border-control. Aldrig border-subtle, aldrig #FFF").

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
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
    this.trailing,
    this.focusNode,
    this.tokens,
    super.key,
  });

  /// The box over an empty library: disabled, saying there is nothing to
  /// search yet instead of inviting a search (Komponentark v1 §07
  /// "Inaktiverad (tomt bibliotek)").
  const ButlerySearchBox.nothingToSearch({super.key})
    : controller = null,
      hintText = null,
      onChanged = null,
      onSubmitted = null,
      onClear = null,
      autofocus = false,
      enabled = false,
      prefixIcon = null,
      suffixIcon = null,
      trailing = null,
      focusNode = null,
      tokens = null;

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

  /// A control after the clear button inside the box, such as a filter
  /// toggle or a microphone.
  final Widget? trailing;

  /// Focus node for the text field.
  final FocusNode? focusNode;

  /// Chosen terms drawn as removable chips inside the box, before the
  /// text (Komponentark v1 §07 "Tokeniserad"); the search glyph gives way
  /// to them. A list, even an empty one, keeps the box in this layout, so
  /// the field keeps its focus as the first term is added or the last is
  /// removed.
  final List<SearchToken>? tokens;

  @override
  State<ButlerySearchBox> createState() => _ButlerySearchBoxState();
}

/// One chosen term in a tokenised search box.
class SearchToken {
  const SearchToken({
    required this.id,
    required this.label,
    required this.onRemove,
  });

  /// Keeps each chip's place in the tree as tokens come and go.
  final String id;
  final String label;
  final VoidCallback onRemove;
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

  Widget? _buildSuffix(ColorScheme cs) {
    final clear = _hasText
        ? IconButton(
            icon: ButleryIcon(
              ButleryIcons.x,
              color: cs.onSurface,
              size: AppDimensions.iconSizeM,
            ),
            onPressed: _clearText,
            tooltip: context.l10n.commonClear,
          )
        : null;
    final trailing = widget.trailing;
    if (trailing == null) return clear;
    // Always a Row, so the trailing control keeps its place in the tree
    // when the clear button comes and goes.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [?clear, trailing],
    );
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
    final tokens = widget.tokens;
    if (tokens != null) return _buildTokenised(cs, radius, tokens);
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
          hintText: widget.enabled
              ? widget.hintText ?? context.l10n.searchHint
              : widget.hintText ?? context.l10n.searchNothingYet,
          // Disabled says why in readable text, as a disabled field's value
          // stays readable; the edge and the fill show the state.
          hintStyle: widget.enabled
              ? AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant)
              : fieldTextStyle(
                  context,
                  enabled: false,
                  base: AppTextStyles.bodyMedium,
                ),
          prefixIcon:
              widget.prefixIcon ??
              ButleryIcon(
                ButleryIcons.search,
                color: _isFocused ? cs.onSurface : cs.onSurfaceVariant,
                size: AppDimensions.iconSizeM,
              ),
          suffixIcon: widget.suffixIcon ?? _buildSuffix(cs),
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

  Widget _buildTokenised(
    ColorScheme cs,
    BorderRadius radius,
    List<SearchToken> tokens,
  ) {
    final suffix = widget.suffixIcon ?? _buildSuffix(cs);
    // The chips and the text share the box and wrap together; each line is
    // the 48 dp touch target, so a chip's remove target is that tall
    // (tokens.json controls.chip.hitbox) without growing the box.
    return ButleryFocusRing(
      focused: _isFocused,
      borderRadius: radius,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // The field below is the node a screen reader focuses; this only
        // widens the pointer target to the whole box.
        excludeFromSemantics: true,
        onTap: _focusNode.requestFocus,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
          ),
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.space8,
          ),
          decoration: BoxDecoration(
            color: widget.enabled ? cs.surface : cs.surfaceContainerHighest,
            border: Border.all(
              color: widget.enabled
                  ? cs.outline
                  : AppModeColors.surfaceDisabled(cs.brightness),
              width: AppDimensions.borderWidthStandard,
            ),
            borderRadius: radius,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimensions.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (tokens.isEmpty)
                      ButleryIcon(
                        ButleryIcons.search,
                        color: _isFocused ? cs.onSurface : cs.onSurfaceVariant,
                        size: AppDimensions.iconSizeM,
                      ),
                    for (final token in tokens)
                      _SearchTokenChip(key: ValueKey(token.id), token: token),
                    ConstrainedBox(
                      key: const ValueKey(#searchField),
                      constraints: const BoxConstraints(
                        minWidth: AppDimensions.minTouchTarget * 2,
                      ),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          enabled: widget.enabled,
                          textAlignVertical: TextAlignVertical.center,
                          style: fieldTextStyle(
                            context,
                            enabled: widget.enabled,
                            base: AppTextStyles.bodyMedium.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          // The box draws the edge; the field is a bare
                          // line, 48 dp tall so it is a full touch target.
                          decoration: InputDecoration(
                            hintText:
                                widget.hintText ?? context.l10n.searchHint,
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minHeight: AppDimensions.minTouchTarget,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ?suffix,
            ],
          ),
        ),
      ),
    );
  }
}

/// A chosen term: ink pill with paper text and a remove glyph, the whole
/// chip one remove button (Komponentark v1 §07; tokens.json
/// controls.chipCompactInField).
class _SearchTokenChip extends StatelessWidget {
  const _SearchTokenChip({required this.token, super.key});

  final SearchToken token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pill = BorderRadius.circular(AppDimensions.radiusPill);
    // The pill is its own Material so the press fill draws over the ink,
    // not under it; the line around it still takes the tap, so the target
    // is 48 dp tall (tokens.json controls.chip.hitbox).
    return Semantics(
      button: true,
      label: context.l10n.a11yRemoveIngredientChip(token.label),
      onTap: token.onRemove,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: token.onRemove,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minTouchTarget,
            minWidth: AppDimensions.minTouchTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: cs.onSurface,
              borderRadius: pill,
              child: PressFill(
                surface: PressSurface.ink,
                child: InkWell(
                  onTap: token.onRemove,
                  borderRadius: pill,
                  child: Padding(
                    padding: AppDimensions.chipCompactInFieldPadding,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          token.label,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: cs.surface,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        ButleryIcon(
                          ButleryIcons.x,
                          size: AppDimensions.iconSizeXs,
                          color: cs.surface,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
