// lib/widgets/common/buttons/image_source_buttons.dart
//
// Both are at least 88 dp high with the glyph over the word and
// grow with the text, so an import that takes pictures draws them once.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ImageSourceButtons extends StatelessWidget {
  const ImageSourceButtons({
    required this.cameraLabel,
    required this.libraryLabel,
    required this.onCamera,
    required this.onLibrary,
    this.busy = false,
    super.key,
  });

  final String cameraLabel;
  final String libraryLabel;

  /// Null disables a button.
  final VoidCallback? onCamera;
  final VoidCallback? onLibrary;

  /// Whether a picture is being read. Both buttons keep their surface and
  /// name and get the plate line, so they never take the disabled look.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _SourceButton(
        label: cameraLabel,
        icon: ButleryIcons.camera,
        filled: true,
        busy: busy,
        onTap: onCamera,
      ),
      _SourceButton(
        label: libraryLabel,
        icon: ButleryIcons.image,
        filled: false,
        busy: busy,
        onTap: onLibrary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side each button gets half the width; a label word that
        // does not fit its half would be broken between letters, so the
        // buttons stack instead.
        final half = (constraints.maxWidth - AppDimensions.space12) / 2;
        final stacked =
            isLargeText(context) &&
            widestWord(context, [
                  cameraLabel,
                  libraryLabel,
                ], AppTextStyles.labelLarge) >
                half - 2 * _SourceButton.labelPadding;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(child: buttons[0]),
              const SizedBox(height: AppDimensions.space12),
              IntrinsicHeight(child: buttons[1]),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: AppDimensions.space12),
              Expanded(child: buttons[1]),
            ],
          ),
        );
      },
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final ButleryGlyph icon;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  static const double _minHeight = 88;
  static const double labelPadding = AppDimensions.space8;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      side: filled
          ? BorderSide.none
          : BorderSide(
              color: cs.primary,
              width: AppDimensions.borderWidthOutlinedEdge,
            ),
    );
    final color = filled ? cs.onPrimary : cs.onSurface;
    final button = Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: filled ? cs.primary : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: PressFill(
          surface: filled ? PressSurface.ink : PressSurface.base,
          child: InkWell(
            // Busy keeps the button focusable, so Enter must reach a no-op.
            onTap: busy ? PlateLineButton.ignore : onTap,
            customBorder: shape,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _minHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.space8,
                        horizontal: labelPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ButleryIcon(icon, color: color),
                          const SizedBox(height: AppDimensions.space8),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (busy)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: ButtonPlateLine(color: color, onFill: filled),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return BusyButtonSemantics(busy: busy, name: label, child: button);
  }
}
