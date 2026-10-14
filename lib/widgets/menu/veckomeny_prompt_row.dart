/// The week menu's prompt: one field and, beside it, the view's one saffron
/// action (the approved week menu picture, 21-veckomeny-v2-3 and -4).
///
/// An ordinary field, with no tinted panel around it: the label above and the
/// button beside, or, on a week that is already planned, the field alone with
/// the question as its placeholder (-1). The button appears there once there is
/// something to generate from. Generating stays switched off offline with the
/// reason in words under the row.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

const double _kRoomForClear = 200;

/// Narrower than this and the button goes under the field.
const double _kRoomForField = 170;

class VeckomenyPromptRow extends StatelessWidget {
  const VeckomenyPromptRow({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.hasMenu,
    required this.compact,
    required this.onClear,
    required this.onChanged,
    required this.onGenerate,
    this.focusNode,
    this.voiceButton,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isGenerating;

  /// A generated menu is on screen, so the button reads "Generera ny meny".
  final bool hasMenu;

  /// Field only, the question as its placeholder, until there is text.
  final bool compact;
  final VoidCallback onClear;
  final VoidCallback onChanged;
  final VoidCallback onGenerate;
  final Widget? voiceButton;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final hasText = controller.text.isNotEmpty;
    final showButton = !compact || hasText || isGenerating;
    final buttonLabel = hasMenu ? l10n.menuGenerateNew : l10n.menuGenerate;

    Widget fieldFor({required bool showClear}) => StyledInput(
      controller: controller,
      focusNode: focusNode,
      enabled: !isGenerating,
      hint: compact ? l10n.menuPromptQuestion : l10n.menuPromptHint,
      semanticLabel: l10n.menuPromptQuestion,
      prefixIcon: compact ? const ButleryIcon(ButleryIcons.utensils) : null,
      suffixIcon: ((hasText && showClear) || voiceButton != null)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText && showClear)
                  IconButton(
                    icon: ButleryIcon(
                      ButleryIcons.x,
                      size: AppDimensions.iconSizeM,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: onClear,
                    tooltip: l10n.commonClear,
                  ),
                // Voice prompt (kb-whisper plan): push-to-talk mic — the
                // transcript lands editable in this same field.
                ?voiceButton,
              ],
            )
          : null,
      keyboardType: TextInputType.text,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onChanged: (_) => onChanged(),
    );

    // Beside the button the field has room for its text and the mic; the
    // clear cross comes only when there is room left for it too, so the
    // suffix never overflows the field.
    Widget generate({required bool expand}) => KeyedSubtree(
      key: const ValueKey('test-veckomeny-generate'),
      child: VeckomenyGenerateButton(
        label: buttonLabel,
        busy: isGenerating,
        busyLabel: buttonLabel,
        onGenerate: hasText ? onGenerate : null,
        reasonBelow: false,
        expand: expand,
      ),
    );

    Widget fieldRow(double maxWidth) {
      if (!showButton) return fieldFor(showClear: true);
      final painter = TextPainter(
        text: TextSpan(text: buttonLabel, style: AppTextStyles.labelLarge),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final buttonWidth = painter.width + 2 * AppDimensions.space24;
      painter.dispose();
      final fieldWidth = maxWidth - AppDimensions.space8 - buttonWidth;
      // Large text or a narrow phone: the button goes under the field.
      if (fieldWidth < _kRoomForField) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.space8,
          children: [fieldFor(showClear: true), generate(expand: true)],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: fieldFor(
              showClear: voiceButton == null || fieldWidth >= _kRoomForClear,
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          generate(expand: false),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            l10n.menuPromptQuestion,
            style: AppTextStyles.labelLarge.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppDimensions.space8),
        ],
        LayoutBuilder(builder: (_, c) => fieldRow(c.maxWidth)),
        VeckomenyConnectivity(
          builder: (context, isOnline) => isOnline
              ? const SizedBox.shrink()
              : const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.space8),
                  child: VeckomenyOfflineReason(),
                ),
        ),
      ],
    );
  }
}
