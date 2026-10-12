// lib/widgets/common/buttons/image_source_buttons.dart
//
// The two big buttons that start any picture import (Skarmar v12 'Importera
// från bild'): take the photo now (ink) or choose it from the library
// (outlined). Both are 88 dp high with the glyph over the word, so an import
// that takes pictures draws them once.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ImageSourceButtons extends StatelessWidget {
  const ImageSourceButtons({
    required this.cameraLabel,
    required this.libraryLabel,
    required this.onCamera,
    required this.onLibrary,
    super.key,
  });

  final String cameraLabel;
  final String libraryLabel;

  /// Null disables both buttons, as while a picture is being read.
  final VoidCallback? onCamera;
  final VoidCallback? onLibrary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceButton(
            label: cameraLabel,
            icon: ButleryIcons.camera,
            filled: true,
            onTap: onCamera,
          ),
        ),
        const SizedBox(width: AppDimensions.space12),
        Expanded(
          child: _SourceButton(
            label: libraryLabel,
            icon: ButleryIcons.image,
            filled: false,
            onTap: onLibrary,
          ),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final ButleryGlyph icon;
  final bool filled;
  final VoidCallback? onTap;

  static const double _height = 88;

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
    return Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: filled ? cs.primary : Colors.transparent,
        shape: shape,
        child: PressFill(
          surface: filled ? PressSurface.ink : PressSurface.base,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: SizedBox(
              height: _height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ButleryIcon(icon, color: color),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelLarge.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
