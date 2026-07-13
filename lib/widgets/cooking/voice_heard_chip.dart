// lib/widgets/cooking/voice_heard_chip.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cooking/cooking_voice_controller.dart';

/// Transient «Hörde: "…"» chip (tasks/koksbutlern-plan.md, Batch D) —
/// the misheard-debug aid that sits near [VoiceAssistButton]. Auto-relevance
/// only: it renders [CookingVoiceController.lastHeard] whenever the
/// controller is idle with something to show, and collapses to nothing the
/// moment that stops being true (a new listen cycle, a command executing).
/// No timers of its own — the controller's own state transitions ARE the
/// dismissal signal.
class VoiceHeardChip extends StatelessWidget {
  const VoiceHeardChip({super.key, required this.controller});

  final CookingVoiceController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final heard = controller.lastHeard;
        if (heard == null || controller.state != VoiceAssistState.idle) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        final label = context.l10n.voiceAssistHeard(heard);

        return Semantics(
          label: label,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(color: cs.surface),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: cs.primary),
            ),
          ),
        );
      },
    );
  }
}
