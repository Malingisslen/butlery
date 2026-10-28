// lib/widgets/voice/voice_mic_button.dart
//
// One button
// for every dictated field, so none of them draws its own.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    required this.listening,
    required this.onTap,
    required this.label,
    this.listeningWord,
    this.identifier,
    super.key,
  });

  final bool listening;

  /// Null while another field records or the import runs.
  final VoidCallback? onTap;

  /// What a screen reader says the button does.
  final String label;

  /// Said under the button while it listens.
  final String? listeningWord;

  /// Test and automation handle for the button's semantics node.
  final String? identifier;

  static const double _edge = 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.modeColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    );
    final glyph = listening
        ? ButleryIcon(
            ButleryIcons.stop,
            size: AppDimensions.iconSizeL,
            color: colors.onActionDanger,
          )
        : ButleryIcon(
            ButleryIcons.mic,
            size: AppDimensions.iconSizeL,
            color: cs.onPrimary,
          );
    final inkWell = InkWell(
      onTap: onTap,
      customBorder: shape,
      overlayColor: listening
          ? WidgetStatePropertyAll(colors.actionDangerPressed)
          : null,
      child: SizedBox(
        width: _edge,
        height: _edge,
        child: Center(child: glyph),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: identifier,
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: listening ? colors.actionDanger : cs.primary,
            shape: shape,
            child: listening
                ? inkWell
                : PressFill(surface: PressSurface.ink, child: inkWell),
          ),
        ),
        if (listening && listeningWord != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space4),
            child: Text(
              listeningWord!,
              style: AppTextStyles.bodySmallBold.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}
